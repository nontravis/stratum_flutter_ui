"""Runs one integration plan on its booted target and splits the run's per-test report into one result per file.

Design section 9 owns the run table and the split pass rule: a file's result comes from the run's per-test report
(`flutter test --file-reporter json`, or the `integration_response_data.json` a `flutter drive` driver writes), never
from the exit code alone. C6 owns when a run classes `env` instead (`scripts/lib/run.sh:31-44`, `lane.md:64`). Every
command goes through a `Runner`, so a unit test swaps in `unit/round_fakes.py::FakeRunner`.
"""

from __future__ import annotations

import contextlib
import json
import os
import re
import socket
import subprocess
import time
from collections.abc import Iterable, Iterator, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Literal

from stratum_e2e.round import linux_docker
from stratum_e2e.round.android_host import reserve_port
from stratum_e2e.round.android_traps import strip_drive_prefix
from stratum_e2e.round.boot import Booter, BootRecord
from stratum_e2e.round.catalog import Target
from stratum_e2e.round.entry import RunPlan, cleanup, write_run_file
from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.runner import Completed, Runner

DRIVER = "test_driver/integration_test.dart"
INTEGRATION_FOLDER = "integration_test"
REPORT_NAME = "report.json"
RESPONSE_NAME = "integration_response_data.json"
LOG_NAME = "flutter.log"

# A log line holding one of these never ran a test, so the run is `env`, never `fail` (`scripts/lib/run.sh:31`).
# `DT_WATCHER:` is left out: the round's own timeout replaces the bash watcher that wrote it.
ENV_SIGNS = (
    "Unable to start the app on the device",
    "device offline",
    "ADB exited with exit code",
    "touch up failed, pointer may be held down",
)

# skwasm needs a browser with WasmGC, which Chrome shipped at 119 (`web.sh:21-23`).
CHROME_WASMGC_FLOOR = 119
CHROME_APP = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CHROMEDRIVER_PORTS = ("chromedriver", 4444, 4474, 1)
CHROMEDRIVER_WAIT_S = 30.0

_NOT_FOUND_STATUS = 127
_NO_TESTS_FOUND = "No tests were found"
_NO_TESTS_STATUS = 79
_PROBE_TIMEOUT_S = 30.0
_CHROMEDRIVER_GONE_S = 5.0
_POLL_S = 0.2
_COUNT = re.compile(r"\+(\d+)(?: ~(\d+))?(?: -(\d+))?:")
_TAG = r"(?:[a-z][a-z0-9_]*/)?us\d+/(?:fr\d+(?:/e\d+)?|s\d+)"
_TAG_LIST = re.compile(rf"(?<!\S)({_TAG}(?:, {_TAG})*)(?=:|\s\()")
_REPEAT_TEST = re.compile(r"(?:^|\s)REPEAT run \d+ ")
_FIRST_NUMBER = re.compile(r"\d+")

_Status = Literal["pass", "fail", "skip"]


@dataclass(frozen=True)
class FileResult:
    """One integration file's result on one target.

    `passed` of `runs` reads `n/N`: a wrapped file's passing iterations of `plan.repeat`, else 1/1 on a pass and 0/1
    otherwise. `reason` says why the file did not pass. `tags` are the story ids of the tests that ran.
    """

    cls: Literal["pass", "fail", "env"]
    passed: int
    runs: int
    reason: str
    tags: tuple[str, ...]


@dataclass(frozen=True)
class RunOutcome:
    """One run of a plan: the command it ran, its wall time, and one result per file.

    `argv` is empty and `seconds` 0 when the run never launched (the device, a tool, or a pre-flight check stopped it).
    """

    argv: tuple[str, ...]
    seconds: float
    files: dict[str, FileResult]


@dataclass(frozen=True)
class LinuxRun:
    """What a Linux run needs besides its plan: the image `ensure_image` tagged, the repo mounted at `/work`, and the
    app's folder inside that repo."""

    tag: str
    repo_root: Path
    app_rel: str


