"""The device round catalog: what `e2e/targets.toml` declares and how a round request resolves against it.

Design section 7 owns the values; section 15 owns how `--target`, `--mode`, and `--repeat` combine.
"""

from __future__ import annotations

import tomllib
from collections.abc import Iterator, Mapping
from dataclasses import dataclass, field
from pathlib import Path
from types import MappingProxyType

from stratum_e2e.paths import TARGETS_TOML
from stratum_e2e.round.errors import CatalogError


_DEFAULT_MODE = "fast"
_PLATFORMS = ("android", "ios", "macos", "web", "linux", "windows")
_BUILD_MODES = ("debug", "profile", "release")


@dataclass(frozen=True)
class App:
    """An app the round builds or runs: its folder and the ids a device knows it by."""

    name: str
    folder: str
    android_id: str
    apple_id: str
    driver: str | None
    perf: str | None


@dataclass(frozen=True)
class Target:
    """One place a round runs: its boot identity and which kinds of run it takes.

    `plain_name` and `repeat` are keyed by a path relative to `test_app/integration_test/`.
    """

    name: str
    platform: str
    alone: bool = False
    avd: str | None = None
    build_mode: str | None = None
    emulator_args: tuple[str, ...] = ()
    device: str | None = None
    runtime: str | None = None
    browser: str | None = None
    wasm: bool = False
    apt: tuple[str, ...] = ()
    integration: bool = True
    e2e: bool = True
    catalog_only: bool = False
    plain_name: Mapping[str, str] = field(default_factory=lambda: MappingProxyType({}))
    repeat: Mapping[str, tuple[str, ...]] = field(default_factory=lambda: MappingProxyType({}))


@dataclass(frozen=True)
class RunSequence:
    """Files that run in order in one invocation on one target (`fo10_cold_restart`)."""

    name: str
    target: str
    files: tuple[str, ...]


@dataclass(frozen=True)
class Mode:
    """A named set of targets and the repeat count of the marked repeat blocks."""

    name: str
    targets: tuple[str, ...]
    repeat: int


@dataclass(frozen=True)
class LaneConfig:
    """Time and pressure limits of the machine-wide lane."""

    run_timeout_minutes: int
    boot_settle_timeout_seconds: int
    allow_level2: bool
    heavy_processes: tuple[str, ...]
    lane_wait_minutes: int
    boot_timeout_minutes: int = 10


@dataclass(frozen=True)
class Catalog:
    """Everything `targets.toml` declares."""

    apps: Mapping[str, App]
    targets: Mapping[str, Target]
    modes: Mapping[str, Mode]
    sequences: Mapping[str, RunSequence]
    lane: LaneConfig


@dataclass(frozen=True)
class RoundPlan:
    """What one round runs: its targets in order, the mode it came from, and the repeat count."""

    targets: tuple[Target, ...]
    mode: str
    repeat: int


class _Table:
    """A TOML table read through typed accessors; every miss names the table and key."""

    def __init__(self, raw: object, where: str) -> None:
        if not isinstance(raw, Mapping):
            raise CatalogError(f"{where} must be a table")
        self._raw: Mapping[str, object] = raw
        self.where = where

    def reject_unknown(self, allowed: set[str]) -> None:
        unknown = sorted(set(self._raw) - allowed)
        if unknown:
            raise CatalogError(f"{self.where} has unknown key '{unknown[0]}'")

    def str_(self, key: str) -> str:
        value = self._raw.get(key)
        if not isinstance(value, str) or not value:
            raise CatalogError(f"{self.where}.{key} must be a non-empty string")
        return value

    def opt_str(self, key: str) -> str | None:
        return self.str_(key) if key in self._raw else None

    def bool_(self, key: str, default: bool) -> bool:
        value = self._raw.get(key, default)
        if not isinstance(value, bool):
            raise CatalogError(f"{self.where}.{key} must be true or false")
        return value

    def int_(self, key: str, default: int | None = None) -> int:
        value = self._raw.get(key, default)
        if not isinstance(value, int) or isinstance(value, bool):
            raise CatalogError(f"{self.where}.{key} must be an integer")
        return value

    def strs(self, key: str, *, required: bool = False) -> tuple[str, ...]:
        if key not in self._raw and not required:
            return ()
        value = self._raw.get(key)
        if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
            raise CatalogError(f"{self.where}.{key} must be a list of strings")
        return tuple(str(item) for item in value)

    def table(self, key: str) -> _Table:
        return _Table(self._raw.get(key, {}), f"{self.where}.{key}")

    def keys(self) -> Iterator[str]:
        return iter(self._raw)


