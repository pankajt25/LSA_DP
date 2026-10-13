#!/usr/bin/env bash
# ==============================================================================
# Script Name   : cleanup.sh
# Description   : Controlled Teardown & Environment Sanitization Script
# Project       : Department File Server (DP_03)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

cd "$(dirname "$0")"
PROJECT_DIR="$(pwd -P)"

# shellcheck source=scripts/lib.sh
source "${PROJECT_DIR}/scripts/lib.sh"

log_section "Teardown & Environment Sanitization"

if sudo -n true 2>/dev/null; then
    log_info "Administrative sudo credentials verified."
else
    log_info "Verifying administrative sudo credentials..."
    sudo -v
fi

# Step 1: Turn off filesystem quotas
if mountpoint -q "${MNT_FILESERVER}" 2>/dev/null; then
    log_info "Disabling active filesystem quotas on ${MNT_FILESERVER}..."
    sudo quotaoff -u -g "${MNT_FILESERVER}" 2>/dev/null || true
    log_success "Quota subsystem deactivated."
fi

# Step 2: Unmount Filesystem
if mountpoint -q "${MNT_FILESERVER}" 2>/dev/null; then
    log_info "Unmounting ${MNT_FILESERVER}..."
    sudo umount "${MNT_FILESERVER}" 2>/dev/null || sudo umount -l "${MNT_FILESERVER}" 2>/dev/null || true
    log_success "Filesystem unmounted successfully."
else
    log_info "Mountpoint ${MNT_FILESERVER} is not currently mounted."
fi

# Step 3: Verified Loop Device Detachment
# Mandatory Sandboxing Assertion: Detach ONLY after losetup -j confirms backing image
LOOP_DEV="$(get_verified_loop_device "${IMG_FILE}")"
if [[ -n "${LOOP_DEV}" ]]; then
    log_info "Detaching verified loop device: ${LOOP_DEV}..."
    sudo losetup -d "${LOOP_DEV}"
    log_success "Loop device ${LOOP_DEV} detached."
else
    log_info "No active loop devices associated with ${IMG_FILE}."
fi

# Step 4: Remove Sandbox Runtime Files & Disk Images
log_info "Cleaning sandbox disk images and persistence manifests..."
if [[ -f "${IMG_FILE}" ]]; then
    safe_rm_rf "${IMG_FILE}"
    log_success "Removed disk image: ${IMG_FILE}"
fi

if [[ -f "${FSTAB_DEMO}" ]]; then
    safe_rm_rf "${FSTAB_DEMO}"
    log_success "Removed demo persistence manifest: ${FSTAB_DEMO}"
fi

if [[ -f "${SANDBOX_DIR}/quota_mode.env" ]]; then
    safe_rm_rf "${SANDBOX_DIR}/quota_mode.env"
fi

# Remove mount directory inside sandbox if empty
if [[ -d "${MNT_FILESERVER}" ]]; then
    sudo rm -rf "${MNT_FILESERVER}" 2>/dev/null || true
fi

# Step 5: Remove lsatest_ Test Users
log_info "Removing provisioned test users (lsatest_ namespace)..."
for usr in "${ALL_USERS[@]}"; do
    if id "${usr}" >/dev/null 2>&1; then
        sudo userdel -f "${usr}" 2>/dev/null || true
        log_success "Removed user '${usr}'."
    fi
done

# Step 6: Remove lsatest_ Test Groups
log_info "Removing provisioned test groups (lsatest_ namespace)..."
for grp in "${ALL_GROUPS[@]}"; do
    if getent group "${grp}" >/dev/null 2>&1; then
        sudo groupdel "${grp}" 2>/dev/null || true
        log_success "Removed group '${grp}'."
    fi
done

# Step 7: Final Sanitation Verification & Evidence
log_section "Teardown Verification Audit"

echo "=== 1. Active Mounts Check (mount | grep DP_03) ==="
if mount | grep "DP_03"; then
    log_warn "Active mounts still detected!"
else
    log_success "Zero active DP_03 mounts found."
fi

echo ""
echo "=== 2. Active Loop Devices Check (losetup -a) ==="
sudo losetup -a || true

echo ""
echo "=== 3. Block Device Hierarchy (lsblk) ==="
lsblk || true

echo ""
echo "=== 4. Test Accounts Check (getent passwd | grep lsatest_) ==="
if getent passwd | grep "lsatest_"; then
    log_warn "Lingering lsatest_ users detected!"
else
    log_success "Zero lsatest_ users detected (clean state)."
fi

echo ""
echo "=== 5. Test Groups Check (getent group | grep lsatest_) ==="
if getent group | grep "lsatest_"; then
    log_warn "Lingering lsatest_ groups detected!"
else
    log_success "Zero lsatest_ groups detected (clean state)."
fi

echo ""
echo "=== 6. Sandbox Directory State (ls -la sandbox_data/) ==="
ls -la "${SANDBOX_DIR}"

log_success "Cleanup complete. Project evidence (scripts, docs, logs, report.html) preserved."
