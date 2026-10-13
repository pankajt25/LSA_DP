#!/usr/bin/env bash
# ==============================================================================
# Phase 0 — Preflight Validation Script
# Project: DP_04 Linux Disaster Recovery Solution
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

echo "=============================================================================="
echo " PHASE 0: PREFLIGHT SYSTEM AND KERNEL VERIFICATION"
echo "=============================================================================="

log_info "Collecting system and kernel specifications..."
KERNEL_VER="$(uname -r)"
OS_DESC="$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"' || uname -s)"
HOSTNAME_SYS="$(hostname)"

echo "  Kernel Release : ${KERNEL_VER}"
echo "  Operating Sys  : ${OS_DESC}"
echo "  System Hostname: ${HOSTNAME_SYS}"

# 1. Verify sudo privileges
log_info "Verifying sudo execution privileges..."
if ! sudo -n true 2>/dev/null; then
    log_warn "Passwordless sudo is not configured; testing interactive sudo credentials..."
    sudo -v || { log_error "Failed to obtain sudo credentials. Aborting."; exit 1; }
fi
log_success "Sudo execution confirmed."

# 2. Verify lvm2 package installation
log_info "Checking lvm2 package status..."
if ! dpkg -s lvm2 >/dev/null 2>&1; then
    log_warn "Package 'lvm2' not installed. Attempting installation as allowed by sandbox policy..."
    sudo_run "Install required lvm2 package" apt-get update -y && sudo_run "Install lvm2" apt-get install -y lvm2
fi
LVM2_VER="$(dpkg -s lvm2 | grep -i '^Version:' | awk '{print $2}')"
log_success "Package lvm2 is installed (Version: ${LVM2_VER})."

# 3. Check loop device functionality
log_info "Checking loop block device subsystem..."
FREE_LOOP="$(sudo losetup -f)"
if [[ -z "${FREE_LOOP}" ]]; then
    log_error "No available loop device found on system. Aborting."
    exit 1
fi
log_success "Loop block device subsystem is operational (next candidate: ${FREE_LOOP})."

# 4. Verify device-mapper targets and snapshot kernel target
log_info "Checking Device Mapper (DM) kernel subsystem and targets..."
if ! command -v dmsetup >/dev/null 2>&1; then
    log_error "'dmsetup' utility not found. Aborting."
    exit 1
fi

# Ensure dm-snapshot module is loaded if targets are missing
if ! sudo dmsetup targets | grep -qw "snapshot"; then
    log_info "Snapshot target not yet in active dmsetup table. Attempting to probe dm-snapshot module..."
    sudo modprobe dm-snapshot 2>&1 || true
fi

DM_TARGETS="$(sudo dmsetup targets)"
echo "Active Device Mapper Targets:"
echo "${DM_TARGETS}" | sed 's/^/  /'

if ! echo "${DM_TARGETS}" | grep -qw "snapshot"; then
    log_error "CRITICAL: Device-mapper snapshot target is NOT available in the running kernel."
    log_error "Kernel snapshot support is mandatory for Phase 2 and Phase 3. Refusing to fake snapshots."
    exit 1
fi
log_success "Device-mapper snapshot target is active and verified."

if ! echo "${DM_TARGETS}" | grep -qw "snapshot-merge"; then
    log_warn "Device-mapper snapshot-merge target not listed; full rollback may be restricted."
else
    log_success "Device-mapper snapshot-merge target is active and verified."
fi

log_info "Listing loaded device-mapper kernel modules:"
DM_MODULES="$(lsmod | grep dm_ || true)"
if [[ -n "${DM_MODULES}" ]]; then
    echo "${DM_MODULES}" | sed 's/^/  /'
else
    log_info "dm drivers compiled built-in into kernel or statically linked."
fi

log_success "Preflight validation completed successfully. All prerequisites satisfied."
exit 0
