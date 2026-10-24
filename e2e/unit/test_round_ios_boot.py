"""Unit tests for the iOS pair resolver, the simulator booter, and the host booter, with a scripted simctl."""

from __future__ import annotations

import copy
import json
from collections.abc import Mapping, Sequence
from pathlib import Path

import pytest

from stratum_e2e.round.boot import BootRecord
from stratum_e2e.round.catalog import LaneConfig, Target
from stratum_e2e.round.errors import CatalogError, RoundEnvError
from stratum_e2e.round.ios_boot import HostBooter, IosBooter, IosPair, PairError, resolve_pair
from stratum_e2e.round.runner import Completed
from unit.round_fakes import FakeRunner

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "round" / "simctl_list.json"
DOMAIN = "com.apple.keyboard.preferences"
KEY = "AutomaticMinimizationEnabled"
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

_ALREADY_BOOTED_TEXT = "Unable to boot device in current state: Booted"


@pytest.fixture(autouse=True)
def _in_temp_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Run each test in an empty folder, so the relative `boot.log` the booter appends to never lands in the repo."""
    monkeypatch.chdir(tmp_path)


class FakeClock:
    """A monotonic clock that only moves when a scripted command takes time."""

    def __init__(self) -> None:
        self.now = 0.0

    def monotonic(self) -> float:
        return self.now


class TimedRunner(FakeRunner):
    """A FakeRunner that keeps the timeout each argv ran under, spends `cost` seconds of the fake clock when an argv
    finishes, and raises `interrupt` from one argv."""

    def __init__(
        self,
        script: list[Entry],
        clock: FakeClock,
        *,
        cost: Mapping[tuple[str, ...], float] | None = None,
        interrupt: tuple[tuple[str, ...], BaseException] | None = None,
    ) -> None:
        super().__init__(script)
        self.timeouts: dict[tuple[str, ...], float | None] = {}
        self._clock = clock
        self._cost = dict(cost or {})
        self._interrupt = interrupt

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout_s: float | None = None,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
        log: Path | None = None,
    ) -> Completed:
        call = tuple(argv)
        self.timeouts[call] = timeout_s
        if self._interrupt is not None and call == self._interrupt[0]:
            self.calls.append(call)
            raise self._interrupt[1]
        done = super().run(argv, timeout_s=timeout_s, cwd=cwd, env=env, log=log)
        self._clock.now += self._cost.get(call, 0.0)
        return done


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


def _spawn(udid: str, verb: str, *args: str) -> tuple[str, ...]:
    return ("xcrun", "simctl", "spawn", udid, "defaults", verb, DOMAIN, KEY, *args)


def _pin_script(udid: str, read_back: str = "0\n") -> list[Entry]:
    """The device pin that follows a successful boot: the write, then the read-back."""
    return [
        (_spawn(udid, "write", "-bool", "false"), _done()),
        (_spawn(udid, "read"), _done(read_back)),
    ]


def _boot_script(udid: str, *, fixture: Mapping[str, object] | None = None) -> list[Entry]:
    return [
        _listing(fixture or _fixture()),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done()),
        *_pin_script(udid),
    ]


def _booter(script: list[Entry]) -> tuple[IosBooter, FakeRunner]:
    runner = FakeRunner(script)
    return IosBooter(runner, LANE), runner


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


def test_booted_simulator_is_reused_pinned_and_left_running() -> None:
    udid = _pair().udid
    booted = _with_state(_fixture(), udid, "Booted")
    booter, runner = _booter([_listing(booted), _listing(booted), *_pin_script(udid)])

    assert booter.is_running(IPHONE) is True
    record = booter.boot(IPHONE, Path("boot.log"))
    booter.shutdown(record)

    assert record.reused is True
    assert record.device_id == udid
    assert record.platform == "ios"
    assert record.target == "iphone"
    assert [call[:3] for call in runner.calls] == [("xcrun", "simctl", "list")] * 2 + [("xcrun", "simctl", "spawn")] * 2
    assert not any(call[:3] == ("xcrun", "simctl", "shutdown") for call in runner.calls)


@pytest.mark.parametrize("read_back", ["1\n", "\n"])
def test_reused_simulator_whose_pin_reads_back_wrong_raises_env_and_is_left_running(read_back: str) -> None:
    udid = _pair().udid
    booted = _with_state(_fixture(), udid, "Booted")
    booter, runner = _booter([_listing(booted), *_pin_script(udid, read_back)])

    with pytest.raises(RoundEnvError, match=rf"^env: .*{udid}.*{KEY}"):
        booter.boot(IPHONE, Path("boot.log"))

    assert not any(call[:3] == ("xcrun", "simctl", "shutdown") for call in runner.calls)


def test_shutdown_simulator_is_not_running() -> None:
    booter, runner = _booter([_listing(_fixture())])

    assert booter.is_running(IPHONE) is False
    assert runner.calls == [("xcrun", "simctl", "list", "-j")]


def test_boot_boots_then_waits_then_pins_the_device_keyboard() -> None:
    udid = _pair().udid
    booter, runner = _booter(_boot_script(udid))

    record = booter.boot(IPHONE, Path("boot.log"))

    assert runner.calls == [
        ("xcrun", "simctl", "list", "-j"),
        ("xcrun", "simctl", "boot", udid),
        ("xcrun", "simctl", "bootstatus", udid, "-b"),
        _spawn(udid, "write", "-bool", "false"),
        _spawn(udid, "read"),
    ]
    assert record.reused is False
    assert record.device_id == udid
    assert record.platform == "ios"


def test_boot_and_bootstatus_share_one_boot_timeout() -> None:
    udid = _pair().udid
    boot_argv = ("xcrun", "simctl", "boot", udid)
    status_argv = ("xcrun", "simctl", "bootstatus", udid, "-b")
    clock = FakeClock()
    script = [_listing(_fixture()), (boot_argv, _done()), (status_argv, _done()), *_pin_script(udid)]
    runner = TimedRunner(script, clock, cost={boot_argv: 240.0})

    IosBooter(runner, LANE, monotonic=clock.monotonic).boot(IPHONE, Path("boot.log"))

    assert runner.timeouts[boot_argv] == 600.0
    assert runner.timeouts[status_argv] == 360.0


def test_boot_that_spends_the_whole_timeout_skips_bootstatus_and_shuts_down() -> None:
    udid = _pair().udid
    boot_argv = ("xcrun", "simctl", "boot", udid)
    clock = FakeClock()
    script = [
        _listing(_fixture()),
        (boot_argv, _done()),
        (("xcrun", "simctl", "shutdown", udid), _done()),
    ]
    runner = TimedRunner(script, clock, cost={boot_argv: 600.0})

    with pytest.raises(RoundEnvError, match="did not finish booting within 600 s"):
        IosBooter(runner, LANE, monotonic=clock.monotonic).boot(IPHONE, Path("boot.log"))

    assert not any(call[:4] == ("xcrun", "simctl", "bootstatus", udid) for call in runner.calls)
    assert runner.calls[-1] == ("xcrun", "simctl", "shutdown", udid)


def test_interrupt_during_bootstatus_shuts_down_once_and_reraises() -> None:
    udid = _pair().udid
    status_argv = ("xcrun", "simctl", "bootstatus", udid, "-b")
    script = [
        _listing(_fixture()),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "shutdown", udid), _done()),
    ]
    runner = TimedRunner(script, FakeClock(), interrupt=(status_argv, KeyboardInterrupt()))

    with pytest.raises(KeyboardInterrupt):
        IosBooter(runner, LANE).boot(IPHONE, Path("boot.log"))

    assert runner.calls.count(("xcrun", "simctl", "shutdown", udid)) == 1


def test_interrupt_during_simctl_boot_shuts_down_and_reraises() -> None:
    udid = _pair().udid
    boot_argv = ("xcrun", "simctl", "boot", udid)
    script = [
        _listing(_fixture()),
        (("xcrun", "simctl", "shutdown", udid), _done()),
    ]
    runner = TimedRunner(script, FakeClock(), interrupt=(boot_argv, KeyboardInterrupt()))

    with pytest.raises(KeyboardInterrupt):
        IosBooter(runner, LANE).boot(IPHONE, Path("boot.log"))

    assert runner.calls.count(("xcrun", "simctl", "shutdown", udid)) == 1


def test_interrupt_after_a_lost_boot_race_leaves_the_simulator_running() -> None:
    udid = _pair().udid
    status_argv = ("xcrun", "simctl", "bootstatus", udid, "-b")
    script = [
        _listing(_fixture()),
        (("xcrun", "simctl", "boot", udid), _done(status=164, stderr=_ALREADY_BOOTED_TEXT)),
    ]
    runner = TimedRunner(script, FakeClock(), interrupt=(status_argv, KeyboardInterrupt()))

    with pytest.raises(KeyboardInterrupt):
        IosBooter(runner, LANE).boot(IPHONE, Path("boot.log"))

    assert not any(call[:3] == ("xcrun", "simctl", "shutdown") for call in runner.calls)


def test_already_booted_is_not_an_error() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        (
            ("xcrun", "simctl", "boot", udid),
            _done(status=164, stderr="Unable to boot device in current state: Booted"),
        ),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done()),
        *_pin_script(udid),
    ]
    booter, runner = _booter(script)

    record = booter.boot(IPHONE, Path("boot.log"))
    booter.shutdown(record)

    assert record.device_id == udid
    # Another session booted it between the listing and the boot call: it is not ours to end.
    assert record.reused is True
    assert not any(call[:3] == ("xcrun", "simctl", "shutdown") for call in runner.calls)


def test_failed_boot_raises_env_and_shuts_the_simulator_down() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        (("xcrun", "simctl", "boot", udid), _done(status=1, stderr="Invalid device state")),
        (("xcrun", "simctl", "shutdown", udid), _done()),
    ]
    booter, runner = _booter(script)

    with pytest.raises(RoundEnvError, match="Invalid device state"):
        booter.boot(IPHONE, Path("boot.log"))

    assert runner.calls[-1] == ("xcrun", "simctl", "shutdown", udid)
    assert not any(call[:3] == ("xcrun", "simctl", "bootstatus") for call in runner.calls)


def test_failed_boot_whose_shutdown_also_fails_raises_the_boot_error() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        (("xcrun", "simctl", "boot", udid), _done(status=1, stderr="Invalid device state")),
        (
            ("xcrun", "simctl", "shutdown", udid),
            _done(status=1, stderr="Unable to shutdown device in current state: Creating"),
        ),
    ]
    booter, _ = _booter(script)

    with pytest.raises(RoundEnvError, match="Invalid device state"):
        booter.boot(IPHONE, Path("boot.log"))


def test_retry_after_a_failed_boot_starts_with_a_shutdown_then_boots_and_pins(tmp_path: Path) -> None:
    udid = _pair().udid
    log = tmp_path / "boot.log"
    script = [
        _listing(_fixture()),
        (("xcrun", "simctl", "boot", udid), _done(status=1, stderr="Bundle SimRenderingServices rejected boot")),
        (("xcrun", "simctl", "shutdown", udid), _done()),
        *_boot_script(udid),
    ]
    booter, runner = _booter(script)

    with pytest.raises(RoundEnvError):
        booter.boot(IPHONE, log)
    record = booter.boot(IPHONE, log)

    kinds = [call[2] for call in runner.calls]
    assert kinds == ["list", "boot", "shutdown", "list", "boot", "bootstatus", "spawn", "spawn"]
    assert record.reused is False


def test_boot_log_holds_each_attempts_stderr_bootstatus_output_read_back_and_the_first_error(tmp_path: Path) -> None:
    udid = _pair().udid
    log = tmp_path / "boot.log"
    script = [
        _listing(_fixture()),
        (("xcrun", "simctl", "boot", udid), _done(status=1, stderr="rejected boot: Invalid connectionUUID")),
        (("xcrun", "simctl", "shutdown", udid), _done()),
        _listing(_fixture()),
        (("xcrun", "simctl", "boot", udid), _done(stdout="boot notice", stderr="boot warning")),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done(stdout="Data Migration Failed")),
        *_pin_script(udid),
    ]
    booter, _ = _booter(script)

    with pytest.raises(RoundEnvError):
        booter.boot(IPHONE, log)
    booter.boot(IPHONE, log)

    text = log.read_text()
    assert "boot attempt 1" in text
    assert "boot attempt 1 failed" in text
    assert "rejected boot: Invalid connectionUUID" in text
    assert "boot attempt 2" in text
    assert "boot attempt 2 failed" not in text
    assert "boot warning" in text
    assert "boot notice" in text
    assert "Data Migration Failed" in text
    assert f"{KEY} read back: '0'" in text


def test_timed_out_boot_raises_env_and_shuts_down() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
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


def test_shutdown_ends_a_simulator_this_booter_booted_once() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done()),
        *_pin_script(udid),
        (("xcrun", "simctl", "shutdown", udid), _done()),
    ]
    booter, runner = _booter(script)
    record = booter.boot(IPHONE, Path("boot.log"))

    booter.shutdown(record)
    booter.shutdown(record)

    assert runner.calls.count(("xcrun", "simctl", "shutdown", udid)) == 1


def test_shutdown_ignores_a_record_this_booter_did_not_boot() -> None:
    udid = _pair().udid
    stranger = BootRecord(target="iphone", platform="ios", device_id=udid, reused=False)
    booter, runner = _booter([])

    booter.shutdown(stranger)

    assert runner.calls == []


def test_shutdown_failure_raises_env_naming_the_udid() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done()),
        *_pin_script(udid),
        (("xcrun", "simctl", "shutdown", udid), _done(status=1, stderr="CoreSimulator busy")),
    ]
    booter, _ = _booter(script)
    record = booter.boot(IPHONE, Path("boot.log"))

    with pytest.raises(RoundEnvError, match=f"{udid}.*CoreSimulator busy"):
        booter.shutdown(record)


def test_shutdown_of_an_already_shut_down_simulator_is_not_an_error() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done()),
        *_pin_script(udid),
        (
            ("xcrun", "simctl", "shutdown", udid),
            _done(status=164, stderr="Unable to shutdown device in current state: Shutdown"),
        ),
    ]
    booter, _ = _booter(script)

    booter.shutdown(booter.boot(IPHONE, Path("boot.log")))


def test_pinned_target_boots_its_pinned_pair() -> None:
    pair = resolve_pair(_fixture(), "iPhone Duo", "iOS 27.1")
    script = [
        _listing(_fixture()),
        (("xcrun", "simctl", "boot", pair.udid), _done()),
        (("xcrun", "simctl", "bootstatus", pair.udid, "-b"), _done()),
        *_pin_script(pair.udid),
    ]
    booter, _ = _booter(script)

    assert booter.boot(IPHONE_E2E, Path("boot.log")).device_id == pair.udid


def test_ios_target_without_device_fails_as_catalog_error() -> None:
    booter, _ = _booter([])

    with pytest.raises(CatalogError, match="iphone"):
        booter.is_running(Target(name="iphone", platform="ios"))


def test_pin_writes_the_device_preference_through_simctl_spawn_and_logs_the_read_back(tmp_path: Path) -> None:
    udid = _pair().udid
    log = tmp_path / "boot.log"
    booter, runner = _booter(_boot_script(udid))

    booter.boot(IPHONE, log)

    assert _spawn(udid, "write", "-bool", "false") in runner.calls
    assert _spawn(udid, "read") in runner.calls
    assert f"{DOMAIN} {KEY} read back: '0'" in log.read_text()


@pytest.mark.parametrize("read_back", ["1\n", "\n", "true\n"])
def test_pin_that_reads_back_wrong_raises_env_and_shuts_down_the_simulator_it_booted(read_back: str) -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done()),
        *_pin_script(udid, read_back),
        (("xcrun", "simctl", "shutdown", udid), _done()),
    ]
    booter, runner = _booter(script)

    with pytest.raises(RoundEnvError, match=rf"^env: .*{udid}.*{KEY}"):
        booter.boot(IPHONE, Path("boot.log"))

    assert runner.calls[-1] == ("xcrun", "simctl", "shutdown", udid)


def test_pin_write_that_fails_raises_env_even_when_the_read_back_is_false() -> None:
    udid = _pair().udid
    script = [
        _listing(_fixture()),
        (("xcrun", "simctl", "boot", udid), _done()),
        (("xcrun", "simctl", "bootstatus", udid, "-b"), _done()),
        (_spawn(udid, "write", "-bool", "false"), _done(status=1, stderr="no such domain")),
        (_spawn(udid, "read"), _done("0\n")),
        (("xcrun", "simctl", "shutdown", udid), _done()),
    ]
    booter, _ = _booter(script)

    with pytest.raises(RoundEnvError, match="write status 1"):
        booter.boot(IPHONE, Path("boot.log"))


def test_round_writes_no_host_setting_for_the_keyboard() -> None:
    udid = _pair().udid
    booter, runner = _booter(_boot_script(udid))

    booter.boot(IPHONE, Path("boot.log"))

    assert {call[0] for call in runner.calls} == {"xcrun"}
    assert not any("ConnectHardwareKeyboard" in part or "PlistBuddy" in part for call in runner.calls for part in call)


def test_before_file_runs_nothing() -> None:
    udid = _pair().udid
    booter, runner = _booter([_listing(_with_state(_fixture(), udid, "Booted")), *_pin_script(udid)])

    record = booter.boot(IPHONE, Path("boot.log"))
    calls_after_boot = len(runner.calls)
    booter.before_file(record)

    assert len(runner.calls) == calls_after_boot


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
