"""Unit tests for the iOS pair resolver, the simulator booter, and the host booter, with a scripted simctl."""

from __future__ import annotations

import copy
import json
from collections.abc import Mapping, Sequence
from pathlib import Path

import pytest

from stratum_e2e.round.catalog import LaneConfig, Target
from stratum_e2e.round.errors import CatalogError, RoundEnvError
from stratum_e2e.round.ios_boot import HostBooter, IosBooter, IosPair, PairError, resolve_pair
from stratum_e2e.round.runner import Completed
from unit.round_fakes import FakeRunner

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "round" / "simctl_list.json"
HOME = Path("/Users/tester")
PLIST = str(HOME / "Library/Preferences/com.apple.iphonesimulator.plist")
PLISTBUDDY = "/usr/libexec/PlistBuddy"
RUNTIME_PREFIX = "com.apple.CoreSimulator.SimRuntime.iOS-"
IPHONE = Target(name="iphone", platform="ios", device="iPhone 17", e2e=False)
IPHONE_E2E = Target(name="iphone_e2e", platform="ios", device="iPhone Duo", runtime="iOS 27.1", integration=False)
LANE = LaneConfig(
    run_timeout_minutes=20,
    boot_settle_timeout_seconds=420,
    allow_level2=True,
    heavy_processes=(),
    lane_wait_minutes=30,
    boot_timeout_minutes=10,
)

Entry = tuple[tuple[str, ...], Completed]


class TimeoutRecordingRunner(FakeRunner):
    """A FakeRunner that also keeps the timeout each argv ran under."""

    def __init__(self, script: list[Entry]) -> None:
        super().__init__(script)
        self.timeouts: dict[tuple[str, ...], float | None] = {}

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed:
        self.timeouts[tuple(argv)] = timeout_s
        return super().run(argv, timeout_s=timeout_s, cwd=cwd, env=env, log=log)


def _fixture() -> dict[str, object]:
    loaded: dict[str, object] = json.loads(FIXTURE.read_text())
    return loaded


def _done(stdout: str = "", status: int = 0, stderr: str = "", *, timed_out: bool = False) -> Completed:
    return Completed(argv=(), status=status, stdout=stdout, stderr=stderr, timed_out=timed_out)


def _with_state(fixture: Mapping[str, object], udid: str, state: str) -> dict[str, object]:
    """A deep copy of `fixture` in which the simulator `udid` is in `state`."""
    edited = copy.deepcopy(dict(fixture))
    devices = edited["devices"]
    assert isinstance(devices, dict)
    for listed in devices.values():
        for device in listed:
            if device["udid"] == udid:
                device["state"] = state
    return edited


def _without_runtime(fixture: Mapping[str, object], name: str) -> dict[str, object]:
    """A deep copy of `fixture` in which the runtime `name` is marked unavailable."""
    edited = copy.deepcopy(dict(fixture))
    runtimes = edited["runtimes"]
    assert isinstance(runtimes, list)
    for runtime in runtimes:
        if runtime["name"] == name:
            runtime["isAvailable"] = False
    return edited


def _listing(fixture: Mapping[str, object]) -> Entry:
    return (("xcrun", "simctl", "list", "-j"), _done(json.dumps(fixture)))


def _pair() -> IosPair:
    return resolve_pair(_fixture(), "iPhone 17", None)


def _pin_script(udid: str) -> list[Entry]:
    key = f":DevicePreferences:{udid}:ConnectHardwareKeyboard"
    return [
        (("defaults", "write", "com.apple.iphonesimulator", "ConnectHardwareKeyboard", "-bool", "false"), _done()),
        ((PLISTBUDDY, "-c", f"Print :DevicePreferences:{udid}", PLIST), _done()),
        ((PLISTBUDDY, "-c", f"Set {key} false", PLIST), _done()),
    ]


def _booter(script: list[Entry]) -> tuple[IosBooter, FakeRunner]:
    runner = FakeRunner(script)
    return IosBooter(runner, LANE, HOME), runner


def test_iphone_17_resolves_to_ios_27_0() -> None:
    pair = resolve_pair(_fixture(), "iPhone 17", None)

    assert pair.runtime_name == "iOS 27.0"
    assert pair.runtime_id == RUNTIME_PREFIX + "27-0"
    assert pair.state == "Shutdown"
    assert pair.udid


