#!/usr/bin/env bash
# ==============================================================================
# Script Name   : restore.sh
# Description   : Phase 3 - Disaster Recovery & Point-in-Time Restoration Engine
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

TARGET_DIR="${1:-${RESTORE_DIR}}"

# Path Guard: Target must be non-empty and strictly reside within DP_02/sandbox_data/
assert_sandbox_path "${TARGET_DIR}"

log_info "======================================================================"
log_info "Initiating NovaTech Centralized Recovery & Restoration Engine"
log_info "Target Directory: ${TARGET_DIR}"
log_info "======================================================================"

# 1. Discover latest baseline full backup
LATEST_FULL="$(find "${REPO_DIR}/" -maxdepth 1 -name "full_*.tar.gz" -printf "%f\n" 2>/dev/null | sort | tail -n 1 || true)"

if [[ -z "${LATEST_FULL}" ]]; then
    log_error "RESTORE ABORTED: No full backup baseline found in repository (${REPO_DIR})."
    exit 1
fi

FULL_PATH="${REPO_DIR}/${LATEST_FULL}"
FULL_TS="${LATEST_FULL#full_}"
FULL_TS="${FULL_TS%.tar.gz}"

log_info "Identified Baseline Full Backup: ${LATEST_FULL} (Timestamp: ${FULL_TS})"

# 2. Discover all incremental backups subsequent to this full backup
INCR_CHAIN=()
while IFS= read -r incr_file; do
    if [[ -n "${incr_file}" ]]; then
        incr_name="$(basename "${incr_file}")"
        incr_ts="${incr_name#incr_}"
        incr_ts="${incr_ts%.tar.gz}"
        if [[ "${incr_ts}" > "${FULL_TS}" ]]; then
            INCR_CHAIN+=("${incr_file}")
        fi
    fi
done < <(find "${REPO_DIR}/" -maxdepth 1 -name "incr_*.tar.gz" | sort)

log_info "Identified ${#INCR_CHAIN[@]} incremental backup archive(s) in recovery chain."

# 3. Cryptographic and Integrity Pre-Flight Validation
# In an enterprise environment, restoring corrupt archives compounds disaster.
# Every archive must pass SHA-256 and tar readability checks before extraction starts.
log_info "Executing Pre-Flight Cryptographic Checksum Verification..."

TOTAL_ARCHIVES=("${FULL_PATH}" "${INCR_CHAIN[@]}")

for archive_file in "${TOTAL_ARCHIVES[@]}"; do
    archive_name="$(basename "${archive_file}")"
    checksum_file="${archive_file}.sha256"

    log_info "  Verifying: ${archive_name}..."
    if [[ ! -f "${checksum_file}" ]]; then
        log_error "RESTORE ABORTED: Missing cryptographic checksum manifest for ${archive_name}"
        exit 1
    fi

    if ! (cd "${REPO_DIR}" && sha256sum -c "${archive_name}.sha256" >/dev/null 2>&1); then
        log_error "SECURITY ALERT: CHECKSUM CORRUPTION DETECTED on ${archive_name}!"
        log_error "Restore aborted immediately to prevent state corruption."
        exit 1
    fi

    if ! tar -tzf "${archive_file}" >/dev/null 2>&1; then
        log_error "RECOVERY FAILURE: Archive structure corrupted for ${archive_name}"
        exit 1
    fi
done
log_success "Pre-Flight Verification PASSED: All ${#TOTAL_ARCHIVES[@]} archive(s) verified authentic."

# 4. Prepare Destination Sandbox Target
mkdir -p "${TARGET_DIR}"

# 5. Step A: Extract Baseline Full Backup
START_TIME="$(date +%s)"
log_info "Stage 1: Extracting Full Baseline (${LATEST_FULL}) into target sandbox..."
tar --listed-incremental=/dev/null -xzf "${FULL_PATH}" -C "${TARGET_DIR}"
log_success "Full baseline restored successfully."

# 6. Step B: Sequentially Extract Incremental Archives in Chronological Order
if [[ ${#INCR_CHAIN[@]} -gt 0 ]]; then
    log_info "Stage 2: Replaying ${#INCR_CHAIN[@]} incremental archive(s)..."
    STEP_IDX=1
    for incr_path in "${INCR_CHAIN[@]}"; do
        incr_name="$(basename "${incr_path}")"
        log_info "  Replaying [${STEP_IDX}/${#INCR_CHAIN[@]}]: ${incr_name}..."
        # Extracting with --listed-incremental=/dev/null applies file modifications and removals
        tar --listed-incremental=/dev/null -xzf "${incr_path}" -C "${TARGET_DIR}"
        STEP_IDX=$((STEP_IDX + 1))
    done
    log_success "All incremental revisions replayed successfully."
fi

END_TIME="$(date +%s)"
DURATION=$((END_TIME - START_TIME))

RESTORED_COUNT="$(find "${TARGET_DIR}" -type f | wc -l)"
RESTORED_BYTES="$(du -sb "${TARGET_DIR}" | awk '{print $1}')"

log_success "Point-in-Time Restoration Complete in ${DURATION}s."
log_success "Target Directory : ${TARGET_DIR}"
log_success "Restored Files   : ${RESTORED_COUNT} files ($(format_bytes "${RESTORED_BYTES}"))"
