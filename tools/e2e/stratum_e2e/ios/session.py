"""iOS XCUITest session capabilities and simulator app install (design section 8)."""

from __future__ import annotations

import subprocess
from pathlib import Path

from stratum_e2e.paths import E2E_ROOT

IOS_PLATFORM_VERSION = "27.1"
WDA_TIMEOUT_MS = 600_000  # a cold WebDriverAgent build takes about 2 minutes (spike-ios)
WDA_DERIVED_DATA = E2E_ROOT / ".wda-derived"


def ios_capabilities(
    udid: str, bundle_id: str, derived_data: Path, wda_port: int
) -> dict[str, object]:
    """Return XCUITest capabilities for simulator [udid] that reuse a built WebDriverAgent.

    `platformVersion` must be 27.1: the driver gates its VoiceOver commands on iOS 27.
    A fixed [derived_data] folder keeps the WebDriverAgent build between sessions, and
    `noReset` keeps the installed app, which `fixtures.open_fixture` launches itself.
    """
    return {
        "platformName": "iOS",
        "appium:automationName": "XCUITest",
        "appium:platformVersion": IOS_PLATFORM_VERSION,
        "appium:udid": udid,
        "appium:bundleId": bundle_id,
        "appium:noReset": True,
        "appium:wdaLocalPort": wda_port,
        "appium:wdaLaunchTimeout": WDA_TIMEOUT_MS,
        "appium:wdaConnectionTimeout": WDA_TIMEOUT_MS,
        "appium:derivedDataPath": str(derived_data),
    }


def install_app(udid: str, app: Path) -> None:
    """Install the [app] bundle on simulator [udid], replacing any installed copy.

    Raises subprocess.CalledProcessError when simctl exits non-zero.
    """
    subprocess.run(["xcrun", "simctl", "install", udid, str(app)], check=True)
