"""Unit tests for the round fixtures and hooks: lane, boot, build, items, round dir (design section 6 steps 3-9).

Each test builds an e2e tree under pytester and runs a round in a sub-process. The tree's conftest overrides
`round_backends` with fakes that append one line per call to `events.log`, steered by `scenario.json`; no test boots
a device, builds an app, or starts Appium.
"""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
from typing import Any

import pytest

from stratum_e2e.round.lane import LANE_DIR_ENV, Holder, acquire_lane, heavy_pattern
from stratum_e2e.round.results import ROUNDS_DIR_ENV

E2E_ROOT = Path(__file__).resolve().parents[1]
FILE_A = "smoke/a_test.dart"
FILE_B = "smoke/b_test.dart"
MAC_APP_ID = "dev.stratum.stratumUiTestApp"
REUSED_SERIAL = "emulator-5554"

TARGETS_TOML = """\
[apps.test_app]
folder = "test_app"
android_id = "dev.stratum.stratum_ui_test_app"
apple_id = "{mac_app_id}"

[apps.example]
folder = "example"
android_id = "dev.stratum.stratum_ui_example"
apple_id = "dev.stratum.stratumUiExample"
perf = "dart run tool/perf_abba.dart"

[targets.pixel_8]
platform = "android"
avd = "Pixel_8_API_37"
alone = true
build_mode = "profile"

[targets.tablet]
platform = "android"
avd = "Pixel_Tablet_API_35"
alone = true
build_mode = "profile"

[targets.e2e_talkback]
platform = "android"
avd = "E2E_TalkBack_API_35"
alone = true
integration = false

[targets.mac]
platform = "macos"

[targets.chrome]
platform = "web"
browser = "chrome"

[targets.linux]
platform = "linux"
e2e = false

[targets.linux.plain_name]
"smoke/b_test.dart" = "group B"

[modes.fast]
targets = ["mac"]
repeat = 1

[lane]
allow_level2 = true
run_timeout_minutes = 20
boot_settle_timeout_seconds = 420
heavy_processes = []
lane_wait_minutes = {lane_wait}
"""