def load_catalog(path: Path = TARGETS_TOML, integration_dir: Path | None = None) -> Catalog:
    """Parse `path` into a Catalog, failing with a CatalogError that names the bad table or key.

    With `integration_dir`, every file a target feature or a sequence names must exist under it.
    """
    try:
        with path.open("rb") as handle:
            raw = tomllib.load(handle)
    except FileNotFoundError as error:
        raise CatalogError(f"catalog file {path} is absent") from error
    except tomllib.TOMLDecodeError as error:
        raise CatalogError(f"{path}: {error}") from error

    root = _Table(raw, path.name)
    root.reject_unknown({"apps", "targets", "sequences", "modes", "lane"})
    apps = {name: _app(name, root.table("apps").table(name)) for name in root.table("apps").keys()}
    targets = {
        name: _target(name, root.table("targets").table(name), integration_dir)
        for name in root.table("targets").keys()
    }
    modes = {name: _mode(name, root.table("modes").table(name), targets) for name in root.table("modes").keys()}
    sequences = {
        name: _sequence(name, root.table("sequences").table(name), targets, integration_dir)
        for name in root.table("sequences").keys()
    }
    return Catalog(apps, targets, modes, sequences, _lane(root.table("lane")))


def resolve_round(
    catalog: Catalog,
    target_arg: str | None,
    mode_arg: str | None,
    repeat_arg: int | None,
) -> RoundPlan | None:
    """Turn `--target`, `--mode`, and `--repeat` into a plan; None when none is given (the legacy path).

    `--target` replaces the mode's target list and keeps its repeat count; `--target` or `--repeat` with no
    `--mode` takes `fast`. `--repeat` replaces the mode's count.
    """
    if repeat_arg is not None and repeat_arg < 1:
        raise CatalogError(f"--repeat must be at least 1, got {repeat_arg}")
    if target_arg is None and mode_arg is None and repeat_arg is None:
        return None

    mode_name = mode_arg if mode_arg is not None else _DEFAULT_MODE
    mode = catalog.modes.get(mode_name)
    if mode is None:
        raise CatalogError(f"unknown mode '{mode_name}'; known modes: {', '.join(catalog.modes)}")

    names = mode.targets if target_arg is None else _split_targets(target_arg)
    targets = tuple(_known_target(catalog, name) for name in names)
    return RoundPlan(targets, mode.name, repeat_arg if repeat_arg is not None else mode.repeat)


def _split_targets(target_arg: str) -> tuple[str, ...]:
    names = dict.fromkeys(part.strip() for part in target_arg.split(",") if part.strip())
    if not names:
        raise CatalogError("--target names no target")
    return tuple(names)


def _known_target(catalog: Catalog, name: str) -> Target:
    target = catalog.targets.get(name)
    if target is None:
        raise CatalogError(f"unknown target '{name}'; known targets: {', '.join(catalog.targets)}")
    if target.catalog_only:
        raise CatalogError(f"target '{name}' is catalog-only and cannot run")
    return target


def _app(name: str, table: _Table) -> App:
    table.reject_unknown({"folder", "android_id", "apple_id", "driver", "perf"})
    return App(
        name,
        table.str_("folder"),
        table.str_("android_id"),
        table.str_("apple_id"),
        table.opt_str("driver"),
        table.opt_str("perf"),
    )


