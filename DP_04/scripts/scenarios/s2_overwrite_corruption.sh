#!/usr/bin/env bash
# ==============================================================================
# Scenario 2 (S2) — Accidental Overwrite or Corruption & Single File Restore
# Project: DP_04 Linux Disaster Recovery Solution
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/../common.sh"

echo "=============================================================================="
echo " SCENARIO 2 (S2): FILE CORRUPTION / OVERWRITE & SINGLE-FILE RESTORATION"
echo "=============================================================================="

STATUS_FILE="${LOGS_DIR}/scenario_s2.status"
MANIFEST_FILE="${SANDBOX_DATA}/baseline.manifest"
TARGET_REL="$(grep '^finance/' "${MANIFEST_FILE}" | head -n 1 | awk '{print $1}')"
TARGET_FILE="${MNT_DATA}/${TARGET_REL}"

guard_sandbox_path "${MANIFEST_FILE}"
guard_sandbox_path "${TARGET_FILE}"
guard_sandbox_path "${MNT_DATA}"
guard_sandbox_path "${MNT_SNAP}"

# Ensure origin is mounted
if ! mountpoint -q "${MNT_DATA}"; then
    log_error "Origin volume ${MNT_DATA} is not mounted. Run setup_lab.sh first."
    exit 1
fi

# Clean any existing S2 snapshot
if sudo lvs "${VG_NAME}/lsatest_snap_s2" >/dev/null 2>&1; then
    safe_lvremove "lsatest_snap_s2"
fi

# Get baseline expected hash for target file
EXPECTED_HASH=$(grep "^${TARGET_REL} " "${MANIFEST_FILE}" | awk '{print $2}')
if [[ -z "${EXPECTED_HASH}" ]]; then
    log_error "Target file ${TARGET_REL} not found in baseline manifest."
    exit 1
fi

# 1. Take Snapshot
log_info "Step 1: Creating consistent point-in-time snapshot 'lsatest_snap_s2' (100M)..."
bash "${SCRIPTS_DIR}/snapshot_create.sh" "100M" "s2" >/dev/null
SNAP_EPOCH=$(date +%s)
SNAP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
log_success "Snapshot taken at ${SNAP_ISO} (Epoch: ${SNAP_EPOCH})."

sleep 2

# 2. Simulate Disaster: Overwrite with bounded junk data
log_info "Step 2: Simulating Disaster — Overwriting ${TARGET_REL} with bounded random noise..."
sudo_run "Simulate corruption with bounded write" dd if=/dev/urandom of="${TARGET_FILE}" bs=1k count=24 conv=notrunc status=none
sync

CORRUPTED_HASH=$(sha256sum "${TARGET_FILE}" | awk '{print $1}')
log_info "Baseline Hash : ${EXPECTED_HASH}"
log_info "Corrupted Hash: ${CORRUPTED_HASH}"

if [[ "${CORRUPTED_HASH}" == "${EXPECTED_HASH}" ]]; then
    log_error "File corruption simulation failed; hashes unexpectedly match!"
    exit 1
fi

DISASTER_EPOCH=$(date +%s)
DISASTER_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATA_LOSS_WINDOW=$((DISASTER_EPOCH - SNAP_EPOCH))
log_success "Disaster event simulated at ${DISASTER_ISO}. Data-loss window: ${DATA_LOSS_WINDOW}s."

# 3. Recovery Phase
log_info "Step 3: Commencing single-file recovery from snapshot..."
REC_START=$(date +%s)

# Mount snapshot read-only
log_info "Mounting snapshot /dev/${VG_NAME}/lsatest_snap_s2 read-only at ${MNT_SNAP}..."
sudo_run "Mount S2 snapshot ro" mount -o ro "/dev/${VG_NAME}/lsatest_snap_s2" "${MNT_SNAP}"

# Restore single file
log_info "Restoring single file ${TARGET_REL} using 'cp -a'..."
src="${MNT_SNAP}/${TARGET_REL}"
guard_sandbox_path "${src}"
cp -a "${src}" "${TARGET_FILE}"

# Unmount snapshot
log_info "Unmounting snapshot ${MNT_SNAP}..."
sudo_run "Unmount S2 snapshot" umount "${MNT_SNAP}"

REC_END=$(date +%s)
REC_DURATION=$((REC_END - REC_START))
log_success "Single-file restoration completed in ${REC_DURATION}s."

# 4. Validation against baseline hash
log_info "Step 4: Validating restored file cryptographic checksum against baseline manifest..."
RESTORED_HASH=$(sha256sum "${TARGET_FILE}" | awk '{print $1}')
echo "  Target File   : ${TARGET_REL}"
echo "  Baseline Hash : ${EXPECTED_HASH}"
echo "  Restored Hash : ${RESTORED_HASH}"

TOTAL_FILES=0
MATCHES=0
MISMATCHES=0

while read -r rel exp_h exp_m exp_s; do
    TOTAL_FILES=$((TOTAL_FILES + 1))
    f_path="${MNT_DATA}/${rel}"
    if [[ ! -f "${f_path}" ]]; then
        MISMATCHES=$((MISMATCHES + 1))
        continue
    fi
    act_h=$(sha256sum "${f_path}" | awk '{print $1}')
    if [[ "${act_h}" == "${exp_h}" ]]; then
        MATCHES=$((MATCHES + 1))
    else
        MISMATCHES=$((MISMATCHES + 1))
    fi
done < "${MANIFEST_FILE}"

OUTCOME="FAIL"
if [[ "${RESTORED_HASH}" == "${EXPECTED_HASH}" ]] && [[ "${MISMATCHES}" -eq 0 ]]; then
    OUTCOME="PASS"
    log_success "SCENARIO 2 RESULT: PASS (Restored file checksum matches baseline exactly; entire tree intact)."
else
    log_error "SCENARIO 2 RESULT: FAIL (Checksum mismatch detected)."
fi

# Clean up snapshot
log_info "Cleaning up scenario snapshot 'lsatest_snap_s2'..."
safe_lvremove "lsatest_snap_s2"

# Save persistent status report
{
    echo "SCENARIO_ID=S2"
    echo "SCENARIO_NAME=Accidental Overwrite or Corruption"
    echo "DISASTER_DESC=Targeted overwrite and bit corruption of ${TARGET_REL} with bounded random payload"
    echo "RECOVERY_METHOD=Read-Only Snapshot Mount & Targeted Single File Restore (cp -a)"
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

log_success "Scenario 2 status record generated: ${STATUS_FILE}"

if [[ "${OUTCOME}" != "PASS" ]]; then
    exit 1
fi
exit 0
