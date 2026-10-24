"""Unit tests for the integration run commands and the per-file reader (design section 9); no Flutter, no device."""

from __future__ import annotations

import json
import shutil
import subprocess
from collections.abc import Mapping, Sequence
from pathlib import Path
from types import MappingProxyType
from typing import Literal, cast

import pytest

from stratum_e2e.round import integration_run, linux_docker
from stratum_e2e.round.android_host import reserve_port
from stratum_e2e.round.boot import BootRecord
from stratum_e2e.round.catalog import Target
from stratum_e2e.round.entry import ENTRY_PREFIX, RunPlan
from stratum_e2e.round.errors import RoundEnvError
from stratum_e2e.round.integration_run import (
    CHROME_APP,
    CHROME_WASMGC_FLOOR,
    ENV_SIGNS,
    FileResult,
    LinuxRun,
    check_runnable,
    classify_env,
    read_drive_response,
    read_test_report,
    repeat_count,
    run_argv,
    run_plan,
    run_timeout_s,
    story_tags,
)
from stratum_e2e.round.runner import Completed
from unit.round_fakes import FakeProcess, FakeRunner

REPORTS = Path(__file__).parent / "fixtures" / "round" / "reports"
BUILDS = Path(__file__).parent / "fixtures" / "round" / "builds"
INTEGRATION_FIXTURE = Path(__file__).parent / "fixtures" / "round" / "integration_test"
KEYBOARD = "common/keyboard_visibility_scope_test.dart"
SMOKE = "smoke/semantics_id_test.dart"
WEB_VIEW = "common/web_view_test.dart"
RESTART_1 = "common/page_layout_restart_1_linux_test.dart"
RESTART_2 = "common/page_layout_restart_2_linux_test.dart"
REPEAT_PREFIX = "co01_02/us03/s1"
ENTRY_FILE = Path(f"integration_test/{ENTRY_PREFIX}x_test.dart")
ITEM = Path("/round/item")

PIXEL_2 = Target(name="pixel_2", platform="android", build_mode="debug")
PIXEL_8 = Target(name="pixel_8", platform="android", build_mode="profile")
IPHONE = Target(name="iphone_16", platform="ios", device="iPhone 16", runtime="iOS 18.6")
MAC = Target(name="mac", platform="macos")
CHROME = Target(name="chrome", platform="web", browser="chrome")
CHROME_WASM = Target(name="chrome_wasm", platform="web", browser="chrome", wasm=True)
LINUX = Target(name="linux", platform="linux", apt=("libsecret-1-dev",), e2e=False)

Entry = tuple[tuple[str, ...], Completed]
_LAUNCHES = {("flutter", "test"), ("flutter", "drive"), ("docker", "run")}


def done(status: int = 0, stdout: str = "", stderr: str = "", *, timed_out: bool = False) -> Completed:
    return Completed(argv=(), status=status, stdout=stdout, stderr=stderr, timed_out=timed_out)


def plan_of(
    platform: str,
    files: Sequence[str],
    *,
    kind: Literal["entry", "plain_name", "sequence"] = "entry",
    build_mode: str | None = None,
    wrapped: Mapping[str, tuple[str, ...]] | None = None,
    repeat: int = 1,
    plain_name: str | None = None,
    sequence: str | None = None,
) -> RunPlan:
    return RunPlan(
        key=f"{build_mode or 'none'}-0000abcd",
        platform=platform,
        build_mode=build_mode,
        kind=kind,
        files=tuple(files),
        wrapped=MappingProxyType(dict(wrapped or {})),
        repeat=repeat,
        plain_name=plain_name,
        sequence=sequence,
    )


def record_of(target: Target, device_id: str) -> BootRecord:
    return BootRecord(target=target.name, platform=target.platform, device_id=device_id, reused=True)


class FakeBooter:
    """A booter whose `before_file` records the call and raises `error` when one is given."""

    def __init__(self, error: RoundEnvError | None = None) -> None:
        self.readied: list[str] = []
        self._error = error

    def is_running(self, target: Target) -> bool:
        return True

    def boot(self, target: Target, log: Path) -> BootRecord:
        raise AssertionError("run_plan never boots")

    def before_file(self, record: BootRecord) -> None:
        self.readied.append(record.target)
        if self._error is not None:
            raise self._error

    def shutdown(self, record: BootRecord) -> None:
        raise AssertionError("run_plan never shuts down")


class RecordingRunner(FakeRunner):
    """A FakeRunner that keeps each run's keywords and each spawned process, and writes `leaves` on the launch."""

    def __init__(self, script: Sequence[Entry], leaves: Mapping[Path, str] | None = None) -> None:
        super().__init__(script)
        self.runs: list[dict[str, object]] = []
        self.processes: list[FakeProcess] = []
        self._leaves = dict(leaves or {})

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed:
        self.runs.append({"argv": tuple(argv), "timeout_s": timeout_s, "cwd": cwd, "env": dict(env or {})})
        answer = super().run(argv, timeout_s=timeout_s, cwd=cwd, env=env, log=log)
        if tuple(argv[:2]) in _LAUNCHES:
            for path, text in self._leaves.items():
                path.write_text(text, encoding="utf-8")
        return answer

    def spawn(
        self,
        argv: Sequence[str],
        *,
        log: Path,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
    ) -> subprocess.Popen[bytes]:
        process = super().spawn(argv, log=log, cwd=cwd, env=env)
        self.processes.append(cast("FakeProcess", process))
        return process

    def launch(self) -> dict[str, object]:
        """The keywords of the one flutter or docker launch."""
        launches = [run for run in self.runs if cast("tuple[str, ...]", run["argv"])[:2] in _LAUNCHES]
        assert len(launches) == 1, launches
        return launches[0]


def app_with_tests(tmp_path: Path) -> Path:
    app = tmp_path / "repo" / "test_app"
    shutil.copytree(INTEGRATION_FIXTURE, app / "integration_test")
    return app


def report_lines() -> list[str]:
    return (REPORTS / "flutter_test_report.json").read_text(encoding="utf-8").splitlines()


def drive_sample(name: str) -> dict[str, object]:
    data = json.loads((REPORTS / f"integration_response_data-{name}.json").read_text(encoding="utf-8"))
    assert isinstance(data, dict)
    return data


