"""Appium server lifecycle for the e2e suite (design section 18 item 3)."""

from __future__ import annotations

import os
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path

from stratum_e2e.paths import E2E_ROOT
from stratum_e2e.round.android_host import sdk_root
from stratum_e2e.round.errors import RoundEnvError

LOOPBACK_ADDRESS = "127.0.0.1"
POLL_INTERVAL_S = 0.25
STATUS_TIMEOUT_S = 2.0


class AppiumStartError(RuntimeError):
    """Appium did not answer /status within the start timeout."""


class AppiumServer:
    """One Appium server bound to [port], started and stopped on demand."""

    def __init__(
        self,
        *,
        appium_bin: Path,
        appium_home: Path,
        port: int,
        android_home: Path | None,
    ) -> None:
        self.appium_bin = appium_bin
        self.appium_home = appium_home
        self.port = port
        self.android_home = android_home
        self._process: subprocess.Popen[bytes] | None = None
        self.log_path: Path | None = None

    @property
    def url(self) -> str:
        """Base URL of the server's WebDriver endpoint."""
        return f"http://{LOOPBACK_ADDRESS}:{self.port}"

    def env(self) -> dict[str, str]:
        """Environment the server needs: APPIUM_HOME and ANDROID_HOME when set."""
        merged = dict(os.environ)
        merged["APPIUM_HOME"] = str(self.appium_home)
        if self.android_home is not None:
            merged["ANDROID_HOME"] = str(self.android_home)
        return merged

    def start(self, timeout_s: float = 60, log: Path | None = None) -> None:
        """Spawn the server on loopback only and block until /status answers.

        With `log`, the server's output goes there and `log_path` names it; without, it is discarded.
        Raises AppiumStartError naming the port and the log when the server never answers
        within [timeout_s]; the process is stopped before raising.
        """
        self.stop()
        if log is not None:
            log.parent.mkdir(parents=True, exist_ok=True)
            self.log_path = log
            sink = log.open("ab")
        else:
            self.log_path = None
            sink = None
        try:
            self._process = subprocess.Popen(
                [
                    str(self.appium_bin),
                    "server",
                    "--address",
                    LOOPBACK_ADDRESS,
                    "--port",
                    str(self.port),
                ],
                env=self.env(),
                stdout=sink if sink is not None else subprocess.DEVNULL,
                stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL,
            )
        finally:
            if sink is not None:
                sink.close()
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            if self._process.poll() is not None:
                raise AppiumStartError(
                    f"appium on port {self.port} exited with code {self._process.returncode}"
                    + self._log_note()
                )
            if self._status_ok():
                return
            time.sleep(POLL_INTERVAL_S)
        self.stop()
        raise AppiumStartError(
            f"appium on port {self.port} did not answer /status within {timeout_s:g}s" + self._log_note()
        )

    def poll(self) -> int | None:
        """The server's exit code when it has died, else None; None before the first start."""
        if self._process is None:
            return None
        return self._process.poll()

    def _log_note(self) -> str:
        """The `log:` clause an error names, so a dead server's output is one path away."""
        return f", log: {self.log_path}" if self.log_path is not None else ""

    def stop(self) -> None:
        """Terminate and reap the server; safe to call twice."""
        if self._process is None:
            return
        self._process.terminate()
        try:
            self._process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self._process.kill()
            self._process.wait()
        self._process = None

    def _status_ok(self) -> bool:
        try:
            with urllib.request.urlopen(
                f"{self.url}/status", timeout=STATUS_TIMEOUT_S
            ) as response:
                return response.status == 200
        except (urllib.error.URLError, OSError, ValueError):
            return False


def default_android_home() -> Path | None:
    """Return the Android SDK the device round resolves, or None when none exists."""
    try:
        return sdk_root(E2E_ROOT.parent / "test_app", os.environ, Path.home())
    except RoundEnvError:
        return None
