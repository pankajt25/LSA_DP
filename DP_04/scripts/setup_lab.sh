#!/usr/bin/env bash
# ==============================================================================
# Phase 1 — Lab Storage Environment Setup
# Project: DP_04 Linux Disaster Recovery Solution
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

echo "=============================================================================="
echo " PHASE 1: PROVISION STORAGE LAB (VIRTUAL DISKS, LVM POOL, ORIGIN FILESYSTEM)"
echo "=============================================================================="

IMAGE1="${SANDBOX_DATA}/disk1.img"
IMAGE2="${SANDBOX_DATA}/disk2.img"
FSTAB_DEMO="${SANDBOX_DATA}/fstab.demo"

guard_sandbox_path "${IMAGE1}"
guard_sandbox_path "${IMAGE2}"
guard_sandbox_path "${FSTAB_DEMO}"
guard_sandbox_path "${MNT_DATA}"
guard_sandbox_path "${MNT_SNAP}"

# 1. Check if lab already exists or needs reset
log_info "Evaluating current storage lab status for idempotent provisioning..."

# Unmount any existing sandbox mounts if mounted
if mountpoint -q "${MNT_SNAP}"; then
    log_info "Unmounting existing snapshot mount at ${MNT_SNAP}..."
    sudo_run "Unmount snapshot" umount "${MNT_SNAP}"
fi

# Clean up leftover snapshots in lsatest_dr_vg if VG exists
if sudo vgs --noheadings -o vg_name "${VG_NAME}" 2>/dev/null | grep -qw "${VG_NAME}"; then
    log_info "Existing Volume Group '${VG_NAME}' detected. Checking for leftover snapshots..."
    LEFT_SNAPS=$(sudo lvs --noheadings -o lv_name "${VG_NAME}" 2>/dev/null | tr -d ' ' | grep '^lsatest_snap_' || true)
    for snap in ${LEFT_SNAPS}; do
        if [[ -n "${snap}" ]]; then
            log_info "Cleaning up leftover snapshot: ${snap}"
            safe_lvremove "${snap}"
        fi
    done
fi

# If origin volume exists and VG exists, ensure it is mounted
if sudo lvs --noheadings -o lv_name "${VG_NAME}" 2>/dev/null | grep -qw "${LV_ORIGIN}"; then
    log_info "Logical volume ${ORIGIN_DEV} already exists."
    if ! mountpoint -q "${MNT_DATA}"; then
        log_info "Mounting ${ORIGIN_DEV} at ${MNT_DATA}..."
        sudo_run "Mount origin volume" mount "${ORIGIN_DEV}" "${MNT_DATA}"
    fi
