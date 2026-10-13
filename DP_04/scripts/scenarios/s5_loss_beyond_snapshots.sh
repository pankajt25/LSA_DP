#!/usr/bin/env bash
# ==============================================================================
# Scenario 5 (S5) — Loss Beyond Snapshots (Why Snapshots Are Not Backups)
# Project: DP_04 Linux Disaster Recovery Solution
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/../common.sh"

echo "=============================================================================="
echo " SCENARIO 5 (S5): TOTAL VOLUME DESTRUCTION & ARCHIVE-BASED DISASTER RECOVERY"
echo "=============================================================================="

STATUS_FILE="${LOGS_DIR}/scenario_s5.status"
MANIFEST_FILE="${SANDBOX_DATA}/baseline.manifest"

guard_sandbox_path "${MANIFEST_FILE}"
guard_sandbox_path "${MNT_DATA}"
guard_sandbox_path "${MNT_SNAP}"
guard_sandbox_path "${ARCHIVE_STORE}"

# Ensure origin is mounted
if ! mountpoint -q "${MNT_DATA}"; then
    log_error "Origin volume ${MNT_DATA} is not mounted. Run setup_lab.sh first."
    exit 1
fi

# Clean any existing S5 snapshot
if sudo lvs "${VG_NAME}/lsatest_snap_s5" >/dev/null 2>&1; then
    safe_lvremove "lsatest_snap_s5"
fi

TS="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_NAME="data_${TS}.tar.gz"
ARCHIVE_FILE="${ARCHIVE_STORE}/${ARCHIVE_NAME}"
ARCHIVE_SHA_FILE="${ARCHIVE_FILE}.sha256"

# 1. Take Point-in-Time Snapshot while origin remains online
log_info "Step 1: Creating consistent point-in-time snapshot 'lsatest_snap_s5' while origin stays online..."
bash "${SCRIPTS_DIR}/snapshot_create.sh" "100M" "s5" >/dev/null
SNAP_EPOCH=$(date +%s)
SNAP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 2. Mount Snapshot Read-Only & Generate Verified Backup Archive outside VG
log_info "Step 2: Mounting snapshot read-only and creating compressed archive in external archive store..."
sudo_run "Mount S5 snapshot ro" mount -o ro "/dev/${VG_NAME}/lsatest_snap_s5" "${MNT_SNAP}"

log_info "Creating archive: ${ARCHIVE_FILE}..."
tar -czf "${ARCHIVE_FILE}" -C "${MNT_SNAP}" .
sync

log_info "Generating cryptographic SHA-256 checksum for archive..."
(
    cd "${ARCHIVE_STORE}"
    sha256sum "${ARCHIVE_NAME}" > "${ARCHIVE_NAME}.sha256"
)

ARCHIVE_SIZE=$(ls -lh "${ARCHIVE_FILE}" | awk '{print $5}')
ARCHIVE_HASH=$(awk '{print $1}' "${ARCHIVE_SHA_FILE}")
log_success "Archive generated: ${ARCHIVE_NAME} (${ARCHIVE_SIZE}) | SHA-256: ${ARCHIVE_HASH}"

# Verify archive health immediately
log_info "Verifying archive integrity against checksum file..."
(
    cd "${ARCHIVE_STORE}"
    sha256sum -c "${ARCHIVE_NAME}.sha256"
)
log_success "Archive checksum verified successfully."

# Unmount snapshot
log_info "Unmounting snapshot ${MNT_SNAP}..."
sudo_run "Unmount S5 snapshot" umount "${MNT_SNAP}"

sleep 2

# 3. Simulate Total Catastrophic Loss: Destruction of Origin Volume and Snapshots
log_info "Step 3: Simulating Catastrophic Hardware/Volume Loss..."
log_info "WHY SNAPSHOTS ARE NOT BACKUPS:"
log_info "  1. Snapshots rely on the origin volume's metadata and storage pool."
log_info "  2. When the origin volume or volume group is lost/destroyed, all snapshots perish with it."
log_info "  3. Only independent archives stored OUTSIDE the volume group survive total disaster."

DISASTER_EPOCH=$(date +%s)
DISASTER_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATA_LOSS_WINDOW=$((DISASTER_EPOCH - SNAP_EPOCH))

log_warn "Unmounting origin filesystem..."
sudo_run "Unmount origin filesystem" umount "${MNT_DATA}"

# Remove snapshot and origin volume using explicit, name-checked commands
log_warn "Destroying snapshot 'lsatest_snap_s5'..."
safe_lvremove "lsatest_snap_s5"

log_warn "Destroying origin volume '${LV_ORIGIN}'..."
safe_lvremove "${LV_ORIGIN}"

# Confirm destruction
if sudo lvs "${VG_NAME}/${LV_ORIGIN}" >/dev/null 2>&1; then
    log_error "Origin volume destruction failed!"
    exit 1
fi
log_success "Total loss simulated: Origin volume and all snapshots completely destroyed."

# 4. Disaster Recovery Phase from External Archive Store
log_info "Step 4: Commencing Disaster Recovery from external archive store..."
REC_START=$(date +%s)

