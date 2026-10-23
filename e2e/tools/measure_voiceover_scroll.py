"""Measure open item O3: does VoiceOver scroll on past the last visible element? (design section 8)

A measurement, not a test: it proves no requirement. It walks forward through a native
list longer than the screen (Settings, `com.apple.Preferences`). When VoiceOver scrolls
there, the spike's stop on the Flutter screen belongs to Flutter's iOS bridge; when it
stops there too, it belongs to the simulator's VoiceOver.

Run from e2e/ on a booted iOS 27.1 simulator:
`.venv/bin/python -m tools.measure_voiceover_scroll --udid UDID [--max-moves N]`.
"""

from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ElementTree
from collections.abc import Sequence

from appium import webdriver
from appium.options.ios import XCUITestOptions

from stratum_e2e.appium_server import AppiumServer
from stratum_e2e.ios.session import WDA_DERIVED_DATA, ios_capabilities
from stratum_e2e.ios.voiceover import VoiceOver, VoiceOverSilent
from stratum_e2e.paths import APPIUM_BIN, APPIUM_HOME
from stratum_e2e.ports import free_port
from stratum_e2e.waits import wait_until

SETTINGS_BUNDLE_ID = "com.apple.Preferences"
# The last row of the first Settings screen on the iPhone Duo; waiting for it means the list laid out.
LAST_FIRST_SCREEN_ROW_LABEL = "StandBy"
DEFAULT_MAX_MOVES = 60


def visible_labels(page_source: str) -> list[str]:
    """Return the labels of the visible, labeled elements in [page_source], in tree order."""
    root = ElementTree.fromstring(page_source)
    return [
        node.attrib["label"]
        for node in root.iter()
        if node.attrib.get("visible") == "true" and node.attrib.get("label")
    ]


def spoken_beyond(before: Sequence[str], spoken: Sequence[str]) -> list[str]:
    """Return the utterances in [spoken] whose element was not visible in [before].

    An utterance reads `<label> <role> <hint>`, so an element counts as visible before
    when one of the [before] labels starts the utterance.
    """
    return [
        utterance
        for utterance in spoken
        if not any(utterance.startswith(label) for label in before)
    ]


def verdict(beyond: Sequence[str]) -> str:
    """Return the RESULT line for the utterances spoken [beyond] the first screen."""
    if beyond:
        return "RESULT: VoiceOver scrolled the native list; the stop is Flutter's iOS bridge"
    return "RESULT: VoiceOver did not scroll the native list; the stop is the simulator's VoiceOver"


def measure(udid: str, max_moves: int) -> int:
    """Walk Settings with VoiceOver; print the evidence; return the exit code."""
    server = AppiumServer(
        appium_bin=APPIUM_BIN, appium_home=APPIUM_HOME, port=free_port(), android_home=None
    )
    server.start()
    try:
        caps = ios_capabilities(udid, SETTINGS_BUNDLE_ID, WDA_DERIVED_DATA, free_port())
        driver = webdriver.Remote(
            server.url, options=XCUITestOptions().load_capabilities(caps)
        )
        try:
            return walk(driver, max_moves)
        finally:
            driver.quit()
    finally:
        server.stop()


def _first_screen(driver: webdriver.Remote) -> list[str]:
    """Relaunch Settings and return the labels of the read that shows its whole first screen.

    The condition and the result share one page-source read: two reads in a row can
    disagree while the list lays out.
    """
    driver.execute_script("mobile: terminateApp", {"bundleId": SETTINGS_BUNDLE_ID})
    driver.execute_script("mobile: launchApp", {"bundleId": SETTINGS_BUNDLE_ID})
    seen: list[str] = []

    def last_row_visible() -> bool:
        seen[:] = visible_labels(driver.page_source)
        return LAST_FIRST_SCREEN_ROW_LABEL in seen

    wait_until(
        last_row_visible,
        f"the {LAST_FIRST_SCREEN_ROW_LABEL!r} row on the first Settings screen",
    )
    return list(seen)


def walk(driver: webdriver.Remote, max_moves: int) -> int:
    before = _first_screen(driver)
    print(f"visible.before ({len(before)}): {before}")
    with VoiceOver(driver) as voiceover:
        try:
            spoken = voiceover.walk_forward(max_moves)
        except VoiceOverSilent as error:
            print(f"RESULT: inconclusive, {error}")
            return 1
    beyond = spoken_beyond(before, spoken)
    print(f"spoken ({len(spoken)}): {spoken}")
    print(f"spoken.beyond_first_screen ({len(beyond)}): {beyond}")
    print(verdict(beyond))
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--udid", required=True, help="booted iOS 27.1 simulator udid")
    parser.add_argument("--max-moves", type=int, default=DEFAULT_MAX_MOVES)
    args = parser.parse_args(argv)
    return measure(args.udid, args.max_moves)


if __name__ == "__main__":
    sys.exit(main())