def suite_report(tests: Mapping[str, Sequence[tuple[str, str]]]) -> str:
    """A `flutter test` json report with one suite per path, each test `(name, result)`.

    `result` is the reporter's own (`success`, `failure`, `error`), or `skip` and `hidden` for a skipped test and a
    hidden successful one (a loading test, `setUpAll`, `tearDownAll`).
    """
    events: list[dict[str, object]] = [{"type": "start", "protocolVersion": "0.1.1"}]
    next_id = 0
    for suite_id, (path, rows) in enumerate(tests.items()):
        events.append({"type": "suite", "suite": {"id": suite_id, "platform": "linux", "path": path}})
        for name, result in rows:
            next_id += 1
            events.append({"type": "testStart", "test": {"id": next_id, "name": name, "suiteID": suite_id,
                                                         "groupIDs": []}})
            events.append({"type": "testDone", "testID": next_id, "hidden": result == "hidden",
                           "skipped": result == "skip",
                           "result": "success" if result in ("success", "skip", "hidden") else result})
    events.append({"type": "done", "success": True})
    return "\n".join(json.dumps(event) for event in events) + "\n"


def chrome_answer(version: str = "130.0.6723.58") -> Entry:
    return ((CHROME_APP, "--version"), done(0, f"Google Chrome {version}\n"))


def repeat_log(passes: int, total: int) -> str:
    return "".join(f"I/flutter ( 4198): REPEAT {REPEAT_PREFIX} {run}/{total} ok\n" for run in range(1, passes + 1))


# run_argv: design section 9's run table, one assertion per row.


def test_run_argv_per_platform() -> None:
    entry = plan_of("android", [KEYBOARD, SMOKE], build_mode="debug")
    report = ["--reporter", "expanded", "--file-reporter", "json:/round/item/report.json"]

    assert run_argv(entry, PIXEL_2, [ENTRY_FILE], "emulator-5554", ITEM, None) == [
        "flutter", "test", ENTRY_FILE.as_posix(), "-d", "emulator-5554", "--no-pub", *report,
    ]
    alone = plan_of("android", [WEB_VIEW], kind="plain_name", build_mode="debug", plain_name="group B, native only")
    assert run_argv(alone, PIXEL_2, [ENTRY_FILE], "emulator-5554", ITEM, None) == [
        "flutter", "test", ENTRY_FILE.as_posix(), "-d", "emulator-5554", "--no-pub", *report,
        "--plain-name", "group B, native only",
    ]
    profile = plan_of("android", [KEYBOARD], build_mode="profile")
    assert run_argv(profile, PIXEL_8, [ENTRY_FILE], "emulator-5556", ITEM, None) == [
        "flutter", "drive", "--profile", "--no-pub", "--driver", "test_driver/integration_test.dart",
        "--target", ENTRY_FILE.as_posix(), "-d", "emulator-5556",
    ]
    assert run_argv(plan_of("ios", [KEYBOARD]), IPHONE, [ENTRY_FILE], "UDID-1", ITEM, None) == [
        "flutter", "test", ENTRY_FILE.as_posix(), "-d", "UDID-1", "--no-pub", *report,
    ]
    assert run_argv(plan_of("macos", [KEYBOARD]), MAC, [ENTRY_FILE], "mac", ITEM, None) == [
        "flutter", "test", ENTRY_FILE.as_posix(), "-d", "macos", "--no-pub", *report,
    ]
    web = [
        "flutter", "drive", "--driver=test_driver/integration_test.dart", f"--target={ENTRY_FILE.as_posix()}",
        "-d", "web-server", "--browser-name=chrome", "--headless", "--no-pub", "--driver-port=4445",
    ]
    assert run_argv(plan_of("web", [KEYBOARD]), CHROME, [ENTRY_FILE], "chrome", ITEM, 4445) == web
    assert run_argv(plan_of("web", [KEYBOARD]), CHROME_WASM, [ENTRY_FILE], "chrome_wasm", ITEM, 4445) == [
        *web, "--wasm",
    ]
    image = LinuxRun(tag="stratum-e2e-linux:3.47.7-abcd1234", repo_root=Path("/repo"), app_rel="test_app")
    linux = plan_of("linux", [KEYBOARD])
    assert run_argv(linux, LINUX, [ENTRY_FILE], "linux", ITEM, None, linux=image) == linux_docker.docker_run_argv(
        image.tag, Path("/repo"), "test_app", ITEM,
        linux_docker.inner_command([ENTRY_FILE.as_posix()], None, sequence=False),
        linux_docker.container_name("linux"), False, "linux",
    )


def test_run_argv_passes_a_sequence_its_files_and_keeps_the_app() -> None:
    sequence = plan_of("linux", [RESTART_1, RESTART_2], kind="sequence")
    files = [Path("integration_test", RESTART_1), Path("integration_test", RESTART_2)]
    image = LinuxRun(tag="t", repo_root=Path("/repo"), app_rel="test_app")

    argv = run_argv(sequence, LINUX, files, "linux", ITEM, None, linux=image)

    assert argv[-1] == linux_docker.container_script(
        linux_docker.inner_command([path.as_posix() for path in files], None, sequence=True)
    )
    home = argv.index(f"{linux_docker.home_volume('linux')}:/root/.local/share")
    assert argv[home - 1] == "-v"
    mac_sequence = run_argv(plan_of("macos", [KEYBOARD, SMOKE], kind="sequence"), MAC,
                            [Path("integration_test", KEYBOARD), Path("integration_test", SMOKE)], "mac", ITEM, None)
    assert mac_sequence[2:4] == [f"integration_test/{KEYBOARD}", f"integration_test/{SMOKE}"]
    assert mac_sequence[-1] == "--no-uninstall"


