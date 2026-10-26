"""Unit tests for the secure-setting stage (no adb, no device)."""

from __future__ import annotations

import subprocess

import pytest

from stratum_e2e.android.secure_settings import SecureSetting, read_secure
from stratum_e2e.android.talkback import AVD_NAME

ADB_MODULE = "stratum_e2e.android.adb"
SERIAL = "emulator-5554"
KEY = "show_ime_with_hard_keyboard"


class FakeAdb:
    """In-memory device: the AVD name and the secure settings."""

    def __init__(self) -> None:
        self.avd = AVD_NAME
        self.settings: dict[str, str] = {}
        self.calls: list[list[str]] = []

    def __call__(self, argv: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        assert argv[:3] == ["adb", "-s", SERIAL]
        self.calls.append(argv[3:])
        return subprocess.CompletedProcess(argv, 0, self._answer(argv[3:]), "")

    def writes(self) -> list[list[str]]:
        """Return every settings put or delete the code issued."""
        verbs = (["shell", "settings", "put"], ["shell", "settings", "delete"])
        return [c for c in self.calls if c[:3] in verbs]

    def _answer(self, args: list[str]) -> str:
        if args == ["emu", "avd", "name"]:
            return f"{self.avd}\nOK\n"
        if args[:4] == ["shell", "settings", "get", "secure"]:
            return self.settings.get(args[4], "null") + "\n"
        if args[:4] == ["shell", "settings", "put", "secure"]:
            self.settings[args[4]] = args[5]
        elif args[:4] == ["shell", "settings", "delete", "secure"]:
            self.settings.pop(args[4], None)
        return ""


@pytest.fixture
def fake_adb(monkeypatch: pytest.MonkeyPatch) -> FakeAdb:
    adb = FakeAdb()
    monkeypatch.setattr(f"{ADB_MODULE}.subprocess.run", adb)
    return adb


def test_secure_setting_refuses_a_shared_avd_before_any_write(fake_adb: FakeAdb) -> None:
    fake_adb.avd = "Pixel_8_API_37"

    with pytest.raises(ValueError, match="Pixel_8_API_37"), SecureSetting(SERIAL, KEY, "1"):
        pytest.fail("the body must not run")

    assert fake_adb.writes() == []


def test_secure_setting_puts_the_value_then_restores_the_saved_one(fake_adb: FakeAdb) -> None:
    fake_adb.settings[KEY] = "0"

    with SecureSetting(SERIAL, KEY, "1") as saved:
        assert saved == "0"
        assert fake_adb.settings[KEY] == "1"

    assert fake_adb.settings[KEY] == "0"
    assert fake_adb.writes() == [
        ["shell", "settings", "put", "secure", KEY, "1"],
        ["shell", "settings", "put", "secure", KEY, "0"],
    ]


def test_secure_setting_restores_on_exception(fake_adb: FakeAdb) -> None:
    fake_adb.settings[KEY] = "0"

    with pytest.raises(RuntimeError, match="boom"), SecureSetting(SERIAL, KEY, "1"):
        raise RuntimeError("boom")

    assert fake_adb.settings[KEY] == "0"


def test_secure_setting_deletes_a_key_that_was_unset(fake_adb: FakeAdb) -> None:
    assert read_secure(SERIAL, KEY) == "null"

    with SecureSetting(SERIAL, KEY, "1") as saved:
        assert saved == "null"
        assert fake_adb.settings[KEY] == "1"

    assert KEY not in fake_adb.settings
    assert fake_adb.writes()[-1] == ["shell", "settings", "delete", "secure", KEY]


def test_secure_setting_quotes_an_empty_value_on_put_and_restore(fake_adb: FakeAdb) -> None:
    fake_adb.settings[KEY] = ""

    with SecureSetting(SERIAL, KEY, "") as saved:
        assert saved == ""
        assert fake_adb.writes()[-1] == ["shell", "settings", "put", "secure", KEY, "''"]

    assert fake_adb.writes() == [
        ["shell", "settings", "put", "secure", KEY, "''"],
        ["shell", "settings", "put", "secure", KEY, "''"],
    ]


def test_secure_setting_quotes_a_value_with_a_space(fake_adb: FakeAdb) -> None:
    fake_adb.settings[KEY] = "old value"

    with SecureSetting(SERIAL, KEY, "a b") as saved:
        assert saved == "old value"
        assert fake_adb.writes()[-1] == ["shell", "settings", "put", "secure", KEY, "'a b'"]

    assert fake_adb.writes() == [
        ["shell", "settings", "put", "secure", KEY, "'a b'"],
        ["shell", "settings", "put", "secure", KEY, "'old value'"],
    ]
