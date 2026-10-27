"""macOS Mac2 session capabilities (design section 8)."""

from __future__ import annotations

from pathlib import Path

# The host VoiceOver leg (e2e/common/test_reorderable_list_view_layout.py) sends Mac2 no
# command from `macos: activateApp` to its teardown quit, and Appium ends a session after 60 s
# of silence by default, quitting the app (`skipAppKill` stays false). The leg's own bounds sum
# to about 1825 s (unit/test_reorder_host_legs.py recomputes it from the live constants):
# - start and stop: READY_TIMEOUT_SECONDS 15 s, then STOP_TIMEOUT_SECONDS 10 s after `quit`
#   and 10 s more after `pkill`, 35 s;
# - HOST_MAX_MOVES 60 moves, each a quiet read and a speech wait of HOST_SPEECH_TIMEOUT_S 5 s
#   plus one 0.25 s poll, 615 s;
# - ITEM_COUNT 6 actions menus, each a 3 s quiet read, ACTIONS_MENU_MAX_ENTRIES 30 entries of
#   at most 6.25 s (a 3 s settle that starts a 3 s quiet read at its deadline, plus a poll),
#   and a 5 s quiet read after it, 195.5 s each, 1173 s.
# Every osascript read runs inside those deadlines, so each window overruns by one read at most;
# 2400 s leaves about 575 s for that.
NEW_COMMAND_TIMEOUT_S = 2400


def mac_capabilities(bundle_id: str, arguments: list[str], app_path: Path) -> dict[str, object]:
    """Return Mac2 capabilities that launch the build at [app_path] with command-line [arguments].

    [app_path] must be absolute: the driver resolves a relative one against its own
    folder. `appPath` makes the session start the build the leg names, not whichever copy of
    [bundle_id] LaunchServices finds first. Mac2 drives the Mac's screen through XCTest
    and never starts VoiceOver. The session quits the app when it ends, because
    `skipAppKill` stays at its default; `newCommandTimeout` keeps it alive through the
    host VoiceOver walk (NEW_COMMAND_TIMEOUT_S).
    """
    return {
        "platformName": "mac",
        "appium:automationName": "Mac2",
        "appium:bundleId": bundle_id,
        "appium:appPath": str(app_path),
        "appium:arguments": list(arguments),
        "appium:newCommandTimeout": NEW_COMMAND_TIMEOUT_S,
    }