def test_run_argv_refuses_what_no_row_covers() -> None:
    with pytest.raises(ValueError, match="plain-name"):
        run_argv(plan_of("web", [WEB_VIEW], kind="plain_name", plain_name="x"), CHROME, [ENTRY_FILE], "c", ITEM, 4444)
    with pytest.raises(ValueError, match="driver port"):
        run_argv(plan_of("web", [KEYBOARD]), CHROME, [ENTRY_FILE], "chrome", ITEM, None)
    with pytest.raises(ValueError, match="LinuxRun"):
        run_argv(plan_of("linux", [KEYBOARD]), LINUX, [ENTRY_FILE], "linux", ITEM, None)
    windows = Target(name="windows", platform="windows", catalog_only=True)
    with pytest.raises(ValueError, match="windows"):
        run_argv(plan_of("windows", [KEYBOARD]), windows, [ENTRY_FILE], "windows", ITEM, None)


# The split pass rule (design section 9, pre-flight F13).


@pytest.mark.parametrize("target", [PIXEL_8, CHROME], ids=lambda target: target.name)
def test_check_runnable_refuses_a_plain_name_on_a_drive_target(target: Target) -> None:
    plan = plan_of(target.platform, [WEB_VIEW], kind="plain_name", plain_name="group B, native only")
    with pytest.raises(ValueError, match=f"{target.name}.*--plain-name"):
        check_runnable(plan, target, INTEGRATION_FIXTURE)


def test_check_runnable_refuses_a_sequence_on_a_drive_target() -> None:
    plan = plan_of("web", [KEYBOARD, SMOKE], kind="sequence", sequence="s")
    with pytest.raises(ValueError, match="chrome.*sequence s"):
        check_runnable(plan, CHROME, INTEGRATION_FIXTURE)


@pytest.mark.parametrize("target", [PIXEL_2, MAC], ids=lambda target: target.name)
def test_check_runnable_takes_a_plain_name_on_a_flutter_test_target(target: Target) -> None:
    plan = plan_of(target.platform, [WEB_VIEW], kind="plain_name", plain_name="group B, native only")
    check_runnable(plan, target, INTEGRATION_FIXTURE)


def test_check_runnable_takes_a_wrapped_block_it_can_wrap() -> None:
    plan = plan_of("android", [WEB_VIEW], build_mode="profile", wrapped={WEB_VIEW: (REPEAT_PREFIX,)}, repeat=10)
    check_runnable(plan, PIXEL_8, INTEGRATION_FIXTURE)


def test_check_runnable_refuses_a_wrapped_prefix_naming_no_block() -> None:
    plan = plan_of("android", [WEB_VIEW], build_mode="profile", wrapped={WEB_VIEW: ("co99/us99/s9",)}, repeat=10)
    with pytest.raises(ValueError, match=f"pixel_8.*{WEB_VIEW}.*co99/us99/s9"):
        check_runnable(plan, PIXEL_8, INTEGRATION_FIXTURE)


def test_check_runnable_refuses_a_malformed_wrapped_block(tmp_path: Path) -> None:
    broken = tmp_path / "common" / "broken_test.dart"
    broken.parent.mkdir(parents=True)
    broken.write_text("void main() {\n  testWidgets('co01/us01/s1: opens', (tester) async {\n", encoding="utf-8")
    plan = plan_of("macos", ["common/broken_test.dart"], wrapped={"common/broken_test.dart": ("co01/us01/s1",)})
    with pytest.raises(ValueError, match="unbalanced braces"):
        check_runnable(plan, MAC, tmp_path)


def test_file_passes_when_every_declared_test_passed_whatever_the_exit(tmp_path: Path) -> None:
    app = app_with_tests(tmp_path)
    item = tmp_path / "item"
    item.mkdir()
    report = suite_report({"/x/.round/entry.dart": [(f"{KEYBOARD} fo07/us04/s1: opens", "success"),
                                                     (f"{SMOKE} co01_02/us03/s1: keeps ids", "success")]})
    runner = RecordingRunner([(("flutter", "test"), done(1))], {item / "report.json": report})

    outcome = run_plan(plan_of("macos", [KEYBOARD, SMOKE]), MAC, record_of(MAC, "mac"), FakeBooter(), app, item,
                       runner, 60.0, tmp_path / "ports")

    assert outcome.files == {
        KEYBOARD: FileResult("pass", 1, 1, "", ("fo07/us04/s1",)),
        SMOKE: FileResult("pass", 1, 1, "", ("co01_02/us03/s1",)),
    }


def test_failed_test_fails_its_file_only() -> None:
    files = read_test_report(report_lines(), plan_of("android", [KEYBOARD, SMOKE], build_mode="debug"))

    assert files[KEYBOARD] == FileResult(
        "fail", 0, 1, "failed: fo07/us04/fr02/e01: the scope reads hidden once the keyboard closes",
        ("fo07/us04/s1", "fo07/us04/fr01", "fo07/us04/fr02/e01"),
    )
    assert files[SMOKE].cls == "pass"


def test_file_with_no_report_entry_fails() -> None:
    files = read_test_report(report_lines(), plan_of("android", [KEYBOARD, SMOKE, WEB_VIEW], build_mode="debug"))

    assert files[WEB_VIEW] == FileResult("fail", 0, 1, "no report entry", ())
    assert read_test_report([], plan_of("macos", [SMOKE]))[SMOKE].reason == "no report entry"


def test_skipped_tests_neither_pass_nor_fail_the_file() -> None:
    files = read_test_report(report_lines(), plan_of("android", [KEYBOARD, SMOKE], build_mode="debug"))
    assert files[SMOKE] == FileResult("pass", 1, 1, "", ("co01_02/us03/s1",))  # the skipped s2 proves nothing here

    skipped = suite_report({"/e.dart": [(f"{SMOKE} a", "skip"), (f"{SMOKE} b", "skip")]}).splitlines()
    assert read_test_report(skipped, plan_of("macos", [SMOKE]))[SMOKE] == FileResult("fail", 0, 1, "all skipped", ())


def test_hidden_setup_and_loading_tests_never_count_but_a_failed_one_does() -> None:
    hidden = suite_report({"/e.dart": [("loading /e.dart", "hidden"), (f"{SMOKE} (setUpAll)", "hidden"),
                                       (f"{SMOKE} a", "success")]}).splitlines()
    failed = suite_report({"/e.dart": [(f"{SMOKE} (setUpAll)", "error"), (f"{SMOKE} a", "success")]}).splitlines()

    assert read_test_report(hidden, plan_of("macos", [SMOKE]))[SMOKE] == FileResult("pass", 1, 1, "", ())
    assert read_test_report(failed, plan_of("macos", [SMOKE]))[SMOKE].reason == "failed: (setUpAll)"