@dataclass(frozen=True)
class _Row:
    name: str
    status: _Status


def run_timeout_s(plan: RunPlan, per_file_timeout_s: float) -> float:
    """The bound of one run of `plan`: the per-file budget times its files, a wrapped file counted `plan.repeat` times.

    Raises `ValueError` for a budget that is not positive.
    """
    if per_file_timeout_s <= 0:
        raise ValueError(f"per_file_timeout_s must be positive, got {per_file_timeout_s}")
    extra_runs = max(plan.repeat - 1, 0) * len(plan.wrapped)
    return per_file_timeout_s * (len(plan.files) + extra_runs)


def run_argv(
    plan: RunPlan,
    target: Target,
    run_files: Sequence[Path],
    device_id: str,
    item_dir: Path,
    driver_port: int | None,
    *,
    linux: LinuxRun | None = None,
) -> list[str]:
    """The command of design section 9's run table that runs `run_files` for `plan` on `target`.

    `run_files` are relative to the app folder: the plan's entry file, or a sequence's own files in order (a sequence
    has no entry). `driver_port` is the chromedriver port of a web run; `linux` is the image of a Linux run.
    Raises `ValueError` for what no row covers: an unknown platform or Android build mode, `--plain-name` or more than
    one file on `flutter drive`, a web run with no driver port, a Linux run with no `LinuxRun`.
    """
    files = [path.as_posix() for path in run_files]
    if not files:
        raise ValueError(f"run_argv needs at least one file for {target.name}")
    if target.platform == "linux":
        if linux is None:
            raise ValueError(f"a linux run needs its LinuxRun (image tag, repo root, app folder): {target.name}")
        sequence = plan.kind == "sequence"
        inner = linux_docker.inner_command(files, plan.plain_name, sequence)
        container = linux_docker.container_name(target.name)
        return linux_docker.docker_run_argv(
            linux.tag, linux.repo_root, linux.app_rel, item_dir, inner, container, sequence, target.name
        )
    if target.platform not in ("android", "ios", "macos", "web"):
        raise ValueError(f"no integration run for platform {target.platform!r} ({target.name})")
    if target.platform == "android" and target.build_mode not in (None, "debug", "profile"):
        raise ValueError(f"no integration run for android build mode {target.build_mode!r} ({target.name})")
    if _drives(target):
        if plan.plain_name is not None or len(files) != 1:
            raise ValueError(f"flutter drive runs one file and takes no --plain-name: {target.name} {files}")
        if target.platform == "android":
            return [
                "flutter", "drive", "--profile", "--no-pub", "--driver", DRIVER, "--target", files[0], "-d", device_id,
            ]
        if driver_port is None:
            raise ValueError(f"a web run needs its chromedriver driver port: {target.name}")
        argv = [
            "flutter", "drive", f"--driver={DRIVER}", f"--target={files[0]}", "-d", "web-server",
            f"--browser-name={target.browser or 'chrome'}", "--headless", "--no-pub", f"--driver-port={driver_port}",
        ]
        return [*argv, "--wasm"] if target.wasm else argv
    device = "macos" if target.platform == "macos" else device_id
    argv = [
        "flutter", "test", *files, "-d", device, "--no-pub", "--reporter", "expanded",
        "--file-reporter", f"json:{item_dir / REPORT_NAME}",
    ]
    if plan.plain_name is not None:
        argv += ["--plain-name", plan.plain_name]
    if plan.kind == "sequence":
        argv.append("--no-uninstall")
    return argv


