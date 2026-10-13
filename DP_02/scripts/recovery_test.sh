#!/usr/bin/env bash
# ==============================================================================
# Script Name   : recovery_test.sh
# Description   : Phase 3 - End-to-End Disaster Recovery Validation Suite (CO4 Core)
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

assert_sandbox_path "${SOURCE_DIR}"
assert_sandbox_path "${REPO_DIR}"
assert_sandbox_path "${RESTORE_DIR}"

TEST_RESULT_FILE="${PROJECT_ROOT}/logs/recovery_results.env"

log_info "======================================================================"
log_info "Executing NovaTech Disaster Recovery Verification Suite (CO4 Core)"
log_info "======================================================================"

# Step 1: Ensure initial seeded dataset is freshly populated
log_info "[Setup] Initializing/refreshing pristine department dataset..."
bash "${SCRIPT_DIR}/seed_data.sh"

# Step 2: Full Backup
log_info "[Step 1/6] Executing Baseline FULL Backup..."
bash "${SCRIPT_DIR}/backup_full.sh"

# Step 3: First Mutation & Incremental Backup 1
log_info "[Step 2/6] Applying Data Mutation Set 1 & Creating Incremental 1..."
bash "${SCRIPT_DIR}/mutate_data.sh" 1
bash "${SCRIPT_DIR}/backup_incremental.sh"

# Step 4: Second Mutation & Incremental Backup 2
log_info "[Step 3/6] Applying Data Mutation Set 2 & Creating Incremental 2..."
bash "${SCRIPT_DIR}/mutate_data.sh" 2
bash "${SCRIPT_DIR}/backup_incremental.sh"

# Step 5: Capture Pre-Disaster Manifest (Gold Standard for CO4 Recovery Proof)
log_info "[Step 4/6] Generating Pre-Disaster Cryptographic Manifest of Source..."
PRE_MANIFEST="${SANDBOX_DIR}/pre_disaster_manifest.sha256"
(
    cd "${SOURCE_DIR}"
    find . -type f -exec sha256sum {} + | sort
) > "${PRE_MANIFEST}"

TOTAL_FILES_PRE="$(wc -l < "${PRE_MANIFEST}")"
log_success "Pre-disaster snapshot indexed: ${TOTAL_FILES_PRE} files recorded."

# Step 6: Simulate Catastrophic Disaster inside Sandbox
log_info "[Step 5/6] Simulating Catastrophic Data Loss in Source Sandbox..."
log_warn "  [DISASTER SIMULATION] Purging entire department share: source/sales/"
safe_rm_rf "${SOURCE_DIR}/sales"

log_warn "  [DISASTER SIMULATION] Corrupting critical technical asset: source/engineering/architecture_decision_records.md"
echo "MALICIOUS DISK CORRUPTION DETECTED - DATA OVERWRITTEN AT RANDOM" > "${SOURCE_DIR}/engineering/architecture_decision_records.md"

FILES_AFTER_DISASTER="$(find "${SOURCE_DIR}" -type f | wc -l)"
log_warn "Disaster effect: File count dropped from ${TOTAL_FILES_PRE} to ${FILES_AFTER_DISASTER} files."

# Step 7: Restore from Backup Repository to restore_target/
log_info "[Step 6/6] Executing Full Chain Disaster Restoration..."
safe_rm_rf "${RESTORE_DIR}"
mkdir -p "${RESTORE_DIR}"

bash "${SCRIPT_DIR}/restore.sh" "${RESTORE_DIR}"

# Step 8: Compare and Validate Restored Directory against Pre-Disaster Manifest
log_info "Analyzing restored dataset against pre-disaster cryptographic manifest..."
POST_MANIFEST="${SANDBOX_DIR}/post_restore_manifest.sha256"
(
    cd "${RESTORE_DIR}"
    find . -type f -exec sha256sum {} + | sort
) > "${POST_MANIFEST}"

TOTAL_RESTORED="$(wc -l < "${POST_MANIFEST}")"

MATCHED_COUNT=0
MISMATCHED_COUNT=0
MISSING_COUNT=0

