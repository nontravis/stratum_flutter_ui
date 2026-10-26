"""Secure settings on the e2e AVD: read one, change one for a block, restore (ruling Q3)."""

from __future__ import annotations

from types import TracebackType

from stratum_e2e.android.adb import AVD_NAME, avd_name, get_secure, put_secure, restore_secure


def read_secure(serial: str, key: str) -> str:
    """Return the value of secure setting [key] on [serial]; `null` when it is unset."""
    return get_secure(serial, key)


class SecureSetting:
    """Hold secure setting [key] at [value] for the `with` block, then restore what it read before.

    Entering returns the saved value. Refuses a shared AVD before any write; the restore
    runs on success and on an exception, and deletes the key when it was unset before
    (ruling Q3: only the dedicated e2e AVD takes settings changes).
    """

    def __init__(self, serial: str, key: str, value: str) -> None:
        self._serial = serial
        self._key = key
        self._value = value

    def __enter__(self) -> str:
        name = avd_name(self._serial)
        if name != AVD_NAME:
            raise ValueError(
                f"refusing {self._serial}: AVD is {name!r}, secure settings change only on {AVD_NAME!r}"
            )
        self._saved = read_secure(self._serial, self._key)
        try:
            put_secure(self._serial, self._key, self._value)
        except BaseException:
            self._restore()
            raise
        return self._saved

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        self._restore()

    def _restore(self) -> None:
        restore_secure(self._serial, self._key, self._saved)