def classify_env(log: str, exit_code: int, timed_out: bool) -> str | None:
    """Why the environment, not the code under test, ended a run whose output is `log`; `None` when it did not.

    `env` is the round's own timeout, an `ENV_SIGNS` line, or `No tests were found` with exit 79 or with no test
    started. A test started when any `+P ~S -F` count line reads above 0 in total, so a failed or skipped test counts
    as started. `No tests were found` after a test started is left to the per-file reader, which fails the files it
    lost.
    """
    if timed_out:
        return "run timeout"
    sign = next((sign for sign in ENV_SIGNS if sign in log), None)
    if sign is not None:
        return sign
    if _NO_TESTS_FOUND in log:
        if exit_code == _NO_TESTS_STATUS:
            return f"{_NO_TESTS_FOUND} (exit {_NO_TESTS_STATUS})"
        if not any(sum(int(count or 0) for count in line) > 0 for line in _COUNT.findall(log)):
            return f"{_NO_TESTS_FOUND} before any test started"
    return None


def story_tags(test_name: str) -> tuple[str, ...]:
    """The story ids a Dart test name leads with (TRACE-TEST shape), in order and without repeats.

    A tag list starts a name or follows a space and ends at `:` or ` (`, so a group's tags and its test's tags both
    count, and a tag mentioned in prose does not.
    """
    found = [tag for tags in _TAG_LIST.findall(test_name) for tag in tags.split(", ")]
    return tuple(dict.fromkeys(found))


def repeat_count(log: str, prefix: str) -> int:
    """How many iterations of the wrapped block `prefix` passed: the distinct `i` of its `REPEAT <prefix> <i>/<n> ok`
    lines, so a line the log repeats counts once."""
    line = re.compile(rf"^REPEAT {re.escape(prefix)} (\d+)/\d+ ok\r?$", re.MULTILINE)
    return len(set(line.findall(log)))


def read_test_report(lines: Iterable[str], plan: RunPlan, *, log: str = "") -> dict[str, FileResult]:
    """One result per file of `plan` from a `flutter test --file-reporter json` report, one event per line.

    A test maps to a file by its group prefix (the entry names each group by the file's path), or, in a sequence, by
    its suite path. A hidden test (loading, a passing `setUpAll` or `tearDownAll`) never counts; a test that started
    and never finished failed. A line that is not a JSON object, such as one a killed run cut short, is skipped. `log`
    is the run's output, where a wrapped file's `REPEAT` lines are counted.
    """
    suites: dict[int, str] = {}
    started: dict[int, tuple[str, int | None]] = {}
    finished: dict[int, _Status | None] = {}
    for line in lines:
        event = _json_object(line)
        if event is None:
            continue
        kind = event.get("type")
        if kind == "suite":
            suite = _mapping(event.get("suite"))
            suite_id, path = _int(suite.get("id")), suite.get("path")
            if suite_id is not None and isinstance(path, str):
                suites[suite_id] = path
        elif kind == "testStart":
            test = _mapping(event.get("test"))
            test_id, name = _int(test.get("id")), test.get("name")
            if test_id is not None and isinstance(name, str):
                started[test_id] = (name, _int(test.get("suiteID")))
        elif kind == "testDone":
            test_id = _int(event.get("testID"))
            if test_id is not None:
                finished[test_id] = _done_status(event)
    rows: dict[str, list[_Row]] = {}
    for test_id, (name, suite_id) in started.items():
        status = finished.get(test_id, "fail")
        if status is None:
            continue
        located = _locate(plan, name, suites.get(suite_id, "") if suite_id is not None else "")
        if located is not None:
            rows.setdefault(located[0], []).append(_Row(located[1], status))
    return {file: _judge(plan, file, rows.get(file), log) for file in plan.files}


def read_drive_response(
    data: Mapping[str, object] | None, plan: RunPlan, *, log: str = ""
) -> dict[str, FileResult]:
    """One result per file of `plan` from a `flutter drive` run's `integration_response_data.json`.

    The entry stores, under `stratum_round`, each file's map of test name to `pass` or `fail`; a value other than
    `pass` fails. No data, or no map for a file, fails that file `no report entry`; an empty map (every test skipped)
    fails it `all skipped`. `log` is the run's output, where a wrapped file's `REPEAT` lines are counted.
    """
    per_file = (data or {}).get("stratum_round")
    rows: dict[str, list[_Row]] = {}
    if isinstance(per_file, Mapping):
        for file in plan.files:
            tests = per_file.get(file)
            if isinstance(tests, Mapping):
                rows[file] = [_Row(str(name), "pass" if value == "pass" else "fail") for name, value in tests.items()]
    return {file: _judge(plan, file, rows.get(file), log) for file in plan.files}


