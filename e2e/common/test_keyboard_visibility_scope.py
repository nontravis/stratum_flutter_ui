"""Keyboard visibility: the scope follows the OS keyboard report, inset or none (FO-07 US-04 FR-02).

Drives the `common/keyboard_visibility_scope` fixture. E04 (the stylus toolbar): on the dedicated stylus AVD an
`adb shell input stylus tap` inside `SecureSetting(stylus_handwriting_enabled, 1)`, entered before the app's cold
start, shows Gboard's floating toolbar,
so the IME window shows (`dumpsys input_method` `mInputShown=true`) while the fixture reads `keyboard: open` and
`inset: 0`, both holding for the scope bound after that; "Close keyboard" gives `keyboard: closed`. Gboard's stylus
mode is sticky: once one stylus tap has entered it, a finger tap or an unset flag still shows the toolbar, so the
measured tap proves the scope holds `keyboard: open` at `inset: 0` while the IME shows, not that the flag or the
stylus tap caused the toolbar; the preparation tap below enters stylus mode first. A fresh Gboard answers its first stylus tap with a first-run
sheet that hides the fixture from Appium, so E04 first stylus-taps once and presses BACK (owner ruling 2026-10-27),
then measures the next tap. E07 runs with
TalkBack off for its whole body, so `_tap_field`'s one console tap focuses the field instead
of only moving accessibility focus (rca-t49-e04). E07: with a hardware keyboard attached (the
registered uhid keyboard), each `show_ime_with_hard_keyboard` value gives one state — the
on-screen keyboard shown (an inset above 0, the scope open within the OS-event bound) or
hidden throughout (inset 0, the scope closed) — judged by the inset, never by the setting
(owner ruling 2026-10-18, DR18). The tests hold the settings only inside `SecureSetting` and
`TalkBackOff` blocks on a dedicated AVD (ruling Q3).
"""

from __future__ import annotations

import subprocess
import time
from typing import Any

import pytest
from appium.webdriver.common.appiumby import AppiumBy

from stratum_e2e.android.adb import adb
from stratum_e2e.android.emu_mouse import center, tap
from stratum_e2e.android.secure_settings import SecureSetting, read_secure
from stratum_e2e.android.stylus import read_ime_input_shown, stylus_tap
from stratum_e2e.android.talkback import TalkBackOff
from stratum_e2e.android.uhid_keyboard import UhidKeyboard
from stratum_e2e.fixtures import open_fixture
from stratum_e2e.locate import NODE_NOT_FOUND, by_id, by_label, click, is_displayed, label_of
from stratum_e2e.waits import wait_until

FIXTURE_ID = "common/keyboard_visibility_scope"
STATE_ID = "keyboard_visibility_scope.state"
INSET_ID = "keyboard_visibility_scope.inset"
STATE_OPEN = "keyboard: open"
STATE_CLOSED = "keyboard: closed"
INSET_ZERO = "inset: 0"
CLOSE_BUTTON = "Close keyboard"
SHOW_IME_KEY = "show_ime_with_hard_keyboard"
STYLUS_KEY = "stylus_handwriting_enabled"
EDIT_TEXT_CLASS = "android.widget.EditText"
# The device test's `_keyboardSettleTimeout` and `_scopeAfterOsEventBound`
# (keyboard_visibility_device_test.dart).
SETTLE_S = 10
SCOPE_AFTER_INSET_S = 2
POLL_S = 0.25
OPEN_TIMEOUT_S = 10


def _open(driver: Any, platform: str, app_id: str) -> None:
    """Cold-start the fixture and wait until its text field is on screen."""
    open_fixture(driver, platform, app_id, FIXTURE_ID)
    wait_until(
        lambda: is_displayed(driver.find_element(AppiumBy.CLASS_NAME, EDIT_TEXT_CLASS), platform),
        f"the {FIXTURE_ID!r} text field on screen",
        timeout_s=OPEN_TIMEOUT_S,
        catch=NODE_NOT_FOUND,
    )


def _state(driver: Any) -> str:
    return label_of(by_id(driver, "android", STATE_ID), "android")


