#!/usr/bin/env bash
# ==============================================================================
# Script Name   : lib.sh
# Description   : Common Utility Library, Path Guards, Logging & Constants
# Project       : Department File Server (DP_03)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

# ANSI Color Codes
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
readonly MNT_BASE="${SANDBOX_DIR}/mnt"
readonly MNT_FILESERVER="${MNT_BASE}/fileserver"
readonly IMG_FILE="${SANDBOX_DIR}/fileserver.img"
readonly FSTAB_DEMO="${SANDBOX_DIR}/fstab.demo"
readonly LOGS_DIR="${PROJECT_ROOT}/logs"
readonly MAIN_LOG="${LOGS_DIR}/fileserver.log"
readonly TEST_LOG="${LOGS_DIR}/test_execution.log"
readonly TEST_REPORT_MD="${PROJECT_ROOT}/docs/testing-report.md"
readonly TEST_RESULTS_JSON="${LOGS_DIR}/test_results.json"

# Department Directory Paths (under fileserver mount)
readonly DIR_FINANCE="${MNT_FILESERVER}/finance"
readonly DIR_HR="${MNT_FILESERVER}/hr"
readonly DIR_ENG="${MNT_FILESERVER}/eng"
readonly DIR_SALES="${MNT_FILESERVER}/sales"

# Identity Configuration (lsatest_ namespace)
readonly GRP_FINANCE="lsatest_grp_finance"
readonly GRP_HR="lsatest_grp_hr"
readonly GRP_ENG="lsatest_grp_eng"
readonly GRP_SALES="lsatest_grp_sales"
readonly GRP_AUDIT="lsatest_grp_audit"

readonly ALL_GROUPS=(
    "${GRP_FINANCE}"
    "${GRP_HR}"
    "${GRP_ENG}"
    "${GRP_SALES}"
    "${GRP_AUDIT}"
)

# Department Users (2 per dept + 1 auditor)
readonly USERS_FINANCE=("lsatest_fin_alice" "lsatest_fin_bob")
readonly USERS_HR=("lsatest_hr_carol" "lsatest_hr_dave")
readonly USERS_ENG=("lsatest_eng_eve" "lsatest_eng_frank")
readonly USERS_SALES=("lsatest_sales_grace" "lsatest_sales_heidi")
readonly USERS_AUDIT=("lsatest_aud_ivan")

readonly ALL_USERS=(
    "${USERS_FINANCE[@]}"
    "${USERS_HR[@]}"
    "${USERS_ENG[@]}"
    "${USERS_SALES[@]}"
    "${USERS_AUDIT[@]}"
)

# Quota Limits (in 1-KiB blocks: 1M = 1024 KiB)
# Finance: Group 200M/250M, User 90M/110M
readonly QUOTA_GRP_FIN_SOFT=204800
readonly QUOTA_GRP_FIN_HARD=256000
readonly QUOTA_USR_FIN_SOFT=92160
readonly QUOTA_USR_FIN_HARD=112640

# HR: Group 100M/120M, User 50M/60M
readonly QUOTA_GRP_HR_SOFT=102400
readonly QUOTA_GRP_HR_HARD=122880
readonly QUOTA_USR_HR_SOFT=51200
readonly QUOTA_USR_HR_HARD=61440

# Engineering: Group 400M/500M, User 150M/200M
readonly QUOTA_GRP_ENG_SOFT=409600
readonly QUOTA_GRP_ENG_HARD=512000
readonly QUOTA_USR_ENG_SOFT=153600
readonly QUOTA_USR_ENG_HARD=204800

# Sales: Group 100M/120M, User 50M/60M
readonly QUOTA_GRP_SALES_SOFT=102400
readonly QUOTA_GRP_SALES_HARD=122880
readonly QUOTA_USR_SALES_SOFT=51200
readonly QUOTA_USR_SALES_HARD=61440

# Inode limits (0 = unlimited inodes, focusing on block limits per scenario)
readonly QUOTA_INODE_SOFT=0
readonly QUOTA_INODE_HARD=0