def test_a_test_that_started_and_never_finished_fails() -> None:
    lines = [
        json.dumps({"type": "suite", "suite": {"id": 0, "path": "/e.dart"}}),
        json.dumps({"type": "testStart", "test": {"id": 1, "name": f"{SMOKE} a", "suiteID": 0}}),
        '{"type": "testDone", "testID": 1, "res',
    ]

    assert read_test_report(lines, plan_of("macos", [SMOKE]))[SMOKE] == FileResult("fail", 0, 1, "failed: a", ())


def test_a_sequence_maps_tests_by_suite_path() -> None:
    lines = suite_report({
        f"/work/test_app/integration_test/{RESTART_1}": [("fo10/us01/s2: launch 1 stores", "success")],
        f"/work/test_app/integration_test/{RESTART_2}": [("fo10/us01/s2: launch 2 restarts", "failure")],
    }).splitlines()

    files = read_test_report(lines, plan_of("linux", [RESTART_1, RESTART_2], kind="sequence"))

    assert files[RESTART_1] == FileResult("pass", 1, 1, "", ("fo10/us01/s2",))
    assert files[RESTART_2].reason == "failed: fo10/us01/s2: launch 2 restarts"


def test_drive_response_splits_per_file() -> None:
    files = read_drive_response(drive_sample("fail"), plan_of("web", [KEYBOARD, SMOKE]))

    assert files[KEYBOARD].cls == "fail"
    assert files[KEYBOARD].reason == "failed: fo07/us04/fr02/e01: the scope reads hidden once the keyboard closes"
    assert files[SMOKE] == FileResult("pass", 1, 1, "", ("co01_02/us03/s1",))
    passing = read_drive_response(drive_sample("pass"), plan_of("web", [KEYBOARD, SMOKE]))
    assert {file: result.cls for file, result in passing.items()} == {KEYBOARD: "pass", SMOKE: "pass"}


def test_drive_response_missing_fails_every_file() -> None:
    plan = plan_of("web", [KEYBOARD, SMOKE])

    for data in (None, {}, {"stratum_round": "garbled"}):
        files = read_drive_response(data, plan)
        assert files == {file: FileResult("fail", 0, 1, "no report entry", ()) for file in plan.files}
    empty = read_drive_response({"stratum_round": {KEYBOARD: {}}}, plan)
    assert empty[KEYBOARD].reason == "all skipped"


# classify_env (C6, scripts/lib/run.sh:31-44).


def test_no_tests_found_with_exit_79_is_env() -> None:
    log = (REPORTS / "pixel_8-env-fail.log").read_text(encoding="utf-8")
    started = "00:00 +0: loading x\n00:04 +1: a passes\nNo tests were found.\n"

    assert classify_env(log, 79, False) is not None
    assert classify_env(log, 1, False) is not None  # its count lines all read +0: no test started
    assert classify_env(started, 79, False) == "No tests were found (exit 79)"


def test_no_tests_found_after_a_test_started_is_fail() -> None:
    started = "00:00 +0: loading x\n00:04 +1: a passes\n00:09 +1 -1: b [E]\nNo tests were found.\n"
    failed_first = "00:00 +0: loading x\n00:05 +0 -1: f_test.dart a [E]\nNo tests were found\n"
    skipped_first = "00:00 +0: loading x\n00:02 +0 ~1: a\n00:04 +1 ~1: b\n00:07 +1 ~1 -1: c [E]\nNo tests were found\n"
    only_skipped = "00:00 +0: loading x\n00:02 +0 ~1: a\nNo tests were found\n"
    never = "00:00 +0: loading x\nNo tests were found.\n"

    for log in (started, failed_first, skipped_first, only_skipped):
        assert classify_env(log, 1, False) is None, log
    assert classify_env(never, 1, False) is not None
    assert classify_env((REPORTS / "pixel_8.log").read_text(encoding="utf-8"), 1, False) is None


def test_round_timeout_is_env() -> None:
    assert classify_env("", -9, True) == "run timeout"


def test_env_signs_class_env() -> None:
    offline = (REPORTS / "pixel_2-adb-offline.log").read_text(encoding="utf-8")

    assert classify_env(offline, 1, False) is not None
    assert classify_env("Failed: Unable to start the app on the device.\n", 1, False) == (
        "Unable to start the app on the device"
    )
    assert classify_env("adb: device offline\n", 1, False) == "device offline"
    assert not any("DT_WATCHER" in sign for sign in ENV_SIGNS)
    watcher = (REPORTS / "pixel_2-dr19-timeout.log").read_text(encoding="utf-8")
    assert classify_env(watcher, 124, False) is None


def test_a_failed_linux_source_sync_is_env() -> None:
    log = f"rsync: [receiver] write failed: No space left on device (28)\n{linux_docker.SYNC_FAILED_SIGN}\n"
    assert classify_env(log, 1, False) == linux_docker.SYNC_FAILED_SIGN


# Run results, logs, and timeouts through run_plan.


def test_drive_log_prefix_is_stripped_once(tmp_path: Path) -> None:
    app = app_with_tests(tmp_path)
    item = tmp_path / "item"
    spike = (REPORTS / "spike-profile-drive-p1.log").read_text(encoding="utf-8")
    runner = RecordingRunner([(("flutter", "drive"), done(0, spike + "I/flutter ( 4198): I/flutter ( 77): nested\n"))])

    run_plan(plan_of("android", [KEYBOARD], build_mode="profile"), PIXEL_8, record_of(PIXEL_8, "emulator-5556"),
             FakeBooter(), app, item, runner, 60.0, tmp_path / "ports")

    log = (item / "flutter.log").read_text(encoding="utf-8")
    assert "PROBE:dark_header" in log.splitlines()
    assert "I/flutter ( 77): nested" in log.splitlines()
    assert "I/flutter ( 4198)" not in log
    assert runner.launch()["env"] == {"FLUTTER_TEST_OUTPUTS_DIR": str(item)}


