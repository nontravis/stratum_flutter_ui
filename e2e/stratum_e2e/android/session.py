"""Android UiAutomator2 session capabilities and APK install (design section 8)."""

from __future__ import annotations

import subprocess
from pathlib import Path


def android_capabilities(serial: str, app_id: str) -> dict[str, object]:
    """Return UiAutomator2 capabilities that keep TalkBack bound and the app unlaunched.

    The session never launches or resets the app (`fixtures.open_fixture` does), and
    `disableSuppressAccessibilityService` stays True: False unbinds TalkBack for the
    whole session.
    """
    return {
        "platformName": "Android",
        "appium:automationName": "UiAutomator2",
        "appium:udid": serial,
        "appium:appPackage": app_id,
        "appium:noReset": True,
        "appium:autoLaunch": False,
        "appium:disableSuppressAccessibilityService": True,
    }


def install_apk(serial: str, apk: Path) -> None:
    """Install [apk] on device [serial], replacing any installed copy.

    Raises subprocess.CalledProcessError when adb exits non-zero.
    """
    subprocess.run(["adb", "-s", serial, "install", "-r", str(apk)], check=True)
