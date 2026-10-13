#!/usr/bin/env bash
# ==============================================================================
# Script Name   : storage_setup.sh
# Description   : Phase 0 - Dedicated Storage Volume Setup using Loopback & LVM
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_info "======================================================================"
log_info "Phase 0: Initializing Dedicated Backup Storage Infrastructure"
log_info "======================================================================"

DEMO_LVM="${1:-}"

# Check path guard on image location
assert_sandbox_path "${DISK_IMG}"
assert_sandbox_path "${REPO_MOUNT}"
assert_sandbox_path "${REPO_DIR}"

# Step 1: Create a 1 GB sparse disk image inside sandbox
log_info "[Step 1/4] Creating 1 GiB sparse image file: ${DISK_IMG}"
truncate -s 1G "${DISK_IMG}"
log_success "Sparse image created: $(ls -lh "${DISK_IMG}" | awk '{print $5, $9}')"

# Step 2: Check sudo privilege and attach loop device
if ! sudo -n true 2>/dev/null; then
    log_warn "Sudo privileges not detected. Falling back to directory-based repository."
    mkdir -p "${REPO_DIR}"
    log_info "Fallback initialized: Repository directory active at ${REPO_DIR}"
    exit 0
fi

log_info "[Step 2/4] Attaching loopback device to ${DISK_IMG}..."
LOOP_DEV="$(sudo losetup -f --show "${DISK_IMG}")"
log_info "Allocated loop device: ${LOOP_DEV}"

# Mandatory verification: Ensure allocated device maps strictly to our project image
log_info "Verifying device-to-file mapping via losetup -j..."
MATCHED_DEV="$(losetup -j "${DISK_IMG}" | cut -d':' -f1)"

if [[ "${LOOP_DEV}" != "${MATCHED_DEV}" ]]; then
    log_error "SECURITY VERIFICATION FAILED!"
    log_error "Assigned device (${LOOP_DEV}) does not match losetup lookup (${MATCHED_DEV})."
    sudo losetup -d "${LOOP_DEV}" 2>/dev/null || true
    exit 1
fi
log_success "Device verification PASSED: ${LOOP_DEV} safely mapped to ${DISK_IMG}"

# Optional LVM Stretch Demonstration
if [[ "${DEMO_LVM}" == "--demo-lvm" ]]; then
    log_info "------------------------------------------------------------------"
    log_info "Running Optional Stretch: LVM Physical Volume & Elastic Volume Demo"
    log_info "------------------------------------------------------------------"
    log_info "Initializing Physical Volume (PV) on ${LOOP_DEV}..."
    sudo pvcreate -f "${LOOP_DEV}"
    
    log_info "Creating Volume Group 'backup_vg'..."
    sudo vgcreate -f backup_vg "${LOOP_DEV}"
    
    log_info "Creating Logical Volume 'backup_lv' (Initial size: 500M)..."
    sudo lvcreate -L 500M -n backup_lv backup_vg
    
    log_info "Formatting /dev/backup_vg/backup_lv with ext4..."
    sudo mkfs.ext4 -F /dev/backup_vg/backup_lv
    
    mkdir -p "${REPO_MOUNT}"
    sudo mount /dev/backup_vg/backup_lv "${REPO_MOUNT}"
    log_success "Mounted initial LVM volume at ${REPO_MOUNT}:"
    df -h "${REPO_MOUNT}"
    
    log_info "Demonstrating Online LVM Elastic Expansion (+300M)..."
    sudo lvextend -L +300M /dev/backup_vg/backup_lv
    sudo resize2fs /dev/backup_vg/backup_lv
    log_success "Online expansion complete. Updated filesystem capacity:"
    df -h "${REPO_MOUNT}"
    sudo lvs backup_vg
    
    log_info "Cleaning up LVM stretch demo to return to standard loop ext4 structure..."
    sudo umount "${REPO_MOUNT}"
    sudo lvremove -f /dev/backup_vg/backup_lv
    sudo vgremove -f backup_vg
    sudo pvremove -f "${LOOP_DEV}"
    log_success "LVM Stretch Demonstration concluded successfully."
fi

# Step 3: Format ext4 filesystem on verified loop device
log_info "[Step 3/4] Formatting ext4 filesystem on verified device ${LOOP_DEV}..."
sudo mkfs.ext4 -F -L "NOVA_BACKUP" "${LOOP_DEV}"
log_success "ext4 filesystem initialized on ${LOOP_DEV}"

# Step 4: Mount filesystem at sandbox_data/repo_mount/
log_info "[Step 4/4] Mounting ${LOOP_DEV} at ${REPO_MOUNT}..."
mkdir -p "${REPO_MOUNT}"
sudo mount "${LOOP_DEV}" "${REPO_MOUNT}"

# Set permissions so the active user can write to the mounted volume
sudo chown -R "$(id -u):$(id -g)" "${REPO_MOUNT}"
sudo chmod 775 "${REPO_MOUNT}"

# Initialize repository directory structure inside mount point
mkdir -p "${REPO_MOUNT}/repo/.meta"

# If repo directory already existed as a regular directory outside mount, handle safely
if [[ -d "${REPO_DIR}" && ! -L "${REPO_DIR}" && "${REPO_DIR}" != "${REPO_MOUNT}/repo" ]]; then
    if [[ "$(ls -A "${REPO_DIR}")" ]]; then
        cp -a "${REPO_DIR}"/* "${REPO_MOUNT}/repo/" 2>/dev/null || true
    fi
    rm -rf "${REPO_DIR}"
fi

# Link sandbox_data/repo -> sandbox_data/repo_mount/repo
ln -sfn "${REPO_MOUNT}/repo" "${REPO_DIR}"
log_success "Repository successfully mounted and linked: ${REPO_DIR} -> ${REPO_MOUNT}/repo"

# Print block device evidence for storage verification
echo ""
log_info "======================================================================"
log_info "Phase 0 Verification Evidence (Storage Implementation)"
log_info "======================================================================"
lsblk "${LOOP_DEV}"
echo ""
df -h "${REPO_MOUNT}"
echo ""
sudo blkid "${LOOP_DEV}"
log_info "======================================================================"
log_success "Phase 0 Storage Volume Setup Completed Successfully."
