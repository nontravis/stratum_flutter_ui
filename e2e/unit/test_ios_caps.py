"""Unit tests for the iOS capabilities, simulator install, fixture launch, and locator."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
from appium.webdriver.common.appiumby import AppiumBy

from stratum_e2e import fixtures, locate
from stratum_e2e.ios import session
from stratum_e2e.ios.session import ios_capabilities, install_app
from stratum_e2e.ports import free_port

UDID = "8ED795EF-EEA8-47F3-A063-A2B9CE441EEF"
BUNDLE_ID = "dev.stratum.stratumUiTestApp"
DERIVED_DATA = Path("/tmp/e2e/.wda-derived")


class ScriptDriver:
    """Driver stub that records execute_script and find_element calls."""

    def __init__(self) -> None:
        self.scripts: list[tuple[str, dict[str, Any]]] = []
        self.finds: list[tuple[str, str]] = []

    def execute_script(self, script: str, args: dict[str, Any]) -> None:
        self.scripts.append((script, args))

    def find_element(self, by: str, value: str) -> str:
        self.finds.append((by, value))
        return "node"


def test_ios_caps_pin_platform_version_27_1() -> None:
    caps = ios_capabilities(UDID, BUNDLE_ID, DERIVED_DATA, free_port())

    assert caps["appium:platformVersion"] == "27.1"


def test_ios_caps_take_a_free_wda_port() -> None:
    port = free_port()

    caps = ios_capabilities(UDID, BUNDLE_ID, DERIVED_DATA, port)

    assert caps["appium:wdaLocalPort"] == port


def test_ios_caps_reuse_the_wda_build_and_wait_for_a_cold_one() -> None:
    caps = ios_capabilities(UDID, BUNDLE_ID, DERIVED_DATA, 8111)

    assert caps["platformName"] == "iOS"
    assert caps["appium:automationName"] == "XCUITest"
    assert caps["appium:udid"] == UDID
    assert caps["appium:bundleId"] == BUNDLE_ID
    assert caps["appium:noReset"] is True
    assert caps["appium:derivedDataPath"] == str(DERIVED_DATA)
    assert caps["appium:wdaLaunchTimeout"] == 600000
    assert caps["appium:wdaConnectionTimeout"] == 600000


def test_default_derived_data_is_the_dot_folder_beside_the_package() -> None:
    assert session.WDA_DERIVED_DATA == Path(session.__file__).resolve().parents[2] / ".wda-derived"


def test_install_app_installs_into_the_named_simulator(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[list[str]] = []
    monkeypatch.setattr(
        session.subprocess, "run", lambda argv, **_: calls.append(argv)
    )

    install_app(UDID, Path("/tmp/Runner.app"))

    assert calls == [["xcrun", "simctl", "install", UDID, "/tmp/Runner.app"]]


def test_open_fixture_terminates_then_launches_with_the_route() -> None:
    driver = ScriptDriver()

    fixtures.open_fixture(driver, "ios", BUNDLE_ID, "smoke/semantics_id")

    assert driver.scripts == [
        ("mobile: terminateApp", {"bundleId": BUNDLE_ID}),
        (
            "mobile: launchApp",
            {"bundleId": BUNDLE_ID, "arguments": ["--route=/fixture/smoke/semantics_id"]},
        ),
    ]


def test_by_id_on_ios_matches_the_accessibility_id() -> None:
    driver = ScriptDriver()

    assert locate.by_id(driver, "ios", "smoke.button") == "node"
    assert driver.finds == [(AppiumBy.ACCESSIBILITY_ID, "smoke.button")]
