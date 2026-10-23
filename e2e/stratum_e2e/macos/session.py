"""macOS Mac2 session capabilities (design section 8)."""

from __future__ import annotations

from pathlib import Path


def mac_capabilities(bundle_id: str, arguments: list[str], app_path: Path) -> dict[str, object]:
    """Return Mac2 capabilities that launch the build at [app_path] with command-line [arguments].

    [app_path] must be absolute: the driver resolves a relative one against its own
    folder. `appPath` makes the session start the build the leg names, not whichever copy of
    [bundle_id] LaunchServices finds first. Mac2 drives the Mac's screen through XCTest
    and never starts VoiceOver. The session quits the app when it ends, because
    `skipAppKill` stays at its default.
    """
    return {
        "platformName": "mac",
        "appium:automationName": "Mac2",
        "appium:bundleId": bundle_id,
        "appium:appPath": str(app_path),
        "appium:arguments": list(arguments),
    }
