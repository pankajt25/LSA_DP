#!/usr/bin/env bash
# ==============================================================================
# Script Name   : lib.sh
# Description   : Common Utility Library, Path Guards, and Logging Framework
# Project       : Enterprise Storage Infrastructure (DP_01)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

# ANSI Color Codes for enhanced terminal reporting
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_RESET='\033[0m'

# Canonical Path Definitions
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly PROJECT_ROOT
readonly SANDBOX_DIR="${PROJECT_ROOT}/sandbox_data"
readonly DISKS_DIR="${SANDBOX_DIR}/disks"
readonly MNT_DIR="${SANDBOX_DIR}/mnt"
readonly BACKUP_DIR="${SANDBOX_DIR}/backup"
readonly LOGS_DIR="${PROJECT_ROOT}/logs"
readonly MAIN_LOG="${LOGS_DIR}/storage_deploy.log"
readonly VALIDATION_LOG="${LOGS_DIR}/validation.log"
readonly BACKUP_LOG="${LOGS_DIR}/backup.log"
readonly FSTAB_DEMO="${SANDBOX_DIR}/fstab.demo"

# Virtual Disk Image Paths (3 disks: 10G, 15G, 20G sparse)
readonly DISK1_IMG="${DISKS_DIR}/disk1.img"
readonly DISK2_IMG="${DISKS_DIR}/disk2.img"
readonly DISK3_IMG="${DISKS_DIR}/disk3.img"

# Volume Group and Logical Volume Naming Constants
readonly VG_NAME="company_vg"
readonly LV_HR="lv_hr"
readonly LV_FIN="lv_finance"
readonly LV_ENG="lv_eng"
readonly LV_SALES="lv_sales"

# Department Mount Points inside Sandbox
readonly MNT_HR="${MNT_DIR}/hr"
readonly MNT_FIN="${MNT_DIR}/finance"
readonly MNT_ENG="${MNT_DIR}/eng"
readonly MNT_SALES="${MNT_DIR}/sales"

# Ensure base log and sandbox directories exist
mkdir -p "${LOGS_DIR}" "${DISKS_DIR}" "${MNT_DIR}" "${BACKUP_DIR}"

# ------------------------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------------------------
get_iso_timestamp() {
    date +'%Y-%m-%d %H:%M:%S'
}

log_info() {
    local message="$1"
    local timestamp
    timestamp="$(get_iso_timestamp)"
    echo -e "${COLOR_BLUE}[${timestamp}] [INFO]${COLOR_RESET} ${message}"
    echo "[${timestamp}] [INFO] ${message}" >> "${MAIN_LOG}"
}

log_success() {
    local message="$1"
    local timestamp
    timestamp="$(get_iso_timestamp)"
    echo -e "${COLOR_GREEN}[${timestamp}] [SUCCESS]${COLOR_RESET} ${message}"
    echo "[${timestamp}] [SUCCESS] ${message}" >> "${MAIN_LOG}"
}

log_warn() {
    local message="$1"
    local timestamp
    timestamp="$(get_iso_timestamp)"
    echo -e "${COLOR_YELLOW}[${timestamp}] [WARN]${COLOR_RESET} ${message}"
    echo "[${timestamp}] [WARN] ${message}" >> "${MAIN_LOG}"
}

log_error() {
    local message="$1"
    local timestamp
    timestamp="$(get_iso_timestamp)"
    echo -e "${COLOR_RED}[${timestamp}] [ERROR]${COLOR_RESET} ${message}" >&2
    echo "[${timestamp}] [ERROR] ${message}" >> "${MAIN_LOG}"
}

# ------------------------------------------------------------------------------
# Security Path Guard (Mandatory Sandbox Isolation)
# Prevents any modification, deletion, or backup outside DP_01/sandbox_data/
# ------------------------------------------------------------------------------
assert_sandbox_path() {
    local target_path="${1:-}"

    if [[ -z "${target_path}" ]]; then
        log_error "Path guard violation: Target path variable is empty."
        exit 1
    fi

    local resolved_target
    resolved_target="$(realpath -m "${target_path}")"
    local resolved_sandbox
    resolved_sandbox="$(realpath -m "${SANDBOX_DIR}")"

    if [[ "${resolved_target}" != "${resolved_sandbox}"* ]]; then
        log_error "SECURITY ALERT: Path Guard Violation!"
        log_error "Target '${resolved_target}' is outside sandbox '${resolved_sandbox}'"
        log_error "Operation terminated immediately to protect host system."
        exit 1
    fi
}

safe_rm_rf() {
    local target="${1:-}"
    assert_sandbox_path "${target}"

    local resolved_target
    resolved_target="$(realpath -m "${target}")"
    local resolved_sandbox
    resolved_sandbox="$(realpath -m "${SANDBOX_DIR}")"

    if [[ "${resolved_target}" == "${resolved_sandbox}" || "${resolved_target}" == "/" ]]; then
        log_error "Refusing to delete entire sandbox directory: ${resolved_target}"
        exit 1
    fi

    if [[ -e "${resolved_target}" || -L "${resolved_target}" ]]; then
        rm -rf "${resolved_target}"
    fi
}

# Format byte counts into human-readable representation
format_bytes() {
    local bytes="$1"
    if [[ "${bytes}" -lt 1024 ]]; then
        echo "${bytes} B"
    elif [[ "${bytes}" -lt 1048576 ]]; then
        awk "BEGIN {printf \"%.2f KB\", ${bytes}/1024}"
    elif [[ "${bytes}" -lt 1073741824 ]]; then
        awk "BEGIN {printf \"%.2f MB\", ${bytes}/1048576}"
    else
        awk "BEGIN {printf \"%.2f GB\", ${bytes}/1073741824}"
    fi
}