def test_repeat_block_reads_n_of_N(tmp_path: Path) -> None:  # noqa: N802 - n/N is the summary's own notation
    plan = plan_of("android", [WEB_VIEW, SMOKE], build_mode="profile", wrapped={WEB_VIEW: (REPEAT_PREFIX,)},
                   repeat=10)
    tests = {f"REPEAT run {run} {REPEAT_PREFIX}, co01_02/us03/s2: a page": "pass" for run in range(10)}
    response = json.dumps({"stratum_round": {WEB_VIEW: tests, SMOKE: {"co01_02/us03/s1: ids": "pass"}}})

    for passes, expected in ((9, FileResult("fail", 9, 10, "9/10", ("co01_02/us03/s1", "co01_02/us03/s2"))),
                             (10, FileResult("pass", 10, 10, "", ("co01_02/us03/s1", "co01_02/us03/s2")))):
        app = app_with_tests(tmp_path / str(passes))
        item = tmp_path / str(passes) / "item"
        item.mkdir(parents=True)
        runner = RecordingRunner([(("flutter", "drive"), done(0, repeat_log(passes, 10)))],
                                 {item / "integration_response_data.json": response})

        outcome = run_plan(plan, PIXEL_8, record_of(PIXEL_8, "emulator-5556"), FakeBooter(), app, item, runner,
                           60.0, tmp_path / "ports")

        assert outcome.files[WEB_VIEW] == expected
        assert outcome.files[SMOKE] == FileResult("pass", 1, 1, "", ("co01_02/us03/s1",))


def test_repeat_count_counts_each_passing_iteration_once() -> None:
    log = "REPEAT p 1/3 ok\nREPEAT p 1/3 ok\nREPEAT p 3/3 ok\nREPEAT other 2/3 ok\nREPEAT p 2/3 failed\n"

    assert repeat_count(log, "p") == 2
    assert repeat_count("REPEAT a.b 1/2 ok\n", "a?b") == 0


def test_story_tags_from_dart_names() -> None:
    assert story_tags("co01_02/us03/s1, co01_02/us03/s2: a page ...") == ("co01_02/us03/s1", "co01_02/us03/s2")
    assert story_tags("group A, the demo tabs us08/s1, us08/fr01/e06: the URL tab") == ("us08/s1", "us08/fr01/e06")
    assert story_tags("fo07/us04/fr02/e07 (ios, attended): a human connects") == ("fo07/us04/fr02/e07",)
    assert story_tags("us08/s7: group B, native only us08/s13: the app") == ("us08/s7", "us08/s13")
    assert story_tags(f"REPEAT run 3 {REPEAT_PREFIX}: a page") == (REPEAT_PREFIX,)
    assert story_tags("smoke fixture keeps its semantics identifiers on device") == ()
    assert story_tags("the page from us03/s1 stays") == ()


def test_wasm_needs_chrome_119(tmp_path: Path) -> None:
    app = app_with_tests(tmp_path)
    for answers, found in (
        ([((CHROME_APP, "--version"), done(0, "Google Chrome 118.0.5993.70\n"))], "found Chrome 118"),
        ([((CHROME_APP, "--version"), done(127)), (("google-chrome", "--version"), done(127))], "no Chrome version"),
    ):
        runner = RecordingRunner(answers)

        outcome = run_plan(plan_of("web", [KEYBOARD, SMOKE]), CHROME_WASM, record_of(CHROME_WASM, "chrome_wasm"),
                           FakeBooter(), app, tmp_path / "item", runner, 60.0, tmp_path / "ports")

        assert {result.cls for result in outcome.files.values()} == {"env"}
        assert f"Chrome {CHROME_WASMGC_FLOOR}+" in outcome.files[KEYBOARD].reason
        assert found in outcome.files[KEYBOARD].reason
        assert outcome.argv == ()
        assert not [call for call in runner.calls if call[0] in ("flutter", "chromedriver")]