def test_pinned_runtime_resolves_iphone_duo() -> None:
    pair = resolve_pair(_fixture(), "iPhone Duo", "iOS 27.1")

    assert pair.runtime_name == "iOS 27.1"


def test_unpinned_device_in_many_runtimes_takes_the_newest() -> None:
    # "iPhone Air" is held by iOS 26.2 and iOS 27.0; the newer wins without a pin.
    assert resolve_pair(_fixture(), "iPhone Air", None).runtime_name == "iOS 27.0"
    assert resolve_pair(_fixture(), "iPhone Air", "iOS 26.2").runtime_name == "iOS 26.2"


def test_device_no_runtime_holds_fails_naming_both() -> None:
    with pytest.raises(PairError, match="iPhone 99.*iOS 27.1"):
        resolve_pair(_fixture(), "iPhone 99", "iOS 27.1")


def test_pinned_runtime_without_the_device_fails_even_when_another_runtime_holds_it() -> None:
    with pytest.raises(PairError, match="iPhone 17.*iOS 27.1"):
        resolve_pair(_fixture(), "iPhone 17", "iOS 27.1")


def test_unpinned_missing_device_fails_naming_the_device() -> None:
    with pytest.raises(PairError, match="iPhone 99"):
        resolve_pair(_fixture(), "iPhone 99", None)


def test_pair_error_is_a_round_env_error() -> None:
    with pytest.raises(RoundEnvError, match="^env: "):
        resolve_pair(_fixture(), "iPhone 99", None)


def test_unavailable_runtime_is_skipped() -> None:
    fixture = _without_runtime(_fixture(), "iOS 27.0")

    assert resolve_pair(fixture, "iPhone 17", None).runtime_name == "iOS 26.2"
    with pytest.raises(PairError, match="iPhone 17.*iOS 27.0"):
        resolve_pair(fixture, "iPhone 17", "iOS 27.0")


def test_unavailable_device_is_skipped() -> None:
    fixture = copy.deepcopy(_fixture())
    devices = fixture["devices"]
    assert isinstance(devices, dict)
    for device in devices[RUNTIME_PREFIX + "27-0"]:
        if device["name"] == "iPhone 17":
            device["isAvailable"] = False

    assert resolve_pair(fixture, "iPhone 17", None).runtime_name == "iOS 26.2"


def test_malformed_listing_fails_naming_the_pair() -> None:
    with pytest.raises(PairError, match="iPhone 17"):
        resolve_pair({"runtimes": "nope", "devices": []}, "iPhone 17", None)


def test_booted_simulator_is_reused_without_pin_or_shutdown() -> None:
    udid = _pair().udid
    booted = _with_state(_fixture(), udid, "Booted")
    booter, runner = _booter([_listing(booted), _listing(booted)])

    assert booter.is_running(IPHONE) is True
    record = booter.boot(IPHONE, Path("boot.log"))
    booter.shutdown(record)

    assert record.reused is True
    assert record.device_id == udid
    assert record.platform == "ios"
    assert record.target == "iphone"
    assert [call[:3] for call in runner.calls] == [("xcrun", "simctl", "list")] * 2


def test_shutdown_simulator_is_not_running() -> None:
    booter, runner = _booter([_listing(_fixture())])

    assert booter.is_running(IPHONE) is False
    assert runner.calls == [("xcrun", "simctl", "list", "-j")]


def test_boot_pins_keyboard_then_boots_then_waits() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        *_pin_script(udid),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done()),
    ]
    booter, runner = _booter(script)

    record = booter.boot(IPHONE, Path("boot.log"))

    assert [call[:4] for call in runner.calls] == [
        ("xcrun", "simctl", "list", "-j"),
        ("defaults", "write", "com.apple.iphonesimulator", "ConnectHardwareKeyboard"),
        (PLISTBUDDY, "-c", f"Print :DevicePreferences:{udid}", PLIST),
        (PLISTBUDDY, "-c", f"Set :DevicePreferences:{udid}:ConnectHardwareKeyboard false", PLIST),
        ("xcrun", "simctl", "boot", udid),
        ("xcrun", "simctl", "bootstatus", udid),
    ]
    assert record.reused is False
    assert record.device_id == udid
    assert record.platform == "ios"


def test_boot_and_bootstatus_run_within_the_lane_boot_timeout() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        *_pin_script(udid),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done()),
    ]
    runner = TimeoutRecordingRunner(script)

    IosBooter(runner, LANE, HOME).boot(IPHONE, Path("boot.log"))

    assert runner.timeouts[("xcrun", "simctl", "boot", udid)] == 600.0
    assert runner.timeouts[("xcrun", "simctl", "bootstatus", udid, "-b")] == 600.0


