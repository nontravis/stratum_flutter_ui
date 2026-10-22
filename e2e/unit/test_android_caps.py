"""Unit tests for the Android capabilities and the fixture launch command."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest

from stratum_e2e import fixtures, locate
from stratum_e2e.android.session import android_capabilities, install_apk

SERIAL = "emulator-5554"
APP_ID = "dev.stratum.stratum_ui_test_app"


class FakeDriver:
    """Driver stub exposing only the session capabilities."""

    def __init__(self, capabilities: dict[str, Any]) -> None:
        self.capabilities = capabilities


class RecordingRun:
    """Stand-in for subprocess.run that records every argv."""

    def __init__(self) -> None:
        self.calls: list[list[str]] = []

    def __call__(self, argv: list[str], **_: object) -> None:
        self.calls.append(argv)


def test_android_capabilities_keep_talkback_bound() -> None:
    caps = android_capabilities(SERIAL, APP_ID)

    assert caps["appium:disableSuppressAccessibilityService"] is True
    assert caps["appium:autoLaunch"] is False
    assert caps["appium:noReset"] is True
    assert caps["appium:automationName"] == "UiAutomator2"
    assert caps["appium:udid"] == SERIAL
    assert caps["appium:appPackage"] == APP_ID


def test_open_fixture_takes_serial_from_udid(monkeypatch: pytest.MonkeyPatch) -> None:
    run = RecordingRun()
    monkeypatch.setattr(fixtures.subprocess, "run", run)
    driver = FakeDriver({"udid": SERIAL})

    fixtures.open_fixture(driver, "android", APP_ID, "smoke/semantics_id")

    assert run.calls == [
        [
            "adb", "-s", SERIAL, "shell", "am", "start", "-S", "-W",
            "-n", f"{APP_ID}/.MainActivity",
            "--es", "route", "/fixture/smoke/semantics_id",
        ]
    ]


def test_open_fixture_rejects_other_platforms() -> None:
    with pytest.raises(ValueError, match="ios"):
        fixtures.open_fixture(FakeDriver({"udid": SERIAL}), "ios", APP_ID, "x")


class RecordingFinder:
    """Driver stub that records find_element calls."""

    def __init__(self) -> None:
        self.finds: list[tuple[str, str]] = []

    def find_element(self, by: str, value: str) -> str:
        self.finds.append((by, value))
        return "node"


def test_by_id_matches_the_bare_resource_id_exactly() -> None:
    finder = RecordingFinder()

    assert locate.by_id(finder, "android", "smoke.button") == "node"

    assert finder.finds == [
        ("-android uiautomator", 'new UiSelector().resourceId("smoke.button")')
    ]


def test_by_id_rejects_selector_injection() -> None:
    with pytest.raises(ValueError, match="quote or backslash"):
        locate.by_id(RecordingFinder(), "android", 'x").instance(0)\n//')


def test_install_apk_replaces_on_the_named_serial(monkeypatch: pytest.MonkeyPatch) -> None:
    run = RecordingRun()
    monkeypatch.setattr("stratum_e2e.android.session.subprocess.run", run)

    install_apk(SERIAL, Path("/tmp/app-debug.apk"))

    assert run.calls == [["adb", "-s", SERIAL, "install", "-r", "/tmp/app-debug.apk"]]
