#!/usr/bin/env bash
# ==============================================================================
# Scenario 1 (S1) — Accidental File Deletion & Selective Snapshot Restore
# Project: DP_04 Linux Disaster Recovery Solution
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/../common.sh"

echo "=============================================================================="
echo " SCENARIO 1 (S1): ACCIDENTAL FILE DELETION & SELECTIVE RESTORATION"
echo "=============================================================================="

STATUS_FILE="${LOGS_DIR}/scenario_s1.status"
MANIFEST_FILE="${SANDBOX_DATA}/baseline.manifest"

guard_sandbox_path "${MANIFEST_FILE}"
guard_sandbox_path "${MNT_DATA}"
guard_sandbox_path "${MNT_SNAP}"

# Ensure origin is mounted
if ! mountpoint -q "${MNT_DATA}"; then
    log_error "Origin volume ${MNT_DATA} is not mounted. Run setup_lab.sh first."
    exit 1
fi

# Clean any existing S1 snapshot
if sudo lvs "${VG_NAME}/lsatest_snap_s1" >/dev/null 2>&1; then
    safe_lvremove "lsatest_snap_s1"
fi

# 1. Take Snapshot
log_info "Step 1: Creating consistent point-in-time snapshot 'lsatest_snap_s1' (100M)..."
bash "${SCRIPTS_DIR}/snapshot_create.sh" "100M" "s1" >/dev/null
SNAP_EPOCH=$(date +%s)
SNAP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
log_success "Snapshot taken at ${SNAP_ISO} (Epoch: ${SNAP_EPOCH})."

sleep 2

# 2. Simulate Disaster: Accidental File Deletion
log_info "Step 2: Simulating Disaster — Accidental deletion of critical department files..."
DELETED_FILES=(
    "$(grep '^finance/' "${MANIFEST_FILE}" | head -n 1 | awk '{print $1}')"
    "$(grep '^hr/' "${MANIFEST_FILE}" | head -n 1 | awk '{print $1}')"
    "$(grep '^engineering/' "${MANIFEST_FILE}" | head -n 1 | awk '{print $1}')"
    "$(grep '^sales/' "${MANIFEST_FILE}" | head -n 1 | awk '{print $1}')"
    "$(grep '^finance/' "${MANIFEST_FILE}" | tail -n 1 | awk '{print $1}')"
)

for rel in "${DELETED_FILES[@]}"; do
    target="${MNT_DATA}/${rel}"
    guard_sandbox_path "${target}"
    log_warn "Deleting file: ${rel}"
    rm -f "${target}"
done

DISASTER_EPOCH=$(date +%s)
DISASTER_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATA_LOSS_WINDOW=$((DISASTER_EPOCH - SNAP_EPOCH))
log_success "Disaster event simulated at ${DISASTER_ISO}. Data-loss window: ${DATA_LOSS_WINDOW}s."

# Confirm files are deleted
for rel in "${DELETED_FILES[@]}"; do
    if [[ -f "${MNT_DATA}/${rel}" ]]; then
        log_error "File was not deleted: ${rel}"
        exit 1
    fi
done

# 3. Recovery Phase
log_info "Step 3: Commencing selective recovery from snapshot..."
REC_START=$(date +%s)

# Mount snapshot read-only
log_info "Mounting snapshot /dev/${VG_NAME}/lsatest_snap_s1 read-only at ${MNT_SNAP}..."
sudo_run "Mount S1 snapshot ro" mount -o ro "/dev/${VG_NAME}/lsatest_snap_s1" "${MNT_SNAP}"

# Restore deleted files with metadata preservation (cp -a)
log_info "Restoring deleted files using 'cp -a' from read-only snapshot mount..."
for rel in "${DELETED_FILES[@]}"; do
    src="${MNT_SNAP}/${rel}"
    dst="${MNT_DATA}/${rel}"
    guard_sandbox_path "${src}"
    guard_sandbox_path "${dst}"
    log_info "Restoring: ${rel}"
    cp -a "${src}" "${dst}"
done

# Unmount snapshot
log_info "Unmounting snapshot ${MNT_SNAP}..."
sudo_run "Unmount S1 snapshot" umount "${MNT_SNAP}"

REC_END=$(date +%s)
REC_DURATION=$((REC_END - REC_START))
log_success "Selective restoration completed in ${REC_DURATION}s."

# 4. Validation against baseline manifest
log_info "Step 4: Validating restored dataset against cryptographic baseline manifest..."
TOTAL_FILES=0
MATCHES=0
MISMATCHES=0

while read -r rel expected_hash expected_mode expected_size; do
    TOTAL_FILES=$((TOTAL_FILES + 1))
    file_path="${MNT_DATA}/${rel}"
    
    if [[ ! -f "${file_path}" ]]; then
        log_error "Missing file: ${rel}"
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
    log_success "SCENARIO 1 RESULT: PASS (100% integrity and permissions verified, 0 mismatches)."
else
    log_error "SCENARIO 1 RESULT: FAIL (Integrity mismatches detected)."
fi

# Clean up snapshot
log_info "Cleaning up scenario snapshot 'lsatest_snap_s1'..."
safe_lvremove "lsatest_snap_s1"

# Save persistent status report for validation document & HTML report
{
    echo "SCENARIO_ID=S1"
    echo "SCENARIO_NAME=Accidental File Deletion"
    echo "DISASTER_DESC=Accidental deletion of 5 departmental files across Finance, HR, Eng, Sales"
    echo "RECOVERY_METHOD=Read-Only Snapshot Mount & Selective File Restore (cp -a)"
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

log_success "Scenario 1 status record generated: ${STATUS_FILE}"

if [[ "${OUTCOME}" != "PASS" ]]; then
    exit 1
fi
exit 0