else
    # Check if VG exists without the LV
    if ! sudo vgs --noheadings -o vg_name "${VG_NAME}" 2>/dev/null | grep -qw "${VG_NAME}"; then
        # Need to create images, loop devices, PVs, and VG
        log_info "Creating two 600 MB sparse disk image files in sandbox_data/..."
        truncate -s 600M "${IMAGE1}"
        truncate -s 600M "${IMAGE2}"
        log_success "Created sparse images: $(ls -lh "${IMAGE1}" "${IMAGE2}" | awk '{print $9, "(" $5 ")"}')"

        # Attach loop devices
        log_info "Attaching loop block devices..."
        # Detach any existing loops referencing these images first
        EXISTING_L1=$(sudo losetup -j "${IMAGE1}" | cut -d: -f1 || true)
        EXISTING_L2=$(sudo losetup -j "${IMAGE2}" | cut -d: -f1 || true)
        if [[ -n "${EXISTING_L1}" ]]; then sudo_run "Detach stale loop" losetup -d "${EXISTING_L1}"; fi
        if [[ -n "${EXISTING_L2}" ]]; then sudo_run "Detach stale loop" losetup -d "${EXISTING_L2}"; fi

        LOOP1=$(sudo losetup -f --show "${IMAGE1}")
        LOOP2=$(sudo losetup -f --show "${IMAGE2}")

        log_success "Attached ${IMAGE1} -> ${LOOP1}"
        log_success "Attached ${IMAGE2} -> ${LOOP2}"

        # Mandatory security verification: losetup -j
        log_info "Verifying loop attachments via losetup -j..."
        V_CHECK1=$(sudo losetup -j "${IMAGE1}" | grep -w "${LOOP1}" || true)
        V_CHECK2=$(sudo losetup -j "${IMAGE2}" | grep -w "${LOOP2}" || true)

        if [[ -z "${V_CHECK1}" ]] || [[ -z "${V_CHECK2}" ]]; then
            log_error "Loop device attachment verification failed!"
            exit 1
        fi
        log_success "Loop verification PASSED. ${LOOP1} and ${LOOP2} securely backed by sandbox images."

        # Confirm no VG named lsatest_dr_vg exists before vgcreate
        if sudo vgs --noheadings -o vg_name "${VG_NAME}" 2>/dev/null | grep -qw "${VG_NAME}"; then
            log_error "VG ${VG_NAME} unexpectedly exists before vgcreate. Aborting."
            exit 1
        fi

        log_info "Initializing Physical Volumes on ${LOOP1} and ${LOOP2}..."
        sudo_run "Initialize PV on ${LOOP1}" pvcreate -f "${LOOP1}"
        sudo_run "Initialize PV on ${LOOP2}" pvcreate -f "${LOOP2}"

        log_info "Creating Volume Group '${VG_NAME}' pooling ${LOOP1} and ${LOOP2}..."
        sudo_run "Create VG ${VG_NAME}" vgcreate "${VG_NAME}" "${LOOP1}" "${LOOP2}"
        log_success "Volume Group '${VG_NAME}' successfully created."
    fi

    # Create origin Logical Volume (500 MB)
    log_info "Creating origin Logical Volume '${LV_ORIGIN}' (500 MB)..."
    sudo_run "Create origin LV" lvcreate -y -W y -L 500M -n "${LV_ORIGIN}" "${VG_NAME}"

    log_info "Formatting ${ORIGIN_DEV} with ext4 filesystem..."
    sudo_run "Format origin filesystem" mkfs.ext4 -F -L "DR_ORIGIN" "${ORIGIN_DEV}"

    log_info "Mounting ${ORIGIN_DEV} at ${MNT_DATA}..."
    sudo_run "Mount origin LV" mount "${ORIGIN_DEV}" "${MNT_DATA}"
fi

# Print Volume Group capacity showing reserved free extents for snapshots
log_info "Checking Volume Group capacity and available extents for snapshots:"
sudo vgs -o vg_name,vg_size,vg_free,lv_count,pv_count "${VG_NAME}"

# Create sandbox demo fstab and validate with findmnt
log_info "Generating sandbox demo fstab (${FSTAB_DEMO})..."
ORIGIN_UUID=$(sudo blkid -s UUID -o value "${ORIGIN_DEV}" || true)
{
    echo "# /etc/fstab demo specification for NovaTech Disaster Recovery Origin Volume"
    echo "# Host /etc/fstab is strictly preserved untouched per sandbox compliance."
    echo "UUID=${ORIGIN_UUID}  ${MNT_DATA}  ext4  defaults,noatime  0  2"
} > "${FSTAB_DEMO}"

log_info "Validating demo fstab specification via findmnt --verify..."
if findmnt --verify --tab-file "${FSTAB_DEMO}"; then
    log_success "Demo fstab verification PASSED."
else
    log_warn "findmnt reported non-fatal warning on demo fstab; proceeding."
fi

# Seed data and baseline manifest
log_info "Invoking seed_data.sh to populate departmental records..."
bash "${SCRIPT_DIR}/seed_data.sh"

echo "------------------------------------------------------------------------------"
echo " LIVE STORAGE & LVM STATUS EVIDENCE"
echo "------------------------------------------------------------------------------"
log_info "1. Block device hierarchy (lsblk):"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT | grep -E "loop|lsatest" || true

log_info "2. Physical Volumes (pvs):"
sudo pvs -o pv_name,vg_name,pv_size,pv_free | grep -E "PV|lsatest" || sudo pvs

log_info "3. Volume Groups (vgs):"
sudo vgs -o vg_name,pv_count,lv_count,vg_size,vg_free | grep -E "VG|lsatest" || sudo vgs

log_info "4. Logical Volumes (lvs):"
sudo lvs -o lv_name,vg_name,lv_size,lv_attr,data_percent | grep -E "LV|lsatest" || sudo lvs

log_info "5. Filesystem usage (df -h):"
df -h "${MNT_DATA}"

log_success "Phase 1 Lab Storage setup complete and verified."
exit 0
