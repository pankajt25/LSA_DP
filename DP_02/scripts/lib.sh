#!/usr/bin/env bash
# ==============================================================================
# Script Name   : lib.sh
# Description   : Common Utility Library, Path Guards, and Logging Framework
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

# Enable strict mode: exit immediately on error, uninitialized variables, or pipe failure
set -euo pipefail

# ANSI Color Codes for enhanced terminal reporting
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_BOLD='\033[1m'
readonly COLOR_RESET='\033[0m'

# Canonical Path Definitions
# Resolve all paths relative to DP_02 directory root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly PROJECT_ROOT
readonly SANDBOX_DIR="${PROJECT_ROOT}/sandbox_data"
readonly SOURCE_DIR="${SANDBOX_DIR}/source"
readonly REPO_MOUNT="${SANDBOX_DIR}/repo_mount"
readonly REPO_DIR="${SANDBOX_DIR}/repo"
readonly RESTORE_DIR="${SANDBOX_DIR}/restore_target"
readonly LOGS_DIR="${PROJECT_ROOT}/logs"
readonly BACKUP_LOG="${LOGS_DIR}/backup.log"
readonly CRON_LOG="${LOGS_DIR}/cron.log"
readonly RECOVERY_LOG="${LOGS_DIR}/recovery.log"
readonly DISK_IMG="${SANDBOX_DIR}/backup_disk.img"
readonly META_DIR="${REPO_DIR}/.meta"
readonly ACTIVE_SNAR="${META_DIR}/active.snar"

# Ensure base log directory exists
mkdir -p "${LOGS_DIR}"

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
    echo "[${timestamp}] [INFO] ${message}" >> "${BACKUP_LOG}"
}

log_success() {
    local message="$1"
    local timestamp
    timestamp="$(get_iso_timestamp)"
    echo -e "${COLOR_GREEN}[${timestamp}] [SUCCESS]${COLOR_RESET} ${message}"
    echo "[${timestamp}] [SUCCESS] ${message}" >> "${BACKUP_LOG}"
}

log_warn() {
    local message="$1"
    local timestamp
    timestamp="$(get_iso_timestamp)"
    echo -e "${COLOR_YELLOW}[${timestamp}] [WARN]${COLOR_RESET} ${message}"
    echo "[${timestamp}] [WARN] ${message}" >> "${BACKUP_LOG}"
}

log_error() {
    local message="$1"
    local timestamp
    timestamp="$(get_iso_timestamp)"
    echo -e "${COLOR_RED}[${timestamp}] [ERROR]${COLOR_RESET} ${message}" >&2
    echo "[${timestamp}] [ERROR] ${message}" >> "${BACKUP_LOG}"
}

# ------------------------------------------------------------------------------
# Security Path Guard (Mandatory Sandbox Isolation)
# Prevents any modification, deletion, or backup outside DP_02/sandbox_data/
# ------------------------------------------------------------------------------
assert_sandbox_path() {
    local target_path="${1:-}"

    if [[ -z "${target_path}" ]]; then
        log_error "Path guard violation: Target path variable is empty."
        exit 1
    fi

    # Canonicalize both target path and sandbox root path
    local resolved_target
    resolved_target="$(realpath -m "${target_path}")"
    local resolved_sandbox
    resolved_sandbox="$(realpath -m "${SANDBOX_DIR}")"

    # Strict prefix comparison: path must start with sandbox root
    if [[ "${resolved_target}" != "${resolved_sandbox}"* ]]; then
        log_error "SECURITY ALERT: Path Guard Violation!"
        log_error "Target '${resolved_target}' is outside sandbox '${resolved_sandbox}'"
        log_error "Operation terminated immediately to protect host system."
        exit 1
    fi
}

# Safe deletion function that runs the path guard before any rm operation
safe_rm_rf() {
    local target="${1:-}"
    assert_sandbox_path "${target}"

    local resolved_target
    resolved_target="$(realpath -m "${target}")"
    local resolved_sandbox
    resolved_sandbox="$(realpath -m "${SANDBOX_DIR}")"

    # Never delete the sandbox root directory itself or root filesystem
    if [[ "${resolved_target}" == "${resolved_sandbox}" || "${resolved_target}" == "/" ]]; then
        log_error "Refusing to delete entire sandbox directory: ${resolved_target}"
        exit 1
    fi

    if [[ -e "${resolved_target}" || -L "${resolved_target}" ]]; then
        rm -rf "${resolved_target}"
    fi
}

# ------------------------------------------------------------------------------
# Storage and Capacity Validation Helpers
# ------------------------------------------------------------------------------
check_repo_space() {
    local min_kb="${1:-20480}" # Default minimum: 20 MB free
    local repo_target="${REPO_DIR}"

    if [[ ! -d "${repo_target}" ]]; then
        log_error "Repository directory does not exist: ${repo_target}"
        return 1
    fi

    # Available KB from df output
    local available_kb
    available_kb="$(df -k "${repo_target}" | awk 'NR==2 {print $4}')"

    if [[ "${available_kb}" -lt "${min_kb}" ]]; then
        log_error "Insufficient disk space in repository: ${available_kb} KB available (minimum ${min_kb} KB required)."
        return 1
    fi

    log_info "Repository storage check: ${available_kb} KB free space available (threshold: ${min_kb} KB)."
    return 0
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
