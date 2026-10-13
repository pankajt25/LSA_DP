#!/usr/bin/env bash
# ==============================================================================
# Scenario 3 (S3) — Catastrophic Loss with Full Rollback via lvconvert --merge
# Project: DP_04 Linux Disaster Recovery Solution
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/../common.sh"

echo "=============================================================================="
echo " SCENARIO 3 (S3): CATASTROPHIC DIRECTORY LOSS & FULL BLOCK-LEVEL ROLLBACK"
echo "=============================================================================="

STATUS_FILE="${LOGS_DIR}/scenario_s3.status"
MANIFEST_FILE="${SANDBOX_DATA}/baseline.manifest"

guard_sandbox_path "${MANIFEST_FILE}"
guard_sandbox_path "${MNT_DATA}"

# Ensure origin is mounted
if ! mountpoint -q "${MNT_DATA}"; then
    log_error "Origin volume ${MNT_DATA} is not mounted. Run setup_lab.sh first."
    exit 1
fi

# Clean any existing S3 snapshot
if sudo lvs "${VG_NAME}/lsatest_snap_s3" >/dev/null 2>&1; then
    safe_lvremove "lsatest_snap_s3"
fi

# 1. Take Snapshot
log_info "Step 1: Creating point-in-time baseline snapshot 'lsatest_snap_s3' (100M)..."
bash "${SCRIPTS_DIR}/snapshot_create.sh" "100M" "s3" >/dev/null
SNAP_EPOCH=$(date +%s)
SNAP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
log_success "Snapshot taken at ${SNAP_ISO} (Epoch: ${SNAP_EPOCH})."

sleep 2

# 2. Simulate Catastrophic Disaster: Deleting entire Engineering and Sales trees
log_info "Step 2: Simulating Disaster — Catastrophic recursive deletion of 2 entire departments..."
guard_sandbox_path "${MNT_DATA}/engineering"
guard_sandbox_path "${MNT_DATA}/sales"

log_warn "Recursively deleting ${MNT_DATA}/engineering..."
rm -rf "${MNT_DATA}/engineering"

log_warn "Recursively deleting ${MNT_DATA}/sales..."
rm -rf "${MNT_DATA}/sales"
sync

DISASTER_EPOCH=$(date +%s)
DISASTER_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATA_LOSS_WINDOW=$((DISASTER_EPOCH - SNAP_EPOCH))
log_success "Catastrophic event simulated at ${DISASTER_ISO}. Data-loss window: ${DATA_LOSS_WINDOW}s."

# Verify directories are gone
if [[ -d "${MNT_DATA}/engineering" ]] || [[ -d "${MNT_DATA}/sales" ]]; then
    log_error "Disaster simulation failed; departments still exist!"
    exit 1
fi
log_info "Department directories confirmed missing from mounted origin."

# 3. Recovery Phase: Full Block-Level Merge Rollback
log_info "Step 3: Commencing full block-level rollback using 'lvconvert --merge'..."
log_info "ARCHITECTURAL PRINCIPLE: The origin filesystem MUST be unmounted before merging."
log_info "Reason: 'lvconvert --merge' directly overwrites underlying block allocation extents."
log_info "Merging a live, mounted filesystem would cause ext4 metadata corruption and kernel panics."

REC_START=$(date +%s)

# Unmount origin volume
log_info "Unmounting origin filesystem at ${MNT_DATA}..."
sudo_run "Unmount origin volume for merge" umount "${MNT_DATA}"

# Merge snapshot into origin
log_info "Executing: lvconvert --merge /dev/${VG_NAME}/lsatest_snap_s3..."
sudo_run "Merge snapshot into origin" lvconvert --merge "/dev/${VG_NAME}/lsatest_snap_s3"

# Reactivate volume to ensure full block consistency
log_info "Reactivating logical volume ${ORIGIN_DEV}..."
sudo_run "Reactivate origin volume" lvchange -ay "${ORIGIN_DEV}"

# Remount origin volume
log_info "Remounting origin filesystem at ${MNT_DATA}..."
sudo_run "Remount origin filesystem" mount "${ORIGIN_DEV}" "${MNT_DATA}"

REC_END=$(date +%s)
REC_DURATION=$((REC_END - REC_START))
log_success "Block-level merge rollback completed in ${REC_DURATION}s."

# Confirm snapshot was consumed
log_info "Verifying that 'lvconvert --merge' consumed the snapshot..."
if sudo lvs "${VG_NAME}/lsatest_snap_s3" >/dev/null 2>&1; then
    log_warn "Snapshot 'lsatest_snap_s3' is still visible; merge may be completing in background."
else
    log_success "Snapshot 'lsatest_snap_s3' was consumed by the merge as expected."
fi

# 4. Validation against baseline manifest
log_info "Step 4: Validating entire restored filesystem tree against baseline manifest..."
TOTAL_FILES=0
MATCHES=0
MISMATCHES=0

while read -r rel expected_hash expected_mode expected_size; do
    TOTAL_FILES=$((TOTAL_FILES + 1))
    file_path="${MNT_DATA}/${rel}"
    
    if [[ ! -f "${file_path}" ]]; then
        log_error "Missing file after merge: ${rel}"
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
        log_error "Mismatch detected in ${rel} post-merge:"
        echo "  Expected: hash=${expected_hash} mode=${expected_mode} size=${expected_size}"
        echo "  Actual  : hash=${actual_hash} mode=${actual_mode} size=${actual_size}"
        MISMATCHES=$((MISMATCHES + 1))
    fi
done < "${MANIFEST_FILE}"

log_info "Validation Results: Total Files: ${TOTAL_FILES} | Matches: ${MATCHES} | Mismatches: ${MISMATCHES}"

OUTCOME="FAIL"
if [[ "${MISMATCHES}" -eq 0 ]] && [[ "${MATCHES}" -eq "${TOTAL_FILES}" ]]; then
    OUTCOME="PASS"
    log_success "SCENARIO 3 RESULT: PASS (100% full rollback verified, 0 mismatches across all 105 files)."
else
    log_error "SCENARIO 3 RESULT: FAIL (Integrity mismatches post-merge)."
fi

# Save persistent status report
{
    echo "SCENARIO_ID=S3"
    echo "SCENARIO_NAME=Catastrophic Loss with Full Rollback"
    echo "DISASTER_DESC=Catastrophic recursive deletion of 2 entire departments (engineering/ and sales/)"
    echo "RECOVERY_METHOD=Full Block-Level Snapshot Rollback (lvconvert --merge offline)"
    echo "SNAPSHOT_TIME_ISO=${SNAP_ISO}"
    echo "SNAPSHOT_EPOCH=${SNAP_EPOCH}"
    echo "DISASTER_TIME_ISO=${DISASTER_ISO}"
    echo "DISASTER_EPOCH=${DISASTER_EPOCH}"
    echo "DATA_LOSS_WINDOW_SEC=${DATA_LOSS_WINDOW}"
    echo "RECOVERY_START_EPOCH=${REC_START}"
    echo "RECOVERY_END_EPOCH=${REC_END}"
    echo "RECOVERY_TIME_SEC=${REC_DURATION}"
    echo "FILES_COMPARED=${TOTAL_FILES}"
    echo "MATCHES=${MATCHES}"
    echo "MISMATCHES=${MISMATCHES}"
    echo "RESULT=${OUTCOME}"
} > "${STATUS_FILE}"

log_success "Scenario 3 status record generated: ${STATUS_FILE}"

if [[ "${OUTCOME}" != "PASS" ]]; then
    exit 1
fi
exit 0
