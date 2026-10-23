"""The dedicated e2e AVD: create it, turn TalkBack and Diagnosis mode on, check it (ruling Q3).

Run from e2e/: `.venv/bin/python -m tools.e2e_avd create | talkback --serial S |
diagnosis --serial S | check --serial S`. Only this AVD gets TalkBack, Diagnosis mode, or
settings changes; every device command refuses any other AVD (design section 8).
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from collections.abc import Sequence
from pathlib import Path

from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.webdriver.common.appiumby import AppiumBy
from appium.webdriver.webdriver import WebDriver
from appium.webdriver.webelement import WebElement

from stratum_e2e.android.session import android_capabilities
from stratum_e2e.android.talkback import (
    AVD_NAME,
    TALKBACK_SERVICE,
    TalkBackSession,
    TalkBackSilent,
    TalkBackStuck,
    avd_name,
)
from stratum_e2e.appium_server import AppiumServer, default_android_home
from stratum_e2e.paths import APPIUM_BIN, APPIUM_HOME
from stratum_e2e.ports import free_port

SYSTEM_IMAGE = "system-images;android-35;google_apis_playstore_tablet;arm64-v8a"
DEVICE_PROFILE = "pixel_tablet"
KEYBOARD_KEY = "hw.keyboard"
# Cold boot only: quick boot saves a ~3.8 GB snapshot on every exit, even under -no-snapshot-load.
CONFIG_VALUES = {
    KEYBOARD_KEY: "yes",
    "fastboot.forceColdBoot": "yes",
    "fastboot.forceFastBoot": "no",
}

KEY_REPEAT_SETTING = "key_repeat_timeout"
KEY_REPEAT_TIMEOUT_MS = 10000

TALKBACK_PACKAGE = "com.google.android.marvin.talkback"
TALKBACK_SETTINGS_ACTIVITY = "com.android.talkback.TalkBackPreferencesActivity"

EXIT_OK = 0
EXIT_FAILED = 1
EXIT_AVD_EXISTS = 2

FIND_TIMEOUT_S = 15

_SERVICES_SETTING = "enabled_accessibility_services"
_ENABLED_SETTING = "accessibility_enabled"
_NOTIFICATIONS_PERMISSION = "android.permission.POST_NOTIFICATIONS"
_VERSION_NAME = re.compile(r"versionName=(\S+)")
_DIAGNOSIS_ROW = "Diagnosis mode"
_DIAGNOSIS_SWITCH = f'//*[@text="{_DIAGNOSIS_ROW}"]/../..//android.widget.Switch'


def set_ini_value(text: str, key: str, value: str) -> str:
    """Return [text] with every `key=` line set to [value]; appends the line when absent.

    A line matches on its whole key, so `hw.keyboard.lid` never matches `hw.keyboard`.
    """
    line = f"{key}={value}\n"
    lines = text.splitlines(keepends=True)
    matches = [index for index, current in enumerate(lines) if _ini_key(current) == key]
    for index in matches:
        lines[index] = line
    if not matches:
        if lines and not lines[-1].endswith("\n"):
            lines[-1] += "\n"
        lines.append(line)
    return "".join(lines)


def ini_value(text: str, key: str) -> str | None:
    """Return the value of the first [key] line in [text], or None when absent."""
    for line in text.splitlines():
        if _ini_key(line) == key:
            return line.partition("=")[2].strip()
    return None


def version_name(dumpsys_package: str) -> str | None:
    """Return the first `versionName` in `dumpsys package` output, or None when absent."""
    match = _VERSION_NAME.search(dumpsys_package)
    return match.group(1) if match else None


def avd_home() -> Path:
    """Return ANDROID_AVD_HOME, else ~/.android/avd, where avdmanager writes AVDs."""
    from_env = os.environ.get("ANDROID_AVD_HOME")
    return Path(from_env) if from_env else Path.home() / ".android" / "avd"


def config_path() -> Path:
    """Return the config.ini of the AVD named AVD_NAME."""
    return avd_home() / f"{AVD_NAME}.avd" / "config.ini"


def create() -> int:
    """Create the AVD with avdmanager, then write CONFIG_VALUES into its config.ini.

    Returns EXIT_AVD_EXISTS, creating nothing, when the AVD already exists.
    """
    if (avd_home() / f"{AVD_NAME}.ini").exists():
        print(f"{AVD_NAME} already exists in {avd_home()}", file=sys.stderr)
        return EXIT_AVD_EXISTS
    subprocess.run(
        [
            str(_avdmanager()),
            "create",
            "avd",
            "-n",
            AVD_NAME,
            "-k",
            SYSTEM_IMAGE,
            "-d",
            DEVICE_PROFILE,
        ],
        check=True,
        input="no\n",  # answers "Do you wish to create a custom hardware profile?"
        text=True,
    )
    config = config_path()
    text = config.read_text()
    for key, value in CONFIG_VALUES.items():
        text = set_ini_value(text, key, value)
    config.write_text(text)
    settings = ", ".join(f"{key}={value}" for key, value in CONFIG_VALUES.items())
    print(f"created {AVD_NAME}: {settings} in {config}")
    return EXIT_OK


def talkback(serial: str) -> int:
    """Turn TalkBack on through the secure settings of device [serial].

    Grants POST_NOTIFICATIONS first: while ungranted, every TalkBack start opens a
    permission dialog that takes the screen. Sets the key repeat timeout before TalkBack
    turns on, so no key is ever dispatched under the stock timeout.
    """
    _adb(serial, "shell", "pm", "grant", TALKBACK_PACKAGE, _NOTIFICATIONS_PERMISSION)
    # WORKAROUND: with TalkBack on, every key passes through its key filter, and one it
    # re-injects past InputDispatcher's KeyRepeatTimeout (400 ms) auto-repeats, so a Tab walk
    # sees extra Tabs (Android + TalkBack, not stratum_ui); remove when a TalkBack-on Tab walk
    # shows no extra Tab with this setting unset, or level-1 walks run with TalkBack off.
    _put_secure(serial, KEY_REPEAT_SETTING, str(KEY_REPEAT_TIMEOUT_MS))
    _put_secure(serial, _SERVICES_SETTING, TALKBACK_SERVICE)
    _put_secure(serial, _ENABLED_SETTING, "1")
    print("talkback=on")
    return EXIT_OK


def diagnosis(serial: str) -> int:
    """Switch TalkBack's Diagnosis mode on through Appium (spike-android Q3b steps 1-2).

    Leaves an already-on switch untouched, so a second run changes nothing.
    """
    server = AppiumServer(
        appium_bin=APPIUM_BIN,
        appium_home=APPIUM_HOME,
        port=free_port(),
        android_home=default_android_home(),
    )
    server.start()
    try:
        # TalkBack has no launcher activity; without appActivity the session fails.
        capabilities = android_capabilities(serial, TALKBACK_PACKAGE)
        capabilities["appium:appActivity"] = TALKBACK_SETTINGS_ACTIVITY
        options = UiAutomator2Options().load_capabilities(capabilities)
        driver = webdriver.Remote(server.url, options=options)
        try:
            switched_on = _switch_diagnosis_on(driver, serial)
        finally:
            driver.quit()
    finally:
        server.stop()
    _adb(serial, "shell", "input", "keyevent", "KEYCODE_HOME")
    print(f"diagnosis mode={'on' if switched_on else 'off'}")
    return EXIT_OK if switched_on else EXIT_FAILED


def check(serial: str) -> int:
    """Print the AVD's keyboard, TalkBack version, key repeat timeout, and Diagnosis mode.

    0 when all hold: the keyboard is on, TalkBack is installed, the key repeat timeout is
    KEY_REPEAT_TIMEOUT_MS, and Diagnosis mode speaks.
    """
    keyboard = ini_value(config_path().read_text(), KEYBOARD_KEY)
    version = talkback_version(serial)
    repeat = key_repeat_timeout(serial)
    speaks = diagnosis_speaks(serial)
    print(f"{KEYBOARD_KEY}={keyboard or 'unset'}")
    print(f"talkback={version or 'missing'}")
    print(f"{KEY_REPEAT_SETTING}={'unset' if repeat is None else repeat}")
    print(f"diagnosis={'on' if speaks else 'off'}")
    ok = keyboard == "yes" and version and repeat == KEY_REPEAT_TIMEOUT_MS and speaks
    return EXIT_OK if ok else EXIT_FAILED


def key_repeat_timeout(serial: str) -> int | None:
    """Return the secure key_repeat_timeout of [serial] in ms, or None when it is not set."""
    printed = _adb(serial, "shell", "settings", "get", "secure", KEY_REPEAT_SETTING).strip()
    return int(printed) if printed.isdigit() else None


def talkback_version(serial: str) -> str | None:
    """Return the installed TalkBack's versionName on [serial], or None when absent."""
    return version_name(_adb(serial, "shell", "dumpsys", "package", TALKBACK_PACKAGE))