def _target(name: str, table: _Table, integration_dir: Path | None) -> Target:
    table.reject_unknown({
        "platform", "alone", "avd", "build_mode", "emulator_args", "device", "runtime", "browser", "wasm", "apt",
        "integration", "e2e", "catalog_only", "plain_name", "repeat",
    })
    platform = table.str_("platform")
    if platform not in _PLATFORMS:
        raise CatalogError(f"{table.where}.platform '{platform}' is not one of {', '.join(_PLATFORMS)}")
    build_mode = table.opt_str("build_mode")
    if build_mode is not None and build_mode not in _BUILD_MODES:
        raise CatalogError(f"{table.where}.build_mode '{build_mode}' is not one of {', '.join(_BUILD_MODES)}")
    # The booter of the platform boots by this key; a target without it would fail every item at bring-up.
    avd = table.str_("avd") if platform == "android" else table.opt_str("avd")
    device = table.str_("device") if platform == "ios" else table.opt_str("device")

    plain_name_table = table.table("plain_name")
    plain_name = {key: plain_name_table.str_(key) for key in plain_name_table.keys()}
    repeat_table = table.table("repeat")
    repeat = {key: repeat_table.strs(key, required=True) for key in repeat_table.keys()}
    for relative in (*plain_name, *repeat):
        _require_file(integration_dir, relative, table.where)

    return Target(
        name=name,
        platform=platform,
        alone=table.bool_("alone", False),
        avd=avd,
        build_mode=build_mode,
        emulator_args=table.strs("emulator_args"),
        device=device,
        runtime=table.opt_str("runtime"),
        browser=table.opt_str("browser"),
        wasm=table.bool_("wasm", False),
        apt=table.strs("apt"),
        integration=table.bool_("integration", True),
        e2e=table.bool_("e2e", True),
        catalog_only=table.bool_("catalog_only", False),
        plain_name=MappingProxyType(plain_name),
        repeat=MappingProxyType(repeat),
    )


def _mode(name: str, table: _Table, targets: Mapping[str, Target]) -> Mode:
    table.reject_unknown({"targets", "repeat"})
    names = table.strs("targets", required=True)
    for target_name in names:
        _check_runnable(table.where, target_name, targets)
    repeat = table.int_("repeat")
    if repeat < 1:
        raise CatalogError(f"{table.where}.repeat must be at least 1")
    return Mode(name, names, repeat)


def _sequence(name: str, table: _Table, targets: Mapping[str, Target], integration_dir: Path | None) -> RunSequence:
    table.reject_unknown({"target", "files"})
    target = table.str_("target")
    if target not in targets:
        raise CatalogError(f"{table.where}.target names unknown target '{target}'")
    files = table.strs("files", required=True)
    for relative in files:
        _require_file(integration_dir, relative, table.where)
    return RunSequence(name, target, files)


def _lane(table: _Table) -> LaneConfig:
    table.reject_unknown({
        "run_timeout_minutes", "boot_settle_timeout_seconds", "allow_level2", "heavy_processes",
        "lane_wait_minutes", "boot_timeout_minutes",
    })
    return LaneConfig(
        run_timeout_minutes=table.int_("run_timeout_minutes"),
        boot_settle_timeout_seconds=table.int_("boot_settle_timeout_seconds"),
        allow_level2=table.bool_("allow_level2", False),
        heavy_processes=table.strs("heavy_processes"),
        lane_wait_minutes=table.int_("lane_wait_minutes"),
        boot_timeout_minutes=table.int_("boot_timeout_minutes", 10),
    )


def _check_runnable(where: str, name: str, targets: Mapping[str, Target]) -> None:
    target = targets.get(name)
    if target is None:
        raise CatalogError(f"{where}.targets names unknown target '{name}'")
    if target.catalog_only:
        raise CatalogError(f"{where}.targets names catalog-only target '{name}'")


def _require_file(integration_dir: Path | None, relative: str, where: str) -> None:
    if integration_dir is not None and not (integration_dir / relative).is_file():
        raise CatalogError(f"{where} names {relative}, which is absent under {integration_dir}")