def port_accepts(port: int) -> bool:
    """Whether something takes a TCP connection on `127.0.0.1:<port>`."""
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=1.0):
            return True
    except OSError:
        return False


def run_plan(
    plan: RunPlan,
    target: Target,
    record: BootRecord,
    booter: Booter,
    app_dir: Path,
    item_dir: Path,
    runner: Runner,
    per_file_timeout_s: float,
    port_dir: Path,
    *,
    flutter_version: str | None = None,
) -> RunOutcome:
    """Run `plan` once on the device of `record` and return its command, wall time, and one result per file.

    Readies the device (`booter.before_file`), then the platform: a web run checks Chrome (a readable version, and
    `CHROME_WASMGC_FLOOR` for `wasm`), then holds a chromedriver on a port reserved in `port_dir` for the run; a Linux
    run checks the plugin packages, then
    builds or reuses the image (from `flutter_version`, read here when the caller has none), resets a sequence's home
    volume, and removes a stale container. It writes the plan's entry right before the launch and `cleanup` removes
    it after, whatever happens. The output goes to `<item_dir>/flutter.log`, a drive run's logcat prefix stripped.
    A failed preparation, a missing command, or `classify_env` classes every file `env` with the reason.
    Raises `ValueError` for a plan no run covers (`run_argv`) or a repeat prefix with no block to wrap.
    """
    timeout_s = run_timeout_s(plan, per_file_timeout_s)
    item_dir = item_dir.absolute()
    item_dir.mkdir(parents=True, exist_ok=True)
    for stale in (REPORT_NAME, RESPONSE_NAME):
        (item_dir / stale).unlink(missing_ok=True)
    try:
        with contextlib.ExitStack() as stack:
            booter.before_file(record)
            driver_port: int | None = None
            linux: LinuxRun | None = None
            if target.platform == "web":
                _require_chrome(runner, target.wasm)
                driver_port = stack.enter_context(_chromedriver(runner, port_dir, item_dir))
            elif target.platform == "linux":
                linux = _prepare_linux(plan, target, app_dir, runner, flutter_version)
            argv = tuple(run_argv(plan, target, _run_files(plan, app_dir), record.device_id, item_dir, driver_port,
                                  linux=linux))
            env = {"FLUTTER_TEST_OUTPUTS_DIR": str(item_dir)} if _drives(target) else None
            started = time.monotonic()
            completed = runner.run(argv, timeout_s=timeout_s, cwd=app_dir, env=env)
            seconds = time.monotonic() - started
        if completed.timed_out and linux is not None:
            # Killing `docker run` leaves its container running; end it before the next run takes the name.
            runner.run(linux_docker.remove_stale_container_argv(target.name), timeout_s=_PROBE_TIMEOUT_S)
    except RoundEnvError as error:
        return RunOutcome((), 0.0, _env_files(plan, error.reason))
    finally:
        cleanup(app_dir / INTEGRATION_FOLDER)
    output = completed.stdout + completed.stderr
    log = strip_drive_prefix(output) if _drives(target) else output
    (item_dir / LOG_NAME).write_text(log, encoding="utf-8")
    return RunOutcome(argv, seconds, _files_of(plan, target, argv, completed, log, item_dir))


def _drives(target: Target) -> bool:
    return target.platform == "web" or (target.platform == "android" and target.build_mode == "profile")


def _run_files(plan: RunPlan, app_dir: Path) -> list[Path]:
    if plan.kind == "sequence":
        return [Path(INTEGRATION_FOLDER, file) for file in plan.files]
    return [write_run_file(plan, app_dir / INTEGRATION_FOLDER).relative_to(app_dir)]