# The fake backends, loaded by the tree's root conftest. Every call appends one line to `events.log`.
FAKE_SOURCE = r'''
"""Fake round backends for a pytester tree, steered by scenario.json; every call appends a line to events.log."""

from __future__ import annotations

import json
import subprocess
from datetime import UTC, datetime
from pathlib import Path

import appium.webdriver
import playwright.sync_api
import pytest
import tools.e2e_avd
from selenium.common.exceptions import WebDriverException

import stratum_e2e.android.session as android_session
import stratum_e2e.android.talkback as talkback
import stratum_e2e.android.uhid_keyboard as uhid_keyboard
import stratum_e2e.round.bring_up as bring_up
import stratum_e2e.round.state as state
from stratum_e2e.appium_server import AppiumServer, AppiumStartError
from stratum_e2e.round.android_boot import AndroidBooter
from stratum_e2e.round.app_build import AppBuild
from stratum_e2e.round.boot import BootRecord
from stratum_e2e.round.errors import BuildFailure, RoundEnvError
from stratum_e2e.round.integration_run import LOG_NAME, FileResult, RunOutcome
from stratum_e2e.round.lane import host_memory_reasons
from stratum_e2e.round.runner import Completed

ROOT = Path(__file__).resolve().parent
SCENARIO = json.loads((ROOT / "scenario.json").read_text())
NOW = datetime(2026, 10, 24, 1, 2, 3, tzinfo=UTC)
HOST_PLATFORMS = ("macos", "web", "linux")


def event(text: str) -> None:
    with (ROOT / "events.log").open("a", encoding="utf-8") as sink:
        sink.write(text + "\n")


class FakeRunner:
    """Answers the host probes, the reused emulator's adb reads, and the perf command; anything else passes."""

    def __init__(self) -> None:
        self._pgrep = list(SCENARIO.get("pgrep", []))

    def run(self, argv, *, timeout_s=None, cwd=None, env=None, log=None):
        call = tuple(str(arg) for arg in argv)
        event("run " + " ".join(call) + (f" cwd={Path(cwd).name}" if cwd is not None else ""))
        status, stdout = 0, ""
        if call[0] == "memory_pressure":
            stdout = "System-wide memory free percentage: 60%\n"
        elif call[0] == "sysctl":
            stdout = "1\n"
        elif call[0] == "pgrep":
            stdout = self._pgrep.pop(0) if len(self._pgrep) > 1 else (self._pgrep[0] if self._pgrep else "")
            status = 0 if stdout else 1
        elif call[1:] == ("devices",):
            stdout = f"List of devices attached\n{SCENARIO['reused_serial']}\tdevice\n\n"
        elif call[-3:] == ("emu", "avd", "name"):
            stdout = f"{SCENARIO['real_android']}\r\nOK\r\n"
        elif "ping" in call:
            stdout = "64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time=12.3 ms\n"
        elif call[:3] == ("flutter", "--version", "--machine"):
            stdout = '{"frameworkVersion": "3.99.0"}'
        elif call[:3] == ("ioreg", "-n", "Root"):
            locked = "Yes" if SCENARIO.get("console_locked") else "No"
            stdout = f'    | {{\n    "CGSSessionScreenIsLocked"={locked}\n    }}\n'
        elif call[:2] == ("dart", "run"):
            status = SCENARIO.get("perf_status", 0)
        elif call[0] == "screencapture":
            Path(call[-1]).write_bytes(b"png")
        if log is not None:
            Path(log).parent.mkdir(parents=True, exist_ok=True)
            Path(log).write_text(stdout, encoding="utf-8")
        return Completed(call, status, stdout, "", False)

    def spawn(self, argv, *, log, cwd=None, env=None):
        event("spawn " + " ".join(str(arg) for arg in argv))
        raise OSError("the fake runner spawns nothing")


# Per process: the round's last item tears every session fixture down, so its re-run gets a fresh booter.
_shutdowns = {}


class FakeBooter:
    """Reuses a host target always and a device target named in `running`; `boot_fail` counts boots that fail."""

    def __init__(self) -> None:
        self._failures = dict(SCENARIO.get("boot_fail", {}))

    def is_running(self, target):
        return target.platform in HOST_PLATFORMS or target.name in SCENARIO.get("running", [])

    def boot(self, target, log):
        event(f"boot {target.name}")
        left = self._failures.get(target.name, 0)
        if left:
            self._failures[target.name] = left - 1
            raise RoundEnvError("emulator never ready")
        device = target.name if target.platform in HOST_PLATFORMS else f"dev-{target.name}"
        device = SCENARIO.get("devices", {}).get(target.name, device)
        return BootRecord(target.name, target.platform, device, reused=self.is_running(target))

    def before_file(self, record):
        pass

    def shutdown(self, record):
        """End the device; the target's n-th shutdown fails to restore its n-th listed setting, if any.

        A target named in `shutdown_fail` raises instead: `env` a `RoundEnvError`, `os` an `OSError`.
        """
        event(f"shutdown {record.target}")
        count = _shutdowns[record.target] = _shutdowns.get(record.target, 0) + 1
        failures = SCENARIO.get("setting_failures", {}).get(record.target, [])
        if count <= len(failures):
            record.setting_failures.append(failures[count - 1])
        how = SCENARIO.get("shutdown_fail", {}).get(record.target)
        if how == "env":
            raise RoundEnvError(f"simctl shutdown {record.device_id} failed (status 1): busy")
        if how == "os":
            raise OSError(f"cannot end {record.device_id}")


_resolve_failures = [SCENARIO.get("resolve_fail", 0)]


def resolve(app_dir, package_root, flutter_version, runner, log):
    event(f"resolve {app_dir.name}")
    if _resolve_failures[0]:
        _resolve_failures[0] -= 1
        raise RoundEnvError("flutter pub get failed (exit 1): Could not resolve host pub.dev")


_build_failures = dict(SCENARIO.get("build_fail", {}))
_broken_builds = dict(SCENARIO.get("broken_build", {}))
BROKEN_LINE = "lib/main.dart:5:3: Error: Method not found: 'runAp'."


def build(app_dir, package_root, platform, wasm, runner, log):
    event(f"build {platform}")
    if _build_failures.get(platform, 0):
        _build_failures[platform] -= 1
        raise RoundEnvError("flutter build failed (exit 1): Gradle daemon died")
    if _broken_builds.get(platform, 0):
        _broken_builds[platform] -= 1
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(f"Building...\n{BROKEN_LINE}\n", encoding="utf-8")
        raise BuildFailure(BROKEN_LINE, log, ("flutter", "build", platform), 3.0)
    path = ROOT / f"app-{platform}"
    path.mkdir(exist_ok=True)  # a web build is a folder the static server serves
    return AppBuild(path=path, argv=("flutter", "build", platform), seconds=2.0, reused=False)


_plan_env = dict(SCENARIO.get("plan_env", {}))
_linux_build_failures = [SCENARIO.get("linux_build_fail", 0)]


def run_plan(plan, target, record, booter, app_dir, item_dir, runner, per_file_timeout_s, port_dir, *,
             flutter_version=None, build_first=False):
    event(f"run_plan {target.name} {plan.kind}" + (" build" if build_first else ""))
    item_dir.mkdir(parents=True, exist_ok=True)
    (item_dir / LOG_NAME).write_text(f"ran {plan.key}\n", encoding="utf-8")
    if build_first and _linux_build_failures[0]:
        _linux_build_failures[0] -= 1
        reason = "CMake Error: The source does not match the source used to generate cache."
        (item_dir / "linux_build.log").write_text(reason + "\n", encoding="utf-8")
        files = {file: FileResult("build", 0, 1, reason, (), "linux_build.log") for file in plan.files}
        return RunOutcome((), 0.0, files, ("flutter", "build", "linux"), 4.0, build_failed=True)
    build_argv = ("flutter", "build", "linux") if build_first else ()
    argv = ("flutter", "test", plan.key)
    if _plan_env.get(target.name, 0):
        _plan_env[target.name] -= 1
        return RunOutcome(argv, 3.0, {file: FileResult("env", 0, 1, "adb offline", ()) for file in plan.files})
    files = {}
    for file in plan.files:
        cls = SCENARIO.get("outcomes", {}).get(file, "pass")
        reason = "" if cls == "pass" else f"{file} broke"
        files[file] = FileResult(cls, 1 if cls == "pass" else 0, 1, reason, (f"tag/{Path(file).stem}",))
    status = 0 if all(result.cls == "pass" for result in files.values()) else 1
    return RunOutcome(argv, 1.5, files, build_argv, 4.0 if build_argv else 0.0, exit_status=status)


@pytest.fixture(scope="session")
def round_backends(request):
    runner = FakeRunner()
    fake = FakeBooter()
    real = None
    if "real_android" in SCENARIO:
        real = AndroidBooter(runner, ROOT / "sdk", request.config.stash[state.CATALOG_KEY].lane, ROOT / "avd",
                             ROOT / "ports")

    def booter_for(target):
        return real if real is not None and target.platform == "android" else fake

    return state.Backends(
        runner=runner,
        booter_for=booter_for,
        resolve=resolve,
        build=build,
        run_plan=run_plan,
        memory_reasons=lambda: host_memory_reasons(runner, request.config.stash[state.CATALOG_KEY].lane),
        now=lambda: NOW,
        port_dir=ROOT / "ports",
        sleep=lambda seconds: event("sleep"),
    )


_appium_failures = [SCENARIO.get("appium_fail", 0)]


def _start(self, timeout_s=60):
    """Stands in for the real start under the real `appium_server` getter; fails `appium_fail` times."""
    event("appium start")
    if _appium_failures[0]:
        _appium_failures[0] -= 1
        raise AppiumStartError(f"appium on port {self.port} never answered /status")


def _stop(self):
    event("appium stop")


AppiumServer.start = _start
AppiumServer.stop = _stop


class _Session:
    def quit(self):
        event("quit")


_remote_failures = [SCENARIO.get("remote_fail", 0)]


def _remote(url, options=None):
    event("remote")
    if _remote_failures[0]:
        _remote_failures[0] -= 1
        raise WebDriverException("session not created")
    return _Session()


appium.webdriver.Remote = _remote


class _Adb:
    """Stands in for `subprocess` inside `stratum_e2e.android.session`: an install logs its serial and fails the first
    `install_fail` times."""

    CalledProcessError = subprocess.CalledProcessError

    @staticmethod
    def run(argv, check=False):
        event(f"install {argv[2]}")
        if _install_failures[0]:
            _install_failures[0] -= 1
            raise subprocess.CalledProcessError(1, argv, stderr="INSTALL_FAILED_INSUFFICIENT_STORAGE")
        return subprocess.CompletedProcess(argv, 0)


_install_failures = [SCENARIO.get("install_fail", 0)]


android_session.subprocess = _Adb

_real_acquire = bring_up.acquire_lane


class _Lease:
    def __init__(self, lease, target):
        self._lease = lease
        self._target = target

    def release(self):
        event(f"release {self._target}")
        self._lease.release()
        if self._target in SCENARIO.get("release_fail", []):
            raise OSError(f"cannot unlink the {self._target} holder file")


def _acquire(target, alone, wait_s, directory, holder, **kwargs):
    event(f"lane {target}")
    try:
        lease = _real_acquire(target, alone, wait_s, directory, holder, **kwargs)
    except bring_up.LaneBusy:
        event(f"lane busy {target}")
        raise
    return _Lease(lease, target)


bring_up.acquire_lane = _acquire


def _check(serial):
    event(f"check {serial}")
    status = SCENARIO.get("avd_check", 0)
    print("hw.keyboard=yes")
    print("talkback=" + ("missing" if status else "15.1"))
    return status


tools.e2e_avd.check = _check

_launch_failures = [SCENARIO.get("chrome_launch_fail", 0)]
_page_failures = [SCENARIO.get("chrome_page_fail", 0)]


class _Page:
    def close(self):
        event("page close")


class _Chrome:
    def new_page(self, base_url=None):
        event("page")
        if _page_failures[0]:
            _page_failures[0] -= 1
            raise playwright.sync_api.Error("Target page, context or browser has been closed")
        return _Page()

    def close(self):
        event("chrome close")


class _Chromium:
    def launch(self, channel=None, headless=None):
        event("chrome launch")
        if _launch_failures[0]:
            _launch_failures[0] -= 1
            raise playwright.sync_api.Error(
                "BrowserType.launch: Chromium distribution 'chrome' is not found\nRun npx playwright install chrome"
            )
        return _Chrome()


class _Playwright:
    """Stands in for `sync_playwright()`: its Chromium launches `_Chrome`, failing `chrome_launch_fail` times."""

    chromium = _Chromium()

    def __enter__(self):
        event("playwright start")
        return self

    def __exit__(self, *exc_info):
        event("playwright stop")


playwright.sync_api.sync_playwright = _Playwright

_talkback_failures = [SCENARIO.get("talkback_stuck", 0)]
_keyboard_failures = [SCENARIO.get("uhid_fail", 0)]


def _talkback_enter(self):
    """Stands in for turning TalkBack on; stays bound (TalkBackStuck) the first `talkback_stuck` times."""
    event("talkback on")
    if _talkback_failures[0]:
        _talkback_failures[0] -= 1
        raise talkback.TalkBackStuck("TalkBack still bound 10 s after the off switch")
    return talkback.TalkBackLog(self._serial)


def _keyboard_enter(self):
    """Stands in for registering the uhid keyboard; adb fails the first `uhid_fail` times."""
    event("keyboard on")
    if _keyboard_failures[0]:
        _keyboard_failures[0] -= 1
        raise subprocess.CalledProcessError(1, ["adb", "shell", "hid", "-"], stderr="error: device offline")
    return self


talkback.TalkBackSession.__enter__ = _talkback_enter
talkback.TalkBackSession.__exit__ = lambda self, *exc_info: event("talkback off")
uhid_keyboard.UhidKeyboard.__enter__ = _keyboard_enter
uhid_keyboard.UhidKeyboard.__exit__ = lambda self, *exc_info: event("keyboard off")
'''

