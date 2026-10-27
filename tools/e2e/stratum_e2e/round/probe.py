"""Whether a mobile device a failed e2e item ran on is still there (design section 10, `env` rule).

A raw adb or simctl caller that dies mid-item leaves an error the round would class `fail`, though the device, not
the code under test, is gone: the emulator hung itself (`R3 e2e_talkback`), the simulator shut down, the serial went
`offline`. `lost_device_reason` probes the boot record's device and answers the `env: device lost (<probe result>)`
reason when it cannot answer as a live device, so every such caller is covered at classing time, not one call site.
"""

from __future__ import annotations

import json
from typing import Final

from stratum_e2e.round.boot import BootRecord
from stratum_e2e.round.runner import Runner

_PROBE_TIMEOUT_S: Final = 10.0
_NOT_FOUND_STATUS: Final = 127  # the status `SubprocessRunner` gives a binary that does not exist
_ADB: Final = "adb"
_SIMCTL: Final = "xcrun"


def lost_device_reason(runner: Runner, record: BootRecord) -> str | None:
    """Why `record`'s device reads lost, or None while it answers as a live device.

    Android asks `adb -s <serial> get-state` and reads `device`; iOS asks `simctl list -j` and reads the
    simulator `Booted`. Host platforms and a probe that itself failed (timed out, `adb` missing, no readable
    answer) read not-lost: their failure never pointed at a device.
    """
    if record.platform == "android":
        return _android_reason(runner, record.device_id)
    if record.platform == "ios":
        return _ios_reason(runner, record.device_id)
    return None


def _android_reason(runner: Runner, serial: str) -> str | None:
    done = runner.run([_ADB, "-s", serial, "get-state"], timeout_s=_PROBE_TIMEOUT_S)
    if done.timed_out or done.status == _NOT_FOUND_STATUS:
        return None
    # adb prints a state on stdout but its `error: device ... not found` on stderr.
    answer = done.stdout.strip() or done.stderr.strip()
    if not answer or answer == "device":
        return None
    return f"adb get-state: {answer}"


def _ios_reason(runner: Runner, udid: str) -> str | None:
    listed = runner.run([_SIMCTL, "simctl", "list", "-j"], timeout_s=_PROBE_TIMEOUT_S)
    try:
        devices = json.loads(listed.stdout)["devices"]
    except (json.JSONDecodeError, KeyError, TypeError):
        return None
    for entries in devices.values() if isinstance(devices, dict) else []:
        for entry in entries if isinstance(entries, list) else []:
            if isinstance(entry, dict) and entry.get("udid") == udid:
                return None if entry.get("state") == "Booted" else f"simctl state: {entry.get('state')}"
    return f"simctl list: {udid} not listed"
