"""Appium server lifecycle for the e2e suite (design section 18 item 3)."""

from __future__ import annotations

import os
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path

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

    def start(self, timeout_s: float = 60) -> None:
        """Spawn the server on loopback only and block until /status answers.

        Raises AppiumStartError naming the port when the server never answers
        within [timeout_s]; the process is stopped before raising.
        """
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
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
        )
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            if self._process.poll() is not None:
                raise AppiumStartError(
                    f"appium on port {self.port} exited with code {self._process.returncode}"
                )
            if self._status_ok():
                return
            time.sleep(POLL_INTERVAL_S)
        self.stop()
        raise AppiumStartError(
            f"appium on port {self.port} did not answer /status within {timeout_s:g}s"
        )

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
    """Return ANDROID_HOME, else ~/Library/Android/sdk when it exists."""
    from_env = os.environ.get("ANDROID_HOME")
    if from_env:
        return Path(from_env)
    fallback = Path.home() / "Library" / "Android" / "sdk"
    if fallback.is_dir():
        return fallback
    return None