INTEGRATION_FILES = {FILE_A: "void main() {}\n", FILE_B: "void main() {}\n"}

MAC_A = """\
@pytest.mark.macos
def test_mac_a(round_target):
    event(f"item {round_target.target.name} test_mac_a")
"""

WEB_A = """\
@pytest.mark.web
def test_web_a(round_target):
    event(f"item {round_target.target.name} test_web_a")
"""

ANDROID_A = """\
@pytest.mark.android
def test_android_a(round_target):
    event(f"item {round_target.target.name} test_android_a")
"""

E2E_HEADER = """\
import os
import signal
import time

import pytest

from round_fake import event

"""


def _make_tree(
    pytester: pytest.Pytester,
    monkeypatch: pytest.MonkeyPatch,
    e2e: str = "",
    scenario: dict[str, Any] | None = None,
    *,
    lane_wait: int = 30,
) -> Path:
    """Mirror the e2e layout: a fixture catalog, the real tests/ modules, fake backends, and `e2e` as test_e2e.py."""
    root = pytester.path / "e2e"
    root.mkdir()
    shutil.copy(E2E_ROOT / "pytest.ini", root / "pytest.ini")
    shutil.copytree(E2E_ROOT / "stratum_e2e", root / "stratum_e2e", ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copytree(E2E_ROOT / "tools", root / "tools", ignore=shutil.ignore_patterns("__pycache__", "*.sh"))
    conftest = (E2E_ROOT / "conftest.py").read_text()
    (root / "conftest.py").write_text(conftest + "\nfrom round_fake import round_backends  # noqa\n")
    (root / "round_fake.py").write_text(FAKE_SOURCE)
    (root / "targets.toml").write_text(TARGETS_TOML.format(mac_app_id=MAC_APP_ID, lane_wait=lane_wait))
    tests = root / "tests"
    tests.mkdir()
    shutil.copy(E2E_ROOT / "tests" / "conftest.py", tests / "conftest.py")
    for folder in ("integration", "perf"):
        shutil.copytree(E2E_ROOT / "tests" / folder, tests / folder, ignore=shutil.ignore_patterns("__pycache__"))
    (tests / "test_e2e.py").write_text(E2E_HEADER + e2e)
    for relative, text in INTEGRATION_FILES.items():
        path = pytester.path / "test_app" / "integration_test" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    _write_scenario(root, scenario or {})
    monkeypatch.chdir(root)
    monkeypatch.setenv(ROUNDS_DIR_ENV, str(pytester.path / "rounds"))
    monkeypatch.setenv(LANE_DIR_ENV, str(pytester.path / "lanes"))
    return root


def _write_scenario(root: Path, scenario: dict[str, Any]) -> None:
    (root / "scenario.json").write_text(json.dumps(scenario))
    (root / "events.log").unlink(missing_ok=True)


def _round(pytester: pytest.Pytester, *args: str) -> pytest.RunResult:
    return pytester.runpytest_subprocess("tests", "-p", "no:cacheprovider", *args)


def _events(root: Path, *prefixes: str) -> list[str]:
    """The events the fakes logged, in order, keeping only lines that start with one of `prefixes` (all without)."""
    path = root / "events.log"
    lines = path.read_text().splitlines() if path.exists() else []
    return [line for line in lines if not prefixes or line.startswith(prefixes)]


def _round_dirs(pytester: pytest.Pytester) -> list[Path]:
    rounds = pytester.path / "rounds"
    return sorted(rounds.iterdir()) if rounds.exists() else []


def _summary(pytester: pytest.Pytester) -> dict[str, Any]:
    """summary.json of the newest round dir."""
    data: dict[str, Any] = json.loads((_round_dirs(pytester)[-1] / "summary.json").read_text())
    return data


def _cells(summary: dict[str, Any]) -> dict[str, dict[str, dict[str, Any]]]:
    """test -> target -> cell of a summary.json."""
    return {row["test"]: row["cells"] for row in summary["rows"]}


def _lifecycle(root: Path) -> list[str]:
    return _events(root, "lane ", "boot ", "item ", "shutdown ", "release ", "run_plan ")


def test_round_runs_targets_one_after_another(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    root = _make_tree(pytester, monkeypatch, MAC_A + WEB_A)
    result = _round(pytester, "--target", "mac,chrome")
    result.assert_outcomes(passed=6)
    assert _lifecycle(root) == [
        "lane mac", "boot mac", "run_plan mac entry", "item mac test_mac_a", "shutdown mac", "release mac",
        "lane chrome", "boot chrome", "run_plan chrome entry", "item chrome test_web_a", "shutdown chrome",
        "release chrome",
    ]


@pytest.mark.parametrize(
    ("how", "failure"),
    [
        ("env", "shutdown failed: simctl shutdown mac failed (status 1): busy"),
        ("os", "shutdown failed: OSError: cannot end mac"),
    ],
)
def test_a_failed_shutdown_is_recorded_on_its_own_target_not_the_next(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch, how: str, failure: str
) -> None:
    root = _make_tree(pytester, monkeypatch, MAC_A + WEB_A, {"shutdown_fail": {"mac": how, "chrome": how}})
    result = _round(pytester, "--target", "mac,chrome")
    result.assert_outcomes(passed=6)
    assert "release mac" in _events(root)
    summary = _summary(pytester)
    cells = _cells(summary)
    assert [cells[test]["chrome"]["class"] for test in (FILE_A, FILE_B, "test_e2e.py::test_web_a")] == ["pass"] * 3
    assert {t["name"]: t["teardown_failures"] for t in summary["targets"]} == {
        "mac": [failure], "chrome": [failure.replace("mac", "chrome")],
    }
    assert f"- teardown of `mac`: {failure}" in (_round_dirs(pytester)[-1] / "summary.md").read_text()


XFAIL_TESTS = """\
@pytest.mark.macos
@pytest.mark.xfail(reason="known gap")
def test_mac_known_gap(round_target):
    assert False


@pytest.mark.macos
@pytest.mark.xfail(reason="fix landed")
def test_mac_fixed(round_target):
    pass


@pytest.mark.macos
@pytest.mark.xfail(reason="must fail", strict=True)
def test_mac_strict(round_target):
    pass
"""


def test_xfail_and_xpass_items_get_their_rows(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch, XFAIL_TESTS)
    result = _round(pytester, "--target", "mac")
    result.assert_outcomes(passed=2, xfailed=1, xpassed=1, failed=1)
    cells = _cells(_summary(pytester))
    gap, fixed, strict = (cells[f"test_e2e.py::test_mac_{name}"]["mac"] for name in ("known_gap", "fixed", "strict"))
    assert (gap["class"], gap["reason"]) == ("xfail", "known gap")
    assert (fixed["class"], fixed["passed"], fixed["reason"]) == ("xpass", 1, "fix landed")
    assert (strict["class"], strict["reason"]) == ("fail", "[XPASS(strict)] must fail")
    markdown = (_round_dirs(pytester)[-1] / "summary.md").read_text()
    assert "| test_e2e.py::test_mac_known_gap | — |" in markdown
    assert "| test_e2e.py::test_mac_fixed | 1/1 |" in markdown
    assert "- `test_e2e.py::test_mac_known_gap` on `mac` [xfail]: known gap" in markdown
    assert "- `test_e2e.py::test_mac_fixed` on `mac` [xpass]: fix landed" in markdown


def test_a_failed_lane_release_is_recorded_on_its_own_target(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    _make_tree(pytester, monkeypatch, MAC_A + WEB_A, {"release_fail": ["mac"]})
    result = _round(pytester, "--target", "mac,chrome")
    result.assert_outcomes(passed=6)
    summary = _summary(pytester)
    assert _cells(summary)[FILE_A]["chrome"]["class"] == "pass"
    assert {t["name"]: t["teardown_failures"] for t in summary["targets"]} == {
        "mac": ["lane release failed: OSError: cannot unlink the mac holder file"], "chrome": [],
    }


def test_lane_busy_reports_env_on_every_item_of_that_target_and_moves_on(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, MAC_A + WEB_A, lane_wait=0)
    holder = Holder(pid=os.getpid(), session="unittest", started="2026-10-24T00:00:00+00:00")
    with acquire_lane("chrome", False, 0, pytester.path / "lanes", holder):
        result = _round(pytester, "--target", "chrome,mac")
    result.assert_outcomes(passed=3, errors=3)
    cells = _cells(_summary(pytester))
    chrome = [cells[test]["chrome"] for test in (FILE_A, FILE_B, "test_e2e.py::test_web_a")]
    assert [(cell["class"], cell["reason"]) for cell in chrome] == [("env", "lane busy")] * 3
    assert [cells[test]["mac"]["class"] for test in (FILE_A, FILE_B, "test_e2e.py::test_mac_a")] == ["pass"] * 3
    assert _events(root, "lane busy ") == ["lane busy chrome"]
    assert "boot chrome" not in _events(root)
    assert "boot mac" in _events(root)


def test_boot_env_retries_once_then_blocks_the_target(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, MAC_A + WEB_A, {"boot_fail": {"mac": 2}})
    result = _round(pytester, "--target", "mac,chrome")
    result.assert_outcomes(passed=3, errors=3)
    assert _events(root, "boot mac") == ["boot mac", "boot mac"]
    assert "release mac" in _events(root)
    assert "shutdown mac" not in _events(root)
    cells = _cells(_summary(pytester))
    for test in (FILE_A, FILE_B, "test_e2e.py::test_mac_a"):
        assert (cells[test]["mac"]["class"], cells[test]["mac"]["reason"]) == ("env", "target blocked")
    assert "item chrome test_web_a" in _events(root)


def test_integration_env_reruns_once_then_blocks(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    root = _make_tree(pytester, monkeypatch, MAC_A + WEB_A, {"plan_env": {"mac": 2}})
    result = _round(pytester, "--target", "mac,chrome")
    result.assert_outcomes(passed=3, failed=2, errors=1)
    assert _events(root, "run_plan mac") == ["run_plan mac entry", "run_plan mac entry"]
    assert "item mac test_mac_a" not in _events(root)
    cells = _cells(_summary(pytester))
    for test in (FILE_A, FILE_B, "test_e2e.py::test_mac_a"):
        assert (cells[test]["mac"]["class"], cells[test]["mac"]["reason"]) == ("env", "target blocked")
    assert cells[FILE_A]["chrome"]["class"] == "pass"


def test_integration_env_once_reruns_and_passes(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    root = _make_tree(pytester, monkeypatch, MAC_A, {"plan_env": {"mac": 1}})
    result = _round(pytester, "--target", "mac")
    result.assert_outcomes(passed=3)
    assert _events(root, "run_plan mac") == ["run_plan mac entry", "run_plan mac entry"]
    assert _cells(_summary(pytester))[FILE_A]["mac"]["class"] == "pass"


def test_reused_target_gets_no_settings_no_restore_no_kill(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    scenario = {"real_android": "Pixel_8_API_37", "reused_serial": REUSED_SERIAL}
    root = _make_tree(pytester, monkeypatch, ANDROID_A, scenario)
    result = _round(pytester, "--target", "pixel_8")
    result.assert_outcomes(passed=3)
    summary = _summary(pytester)
    assert summary["targets"][0] == {
        "name": "pixel_8", "platform": "android", "device": REUSED_SERIAL, "reused": True, "setting_failures": [],
        "teardown_failures": [],
    }
    device_calls = [line for line in _events(root, "run ", "spawn ") if REUSED_SERIAL in line or "emulator" in line]
    assert device_calls, "the reused emulator was never asked anything"
    assert not [line for line in device_calls if "settings" in line or "kill" in line or line.startswith("spawn")]
    assert not _events(root, "run pgrep", "sleep")


def test_integration_items_split_per_file(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch, scenario={"outcomes": {FILE_A: "pass", FILE_B: "fail"}})
    result = _round(pytester, "--target", "mac")
    result.assert_outcomes(passed=1, failed=1)
    cells = _cells(_summary(pytester))
    passing = cells[FILE_A]["mac"]
    assert (passing["class"], passing["passed"], passing["runs"]) == ("pass", 1, 1)
    assert (cells[FILE_B]["mac"]["class"], cells[FILE_B]["mac"]["reason"]) == ("fail", f"{FILE_B} broke")
    markdown = (_round_dirs(pytester)[-1] / "summary.md").read_text()
    assert f"| {FILE_A} | 1/1 | tag/a_test |" in markdown
    assert f"| {FILE_B} | fail | tag/b_test |" in markdown


def test_target_with_no_selected_item_never_boots(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    web_app = """\
@pytest.mark.web
def test_web_app(round_app):
    event(f"app {round_app}")
"""
    root = _make_tree(pytester, monkeypatch, MAC_A + web_app)
    result = _round(pytester, "--target", "mac,chrome", "-k", "mac")
    result.assert_outcomes(passed=3)
    events = _events(root)
    assert not [line for line in events if "chrome" in line]
    assert not _events(root, "build ")
    assert [target["name"] for target in _summary(pytester)["targets"]] == ["mac"]


def test_sigterm_mid_round_restores_and_kills(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    sigterm = """\
@pytest.mark.macos
def test_mac_sigterm(round_target):
    event("item mac sigterm")
    os.kill(os.getpid(), signal.SIGTERM)
    time.sleep(30)
    event("item mac survived")
"""
    root = _make_tree(pytester, monkeypatch, sigterm)
    result = _round(pytester, "--target", "mac")
    assert result.ret == pytest.ExitCode.INTERRUPTED
    events = _events(root)
    assert "item mac survived" not in events
    assert events.index("shutdown mac") > events.index("item mac sigterm")
    assert events.index("release mac") > events.index("shutdown mac")
    assert (_round_dirs(pytester)[-1] / "summary.json").is_file()


def test_round_dir_holds_summary_and_item_logs(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    failing = """\
@pytest.mark.macos
def test_mac_fails(round_target):
    assert 1 == 2
"""
    root = _make_tree(pytester, monkeypatch, MAC_A + failing)
    result = _round(pytester, "--target", "mac")
    result.assert_outcomes(passed=3, failed=1)
    round_dir = _round_dirs(pytester)[-1]
    assert (round_dir / "summary.md").is_file()
    assert (round_dir / "summary.json").is_file()
    cells = _cells(_summary(pytester))
    flutter_log = cells[FILE_A]["mac"]["log"]
    assert flutter_log.startswith("mac/") and flutter_log.endswith("/flutter.log")
    assert (round_dir / flutter_log).read_text().startswith("ran ")
    failed = cells["test_e2e.py::test_mac_fails"]["mac"]
    assert failed["class"] == "fail"
    assert "assert 1 == 2" in failed["reason"]
    assert "assert 1 == 2" in (round_dir / failed["log"]).read_text()
    assert (round_dir / cells["test_e2e.py::test_mac_a"]["mac"]["log"]).is_file()
    assert len(_events(root, "run screencapture")) == 1
    assert (round_dir / failed["log"]).with_name("screenshot.png").read_bytes() == b"png"
    assert not (round_dir / cells["test_e2e.py::test_mac_a"]["mac"]["log"]).with_name("screenshot.png").exists()


def test_low_level_override_wins(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    options = """\
@pytest.mark.macos
def test_mac_options(request, round_app):
    event(f"app {round_app}")
    event("options " + " ".join(str(request.config.getoption(name)) for name in ("platform", "device", "app_id")))
"""
    root = _make_tree(pytester, monkeypatch, options)
    result = _round(pytester, "--target", "mac", "--app", "/x.app", "--app-id", "com.example.override")
    result.assert_outcomes(passed=3)
    assert _events(root, "app ") == ["app /x.app"]
    assert _events(root, "options ") == ["options macos mac com.example.override"]
    assert not _events(root, "build ")


def test_round_resolves_the_low_level_options_per_target(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    options = """\
@pytest.mark.macos
def test_mac_options(request, platform, app_id):
    event("options " + " ".join(str(request.config.getoption(name)) for name in ("platform", "device", "app_id")))
"""
    root = _make_tree(pytester, monkeypatch, options)
    result = _round(pytester, "--target", "mac")
    result.assert_outcomes(passed=3)
    assert _events(root, "options ") == [f"options macos mac {MAC_APP_ID}"]


def test_app_build_runs_once_per_platform(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    android_app = """\
@pytest.mark.android
def test_android_app(round_target, round_app):
    event(f"app {round_target.target.name} {round_app.name}")
"""
    root = _make_tree(pytester, monkeypatch, android_app, {"running": ["pixel_8", "tablet"]})
    result = _round(pytester, "--target", "pixel_8,tablet")
    result.assert_outcomes(passed=6)
    assert _events(root, "build ") == ["build android"]
    assert _events(root, "app ") == ["app pixel_8 app-android", "app tablet app-android"]
    app_builds = [build for build in _summary(pytester)["builds"] if build["command"][:2] == ["flutter", "build"]]
    build = {"target": "pixel_8", "command": ["flutter", "build", "android"], "seconds": 2.0, "reused": False}
    assert app_builds == [build]


def test_perf_runs_in_example(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    root = _make_tree(pytester, monkeypatch)
    result = _round(pytester, "--target", "mac", "-m", "perf")
    result.assert_outcomes(passed=1)
    assert _events(root, "run dart") == ["run dart run tool/perf_abba.dart cwd=example"]
    assert _cells(_summary(pytester))["perf/test_perf_abba.py::test_perf_abba"]["mac"]["class"] == "pass"


def test_legacy_run_never_runs_perf_even_when_a_marker_selects_it(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch)
    result = _round(pytester, "--platform", "macos", "-m", "perf", "-rs")
    result.assert_outcomes(skipped=1)
    assert "perf runs only in a device round" in result.stdout.str()
    assert not _events(root, "run dart")


def test_perf_fails_on_a_non_zero_exit(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch, scenario={"perf_status": 3})
    result = _round(pytester, "--target", "mac", "-m", "perf")
    result.assert_outcomes(failed=1)


def test_reused_target_skips_the_memory_gate(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    qemu = "4242 qemu-system-aarch64 -avd Pixel_8_API_37"
    scenario = {"running": ["pixel_8"], "pgrep": [qemu, ""]}
    root = _make_tree(pytester, monkeypatch, ANDROID_A, scenario)
    result = _round(pytester, "--target", "pixel_8,tablet")
    result.assert_outcomes(passed=6)
    probe = f"run pgrep -fl {heavy_pattern(())}"
    assert _events(root, "boot ", "run pgrep", "sleep") == ["boot pixel_8", probe, "sleep", probe, "boot tablet"]


def test_memory_pressure_that_stays_is_env(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    scenario = {"pgrep": ["4242 qemu-system-aarch64 -avd Pixel_8_API_37"]}
    root = _make_tree(pytester, monkeypatch, ANDROID_A, scenario, lane_wait=0)
    result = _round(pytester, "--target", "tablet")
    result.assert_outcomes(errors=3)
    assert not _events(root, "boot ")
    reason = _cells(_summary(pytester))[FILE_A]["tablet"]["reason"]
    assert reason.startswith("memory pressure: a heavy process is running: 4242 qemu-system")


def test_linux_builds_its_app_once_per_round_before_its_first_run(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch)
    _round(pytester, "--target", "linux").assert_outcomes(passed=2)
    assert _events(root, "run_plan ") == ["run_plan linux entry build", "run_plan linux plain_name"]
    builds = [(build["command"], build["seconds"]) for build in _summary(pytester)["builds"]]
    assert builds[0] == (["flutter", "build", "linux"], 4.0)
    assert [command[:2] for command, _ in builds[1:]] == [["flutter", "test"]] * 2


def test_linux_build_that_failed_reads_build_and_the_next_run_builds_again(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, scenario={"linux_build_fail": 1})
    _round(pytester, "--target", "linux").assert_outcomes(passed=1, failed=1)
    assert _events(root, "run_plan ") == ["run_plan linux entry build", "run_plan linux plain_name build"]
    cells = _cells(_summary(pytester))
    build = [cell["linux"] for cell in cells.values() if cell["linux"]["class"] == "build"]
    assert [cell["reason"] for cell in build] == ["CMake Error: The source does not match the source used to "
                                                  "generate cache."]
    assert build[0]["log"].endswith("/linux_build.log")
    builds = [build["command"] for build in _summary(pytester)["builds"]]
    assert builds.count(["flutter", "build", "linux"]) == 2


def test_linux_builds_again_after_a_failed_launch(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    root = _make_tree(pytester, monkeypatch, scenario={"outcomes": {FILE_A: "fail"}})
    _round(pytester, "--target", "linux").assert_outcomes(passed=1, failed=1)
    assert _events(root, "run_plan ") == ["run_plan linux entry build", "run_plan linux plain_name build"]


def test_a_build_that_fails_twice_reads_build_for_every_item_and_blocks_nothing(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    apps = MAC_APP + "".join(MAC_APP.replace("test_mac_app", f"test_mac_app_{n}") for n in (2, 3))
    root = _make_tree(pytester, monkeypatch, apps, {"broken_build": {"macos": 99}})
    _round(pytester, "--target", "mac").assert_outcomes(passed=2, errors=3)
    assert _events(root, "build ") == ["build macos", "build macos"]
    summary = _summary(pytester)
    cells = _cells(summary)
    for test in ("test_e2e.py::test_mac_app", "test_e2e.py::test_mac_app_2", "test_e2e.py::test_mac_app_3"):
        cell = cells[test]["mac"]
        assert (cell["class"], cell["reason"]) == ("build", "lib/main.dart:5:3: Error: Method not found: 'runAp'.")
        assert cell["log"] == "mac/app%20build/build.log"
    app_builds = [build for build in summary["builds"] if build["command"][:2] == ["flutter", "build"]]
    assert [(build["command"], build["seconds"]) for build in app_builds] == [(["flutter", "build", "macos"], 3.0)] * 2


def test_a_build_that_fails_once_runs_on_its_plain_rebuild(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, MAC_APP, {"broken_build": {"macos": 1}})
    _round(pytester, "--target", "mac").assert_outcomes(passed=3)
    assert _events(root, "build ", "app ") == ["build macos", "build macos", "app app-macos"]
    assert _cells(_summary(pytester))["test_e2e.py::test_mac_app"]["mac"]["class"] == "pass"
    app_builds = [build["seconds"] for build in _summary(pytester)["builds"] if build["command"][:2] == ["flutter",
                                                                                                         "build"]]
    assert app_builds == [3.0, 2.0]


def test_integration_run_is_recorded_as_a_build_entry(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    _make_tree(pytester, monkeypatch)
    _round(pytester, "--target", "mac").assert_outcomes(passed=2)
    builds = _summary(pytester)["builds"]
    assert len(builds) == 1
    assert builds[0]["target"] == "mac"
    assert builds[0]["command"][:2] == ["flutter", "test"]
    assert (builds[0]["seconds"], builds[0]["reused"]) == (1.5, False)


DRIVER_TESTS = """\
@pytest.mark.macos
@pytest.mark.req("fo01/us01/s1")
def test_mac_driver_a(driver):
    event("item mac driver_a")


@pytest.mark.macos
def test_mac_driver_b(driver):
    event("item mac driver_b")


@pytest.mark.macos
def test_mac_plain(round_target):
    event("item mac plain")
"""


def test_appium_session_failure_is_env_and_retried_once(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, DRIVER_TESTS + WEB_A, {"remote_fail": 1})
    result = _round(pytester, "--target", "mac,chrome")
    result.assert_outcomes(passed=8)
    assert _events(root, "remote", "item mac driver") == ["remote", "remote", "item mac driver_a", "remote",
                                                          "item mac driver_b"]
    cells = _cells(_summary(pytester))
    assert cells["test_e2e.py::test_mac_driver_a"]["mac"]["class"] == "pass"
    row = next(row for row in _summary(pytester)["rows"] if row["test"] == "test_e2e.py::test_mac_driver_a")
    assert row["stories"] == ["fo01/us01/s1"]


def test_second_appium_failure_on_a_module_blocks_the_target(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, DRIVER_TESTS + WEB_A, {"remote_fail": 99})
    result = _round(pytester, "--target", "mac,chrome")
    result.assert_outcomes(passed=5, errors=3)
    assert _events(root, "remote") == ["remote", "remote"]
    cells = _cells(_summary(pytester))
    first = cells["test_e2e.py::test_mac_driver_a"]["mac"]
    assert first["class"] == "env"
    assert first["reason"].startswith("appium session")
    for test in ("test_e2e.py::test_mac_driver_b", "test_e2e.py::test_mac_plain"):
        assert (cells[test]["mac"]["class"], cells[test]["mac"]["reason"]) == ("env", "target blocked")
    assert cells["test_e2e.py::test_web_a"]["chrome"]["class"] == "pass"
    assert "release mac" in _events(root)
    assert len(_events(root, "run screencapture")) == 2  # both runs of driver_a; a blocked item captures nothing
    round_dir = _round_dirs(pytester)[-1]
    blocked_dir = (round_dir / cells["test_e2e.py::test_mac_driver_b"]["mac"]["log"]).parent
    assert sorted(path.name for path in blocked_dir.iterdir()) == ["pytest.log"]


ANDROID_DRIVER = """\
@pytest.mark.android
def test_android_driver(round_target, driver):
    event(f"item {round_target.target.name} android_driver")
"""


def test_appium_start_failure_once_is_retried_and_spares_the_next_target(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, DRIVER_TESTS + ANDROID_DRIVER, {"appium_fail": 1})
    result = _round(pytester, "--target", "mac,pixel_8")
    result.assert_outcomes(passed=8)
    assert _events(root, "appium start") == ["appium start", "appium start"]
    cells = _cells(_summary(pytester))
    assert cells["test_e2e.py::test_mac_driver_a"]["mac"]["class"] == "pass"
    assert cells["test_e2e.py::test_android_driver"]["pixel_8"]["class"] == "pass"


def test_each_target_installs_even_on_a_serial_an_earlier_target_used(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    scenario = {"devices": {"pixel_8": "emulator-5554", "tablet": "emulator-5554"}}
    root = _make_tree(pytester, monkeypatch, ANDROID_DRIVER, scenario)
    result = _round(pytester, "--target", "pixel_8,tablet")
    result.assert_outcomes(passed=6)
    assert _events(root, "install ") == ["install emulator-5554", "install emulator-5554"]
    assert _events(root, "build ") == ["build android"]


def test_app_build_env_once_is_built_again_on_the_rerun(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    mac_app = """\
@pytest.mark.macos
def test_mac_app(round_app):
    event(f"app {round_app.name}")
"""
    root = _make_tree(pytester, monkeypatch, mac_app + MAC_A, {"build_fail": {"macos": 1}})
    result = _round(pytester, "--target", "mac")
    result.assert_outcomes(passed=4)
    assert _events(root, "build ", "app ") == ["build macos", "build macos", "app app-macos"]
    assert _cells(_summary(pytester))["test_e2e.py::test_mac_app"]["mac"]["class"] == "pass"


def test_setting_failures_reach_the_summary(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    failure = "global window_animation_scale 0 (status 255: denied)"
    _make_tree(pytester, monkeypatch, MAC_A, {"setting_failures": {"mac": [failure]}})
    _round(pytester, "--target", "mac").assert_outcomes(passed=3)
    round_dir = _round_dirs(pytester)[-1]
    assert _summary(pytester)["targets"][0]["setting_failures"] == [failure]
    assert f"- boot setting on `mac` failed: {failure}" in (round_dir / "summary.md").read_text()
    assert not list(round_dir.rglob("setting_failures.txt"))


def test_a_second_bring_up_keeps_the_first_boots_setting_failures(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    last_driver = """\
@pytest.mark.macos
def test_mac_driver_last(driver):
    event("item mac driver_last")
"""
    failures = [f"global window_animation_scale 0 (status 255: boot {boot})" for boot in (1, 2)]
    root = _make_tree(pytester, monkeypatch, last_driver, {"remote_fail": 1, "setting_failures": {"mac": failures}})
    _round(pytester, "--target", "mac").assert_outcomes(passed=3)
    assert _events(root, "shutdown ") == ["shutdown mac", "shutdown mac"]
    assert _summary(pytester)["targets"][0]["setting_failures"] == failures


def test_appium_server_failure_is_env(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch, DRIVER_TESTS, {"appium_fail": 99})
    result = _round(pytester, "--target", "mac")
    result.assert_outcomes(passed=2, errors=3)
    cells = _cells(_summary(pytester))
    assert cells["test_e2e.py::test_mac_driver_a"]["mac"]["reason"].startswith("appium server")


WEB_DRIVER = """\
@pytest.mark.web
def test_web_driver_a(driver):
    event("item chrome web_driver_a")


@pytest.mark.web
def test_web_driver_b(driver):
    event("item chrome web_driver_b")
"""

CHROME_MISSING = "chrome launch failed: BrowserType.launch: Chromium distribution 'chrome' is not found"


def test_chrome_launch_failure_is_env_and_the_rerun_launches_again(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, WEB_DRIVER, {"chrome_launch_fail": 1})
    result = _round(pytester, "--target", "chrome")
    result.assert_outcomes(passed=4)
    assert _events(root, "chrome launch") == ["chrome launch", "chrome launch"]
    assert _cells(_summary(pytester))["test_e2e.py::test_web_driver_a"]["chrome"]["class"] == "pass"


def test_chrome_launch_failure_that_stays_reads_env(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    _make_tree(pytester, monkeypatch, WEB_DRIVER, {"chrome_launch_fail": 99})
    result = _round(pytester, "--target", "chrome")
    result.assert_outcomes(passed=2, errors=2)
    cells = _cells(_summary(pytester))
    first = cells["test_e2e.py::test_web_driver_a"]["chrome"]
    assert (first["class"], first["reason"]) == ("env", CHROME_MISSING)
    assert cells["test_e2e.py::test_web_driver_b"]["chrome"]["class"] == "env"


def test_chrome_page_failure_is_env(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    root = _make_tree(pytester, monkeypatch, WEB_DRIVER, {"chrome_page_fail": 1})
    result = _round(pytester, "--target", "chrome")
    result.assert_outcomes(passed=4)
    assert [line for line in _events(root) if line == "page"] == ["page"] * 3
    assert _events(root, "chrome launch") == ["chrome launch"]


def test_legacy_chrome_launch_failure_is_kept_for_the_session(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, WEB_DRIVER, {"chrome_launch_fail": 99})
    build = pytester.path / "web_build"
    build.mkdir()
    result = _round(pytester, "--platform", "web", "--device", "chrome", "--app", str(build), "--app-id", "x")
    result.assert_outcomes(skipped=1, errors=2)  # the integration item has no platform marker
    assert _events(root, "chrome launch") == ["chrome launch"]
    assert CHROME_MISSING in result.stdout.str()


TALKBACK_TESTS = """\
@pytest.mark.android
@pytest.mark.talkback_avd
def test_talkback_a(round_target):
    event(f"item {round_target.target.name} test_talkback_a")


@pytest.mark.android
def test_android_a(round_target):
    event(f"item {round_target.target.name} test_android_a")
"""


def test_talkback_avd_check_failure_is_env(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    root = _make_tree(pytester, monkeypatch, TALKBACK_TESTS, {"avd_check": 1})
    result = _round(pytester, "--target", "e2e_talkback,pixel_8")
    result.assert_outcomes(passed=3, errors=1)
    assert _events(root, "check ") == ["check dev-e2e_talkback"]
    assert "shutdown e2e_talkback" in _events(root)
    reason = _cells(_summary(pytester))["test_e2e.py::test_talkback_a"]["e2e_talkback"]["reason"]
    assert reason.startswith("tools.e2e_avd talkback|diagnosis: ")
    assert "talkback=missing" in reason

    _write_scenario(root, {"avd_check": 0})
    _round(pytester, "--target", "e2e_talkback").assert_outcomes(passed=1)
    assert _events(root, "check ", "item ") == ["check dev-e2e_talkback", "item e2e_talkback test_talkback_a"]


TALKBACK_FIXTURE = """\
@pytest.mark.android
@pytest.mark.talkback_avd
def test_talkback_speaks(talkback):
    event("item talkback_speaks")
"""

KEYBOARD_FIXTURE = """\
@pytest.mark.android
def test_keyboard_types(keyboard):
    event("item keyboard_types")
"""


def test_talkback_setup_failure_is_env_and_retried(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    root = _make_tree(pytester, monkeypatch, TALKBACK_FIXTURE, {"talkback_stuck": 1})
    _round(pytester, "--target", "e2e_talkback").assert_outcomes(passed=1)
    assert _events(root, "talkback on", "item ") == ["talkback on", "talkback on", "item talkback_speaks"]

    _write_scenario(root, {"talkback_stuck": 99})
    _round(pytester, "--target", "e2e_talkback").assert_outcomes(errors=1)
    cell = _cells(_summary(pytester))["test_e2e.py::test_talkback_speaks"]["e2e_talkback"]
    expected = "talkback setup on dev-e2e_talkback failed: TalkBack still bound 10 s after the off switch"
    assert (cell["class"], cell["reason"]) == ("env", expected)


def test_uhid_keyboard_setup_failure_is_env(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    root = _make_tree(pytester, monkeypatch, KEYBOARD_FIXTURE, {"uhid_fail": 99})
    _round(pytester, "--target", "tablet").assert_outcomes(passed=2, errors=1)
    assert _events(root, "keyboard on") == ["keyboard on", "keyboard on"]
    cell = _cells(_summary(pytester))["test_e2e.py::test_keyboard_types"]["tablet"]
    assert cell["class"] == "env"
    assert cell["reason"].startswith("uhid keyboard setup on dev-tablet failed: Command '['adb', 'shell', 'hid', '-']'")


def test_round_option_leaves_unit_items_unparametrized_and_in_order(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, MAC_A)
    (root / "unit").mkdir()
    (root / "unit" / "test_u.py").write_text("def test_b(): pass\n\n\ndef test_a(): pass\n")
    result = pytester.runpytest_subprocess("unit", "tests", "--collect-only", "-q", "--target", "mac")
    assert result.ret == 0
    unit = [line for line in result.outlines if line.startswith("unit/")]
    assert unit == ["unit/test_u.py::test_b", "unit/test_u.py::test_a"]
    assert not _round_dirs(pytester)


def test_legacy_run_without_options_skips_every_tests_item(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, MAC_A)
    result = _round(pytester, "-rs")
    result.assert_outcomes(skipped=2)
    assert "no --platform given" in result.stdout.str()
    assert not _events(root)
    assert not _round_dirs(pytester)


def test_legacy_appium_start_failure_is_kept_for_the_session(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, DRIVER_TESTS, {"appium_fail": 99})
    app = pytester.path / "app.app"
    app.mkdir()
    result = _round(pytester, "--platform", "macos", "--device", "mac", "--app", str(app), "--app-id", MAC_APP_ID)
    result.assert_outcomes(passed=1, skipped=1, errors=2)  # the integration item has no platform marker
    assert _events(root, "appium start") == ["appium start"]
    assert not _round_dirs(pytester)


INSTALL_TESTS = """\
@pytest.mark.android
def test_install_a(installed_app):
    event("item install_a")


@pytest.mark.android
def test_install_b(installed_app):
    event("item install_b")
"""


def test_legacy_install_failure_is_kept_for_the_session(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, INSTALL_TESTS, {"install_fail": 99})
    apk = pytester.path / "app.apk"
    apk.write_bytes(b"apk")
    result = _round(pytester, "--platform", "android", "--device", REUSED_SERIAL, "--app", str(apk), "--app-id", "x")
    result.assert_outcomes(skipped=1, errors=2)  # the integration item has no platform marker
    assert _events(root, "install ") == [f"install {REUSED_SERIAL}"]
    assert f"env: app install on {REUSED_SERIAL} failed" in result.stdout.str()


def test_round_install_failure_installs_again_on_the_rerun(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, INSTALL_TESTS, {"install_fail": 1, "running": ["tablet"]})
    result = _round(pytester, "--target", "tablet")
    result.assert_outcomes(passed=4)
    assert _events(root, "install ") == ["install dev-tablet", "install dev-tablet"]


MAC_APP = """\
@pytest.mark.macos
def test_mac_app(round_app):
    event(f"app {round_app.name}")
"""


def test_packages_resolve_once_before_the_first_build_and_the_first_run(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, MAC_APP + MAC_A)
    _round(pytester, "--target", "mac").assert_outcomes(passed=4)
    events = _events(root, "resolve ", "build ", "run_plan ")
    assert events[0] == "resolve test_app"
    assert sorted(events[1:]) == ["build macos", "run_plan mac entry"]


def test_failed_resolve_is_env_for_the_integration_files_and_retried_once(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, MAC_A, {"resolve_fail": 1})
    _round(pytester, "--target", "mac").assert_outcomes(passed=3)
    assert _events(root, "resolve ", "run_plan ") == ["resolve test_app", "resolve test_app", "run_plan mac entry"]
    assert _cells(_summary(pytester))[FILE_A]["mac"]["class"] == "pass"


def test_resolve_failing_twice_blocks_the_target_as_env_without_a_run(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, MAC_A + WEB_A, {"resolve_fail": 2})
    _round(pytester, "--target", "mac,chrome")
    assert _events(root, "resolve ", "run_plan ") == [
        "resolve test_app", "resolve test_app", "resolve test_app", "run_plan chrome entry"
    ]
    cells = _cells(_summary(pytester))
    for test in (FILE_A, FILE_B):
        assert (cells[test]["mac"]["class"], cells[test]["mac"]["reason"]) == ("env", "target blocked")
    assert cells[FILE_A]["chrome"]["class"] == "pass"


def test_failed_resolve_before_an_app_build_is_env_and_the_rerun_builds(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, MAC_APP, {"resolve_fail": 1})
    _round(pytester, "--target", "mac").assert_outcomes(passed=3)
    assert _events(root, "resolve ", "build ", "app ") == ["resolve test_app", "resolve test_app", "build macos",
                                                           "app app-macos"]


def test_locked_console_is_env_before_any_appium_session(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, DRIVER_TESTS + WEB_A, {"console_locked": True})
    _round(pytester, "--target", "mac,chrome")
    assert _events(root, "remote", "item mac driver") == []
    cells = _cells(_summary(pytester))
    first = cells["test_e2e.py::test_mac_driver_a"]["mac"]
    assert first["class"] == "env"
    assert first["reason"].startswith("macOS console locked")
    assert cells["test_e2e.py::test_mac_plain"]["mac"]["class"] == "env"
    assert cells["test_e2e.py::test_web_a"]["chrome"]["class"] == "pass"


def test_unlocked_console_reaches_the_appium_session(
    pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _make_tree(pytester, monkeypatch, DRIVER_TESTS, {"console_locked": False})
    _round(pytester, "--target", "mac").assert_outcomes(passed=5)
    assert _events(root, "remote") == ["remote", "remote"]
    assert len(_events(root, "run ioreg")) == 2


def test_legacy_run_never_reads_the_console_lock(pytester: pytest.Pytester, monkeypatch: pytest.MonkeyPatch) -> None:
    root = _make_tree(pytester, monkeypatch, DRIVER_TESTS, {"console_locked": True})
    app = pytester.path / "app.app"
    app.mkdir()
    result = _round(pytester, "--platform", "macos", "--device", "mac", "--app", str(app), "--app-id", MAC_APP_ID)
    result.assert_outcomes(passed=3, skipped=1)
    assert _events(root, "remote") == ["remote", "remote"]
    assert _events(root, "run ioreg") == []
