#!/usr/bin/env bash
# ==============================================================================
# Teardown & Sanitization Script — DP_04 Linux Disaster Recovery Solution
# Course: Linux System Administration (E1ITA307) — Modules: IV | CO4
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/scripts/common.sh"

echo "=============================================================================="
echo " SYSTEM SANITIZATION & SANDBOX TEARDOWN (DP_04)"
echo "=============================================================================="

IMAGE1="${SANDBOX_DATA}/disk1.img"
IMAGE2="${SANDBOX_DATA}/disk2.img"
FSTAB_DEMO="${SANDBOX_DATA}/fstab.demo"
MANIFEST_FILE="${SANDBOX_DATA}/baseline.manifest"

# 1. Unmount anything mounted under sandbox_data/mnt/
log_info "Step 1: Unmounting sandbox mounts under ${SANDBOX_DATA}/mnt/..."
for mnt_pt in "${MNT_SNAP}" "${MNT_DATA}"; do
    if mountpoint -q "${mnt_pt}" 2>/dev/null; then
        log_info "Unmounting ${mnt_pt}..."
        sudo_run "Unmount sandbox path ${mnt_pt}" umount "${mnt_pt}"
    fi
done

# Double check any lingering mounts inside sandbox
LINGERING_MOUNTS=$(grep "${SANDBOX_DATA}" /proc/mounts | awk '{print $2}' || true)
for m in ${LINGERING_MOUNTS}; do
    if [[ -n "${m}" ]]; then
        log_info "Unmounting lingering mount: ${m}"
        sudo_run "Unmount lingering mount ${m}" umount "${m}"
    fi
done

# 2. Remove each remaining snapshot by exact name
log_info "Step 2: Scanning for remaining snapshots with prefix 'lsatest_snap_'..."
if sudo vgs "${VG_NAME}" >/dev/null 2>&1; then
    SNAPS=$(sudo lvs --noheadings -o lv_name "${VG_NAME}" 2>/dev/null | tr -d ' ' | grep '^lsatest_snap_' || true)
    for s in ${SNAPS}; do
        if [[ -n "${s}" ]]; then
            log_info "Removing snapshot: ${s}"
            safe_lvremove "${s}"
        fi
    done

    # 3. Remove origin Logical Volume by exact name
    log_info "Step 3: Removing origin Logical Volume '${LV_ORIGIN}'..."
    if sudo lvs "${VG_NAME}/${LV_ORIGIN}" >/dev/null 2>&1; then
        safe_lvremove "${LV_ORIGIN}"
    fi

    # 4. Remove Volume Group lsatest_dr_vg
    log_info "Step 4: Removing Volume Group '${VG_NAME}'..."
    safe_vgremove "${VG_NAME}"
fi

# 5. Remove PVs and detach loop devices after confirming with losetup -j
log_info "Step 5: Verifying loop attachments and clearing Physical Volumes..."
LOOP1=$(sudo losetup -j "${IMAGE1}" 2>/dev/null | cut -d: -f1 || true)
LOOP2=$(sudo losetup -j "${IMAGE2}" 2>/dev/null | cut -d: -f1 || true)

if [[ -n "${LOOP1}" ]]; then
    log_info "Found loop device for disk1.img: ${LOOP1}"
    if sudo pvs "${LOOP1}" >/dev/null 2>&1; then
        safe_pvremove "${LOOP1}"
    fi
    log_info "Detaching loop device ${LOOP1}..."
    sudo_run "Detach loop ${LOOP1}" losetup -d "${LOOP1}"
fi

if [[ -n "${LOOP2}" ]]; then
    log_info "Found loop device for disk2.img: ${LOOP2}"
    if sudo pvs "${LOOP2}" >/dev/null 2>&1; then
        safe_pvremove "${LOOP2}"
    fi
    log_info "Detaching loop device ${LOOP2}..."
    sudo_run "Detach loop ${LOOP2}" losetup -d "${LOOP2}"
fi

# 6. Delete image files and generated sandbox files
log_info "Step 6: Deleting virtual image files and temporary manifests..."
guard_sandbox_path "${IMAGE1}"
guard_sandbox_path "${IMAGE2}"
guard_sandbox_path "${FSTAB_DEMO}"
guard_sandbox_path "${MANIFEST_FILE}"

rm -f "${IMAGE1}" "${IMAGE2}" "${FSTAB_DEMO}" "${MANIFEST_FILE}"

# Clean archive store files but retain placeholder
log_info "Purging archives from archive_store/..."
for f in "${ARCHIVE_STORE}"/*; do
    if [[ -f "${f}" ]] && [[ "$(basename "${f}")" != ".gitkeep" ]]; then
        guard_sandbox_path "${f}"
        rm -f "${f}"
    fi
done

# Ensure placeholders exist
touch "${SANDBOX_DATA}/mnt/.gitkeep" "${SANDBOX_DATA}/archive_store/.gitkeep"

log_success "Sandbox cleanup completed. Scripts, logs, docs, and report.html preserved."

# 7. Verification of clean system state
echo ""
echo "=============================================================================="
echo " POST-CLEANUP VERIFICATION EVIDENCE"
echo "=============================================================================="
echo "1. Active Loop Devices (losetup -a):"
sudo losetup -a || echo "None"

echo "2. Active LVM Volume Groups (vgs):"
sudo vgs 2>/dev/null || echo "None"

echo "3. Active LVM Logical Volumes (lvs):"
sudo lvs 2>/dev/null || echo "None"

echo "4. Device Mapper Tables (dmsetup ls | grep lsatest):"
sudo dmsetup ls | grep lsatest || echo "No lsatest device mapper entries remain."

echo "5. Active Mounts for DP_04:"
mount | grep DP_04 || echo "No mounts active under DP_04."

echo "6. Sandbox directory contents (placeholders only):"
ls -la "${SANDBOX_DATA}"
echo "=============================================================================="

exit 0