def test_pin_adds_the_key_when_set_fails_on_a_missing_key() -> None:
    udid = _pair().udid
    key = f":DevicePreferences:{udid}:ConnectHardwareKeyboard"
    script = [
        _listing(_fixture()),
        (("defaults", "write"), _done()),
        ((PLISTBUDDY, "-c", f"Print :DevicePreferences:{udid}", PLIST), _done()),
        ((PLISTBUDDY, "-c", f"Set {key} false", PLIST), _done(status=1)),
        ((PLISTBUDDY, "-c", f"Add {key} bool false", PLIST), _done()),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done()),
    ]
    booter, runner = _booter(script)

    booter.boot(IPHONE, Path("boot.log"))

    assert (PLISTBUDDY, "-c", f"Add {key} bool false", PLIST) in runner.calls


def test_pin_skips_plistbuddy_when_the_device_has_no_preference_dict() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        (("defaults", "write"), _done()),
        ((PLISTBUDDY, "-c", f"Print :DevicePreferences:{udid}", PLIST), _done(status=1)),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done()),
    ]
    booter, runner = _booter(script)

    booter.boot(IPHONE, Path("boot.log"))

    assert not any(call[0] == PLISTBUDDY and call[2].startswith(("Set", "Add")) for call in runner.calls)


@pytest.mark.parametrize("failing", ["defaults", "plist"])
def test_failed_pin_raises_env_and_boots_nothing(failing: str) -> None:
    udid = _pair().udid
    key = f":DevicePreferences:{udid}:ConnectHardwareKeyboard"
    if failing == "defaults":
        script = [_listing(_fixture()), (("defaults", "write"), _done(status=1, stderr="denied"))]
    else:
        script = [
            _listing(_fixture()),
            (("defaults", "write"), _done()),
            ((PLISTBUDDY, "-c", f"Print :DevicePreferences:{udid}", PLIST), _done()),
            ((PLISTBUDDY, "-c", f"Set {key} false", PLIST), _done(status=1)),
            ((PLISTBUDDY, "-c", f"Add {key} bool false", PLIST), _done(status=1)),
        ]
    booter, runner = _booter(script)

    with pytest.raises(RoundEnvError, match=r"^env: .*Connect Hardware Keyboard"):
        booter.boot(IPHONE, Path("boot.log"))

    assert not any(call[:3] == ("xcrun", "simctl", "boot") for call in runner.calls)
    assert not any(call[:3] == ("xcrun", "simctl", "shutdown") for call in runner.calls)


def test_already_booted_is_not_an_error() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        *_pin_script(udid),
        (
            ("xcrun", "simctl", "boot", udid),
            _done(status=164, stderr="Unable to boot device in current state: Booted"),
        ),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done()),
    ]
    booter, runner = _booter(script)

    record = booter.boot(IPHONE, Path("boot.log"))
    booter.shutdown(record)

    assert record.device_id == udid
    # Another session booted it between the listing and the boot call: it is not ours to end.
    assert record.reused is True
    assert not any(call[:3] == ("xcrun", "simctl", "shutdown") for call in runner.calls)


def test_failed_boot_raises_env_without_shutting_down_a_simulator_it_did_not_start() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        *_pin_script(udid),
        (("xcrun", "simctl", "boot", udid), _done(status=1, stderr="Invalid device state")),
    ]
    booter, runner = _booter(script)

    with pytest.raises(RoundEnvError, match="Invalid device state"):
        booter.boot(IPHONE, Path("boot.log"))

    assert not any(call[:3] == ("xcrun", "simctl", "shutdown") for call in runner.calls)


def test_timed_out_boot_raises_env_and_shuts_down() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        *_pin_script(udid),
        (("xcrun", "simctl", "boot", udid), _done(status=-9, timed_out=True)),
        (("xcrun", "simctl", "shutdown", udid), _done()),
    ]
    booter, runner = _booter(script)

    with pytest.raises(RoundEnvError, match="simctl boot"):
        booter.boot(IPHONE, Path("boot.log"))

    assert runner.calls[-1] == ("xcrun", "simctl", "shutdown", udid)


