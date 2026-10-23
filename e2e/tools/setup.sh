#!/usr/bin/env bash
#
# e2e toolchain setup for the stratum_ui e2e suite.
# Plan task M2-T7; design section 4 (own environment) and section 16 (pinned versions).
#
# Everything lands inside e2e/.venv (Python) and e2e/.tools (Node, Appium, drivers) —
# nothing is installed globally. A plain run is idempotent: any step whose pinned
# version is already present is skipped, so a second run installs nothing.
#
# Usage:
#   e2e/tools/setup.sh            install the missing pieces of the pinned toolchain
#   e2e/tools/setup.sh --check    print "<tool> <version> ok" or "<tool> <got> MISMATCH <want>"
#                                 per tool; exit 1 on any mismatch. Installs nothing.
#
# Exit codes: 0 success or all versions match; 1 install failure or version mismatch;
#             2 python3 below the required floor; 64 bad usage.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
E2E_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
VENV_DIR="${E2E_DIR}/.venv"
TOOLS_DIR="${E2E_DIR}/.tools"
APPIUM_HOME_DIR="${TOOLS_DIR}/appium-home"
APPIUM_BIN="${TOOLS_DIR}/node_modules/.bin/appium"
REQUIREMENTS="${E2E_DIR}/requirements.txt"

readonly PYTHON_FLOOR=3.11
readonly APPIUM_PIN=3.8.0
readonly UIA2_DRIVER_PIN=8.7.0
readonly XCUITEST_DRIVER_PIN=12.19.1
readonly MAC2_DRIVER_PIN=4.5.0

log() { printf 'setup.sh: %s\n' "$*" >&2; }

usage() {
  printf 'usage: %s [--check]\n' "$0" >&2
}

# Print the version of an installed pip distribution from the venv, or nothing.
pip_pkg_version() { # $1: distribution name
  [[ -x "${VENV_DIR}/bin/python" ]] || return 0
  "${VENV_DIR}/bin/python" -c "import importlib.metadata as m; print(m.version('${1}'))" 2>/dev/null || true
}

# Print the pinned version of a package from e2e/requirements.txt, or nothing.
requirements_pin() { # $1: distribution name
  [[ -f "${REQUIREMENTS}" ]] || return 0
  sed -n "s/^${1}==\(.*\)\$/\1/p" "${REQUIREMENTS}" | head -n 1
}

# Print the version of the appium CLI, or nothing.
appium_version() {
  [[ -x "${APPIUM_BIN}" ]] || return 0
  "${APPIUM_BIN}" --version 2>/dev/null | tr -d '[:space:]' || true
}

# Print the version appium's own extension registry reports for an installed driver,
# or nothing. The registry — not a package.json — is the source of truth: a divergent
# state (registry and package.json apart) reads as the registry's version.
driver_version() { # $1: driver name
  local json
  [[ -x "${APPIUM_BIN}" ]] || return 0
  json="$(APPIUM_HOME="${APPIUM_HOME_DIR}" "${APPIUM_BIN}" driver list --installed --json 2>/dev/null || true)"
  [[ -n "${json}" ]] || return 0
  node -e "const d=JSON.parse(process.argv[1])['${1}']; if (d && d.installed) console.log(d.version)" "${json}" 2>/dev/null || true
}

# True when $1 (X.Y) is at or above $2 (X.Y). Pure bash: no sort -V on macOS BSD tools.
version_ge() { # $1: have, $2: floor; tolerates trailing patch components
  local have_major have_minor floor_major floor_minor _
  IFS=. read -r have_major have_minor _ <<<"$1"
  IFS=. read -r floor_major floor_minor _ <<<"$2"
  ((have_major > floor_major || (have_major == floor_major && have_minor >= floor_minor)))
}

require_python3() {
  local have
  have="$(python3 -c 'import sys; print("{}.{}".format(*sys.version_info[:2]))')"
  if ! version_ge "${have}" "${PYTHON_FLOOR}"; then
    log "python3 ${have} is below ${PYTHON_FLOOR}; install a newer python3"
    exit 2
  fi
}