def _files_of(
    plan: RunPlan, target: Target, argv: Sequence[str], completed: Completed, log: str, item_dir: Path
) -> dict[str, FileResult]:
    if completed.status == _NOT_FOUND_STATUS and not completed.stdout:
        return _env_files(plan, f"{argv[0]} not found")
    reason = classify_env(log, completed.status, completed.timed_out)
    if reason is not None:
        return _env_files(plan, reason)
    if _drives(target):
        response = item_dir / RESPONSE_NAME
        data = _json_object(response.read_text(encoding="utf-8", errors="replace")) if response.is_file() else None
        return read_drive_response(data, plan, log=log)
    report = item_dir / REPORT_NAME
    lines = report.read_text(encoding="utf-8", errors="replace").splitlines() if report.is_file() else []
    return read_test_report(lines, plan, log=log)


def _env_files(plan: RunPlan, reason: str) -> dict[str, FileResult]:
    return {
        file: FileResult("env", 0, plan.repeat if file in plan.wrapped else 1, reason, ()) for file in plan.files
    }


def _judge(plan: RunPlan, file: str, rows: Sequence[_Row] | None, log: str) -> FileResult:
    """The split pass rule for one file: at least one test ran and every test that ran passed; a skip counts neither
    way. A wrapped file also needs every iteration of each block (`repeat_count == plan.repeat`); its weakest block
    gives its `n/N`."""
    prefixes = plan.wrapped.get(file, ())
    ran = [row for row in rows or () if row.status != "skip"]
    tags = tuple(dict.fromkeys(tag for row in ran for tag in story_tags(row.name)))
    iterations = [row for row in ran if prefixes and _REPEAT_TEST.search(row.name)]
    own = [row for row in ran if row not in iterations]
    reasons: list[str] = []
    if rows is None:
        reasons.append("no report entry")
    elif not ran:
        reasons.append("all skipped")
    reasons += _failed([row for row in own if row.status == "fail"])
    if not prefixes:
        return FileResult("fail" if reasons else "pass", 0 if reasons else 1, 1, "; ".join(reasons), tags)
    count = min(repeat_count(log, prefix) for prefix in prefixes)
    if count != plan.repeat:
        reasons.append(f"{count}/{plan.repeat}")
    else:
        reasons += _failed([row for row in iterations if row.status == "fail"])
    return FileResult("fail" if reasons else "pass", count, plan.repeat, "; ".join(reasons), tags)


def _failed(rows: Sequence[_Row]) -> list[str]:
    return [f"failed: {'; '.join(row.name for row in rows)}"] if rows else []


def _locate(plan: RunPlan, name: str, suite_path: str) -> tuple[str, str] | None:
    """The file a reported test belongs to and its name without the entry's group prefix, or `None`."""
    if plan.kind == "sequence":
        parts = PurePosixPath(suite_path).parts
        for file in plan.files:
            tail = (INTEGRATION_FOLDER, *PurePosixPath(file).parts)
            if parts[-len(tail):] == tail:
                return file, name
        return None
    for file in plan.files:
        if name.startswith(f"{file} "):
            return file, name[len(file) + 1:]
    return None


def _done_status(event: Mapping[str, object]) -> _Status | None:
    if event.get("hidden") is True:
        return None
    if event.get("skipped") is True:
        return "skip"
    return "pass" if event.get("result") == "success" else "fail"


def _json_object(text: str) -> Mapping[str, object] | None:
    try:
        value = json.loads(text)
    except ValueError:
        return None
    return value if isinstance(value, dict) else None


def _mapping(value: object) -> Mapping[str, object]:
    return value if isinstance(value, dict) else {}