def _inset(driver: Any) -> str:
    return label_of(by_id(driver, "android", INSET_ID), "android")


def _tap_field(driver: Any, serial: str) -> None:
    """Touch the field's centre through the kernel (`emu_mouse`), never an Appium click."""
    x, y = center(driver.find_element(AppiumBy.CLASS_NAME, EDIT_TEXT_CLASS).rect)
    tap(serial, x, y)


def _stylus_tap_field(driver: Any, serial: str) -> None:
    """Touch the field's centre with a stylus; the console mouse is a finger, so it cannot start stylus mode."""
    x, y = center(driver.find_element(AppiumBy.CLASS_NAME, EDIT_TEXT_CLASS).rect)
    stylus_tap(serial, x, y)


def _wait_for_the_stylus_toolbar(driver: Any, serial: str) -> None:
    """Wait for the IME window, `keyboard: open`, and `inset: 0` together; a timeout names the last three reads.

    A failed adb read counts as not-yet, like a node not found.
    """
    last: list[tuple[bool, str, str]] = []

    def reads_toolbar() -> bool:
        reads = (read_ime_input_shown(serial), _state(driver), _inset(driver))
        last[:] = [reads]
        return reads == (True, STATE_OPEN, INSET_ZERO)

    try:
        wait_until(
            reads_toolbar,
            f"the IME window shown, {STATE_OPEN!r}, and {INSET_ZERO!r} after a stylus tap",
            timeout_s=SETTLE_S,
            poll_interval_s=POLL_S,
            catch=(*NODE_NOT_FOUND, subprocess.CalledProcessError),
        )
    except AssertionError as error:
        raise AssertionError(
            f"{error}; last reads (IME shown, state, inset): {last[0] if last else 'none'}"
        ) from error


def _sample(driver: Any) -> tuple[float, str, str]:
    """One (now on the monotonic clock, state, inset) read."""
    return (round(time.monotonic(), 2), _state(driver), _inset(driver))


def _samples(driver: Any, seconds: float, t0: float) -> list[tuple[float, str, str]]:
    """(now, state, inset) read every POLL_S until [seconds] passed since [t0]; the stamps are absolute."""
    out: list[tuple[float, str, str]] = []
    while True:
        out.append(_sample(driver))
        if time.monotonic() - t0 >= seconds:
            return out
        time.sleep(POLL_S)


def _pass_gboard_first_run(driver: Any, serial: str) -> None:
    """Stylus-tap the field, press BACK while the IME shows, then unfocus, so the measured tap meets a settled Gboard.

    A fresh Gboard answers its first stylus tap with a "Try out your stylus" sheet, a window of its own that hides the
    fixture from Appium; BACK dismisses it for good, and later stylus taps show the toolbar (measured on
    E2E_Stylus_API_36, 2026-10-27). On a Gboard past its first run the same tap shows the toolbar and BACK hides it.
    """
    _stylus_tap_field(driver, serial)
    wait_until(
        lambda: read_ime_input_shown(serial),
        "the IME window shown after the preparation stylus tap",
        timeout_s=SETTLE_S,
        catch=(subprocess.CalledProcessError,),
    )
    adb(serial, "shell", "input", "keyevent", "KEYCODE_BACK")
    wait_until(
        lambda: not read_ime_input_shown(serial),
        "the IME window hidden after BACK",
        timeout_s=SETTLE_S,
        catch=(subprocess.CalledProcessError,),
    )
    _close_then_closed(driver)


def _close_then_closed(driver: Any) -> None:
    """Click `Close keyboard` and fail naming the samples unless the scope reads closed in bound."""
    click(by_label(driver, "android", CLOSE_BUTTON, exact=True), "android")
    closing = _samples(driver, SCOPE_AFTER_INSET_S, time.monotonic())
    assert any(state == STATE_CLOSED for _, state, _ in closing), (
        f"the scope did not read {STATE_CLOSED!r} within {SCOPE_AFTER_INSET_S}s of "
        f"{CLOSE_BUTTON!r}: {closing}"
    )