def diagnosis_speaks(serial: str) -> bool:
    """Restart TalkBack on [serial]; True when it speaks within 20 s (Diagnosis mode on).

    False also when TalkBack never unbinds. TalkBackSession restores the settings it
    found, so TalkBack ends on or off as before.
    """
    try:
        with TalkBackSession(serial):
            return True
    except (TalkBackSilent, TalkBackStuck):
        return False


def main(argv: Sequence[str] | None = None) -> int:
    """Run one subcommand; the device ones refuse any AVD but AVD_NAME (exit 1)."""
    parser = argparse.ArgumentParser(prog="python -m tools.e2e_avd", description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("create", help=f"create {AVD_NAME}: {KEYBOARD_KEY}=yes, cold boot only")
    for name, summary in (
        ("talkback", "turn TalkBack on"),
        ("diagnosis", "switch TalkBack's Diagnosis mode on"),
        ("check", "print hw.keyboard, talkback, key_repeat_timeout, and diagnosis"),
    ):
        command = commands.add_parser(name, help=summary)
        command.add_argument("--serial", required=True, help="adb serial of the booted AVD")
    args = parser.parse_args(argv)

    if args.command == "create":
        return create()
    serial: str = args.serial
    name = avd_name(serial)
    if name != AVD_NAME:
        print(f"refusing {serial}: AVD is {name!r}, not {AVD_NAME!r}", file=sys.stderr)
        return EXIT_FAILED
    device_commands = {"talkback": talkback, "diagnosis": diagnosis, "check": check}
    return device_commands[args.command](serial)


def _switch_diagnosis_on(driver: WebDriver, serial: str) -> bool:
    driver.implicitly_wait(FIND_TIMEOUT_S)
    _adb(serial, "shell", "am", "start", "-n", f"{TALKBACK_PACKAGE}/{TALKBACK_SETTINGS_ACTIVITY}")
    for row in ("Advanced settings", "Developer settings"):
        _scroll_to(driver, row).click()
    if not _diagnosis_checked(driver):
        _scroll_to(driver, _DIAGNOSIS_ROW).click()
        driver.find_element(AppiumBy.XPATH, '//*[@text="OK"]').click()
    return _diagnosis_checked(driver)


def _scroll_to(driver: WebDriver, text: str) -> WebElement:
    return driver.find_element(
        AppiumBy.ANDROID_UIAUTOMATOR,
        "new UiScrollable(new UiSelector().scrollable(true))"
        f'.scrollIntoView(new UiSelector().text("{text}"))',
    )


def _diagnosis_checked(driver: WebDriver) -> bool:
    _scroll_to(driver, _DIAGNOSIS_ROW)
    return driver.find_element(AppiumBy.XPATH, _DIAGNOSIS_SWITCH).get_attribute("checked") == "true"


def _ini_key(line: str) -> str:
    return line.partition("=")[0].strip()


def _avdmanager() -> Path:
    sdk = default_android_home()
    if sdk is None:
        raise RuntimeError("no Android SDK: set ANDROID_HOME or install ~/Library/Android/sdk")
    return sdk / "cmdline-tools" / "latest" / "bin" / "avdmanager"


def _put_secure(serial: str, setting: str, value: str) -> None:
    _adb(serial, "shell", "settings", "put", "secure", setting, value)


def _adb(serial: str, *args: str) -> str:
    result = subprocess.run(
        ["adb", "-s", serial, *args],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return result.stdout


if __name__ == "__main__":
    sys.exit(main())