def _int(value: object) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def _require_chrome(runner: Runner, wasm: bool) -> None:
    """Raises `RoundEnvError` unless Chrome reports a version, and for `wasm` unless it is at least
    `CHROME_WASMGC_FLOOR`.

    A missing Chrome would only fail chromedriver's session, which reads as every file failing. `--wasm` on an older
    browser falls back to CanvasKit without failing, so a skwasm result could not be told from a CanvasKit one
    (`web.sh:153-171`).
    """
    major: int | None = None
    for binary in (CHROME_APP, "google-chrome"):
        probe = runner.run([binary, "--version"], timeout_s=_PROBE_TIMEOUT_S)
        if probe.status == 0:
            number = _FIRST_NUMBER.search(probe.stdout)
            major = int(number.group()) if number else None
            break
    need = f"wasm needs Chrome {CHROME_WASMGC_FLOOR}+ for WasmGC (skwasm)" if wasm else "web needs Chrome"
    if major is None:
        raise RoundEnvError(f"{need}; no Chrome version could be read from {CHROME_APP} or google-chrome")
    if wasm and major < CHROME_WASMGC_FLOOR:
        raise RoundEnvError(f"{need}; found Chrome {major}")


@contextlib.contextmanager
def _chromedriver(runner: Runner, port_dir: Path, item_dir: Path) -> Iterator[int]:
    """Holds a chromedriver on a reserved port for one web run; stops it and frees the port after (`web.sh::p_run`)."""
    name, low, high, step = CHROMEDRIVER_PORTS
    reservation = reserve_port(name, low, high, step, set(), port_dir)
    try:
        try:
            process = runner.spawn(["chromedriver", f"--port={reservation.port}"], log=item_dir / "chromedriver.log")
        except FileNotFoundError as error:
            raise RoundEnvError("chromedriver not found: install it from Chrome for Testing") from error
        try:
            _wait_for_port(process, reservation.port)
            yield reservation.port
        finally:
            _stop(process)
    finally:
        reservation.release()


def _wait_for_port(process: subprocess.Popen[bytes], port: int) -> None:
    deadline = time.monotonic() + CHROMEDRIVER_WAIT_S
    while not port_accepts(port):
        if process.poll() is not None:
            raise RoundEnvError(f"chromedriver exited (status {process.returncode}) before it took port {port}")
        if time.monotonic() >= deadline:
            raise RoundEnvError(f"chromedriver never answered on port {port} within {CHROMEDRIVER_WAIT_S:g} s")
        time.sleep(_POLL_S)


def _stop(process: subprocess.Popen[bytes]) -> None:
    """Kill `process` and wait, bounded, for it to go, so the next run never finds it still on the port."""
    if process.poll() is None:
        process.kill()
    deadline = time.monotonic() + _CHROMEDRIVER_GONE_S
    while process.poll() is None and time.monotonic() < deadline:
        time.sleep(_POLL_S)


def _prepare_linux(
    plan: RunPlan, target: Target, app_dir: Path, runner: Runner, flutter_version: str | None
) -> LinuxRun:
    """The image of a Linux run, ready to launch; the app's parent folder is the repo its `path: ../` needs at `/work`.

    Raises `RoundEnvError` from the package check, the image build, or the home-volume reset.
    """
    app = app_dir.resolve()
    resolved = linux_docker.linux_deps_resolve(
        runner,
        app / "linux" / "flutter" / "generated_plugins.cmake",
        linux_docker.host_pub_cache(os.environ, Path.home()),
        [app / ".dart_tool" / "package_config.json", app.parent / ".dart_tool" / "package_config.json"],
    )
    linux_docker.check_packages(resolved, target.apt)
    tag = linux_docker.ensure_image(runner, target, flutter_version or linux_docker.flutter_version(runner))
    if plan.kind == "sequence":
        linux_docker.reset_home_volume(runner, target.name)
    runner.run(linux_docker.remove_stale_container_argv(target.name), timeout_s=_PROBE_TIMEOUT_S)
    return LinuxRun(tag=tag, repo_root=app.parent, app_rel=app.name)