while IFS= read -r line; do
    expected_sum="$(echo "${line}" | awk '{print $1}')"
    rel_path="$(echo "${line}" | awk '{print $2}')"
    restored_file="${RESTORE_DIR}/${rel_path#./}"

    if [[ ! -f "${restored_file}" ]]; then
        MISSING_COUNT=$((MISSING_COUNT + 1))
        log_error "MISSING FILE: ${rel_path} was not restored!"
    else
        actual_sum="$(sha256sum "${restored_file}" | awk '{print $1}')"
        if [[ "${expected_sum}" == "${actual_sum}" ]]; then
            MATCHED_COUNT=$((MATCHED_COUNT + 1))
        else
            MISMATCHED_COUNT=$((MISMATCHED_COUNT + 1))
            log_error "CHECKSUM MISMATCH: ${rel_path} does not match pre-disaster data!"
        fi
    fi
done < "${PRE_MANIFEST}"

# Additional directory diff check
DIFF_OUTPUT=""
if diff -r -q "${RESTORE_DIR}/finance" "${SOURCE_DIR}/finance" >/dev/null 2>&1; then
    log_info "Directory level check: Restored structure is healthy."
fi

echo ""
echo "======================================================================"
echo "                 DISASTER RECOVERY AUDIT SCORECARD                    "
echo "======================================================================"
printf "%-30s: %d\n" "Pre-Disaster Expected Files" "${TOTAL_FILES_PRE}"
printf "%-30s: %d\n" "Total Files Restored"        "${TOTAL_RESTORED}"
printf "%-30s: %d\n" "Cryptographically Matched"   "${MATCHED_COUNT}"
printf "%-30s: %d\n" "Missing Files"               "${MISSING_COUNT}"
printf "%-30s: %d\n" "Mismatched Checksums"        "${MISMATCHED_COUNT}"
echo "======================================================================"

TEST_VERDICT="FAIL"
if [[ "${MATCHED_COUNT}" -eq "${TOTAL_FILES_PRE}" && "${MISSING_COUNT}" -eq 0 && "${MISMATCHED_COUNT}" -eq 0 ]]; then
    TEST_VERDICT="PASS"
    log_success "RECOVERY AUDIT VERDICT: PASS (100% Data Fidelity Preserved)"
else
    log_error "RECOVERY AUDIT VERDICT: FAIL (Disaster Recovery Discrepancies Detected)"
fi

# Step 9: Demonstrate Corrupted Archive Detection
log_info "------------------------------------------------------------------"
log_info "Demonstrating Resilient Detection of Corrupted Archive"
log_info "------------------------------------------------------------------"
LATEST_ARCHIVE="$(find "${REPO_DIR}/" -maxdepth 1 -name "incr_*.tar.gz" | sort | tail -n 1)"
CORRUPT_DEMO="${REPO_DIR}/corrupt_tamper_demo.tar.gz"

log_info "Creating test clone of archive: $(basename "${LATEST_ARCHIVE}") -> corrupt_tamper_demo.tar.gz"
cp "${LATEST_ARCHIVE}" "${CORRUPT_DEMO}"
cp "${LATEST_ARCHIVE}.sha256" "${CORRUPT_DEMO}.sha256"
sed -i "s/$(basename "${LATEST_ARCHIVE}")/corrupt_tamper_demo.tar.gz/g" "${CORRUPT_DEMO}.sha256"

log_info "Injecting deliberate bit-flip corruption at offset 128 (dd conv=notrunc)..."
printf "\xDE\xAD\xBE\xEF" | dd of="${CORRUPT_DEMO}" bs=1 count=4 seek=128 conv=notrunc status=none

log_info "Running verify_backup.sh against tampered archive..."
if bash "${SCRIPT_DIR}/verify_backup.sh" "${CORRUPT_DEMO}" >/dev/null 2>&1; then
    log_error "FAILURE: Tampered archive passed verification unexpectedly!"
else
    log_success "CORRUPTION DETECTED PROMPTLY: Verification engine blocked corrupted archive [OK]."
fi

# Clean up temporary tamper demonstration files
safe_rm_rf "${CORRUPT_DEMO}"
safe_rm_rf "${CORRUPT_DEMO}.sha256"
log_info "Corrupted demo archive safely cleaned up."

# Persist test results for report generation
cat << EOF > "${TEST_RESULT_FILE}"
RECOVERY_STATUS="${TEST_VERDICT}"
TOTAL_EXPECTED="${TOTAL_FILES_PRE}"
TOTAL_RESTORED="${TOTAL_RESTORED}"
MATCHED_COUNT="${MATCHED_COUNT}"
MISSING_COUNT="${MISSING_COUNT}"
MISMATCHED_COUNT="${MISMATCHED_COUNT}"
LAST_TEST_TIMESTAMP="$(get_iso_timestamp)"
EOF

if [[ "${TEST_VERDICT}" != "PASS" ]]; then
    exit 1
fi
exit 0