# Ensure log and base sandbox directories exist
mkdir -p "${LOGS_DIR}" "${SANDBOX_DIR}" "${MNT_BASE}"

# ------------------------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------------------------
get_iso_timestamp() {
    date +'%Y-%m-%d %H:%M:%S'
}

log_info() {
    local msg="$1"
    local ts
    ts="$(get_iso_timestamp)"
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} [${ts}] ${msg}"
    echo "[INFO] [${ts}] ${msg}" >> "${MAIN_LOG}" 2>/dev/null || true
}

log_success() {
    local msg="$1"
    local ts
    ts="$(get_iso_timestamp)"
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} [${ts}] ${msg}"
    echo "[SUCCESS] [${ts}] ${msg}" >> "${MAIN_LOG}" 2>/dev/null || true
}

log_warn() {
    local msg="$1"
    local ts
    ts="$(get_iso_timestamp)"
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} [${ts}] ${msg}"
    echo "[WARN] [${ts}] ${msg}" >> "${MAIN_LOG}" 2>/dev/null || true
}

log_error() {
    local msg="$1"
    local ts
    ts="$(get_iso_timestamp)"
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} [${ts}] ${msg}" >&2
    echo "[ERROR] [${ts}] ${msg}" >> "${MAIN_LOG}" 2>/dev/null || true
}

log_section() {
    local title="$1"
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}================================================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  ${title}${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}================================================================================${COLOR_RESET}"
    echo "" >> "${MAIN_LOG}" 2>/dev/null || true
    echo "=== ${title} ===" >> "${MAIN_LOG}" 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# Sandboxing & Safety Guards
# ------------------------------------------------------------------------------

# Path guard: verifies that a path strictly resolves inside SANDBOX_DIR
assert_sandbox_path() {
    local target_path="$1"
    if [[ -z "${target_path}" ]]; then
        log_error "Assertion failed: path is empty!"
        exit 1
    fi

    local real_target
    if [[ -e "${target_path}" ]]; then
        real_target="$(realpath "${target_path}")"
    else
        local parent_dir
        parent_dir="$(dirname "${target_path}")"
        if [[ -d "${parent_dir}" ]]; then
            real_target="$(realpath "${parent_dir}")/$(basename "${target_path}")"
        else
            real_target="${target_path}"
        fi
    fi

    local real_sandbox
    real_sandbox="$(realpath "${SANDBOX_DIR}")"

    if [[ "${real_target}" != "${real_sandbox}"* ]]; then
        log_error "CRITICAL SAFETY VIOLATION: Path '${real_target}' is outside sandbox '${real_sandbox}'!"
        exit 1
    fi
}

# Safe removal guard: only allows removal inside SANDBOX_DIR
safe_rm_rf() {
    local target_path="$1"
    assert_sandbox_path "${target_path}"
    if [[ -e "${target_path}" ]]; then
        rm -rf "${target_path}"
    fi
}

# Verified loop device finder: verifies loop device belongs to our own image
get_verified_loop_device() {
    local image_path="$1"
    assert_sandbox_path "${image_path}"

    if [[ ! -f "${image_path}" ]]; then
        echo ""
        return 0
    fi

    local real_img
    real_img="$(realpath "${image_path}")"

    # Query losetup for associations matching this image
    local matched_device
    matched_device="$(sudo losetup -j "${real_img}" 2>/dev/null | cut -d: -f1 | head -n 1 || true)"

    if [[ -n "${matched_device}" ]]; then
        # Double check with losetup backing file query
        local backing_file
        backing_file="$(sudo losetup -O BACK-FILE -n "${matched_device}" 2>/dev/null | tr -d ' ' || true)"
        if [[ "${backing_file}" == "${real_img}" ]]; then
            echo "${matched_device}"
            return 0
        else
            log_error "Loop device mismatch! ${matched_device} points to ${backing_file}, not ${real_img}"
            exit 1
        fi
    fi

    echo ""
}

# Sudo wrapper announcing intent and validating sandbox boundaries
sudo_sandbox_exec() {
    local desc="$1"
    shift
    log_info "Executing administrative command [Sudo]: ${desc}"
    sudo "$@"
}
