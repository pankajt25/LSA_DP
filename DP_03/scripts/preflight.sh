#!/usr/bin/env bash
# ==============================================================================
# Script Name   : preflight.sh
# Description   : Phase 0 - Environment, Kernel Quota Support & Tooling Validation
# Project       : Department File Server (DP_03)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_section "Phase 0: Preflight Environment & Kernel Quota Validation"

PREFLIGHT_LOG="${LOGS_DIR}/preflight.log"
{
    echo "================================================================================"
    echo "Phase 0 Preflight Audit Execution: $(get_iso_timestamp)"
    echo "================================================================================"
} > "${PREFLIGHT_LOG}"

# 1. Kernel Version Audit
KERNEL_VERSION="$(uname -r)"
log_info "Kernel Release: ${KERNEL_VERSION}"
echo "Kernel Release: ${KERNEL_VERSION}" >> "${PREFLIGHT_LOG}"

# 2. Check Sudo Administrative Privilege
log_info "Checking passwordless/cached administrative sudo access..."
if sudo -n true 2>/dev/null || sudo true; then
    log_success "Sudo access verified."
    echo "Sudo Access: PASS" >> "${PREFLIGHT_LOG}"
else
    log_error "Administrative sudo access failed."
    echo "Sudo Access: FAIL" >> "${PREFLIGHT_LOG}"
    exit 1
fi

# 3. Check Admin Packages: acl and quota
log_info "Validating installed packages (acl, quota)..."
for pkg in acl quota; do
    if dpkg -s "${pkg}" >/dev/null 2>&1; then
        pkg_ver="$(dpkg -s "${pkg}" | grep "^Version:" | awk '{print $2}')"
        log_success "Package '${pkg}' is installed (Version: ${pkg_ver})."
        echo "Package ${pkg}: INSTALLED (${pkg_ver})" >> "${PREFLIGHT_LOG}"
    else
        log_warn "Package '${pkg}' is NOT installed. Attempting installation..."
        sudo apt-get update -qq
        sudo apt-get install -y "${pkg}"
        log_success "Package '${pkg}' installed successfully."
        echo "Package ${pkg}: INSTALLED_BY_PREFLIGHT" >> "${PREFLIGHT_LOG}"
    fi
done

# Check if any daemon service was started by quota and ensure none is running
RUNNING_QUOTA_SERVICES="$(systemctl list-units --type=service --state=running 2>/dev/null | grep -E "quota|rpc" || true)"
if [[ -n "${RUNNING_QUOTA_SERVICES}" ]]; then
    log_warn "Quota-related service detected running. Sandboxing policy mandates stopping background services:"
    echo "${RUNNING_QUOTA_SERVICES}"
    sudo systemctl stop quota 2>/dev/null || true
fi

# Verify Essential Command Binaries
log_info "Verifying presence of essential administrative binaries..."
MISSING_TOOLS=0
for tool in setquota quotacheck quotaon quotaoff repquota quota getfacl setfacl losetup mkfs.ext4 tune2fs findmnt; do
    if command -v "${tool}" >/dev/null 2>&1; then
        tool_path="$(command -v "${tool}")"
        echo "Tool ${tool}: AVAILABLE at ${tool_path}" >> "${PREFLIGHT_LOG}"
    else
        log_error "Missing required tool: ${tool}"
        echo "Tool ${tool}: MISSING" >> "${PREFLIGHT_LOG}"
        MISSING_TOOLS=1
    fi
done

if [[ "${MISSING_TOOLS}" -ne 0 ]]; then
    log_error "One or more required administrative binaries are missing."
    exit 1
fi
log_success "All administrative binaries verified."

# 4. Kernel Quota Subsystem Check
log_info "Inspecting Linux kernel quota subsystem..."
KERNEL_QUOTA_SUPPORT=0

if [[ -d "/proc/sys/fs/quota" ]]; then
    log_success "Kernel quota interface detected in /proc/sys/fs/quota."
    ls -la /proc/sys/fs/quota >> "${PREFLIGHT_LOG}"
    KERNEL_QUOTA_SUPPORT=1
else
    log_warn "/proc/sys/fs/quota not found."
fi

if grep -qE "(ext4|xfs)" /proc/filesystems; then
    log_success "Supported filesystem drivers present in /proc/filesystems."
    grep -E "(ext4|xfs)" /proc/filesystems >> "${PREFLIGHT_LOG}"
else
    log_error "ext4 filesystem driver not found in /proc/filesystems!"
    exit 1
fi

# 5. Check Loopback Block Device Availability
log_info "Checking loopback block device subsystem..."
NEXT_LOOP="$(sudo losetup -f 2>/dev/null || true)"
if [[ -n "${NEXT_LOOP}" ]]; then
    log_success "Loopback subsystem available. Next available device: ${NEXT_LOOP}"
    echo "Loopback Subsystem: AVAILABLE (${NEXT_LOOP})" >> "${PREFLIGHT_LOG}"
else
    log_error "No loop devices available in /dev/."
    exit 1
fi

# 6. Mode Decision: Native Quota vs Fallback
QUOTA_MODE_FILE="${SANDBOX_DIR}/quota_mode.env"
if [[ "${KERNEL_QUOTA_SUPPORT}" -eq 1 ]]; then
    QUOTA_MODE="native"
    log_success "Preflight Decision: NATIVE QUOTA MODE selected."
else
    QUOTA_MODE="fallback"
    log_warn "Preflight Decision: FALLBACK MODE selected (Kernel quota missing)."
fi

echo "QUOTA_MODE=${QUOTA_MODE}" > "${QUOTA_MODE_FILE}"
echo "Decision: QUOTA_MODE=${QUOTA_MODE}" >> "${PREFLIGHT_LOG}"

log_success "Phase 0 Preflight completed successfully. Quota Mode: [${QUOTA_MODE}]."