require_commands() {
  local cmd
  for cmd in python3 node npm; do
    if ! command -v "${cmd}" &>/dev/null; then
      log "${cmd} not found in PATH"
      exit 1
    fi
  done
}

setup_venv() {
  if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
    log "creating ${VENV_DIR}"
    python3 -m venv "${VENV_DIR}"
  fi
  "${VENV_DIR}/bin/python" -m pip install --disable-pip-version-check -r "${REQUIREMENTS}"
}

setup_npm() {
  if [[ "$(appium_version)" == "${APPIUM_PIN}" ]]; then
    log "appium ${APPIUM_PIN} already installed; skipping npm ci"
    return 0
  fi
  npm ci --prefix "${TOOLS_DIR}"
}

install_driver() { # $1: driver name, $2: npm package, $3: pinned version
  local installed
  installed="$(driver_version "$1")"
  if [[ "${installed}" == "$3" ]]; then
    log "driver $1 $3 already installed"
    return 0
  fi
  [[ -n "${installed}" ]] || { install_one_driver "$1" "$2" "$3"; return; }
  # A different version is registered: `driver install` would refuse, so remove it first.
  log "driver $1 ${installed} present; replacing with $3"
  APPIUM_HOME="${APPIUM_HOME_DIR}" "${APPIUM_BIN}" driver uninstall "$1"
  install_one_driver "$1" "$2" "$3"
}

install_one_driver() { # $1: driver name, $2: npm package, $3: pinned version
  APPIUM_HOME="${APPIUM_HOME_DIR}" "${APPIUM_BIN}" driver install --source npm "$2@$3"
}

setup_drivers() {
  install_driver uiautomator2 appium-uiautomator2-driver "${UIA2_DRIVER_PIN}"
  install_driver xcuitest appium-xcuitest-driver "${XCUITEST_DRIVER_PIN}"
  install_driver mac2 appium-mac2-driver "${MAC2_DRIVER_PIN}"
}

run_setup() {
  require_commands
  require_python3
  setup_venv
  setup_npm
  setup_drivers
  log "toolchain ready (appium ${APPIUM_PIN}, uiautomator2 ${UIA2_DRIVER_PIN}," \
    "xcuitest ${XCUITEST_DRIVER_PIN}, mac2 ${MAC2_DRIVER_PIN}," \
    "playwright $(requirements_pin playwright))"
}

CHECK_FAILED=0

check_tool() { # $1: label, $2: installed version, $3: wanted version
  if [[ "$2" == "$3" && -n "$3" ]]; then
    printf '%s %s ok\n' "$1" "$2"
  else
    printf '%s %s MISMATCH %s\n' "$1" "${2:-missing}" "${3:-unpinned}"
    CHECK_FAILED=1
  fi
}

run_check() {
  local pytest_pin client_pin playwright_pin
  pytest_pin="$(requirements_pin pytest)"
  client_pin="$(requirements_pin Appium-Python-Client)"
  playwright_pin="$(requirements_pin playwright)"
  check_tool appium "$(appium_version)" "${APPIUM_PIN}"
  check_tool uiautomator2 "$(driver_version uiautomator2)" "${UIA2_DRIVER_PIN}"
  check_tool xcuitest "$(driver_version xcuitest)" "${XCUITEST_DRIVER_PIN}"
  check_tool mac2 "$(driver_version mac2)" "${MAC2_DRIVER_PIN}"
  check_tool Appium-Python-Client "$(pip_pkg_version Appium-Python-Client)" "${client_pin}"
  check_tool pytest "$(pip_pkg_version pytest)" "${pytest_pin}"
  check_tool playwright "$(pip_pkg_version playwright)" "${playwright_pin}"
  exit "${CHECK_FAILED}"
}

main() {
  case "${1:-}" in
    --check) run_check ;;
    "") run_setup ;;
    *)
      usage
      exit 64
      ;;
  esac
}

main "$@"