# Recreate origin Logical Volume
log_info "Recreating origin Logical Volume '${LV_ORIGIN}' (500 MB) in ${VG_NAME}..."
sudo_run "Recreate origin LV" lvcreate -y -W y -L 500M -n "${LV_ORIGIN}" "${VG_NAME}"

# Format fresh ext4 filesystem
log_info "Formatting recreated volume with ext4..."
sudo_run "Format recreated origin LV" mkfs.ext4 -F -L "DR_ORIGIN" "${ORIGIN_DEV}"

# Mount fresh filesystem
log_info "Mounting recreated volume at ${MNT_DATA}..."
sudo_run "Mount recreated volume" mount "${ORIGIN_DEV}" "${MNT_DATA}"
sudo_run "Set permissions on mount" chown -R "$(id -u):$(id -g)" "${MNT_DATA}"

# Verify archive checksum before restore
log_info "Re-verifying archive SHA-256 before restoration..."
(
    cd "${ARCHIVE_STORE}"
    sha256sum -c "${ARCHIVE_NAME}.sha256"
)

# Extract archive into fresh filesystem
log_info "Restoring full directory tree from archive into ${MNT_DATA}..."
tar -xzf "${ARCHIVE_FILE}" -C "${MNT_DATA}"
sync

REC_END=$(date +%s)
REC_DURATION=$((REC_END - REC_START))
log_success "Bare-metal restoration completed in ${REC_DURATION}s."

# 5. Validation against baseline manifest
log_info "Step 5: Validating restored dataset against baseline manifest..."
TOTAL_FILES=0
MATCHES=0
MISMATCHES=0

while read -r rel expected_hash expected_mode expected_size; do
    TOTAL_FILES=$((TOTAL_FILES + 1))
    file_path="${MNT_DATA}/${rel}"
    
    if [[ ! -f "${file_path}" ]]; then
        log_error "Missing file post-archive restore: ${rel}"
        MISMATCHES=$((MISMATCHES + 1))
        continue
    fi

    actual_hash=$(sha256sum "${file_path}" | awk '{print $1}')
    actual_mode=$(stat -c '%a' "${file_path}")
    actual_size=$(stat -c '%s' "${file_path}")

    if [[ "${actual_hash}" == "${expected_hash}" ]] && \
       [[ "${actual_mode}" == "${expected_mode}" ]] && \
       [[ "${actual_size}" == "${expected_size}" ]]; then
        MATCHES=$((MATCHES + 1))
    else
        log_error "Mismatch detected in ${rel}:"
        echo "  Expected: hash=${expected_hash} mode=${expected_mode} size=${expected_size}"
        echo "  Actual  : hash=${actual_hash} mode=${actual_mode} size=${actual_size}"
        MISMATCHES=$((MISMATCHES + 1))
    fi
done < "${MANIFEST_FILE}"

log_info "Validation Results: Total Files: ${TOTAL_FILES} | Matches: ${MATCHES} | Mismatches: ${MISMATCHES}"

OUTCOME="FAIL"
if [[ "${MISMATCHES}" -eq 0 ]] && [[ "${MATCHES}" -eq "${TOTAL_FILES}" ]]; then
    OUTCOME="PASS"
    log_success "SCENARIO 5 RESULT: PASS (100% data restored from external archive with identical SHA-256 hashes)."
else
    log_error "SCENARIO 5 RESULT: FAIL (Integrity mismatches post-archive restore)."
fi

# Save persistent status report
{
    echo "SCENARIO_ID=S5"
    echo "SCENARIO_NAME=Loss Beyond Snapshots (Why Snapshots != Backups)"
    echo "DISASTER_DESC=Total volume destruction: origin LV and all snapshots destroyed"
    echo "RECOVERY_METHOD=External Point-in-Time Tarball Archive Restoration (Outside VG)"
    echo "SNAPSHOT_TIME_ISO=${SNAP_ISO}"
    echo "SNAPSHOT_EPOCH=${SNAP_EPOCH}"
    echo "DISASTER_TIME_ISO=${DISASTER_ISO}"
    echo "DISASTER_EPOCH=${DISASTER_EPOCH}"
    echo "DATA_LOSS_WINDOW_SEC=${DATA_LOSS_WINDOW}"
    echo "RECOVERY_START_EPOCH=${REC_START}"
    echo "RECOVERY_END_EPOCH=${REC_END}"
    echo "RECOVERY_TIME_SEC=${REC_DURATION}"
    echo "ARCHIVE_FILE=${ARCHIVE_NAME}"
    echo "ARCHIVE_SIZE=${ARCHIVE_SIZE}"
    echo "ARCHIVE_SHA256=${ARCHIVE_HASH}"
    echo "FILES_COMPARED=${TOTAL_FILES}"
    echo "MATCHES=${MATCHES}"
    echo "MISMATCHES=${MISMATCHES}"
    echo "RESULT=${OUTCOME}"
} > "${STATUS_FILE}"

log_success "Scenario 5 status record generated: ${STATUS_FILE}"

if [[ "${OUTCOME}" != "PASS" ]]; then
    exit 1
fi
exit 0
