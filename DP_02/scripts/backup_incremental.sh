#!/usr/bin/env bash
# ==============================================================================
# Script Name   : backup_incremental.sh
# Description   : Phase 2 - Incremental Backup Engine with GNU Tar Listed-Incremental
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_info "======================================================================"
log_info "Initiating NovaTech Centralized INCREMENTAL Backup"
log_info "======================================================================"

# 1. Path guards
assert_sandbox_path "${SOURCE_DIR}"
assert_sandbox_path "${REPO_DIR}"

# 2. Source validation
if [[ ! -d "${SOURCE_DIR}" ]]; then
    log_error "Validation Failure: Source directory does not exist: ${SOURCE_DIR}"
    exit 1
fi

# 3. Check for mandatory baseline full backup
# We must refuse to run if no full backup exists (do not silently create a full)
LATEST_FULL="$(find "${REPO_DIR}/" -maxdepth 1 -name "full_*.tar.gz" -printf "%f\n" 2>/dev/null | sort | tail -n 1 || true)"

if [[ -z "${LATEST_FULL}" || ! -f "${ACTIVE_SNAR}" ]]; then
    log_error "MANDATORY BASELINE MISSING: No full backup found in repository."
    log_error "Active snapshot manifest (${ACTIVE_SNAR}) not initialized."
    log_error "Incremental backup refused. You must execute backup_full.sh before running incrementals."
    exit 2
fi

log_info "Baseline full backup verified: ${LATEST_FULL}"
log_info "Active snapshot file detected: ${ACTIVE_SNAR}"

# 4. Check available storage capacity
if ! check_repo_space 10240; then # Require at least 10MB free
    log_error "Backup aborted: Insufficient disk space in repository."
    exit 1
fi

# 5. Generate timestamp and archive filenames
TS="$(date +'%Y%m%d_%H%M%S')"
ARCHIVE_NAME="incr_${TS}.tar.gz"
ARCHIVE_PATH="${REPO_DIR}/${ARCHIVE_NAME}"
CHECKSUM_FILE="${ARCHIVE_PATH}.sha256"
META_FILE="${META_DIR}/${ARCHIVE_NAME}.meta"

log_info "Target Archive: ${ARCHIVE_NAME}"

# 6. Execute GNU tar with --listed-incremental reusing the active snapshot
START_TIME="$(date +%s)"
log_info "Executing GNU tar incremental snapshot against ${ACTIVE_SNAR}..."

tar --listed-incremental="${ACTIVE_SNAR}" \
    -czf "${ARCHIVE_PATH}" \
    -C "${SOURCE_DIR}" .

END_TIME="$(date +%s)"
DURATION=$((END_TIME - START_TIME))

# 7. Generate SHA-256 Checksum Manifest
log_info "Generating SHA-256 cryptographic checksum manifest..."
(
    cd "${REPO_DIR}"
    sha256sum "${ARCHIVE_NAME}" > "${ARCHIVE_NAME}.sha256"
)
CHECKSUM_VAL="$(awk '{print $1}' "${CHECKSUM_FILE}")"
ARCHIVE_SIZE="$(stat -c%s "${ARCHIVE_PATH}")"

# 8. Immediate Post-Backup Integrity Verification
log_info "Verifying archive integrity with sha256sum -c and tar -tzf..."
if ! (cd "${REPO_DIR}" && sha256sum -c "${ARCHIVE_NAME}.sha256" >/dev/null 2>&1); then
    log_error "CRITICAL INTEGRITY FAILURE: Newly created incremental failed SHA-256 verification!"
    exit 1
fi

if ! tar -tzf "${ARCHIVE_PATH}" >/dev/null 2>&1; then
    log_error "CRITICAL ARCHIVE FAILURE: Archive structure corrupted or unreadable by tar!"
    exit 1
fi
log_success "Integrity verification PASSED: SHA-256 and tar decompression valid."

# 9. Apply strict POSIX file permissions (chmod 600)
chmod 600 "${ARCHIVE_PATH}" "${CHECKSUM_FILE}"

# 10. Record metadata for audit trail
cat << EOF > "${META_FILE}"
TYPE=INCREMENTAL
TIMESTAMP=${TS}
ARCHIVE_NAME=${ARCHIVE_NAME}
ARCHIVE_PATH=${ARCHIVE_PATH}
SHA256=${CHECKSUM_VAL}
BYTES=${ARCHIVE_SIZE}
DURATION_SECONDS=${DURATION}
PARENT_FULL=${LATEST_FULL}
EOF

log_success "INCREMENTAL backup completed successfully in ${DURATION}s."
log_success "Archive: ${ARCHIVE_NAME} | Size: $(format_bytes "${ARCHIVE_SIZE}") | SHA256: ${CHECKSUM_VAL:0:16}... (Parent: ${LATEST_FULL})"