def test_every_web_run_needs_a_readable_chrome_but_only_wasm_needs_119(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(integration_run, "port_accepts", lambda port: True)
    app = app_with_tests(tmp_path)
    for answers in (
        [((CHROME_APP, "--version"), done(127)), (("google-chrome", "--version"), done(127))],
        [((CHROME_APP, "--version"), done(0, "garbled\n"))],
    ):
        runner = RecordingRunner(answers)

        outcome = run_plan(plan_of("web", [KEYBOARD]), CHROME, record_of(CHROME, "chrome"), FakeBooter(), app,
                           tmp_path / "item", runner, 60.0, tmp_path / "ports")

        assert outcome.files[KEYBOARD].cls == "env"
        assert "no Chrome version" in outcome.files[KEYBOARD].reason
        assert outcome.argv == ()
        assert not [call for call in runner.calls if call[0] in ("flutter", "chromedriver")]

    old = RecordingRunner([chrome_answer("118.0.5993.70"), (("flutter", "drive"), done(0))])
    outcome = run_plan(plan_of("web", [KEYBOARD]), CHROME, record_of(CHROME, "chrome"), FakeBooter(), app,
                       tmp_path / "item", old, 60.0, tmp_path / "ports")
    assert outcome.argv[:2] == ("flutter", "drive")


def test_run_plan_returns_the_outcome_with_argv_and_seconds(tmp_path: Path) -> None:
    app = app_with_tests(tmp_path)
    item = tmp_path / "item"
    item.mkdir()
    runner = RecordingRunner([(("flutter", "test"), done(1))],
                             {item / "report.json": "\n".join(report_lines())})
    booter = FakeBooter()

    outcome = run_plan(plan_of("macos", [KEYBOARD, SMOKE]), MAC, record_of(MAC, "mac"), booter, app, item, runner,
                       60.0, tmp_path / "ports")

    launch = runner.launch()
    assert outcome.argv == launch["argv"]
    assert outcome.argv[:2] == ("flutter", "test")
    assert outcome.argv[2].startswith(f"integration_test/{ENTRY_PREFIX}macos_none-0000abcd")
    assert launch["cwd"] == app
    assert outcome.seconds >= 0
    assert set(outcome.files) == {KEYBOARD, SMOKE}
    assert outcome.files[KEYBOARD].cls == "fail"
    assert booter.readied == ["mac"]
    assert not list((app / "integration_test").glob(f"{ENTRY_PREFIX}*"))


def test_run_timeout_scales_with_the_files_in_the_plan(tmp_path: Path) -> None:
    assert run_timeout_s(plan_of("macos", [KEYBOARD, SMOKE, WEB_VIEW]), 60.0) == 180.0
    wrapped = plan_of("macos", [KEYBOARD, SMOKE, WEB_VIEW], wrapped={WEB_VIEW: (REPEAT_PREFIX,)}, repeat=10)
    assert run_timeout_s(wrapped, 60.0) == 60.0 * (3 + 9) == 720.0
    with pytest.raises(ValueError, match="positive"):
        run_timeout_s(wrapped, 0.0)

    app = app_with_tests(tmp_path)
    runner = RecordingRunner([(("flutter", "test"), done(0))])
    run_plan(wrapped, MAC, record_of(MAC, "mac"), FakeBooter(), app, tmp_path / "item", runner, 60.0,
             tmp_path / "ports")

    assert runner.launch()["timeout_s"] == 720.0
    assert not list((app / "integration_test").rglob(".dt_*"))


def test_chromedriver_port_comes_from_the_port_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(integration_run, "port_accepts", lambda port: True)
    app = app_with_tests(tmp_path)
    item = tmp_path / "item"
    ports = tmp_path / "ports"
    response = (REPORTS / "integration_response_data-pass.json").read_text(encoding="utf-8")
    runner = RecordingRunner([chrome_answer(), (("flutter", "drive"), done(0))],
                             {item / "integration_response_data.json": response})

    outcome = run_plan(plan_of("web", [KEYBOARD, SMOKE]), CHROME, record_of(CHROME, "chrome"), FakeBooter(), app,
                       item, runner, 60.0, ports)

    assert ("chromedriver", "--port=4444") in runner.calls
    assert "--driver-port=4444" in outcome.argv
    assert (ports / "chromedriver-4444.lock").is_file()
    assert [process.returncode for process in runner.processes] == [-9]
    again = reserve_port("chromedriver", 4444, 4474, 1, set(), ports)
    assert again.port == 4444
    again.release()
    assert {result.cls for result in outcome.files.values()} == {"pass"}
    assert runner.launch()["env"] == {"FLUTTER_TEST_OUTPUTS_DIR": str(item)}


def test_chromedriver_that_never_answers_is_env(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(integration_run, "port_accepts", lambda port: False)
    monkeypatch.setattr(integration_run, "CHROMEDRIVER_WAIT_S", 0.0)
    app = app_with_tests(tmp_path)
    runner = RecordingRunner([chrome_answer()])

    outcome = run_plan(plan_of("web", [KEYBOARD]), CHROME, record_of(CHROME, "chrome"), FakeBooter(), app,
                       tmp_path / "item", runner, 60.0, tmp_path / "ports")

    assert outcome.files[KEYBOARD].cls == "env"
    assert "port 4444" in outcome.files[KEYBOARD].reason
    assert [process.returncode for process in runner.processes] == [-9]
    reserve_port("chromedriver", 4444, 4444, 1, set(), tmp_path / "ports").release()


def test_run_timeout_classes_every_file_env(tmp_path: Path) -> None:
    app = app_with_tests(tmp_path)
    runner = RecordingRunner([(("flutter", "test"), done(-9, timed_out=True))])

    outcome = run_plan(plan_of("macos", [KEYBOARD, SMOKE]), MAC, record_of(MAC, "mac"), FakeBooter(), app,
                       tmp_path / "item", runner, 60.0, tmp_path / "ports")

    assert outcome.files == {file: FileResult("env", 0, 1, "run timeout", ()) for file in (KEYBOARD, SMOKE)}
    assert outcome.argv[:2] == ("flutter", "test")


def test_env_signs_in_the_run_log_class_every_file_env(tmp_path: Path) -> None:
    app = app_with_tests(tmp_path)
    offline = (REPORTS / "pixel_2-adb-offline.log").read_text(encoding="utf-8")
    runner = RecordingRunner([(("flutter", "test"), done(1, offline))])

    outcome = run_plan(plan_of("android", [KEYBOARD, SMOKE], build_mode="debug"), PIXEL_2,
                       record_of(PIXEL_2, "emulator-5554"), FakeBooter(), app, tmp_path / "item", runner, 60.0,
                       tmp_path / "ports")

    assert {result.cls for result in outcome.files.values()} == {"env"}


def test_a_device_that_cannot_ready_classes_every_file_env(tmp_path: Path) -> None:
    app = app_with_tests(tmp_path)
    runner = RecordingRunner([])

    outcome = run_plan(plan_of("android", [KEYBOARD, SMOKE], build_mode="debug"), PIXEL_2,
                       record_of(PIXEL_2, "emulator-5554"), FakeBooter(RoundEnvError("adb: device offline")), app,
                       tmp_path / "item", runner, 60.0, tmp_path / "ports")

    assert outcome.argv == ()
    assert outcome.seconds == 0.0
    assert {result.reason for result in outcome.files.values()} == {"adb: device offline"}
    assert runner.calls == []


def test_a_missing_command_is_env(tmp_path: Path) -> None:
    app = app_with_tests(tmp_path)
    runner = RecordingRunner([(("flutter", "test"), done(127, stderr="flutter: No such file or directory\n"))])

    outcome = run_plan(plan_of("macos", [SMOKE]), MAC, record_of(MAC, "mac"), FakeBooter(), app, tmp_path / "item",
                       runner, 60.0, tmp_path / "ports")

    assert outcome.files[SMOKE] == FileResult("env", 0, 1, "flutter not found", ())


def test_a_report_left_by_an_earlier_run_is_never_read(tmp_path: Path) -> None:
    app = app_with_tests(tmp_path)
    item = tmp_path / "item"
    item.mkdir()
    (item / "report.json").write_text(suite_report({"/e.dart": [(f"{SMOKE} a", "success")]}), encoding="utf-8")
    runner = RecordingRunner([(("flutter", "test"), done(0))])

    outcome = run_plan(plan_of("macos", [SMOKE]), MAC, record_of(MAC, "mac"), FakeBooter(), app, item, runner, 60.0,
                       tmp_path / "ports")

    assert outcome.files[SMOKE].reason == "no report entry"


# Linux: the docker image around inner_command (M1a-T6).


def linux_app(tmp_path: Path) -> Path:
    app = app_with_tests(tmp_path)
    cmake = app / "linux" / "flutter" / "generated_plugins.cmake"
    cmake.parent.mkdir(parents=True)
    cmake.write_text("list(APPEND FLUTTER_PLUGIN_LIST flutter_secure_storage_linux)\n", encoding="utf-8")
    return app


def test_linux_sequence_checks_packages_builds_and_resets_before_its_launch(tmp_path: Path) -> None:
    app = linux_app(tmp_path)
    item = tmp_path / "item"
    item.mkdir()
    report = suite_report({
        f"/work/test_app/integration_test/{RESTART_1}": [("fo10/us01/s2: launch 1 stores", "success")],
        f"/work/test_app/integration_test/{RESTART_2}": [("fo10/us01/s2: launch 2 restarts", "success")],
    })
    runner = RecordingRunner(
        [
            (("python3", "-I", "-c"), done(0, "module flutter_secure_storage_linux libsecret-1\n")),
            (("docker", "image", "inspect"), done(0)),
            (("docker", "volume", "rm", "-f"), done(0)),
            (("docker", "rm", "-f"), done(0)),
            (("docker", "run"), done(0)),
        ],
        {item / "report.json": report},
    )

    outcome = run_plan(plan_of("linux", [RESTART_1, RESTART_2], kind="sequence"), LINUX, record_of(LINUX, "linux"),
                       FakeBooter(), app, item, runner, 60.0, tmp_path / "ports", flutter_version="3.47.7")

    assert [call[:2] for call in runner.calls] == [
        ("python3", "-I"), ("docker", "image"), ("docker", "volume"), ("docker", "rm"), ("docker", "run"),
    ]
    assert {result.cls for result in outcome.files.values()} == {"pass"}
    assert outcome.exit_status == 0
    assert outcome.argv[:2] == ("docker", "run")
    assert f"{app.resolve().parent}:/host:ro" in outcome.argv
    assert "-w" in outcome.argv and outcome.argv[outcome.argv.index("-w") + 1] == "/work/test_app"
    assert "--no-uninstall" in outcome.argv[-1]
    assert f"integration_test/{RESTART_1} integration_test/{RESTART_2}" in outcome.argv[-1]


def linux_prepared() -> list[Entry]:
    """The answers a Linux run gets before its launches: the plugin scan, the image, the stale container check."""
    return [
        (("python3", "-I", "-c"), done(0, "")),
        (("docker", "image", "inspect"), done(0)),
        (("docker", "rm", "-f"), done(0)),
    ]


def test_linux_build_step_failure_is_env_and_runs_no_test(tmp_path: Path) -> None:
    app = linux_app(tmp_path)
    item = tmp_path / "item"
    cmake = "CMake Error: The current CMakeCache.txt directory /work/test_app/build/linux/arm64/debug is different\n"
    runner = RecordingRunner([*linux_prepared(), (("docker", "run"), done(1, cmake + "Build process failed.\n"))])

    outcome = run_plan(plan_of("linux", [KEYBOARD]), LINUX, record_of(LINUX, "linux"), FakeBooter(), app, item,
                       runner, 60.0, tmp_path / "ports", flutter_version="3.47.7", build_first=True)

    assert outcome.files[KEYBOARD].cls == "env"
    assert outcome.files[KEYBOARD].reason.startswith("flutter build linux --debug failed (exit 1): CMake Error: ")
    assert outcome.files[KEYBOARD].reason.endswith(" | Build process failed.")
    assert outcome.build_argv == ()
    launches = [call for call in runner.calls if call[:2] == ("docker", "run")]
    assert len(launches) == 1
    assert launches[0][-1].endswith(f"&& {linux_docker.LINUX_BUILD_COMMAND}; " + 'rc=$?; echo "$rc" > build/'
                                    '.dt-last-exit; exit "$rc"')
    assert "CMakeCache.txt" in (item / integration_run.LINUX_BUILD_LOG).read_text(encoding="utf-8")


def test_linux_build_step_that_times_out_is_env_and_removes_the_container(tmp_path: Path) -> None:
    app = linux_app(tmp_path)
    runner = RecordingRunner([
        *linux_prepared(), (("docker", "run"), done(-9, timed_out=True)), (("docker", "rm", "-f"), done(0)),
    ])

    outcome = run_plan(plan_of("linux", [KEYBOARD]), LINUX, record_of(LINUX, "linux"), FakeBooter(), app,
                       tmp_path / "item", runner, 60.0, tmp_path / "ports", flutter_version="3.47.7", build_first=True)

    assert outcome.files[KEYBOARD].cls == "env"
    assert outcome.files[KEYBOARD].reason.startswith("flutter build linux --debug failed (timed out)")
    assert runner.calls[-1] == tuple(linux_docker.remove_stale_container_argv("linux"))


def test_linux_build_step_with_a_dart_error_reads_fail_and_runs_no_test(tmp_path: Path) -> None:
    app = linux_app(tmp_path)
    dart = (BUILDS / "linux-dart-error.log").read_text(encoding="utf-8")
    runner = RecordingRunner([*linux_prepared(), (("docker", "run"), done(1, dart))])

    outcome = run_plan(plan_of("linux", [KEYBOARD, SMOKE]), LINUX, record_of(LINUX, "linux"), FakeBooter(), app,
                       tmp_path / "item", runner, 60.0, tmp_path / "ports", flutter_version="3.47.7", build_first=True)

    reason = "app build: ../lib/src/layout/column_layout.dart:18:30: Error: Expected ';' after this."
    assert outcome.files == {file: FileResult("fail", 0, 1, reason, ()) for file in (KEYBOARD, SMOKE)}
    assert (outcome.argv, outcome.build_argv, outcome.exit_status) == ((), (), None)
    assert len([call for call in runner.calls if call[:2] == ("docker", "run")]) == 1


def test_linux_build_step_reads_a_container_path_in_the_work_root_as_the_repository(tmp_path: Path) -> None:
    app = linux_app(tmp_path)
    clang = "/work/test_app/linux/runner/my_application.cc:12:3: error: use of undeclared identifier 'gtk'\n"
    runner = RecordingRunner([*linux_prepared(), (("docker", "run"), done(1, clang + "Build process failed\n"))])

    outcome = run_plan(plan_of("linux", [KEYBOARD]), LINUX, record_of(LINUX, "linux"), FakeBooter(), app,
                       tmp_path / "item", runner, 60.0, tmp_path / "ports", flutter_version="3.47.7", build_first=True)

    assert outcome.files[KEYBOARD].cls == "fail"
    assert outcome.files[KEYBOARD].reason == f"app build: {clang.strip()}"


def test_linux_test_file_that_fails_to_load_after_a_green_build_is_fail(tmp_path: Path) -> None:
    app = linux_app(tmp_path)
    item = tmp_path / "item"
    item.mkdir()
    entry = f"/work/test_app/integration_test/{ENTRY_PREFIX}linux_none-0000abcd_test.dart"
    report = suite_report({entry: [(f"loading {entry}", "error")]})
    runner = RecordingRunner(
        [
            *linux_prepared(),
            (("docker", "run"), done(0, "Building Linux application...\n")),
            (("docker", "run"), done(1, f"Error: Expected ';' after this.\nFailed to load \"{entry}\"\n")),
        ],
        {item / "report.json": report},
    )

    outcome = run_plan(plan_of("linux", [KEYBOARD]), LINUX, record_of(LINUX, "linux"), FakeBooter(), app, item,
                       runner, 60.0, tmp_path / "ports", flutter_version="3.47.7", build_first=True)

    assert outcome.files[KEYBOARD].cls == "fail"
    assert outcome.exit_status == 1
    build, test = (call for call in runner.calls if call[:2] == ("docker", "run"))
    assert outcome.build_argv == build
    assert outcome.argv == test
    assert linux_docker.LINUX_BUILD_COMMAND in build[-1]
    assert linux_docker.LINUX_BUILD_COMMAND not in test[-1]


def test_linux_missing_package_is_env_before_the_image_build(tmp_path: Path) -> None:
    app = linux_app(tmp_path)
    runner = RecordingRunner([(("python3", "-I", "-c"), done(0, "module webview_all_linux webkit2gtk-4.1\n"))])

    outcome = run_plan(plan_of("linux", [KEYBOARD]), LINUX, record_of(LINUX, "linux"), FakeBooter(), app,
                       tmp_path / "item", runner, 60.0, tmp_path / "ports", flutter_version="3.47.7")

    assert "libwebkit2gtk-4.1-dev" in outcome.files[KEYBOARD].reason
    assert outcome.files[KEYBOARD].cls == "env"
    assert [call[:2] for call in runner.calls] == [("python3", "-I")]


def test_linux_timeout_removes_the_container(tmp_path: Path) -> None:
    app = linux_app(tmp_path)
    runner = RecordingRunner([
        (("flutter", "--version", "--machine"), done(0, '{"frameworkVersion": "3.47.7"}')),
        (("python3", "-I", "-c"), done(0, "")),
        (("docker", "image", "inspect"), done(0)),
        (("docker", "rm", "-f"), done(0)),
        (("docker", "run"), done(-9, timed_out=True)),
        (("docker", "rm", "-f"), done(1, stderr="Error response from daemon: is the docker daemon running?\n")),
    ])

    outcome = run_plan(plan_of("linux", [KEYBOARD]), LINUX, record_of(LINUX, "linux"), FakeBooter(), app,
                       tmp_path / "item", runner, 60.0, tmp_path / "ports")

    assert outcome.files[KEYBOARD] == FileResult("env", 0, 1, "run timeout", ())
    remove = tuple(linux_docker.remove_stale_container_argv("linux"))
    assert runner.calls[-1] == remove
    removals = [run for run in runner.runs if run["argv"] == remove]
    assert len(removals) == 2
    assert all(isinstance(run["timeout_s"], float) and run["timeout_s"] > 0 for run in removals)
    assert not [call for call in runner.calls if call[:3] == ("docker", "volume", "rm")]


class InterruptedLaunchRunner(RecordingRunner):
    """A RecordingRunner whose `docker run` raises KeyboardInterrupt, as a SIGTERM mid-run does in a round."""

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed:
        if tuple(argv[:2]) == ("docker", "run"):
            self.calls.append(tuple(argv))
            raise KeyboardInterrupt
        return super().run(argv, timeout_s=timeout_s, cwd=cwd, env=env, log=log)


def test_linux_interrupt_removes_the_container_and_reraises(tmp_path: Path) -> None:
    app = linux_app(tmp_path)
    runner = InterruptedLaunchRunner([
        (("flutter", "--version", "--machine"), done(0, '{"frameworkVersion": "3.47.7"}')),
        (("python3", "-I", "-c"), done(0, "")),
        (("docker", "image", "inspect"), done(0)),
        (("docker", "rm", "-f"), done(0)),
        (("docker", "rm", "-f"), done(0)),
    ])

    with pytest.raises(KeyboardInterrupt):
        run_plan(plan_of("linux", [KEYBOARD]), LINUX, record_of(LINUX, "linux"), FakeBooter(), app,
                 tmp_path / "item", runner, 60.0, tmp_path / "ports")

    remove = tuple(linux_docker.remove_stale_container_argv("linux"))
    assert runner.calls[-1] == remove
    assert runner.calls.count(remove) == 2


def test_interrupt_on_a_host_run_removes_no_container(tmp_path: Path) -> None:
    app = app_with_tests(tmp_path)

    class InterruptedFlutter(RecordingRunner):
        def run(
            self,
            argv: Sequence[str],
            *,
            timeout_s: float | None = None,
            cwd: Path | None = None,
            env: Mapping[str, str] | None = None,
            log: Path | None = None,
        ) -> Completed:
            self.calls.append(tuple(argv))
            raise KeyboardInterrupt

    runner = InterruptedFlutter([])

    with pytest.raises(KeyboardInterrupt):
        run_plan(plan_of("macos", [SMOKE]), MAC, record_of(MAC, "mac"), FakeBooter(), app, tmp_path / "item",
                 runner, 60.0, tmp_path / "ports")

    assert [call[:2] for call in runner.calls] == [("flutter", "test")]