def _open_within_scope_bound(
    driver: Any, samples: list[tuple[float, str, str]], first_inset_at: float, value: str
) -> None:
    """Assert the scope reads open within SCOPE_AFTER_INSET_S of [first_inset_at] (s03 INV-10).

    [samples] carries absolute monotonic stamps. When its last sample still sits inside the
    bound, extend the read; the extension is appended, so the failure text names every sample.
    """
    t0 = samples[-1][0]
    if samples[-1][0] < first_inset_at + SCOPE_AFTER_INSET_S:
        samples = samples + _samples(driver, first_inset_at + SCOPE_AFTER_INSET_S - samples[-1][0], t0)
    window = [state for at, state, _ in samples if first_inset_at <= at <= first_inset_at + SCOPE_AFTER_INSET_S]
    assert STATE_OPEN in window, (
        f"value={value}: the scope did not read {STATE_OPEN!r} within {SCOPE_AFTER_INSET_S}s "
        f"of the first inset sample: {samples}"
    )


@pytest.mark.android
@pytest.mark.talkback_avd
@pytest.mark.req("fo07/us04/fr02/e07")
def test_scope_follows_the_on_screen_keyboard_in_both_hardware_keyboard_states(
    driver: Any, platform: str, app_id: str, keyboard: UhidKeyboard
) -> None:
    """E07: each setting value's state is judged by the inset, never by the setting."""
    serial = str(driver.capabilities["udid"])
    with TalkBackOff(serial):
        _run_e07(driver, platform, app_id, serial)


def _run_e07(driver: Any, platform: str, app_id: str, serial: str) -> None:
    _open(driver, platform, app_id)
    # `read_secure` answers `null` for an unset key; the unset state behaves as 0.
    read = read_secure(serial, SHOW_IME_KEY)
    current = "0" if read == "null" else read
    flipped = "0" if current == "1" else "1"

    for value in (current, flipped):
        with SecureSetting(serial, SHOW_IME_KEY, value):
            _tap_field(driver, serial)
            samples = _samples(driver, SETTLE_S, time.monotonic())
            first_inset_at = next(
                (at for at, _, inset in samples if inset != INSET_ZERO), None
            )
            if first_inset_at is not None:
                print(f"E07 branch: value={value} on-screen keyboard shown (inset above 0)")
                _open_within_scope_bound(driver, samples, first_inset_at, value)
                _close_then_closed(driver)
            else:
                print(f"E07 branch: value={value} on-screen keyboard hidden (inset 0 throughout)")
                assert all(state == STATE_CLOSED for _, state, _ in samples), (
                    f"value={value}: the inset stayed {INSET_ZERO!r} the whole {SETTLE_S}s "
                    f"but a sample read open: {samples}"
                )


@pytest.mark.android
@pytest.mark.stylus_avd
@pytest.mark.req("fo07/us04/fr02/e04")
def test_scope_reads_open_while_the_stylus_toolbar_claims_no_inset(
    driver: Any, platform: str, app_id: str
) -> None:
    """E04: the IME window shows, and the scope reads open at inset 0 for the whole scope bound."""
    serial = str(driver.capabilities["udid"])
    with SecureSetting(serial, STYLUS_KEY, "1"):
        # The flag must read 1 before the cold start: an app started while it read 0 (the round's boot setting)
        # reached the toolbar in 6 of 14 stylus taps after the flag turned 1, against 18 of 18 when it read 1 or
        # was unset at the start (measured on E2E_Stylus_API_36, 2026-10-27).
        _open(driver, platform, app_id)
        _pass_gboard_first_run(driver, serial)
        _stylus_tap_field(driver, serial)
        _wait_for_the_stylus_toolbar(driver, serial)
        samples = _samples(driver, SCOPE_AFTER_INSET_S, time.monotonic())
        assert all(state == STATE_OPEN and inset == INSET_ZERO for _, state, inset in samples), (
            f"the scope left {STATE_OPEN!r} at {INSET_ZERO!r} within {SCOPE_AFTER_INSET_S}s of the toolbar "
            f"showing: {samples}"
        )
        _close_then_closed(driver)
