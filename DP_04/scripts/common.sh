#!/usr/bin/env bash
# ==============================================================================
# Linux Disaster Recovery Solution (DP_04) — Common Environment & Safety Guards
# Course: Linux System Administration (E1ITA307)
# Module: IV | CO4
# ==============================================================================

set -euo pipefail

# Project root and canonical path resolution
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd "${COMMON_DIR}/.." && pwd -P)"
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
SANDBOX_DATA="${PROJECT_ROOT}/sandbox_data"
MNT_DATA="${SANDBOX_DATA}/mnt/data"
MNT_SNAP="${SANDBOX_DATA}/mnt/snap"
ARCHIVE_STORE="${SANDBOX_DATA}/archive_store"
LOGS_DIR="${PROJECT_ROOT}/logs"
DOCS_DIR="${PROJECT_ROOT}/docs"
LOG_FILE="${LOGS_DIR}/dr_solution.log"

# Fixed LVM object naming conventions
VG_NAME="lsatest_dr_vg"
LV_ORIGIN="lsatest_data_lv"
ORIGIN_DEV="/dev/${VG_NAME}/${LV_ORIGIN}"

# Color codes for standard output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

mkdir -p "${LOGS_DIR}" "${ARCHIVE_STORE}" "${MNT_DATA}" "${MNT_SNAP}"

log_msg() {
    local level="$1"
    local color="$2"
    shift 2
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${color}[${timestamp}] [${level}]${NC} ${message}"
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

log_info() {
    log_msg "INFO" "${CYAN}" "$@"
}

log_success() {
    log_msg "SUCCESS" "${GREEN}" "$@"
}

log_warn() {
    log_msg "WARN" "${YELLOW}" "$@"
}

log_error() {
    log_msg "ERROR" "${RED}" "$@"
}

# ------------------------------------------------------------------------------
# Sandboxing & Path Guard Implementation
# ------------------------------------------------------------------------------
guard_sandbox_path() {
    local raw_path="$1"
    if [[ -z "${raw_path}" ]]; then
        log_error "Path guard failure: target path is empty."
        exit 1
    fi

    local canonical_path
    canonical_path="$(realpath -m "${raw_path}")"
    local canonical_sandbox
    canonical_sandbox="$(realpath -m "${SANDBOX_DATA}")"

    if [[ "${canonical_path}" != "${canonical_sandbox}"* ]]; then
        log_error "SECURITY VIOLATION: Path '${canonical_path}' is outside sandbox '${canonical_sandbox}'. Aborting."
        exit 1
    fi
}

# Wrapper for privileged operations: states touched target and confirms sandbox containment
sudo_run() {
    local reason="$1"
    shift
    log_info "SUDO EXECUTION [Target Sandbox]: ${reason}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUDO_CMD] ${reason} -> $*" >> "${LOG_FILE}"
    sudo "$@"
}

# Safe LV removal guard: strictly prohibits wildcards, requires explicit name starting with lsatest_
safe_lvremove() {
    local lv_target="$1"
    if [[ -z "${lv_target}" ]]; then
        log_error "safe_lvremove: target name is empty."
        exit 1
    fi

    # Strip /dev/lsatest_dr_vg/ prefix if provided
    local lv_base
    lv_base="$(basename "${lv_target}")"

    if [[ "${lv_base}" != lsatest_* ]]; then
        log_error "SECURITY VIOLATION: LV '${lv_base}' does not start with required prefix 'lsatest_'. Aborting."
        exit 1
    fi

    if [[ "${lv_base}" =~ [*?\[\]] ]]; then
        log_error "SECURITY VIOLATION: Wildcard detected in LV name '${lv_base}'. Wildcards strictly prohibited."
        exit 1
    fi

    log_info "Removing Logical Volume: /dev/${VG_NAME}/${lv_base}"
    sudo_run "Remove Logical Volume /dev/${VG_NAME}/${lv_base}" lvremove -y "/dev/${VG_NAME}/${lv_base}"
}

# Safe VG removal guard: strictly requires VG_NAME to be lsatest_dr_vg
safe_vgremove() {
    local vg_target="$1"
    if [[ "${vg_target}" != "lsatest_dr_vg" ]]; then
        log_error "SECURITY VIOLATION: VG '${vg_target}' is not 'lsatest_dr_vg'. Refusing removal."
        exit 1
    fi
    log_info "Removing Volume Group: ${vg_target}"
    sudo_run "Remove Volume Group ${vg_target}" vgremove -y "${vg_target}"
}

# Safe PV removal guard: verifies loop backing image before removal
safe_pvremove() {
    local pv_dev="$1"
    if [[ -z "${pv_dev}" ]]; then
        log_error "safe_pvremove: device path is empty."
        exit 1
    fi

    # Verify that the loop device is backed by DP_04/sandbox_data/
    local backing_file
    backing_file="$(sudo losetup "${pv_dev}" 2>/dev/null || true)"
    if [[ "${backing_file}" != *"${SANDBOX_DATA}"* ]]; then
        log_error "SECURITY VIOLATION: Device '${pv_dev}' is NOT backed by DP_04 sandbox disk images. Refusing pvremove."
        exit 1
    fi

    log_info "Removing Physical Volume on verified loop device: ${pv_dev}"
    sudo_run "Remove PV on ${pv_dev}" pvremove -y "${pv_dev}"
}