def test_bootstatus_failure_after_a_lost_boot_race_leaves_the_simulator_running() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        *_pin_script(udid),
        (("xcrun", "simctl", "boot", udid), _done(status=164, stderr="Unable to boot device in current state: Booted")),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done(status=1, stderr="boom")),
    ]
    booter, runner = _booter(script)

    with pytest.raises(RoundEnvError, match="boom"):
        booter.boot(IPHONE, Path("boot.log"))

    assert not any(call[:3] == ("xcrun", "simctl", "shutdown") for call in runner.calls)


def test_bootstatus_bound_raises_env() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        *_pin_script(udid),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done(status=-9, timed_out=True)),
        (("xcrun", "simctl", "shutdown", udid), _done()),
    ]
    booter, runner = _booter(script)

    with pytest.raises(RoundEnvError, match=r"iPhone 17.*did not finish booting within 600 s"):
        booter.boot(IPHONE, Path("boot.log"))

    assert runner.calls[-1] == ("xcrun", "simctl", "shutdown", udid)


def test_bootstatus_failure_raises_env_and_shuts_down() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        *_pin_script(udid),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done(status=1, stderr="boom")),
        (("xcrun", "simctl", "shutdown", udid), _done()),
    ]
    booter, runner = _booter(script)

    with pytest.raises(RoundEnvError, match="boom"):
        booter.boot(IPHONE, Path("boot.log"))

    assert runner.calls[-1] == ("xcrun", "simctl", "shutdown", udid)


def test_simctl_list_failure_raises_env() -> None:
    booter, _ = _booter([(("xcrun", "simctl", "list", "-j"), _done(status=1, stderr="no CoreSimulator"))])

    with pytest.raises(RoundEnvError, match="no CoreSimulator"):
        booter.boot(IPHONE, Path("boot.log"))


def test_simctl_list_garbage_raises_env() -> None:
    booter, _ = _booter([(("xcrun", "simctl", "list", "-j"), _done("not json"))])

    with pytest.raises(RoundEnvError, match="simctl list"):
        booter.is_running(IPHONE)


def test_shutdown_ends_a_simulator_this_booter_booted() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        *_pin_script(udid),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done()),
        (("xcrun", "simctl", "shutdown", udid), _done()),
    ]
    booter, runner = _booter(script)

    booter.shutdown(booter.boot(IPHONE, Path("boot.log")))

    assert runner.calls[-1] == ("xcrun", "simctl", "shutdown", udid)


def test_pinned_target_boots_its_pinned_pair() -> None:
    pair = resolve_pair(_fixture(), "iPhone Duo", "iOS 27.1")
    script = [
        _listing(_fixture()),
        *_pin_script(pair.udid),
        (("xcrun", "simctl", "boot", pair.udid), _done()),
        (("xcrun", "simctl", "bootstatus", pair.udid, "-b"), _done()),
    ]
    booter, _ = _booter(script)

    assert booter.boot(IPHONE_E2E, Path("boot.log")).device_id == pair.udid


def test_ios_target_without_device_fails_as_catalog_error() -> None:
    booter, _ = _booter([])

    with pytest.raises(CatalogError, match="iphone"):
        booter.is_running(Target(name="iphone", platform="ios"))


def test_before_file_runs_nothing() -> None:
    udid = _pair().udid
    booter, runner = _booter([_listing(_with_state(_fixture(), udid, "Booted"))])

    booter.before_file(booter.boot(IPHONE, Path("boot.log")))

    assert len(runner.calls) == 1


@pytest.mark.parametrize(
    ("target", "platform", "device_id"),
    [
        (Target(name="mac", platform="macos"), "macos", "mac"),
        (Target(name="chrome", platform="web", browser="chrome"), "web", "chrome"),
        (Target(name="chrome_wasm", platform="web", browser="chrome", wasm=True), "web", "chrome_wasm"),
        (Target(name="linux", platform="linux"), "linux", "linux"),
    ],
)
def test_host_targets_boot_nothing(target: Target, platform: str, device_id: str) -> None:
    runner = FakeRunner([])
    booter = HostBooter()

    assert booter.is_running(target) is True
    record = booter.boot(target, Path("boot.log"))
    booter.before_file(record)
    booter.shutdown(record)

    assert (record.target, record.platform, record.device_id, record.reused) == (target.name, platform, device_id, True)
    assert runner.calls == []


def test_host_booter_refuses_a_device_platform() -> None:
    with pytest.raises(CatalogError, match="pixel_8"):
        HostBooter().boot(Target(name="pixel_8", platform="android", avd="x"), Path("boot.log"))
