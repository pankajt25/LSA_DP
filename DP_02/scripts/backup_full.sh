#!/usr/bin/env bash
# ==============================================================================
# Script Name   : backup_full.sh
# Description   : Phase 2 - Level 0 Full Backup Engine with GNU Tar Listed-Incremental
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_info "======================================================================"
log_info "Initiating NovaTech Centralized FULL Backup (Level 0 Baseline)"
log_info "======================================================================"

# 1. Path guards
assert_sandbox_path "${SOURCE_DIR}"
assert_sandbox_path "${REPO_DIR}"

# 2. Source validation
if [[ ! -d "${SOURCE_DIR}" ]]; then
    log_error "Validation Failure: Source directory does not exist: ${SOURCE_DIR}"
    exit 1
fi

FILE_COUNT="$(find "${SOURCE_DIR}" -type f | wc -l)"
if [[ "${FILE_COUNT}" -eq 0 ]]; then
    log_error "Validation Failure: Source directory is empty. Nothing to back up."
    exit 1
fi
log_info "Source validated: ${FILE_COUNT} files detected across department shares."

# 3. Ensure repository exists and check available storage capacity
mkdir -p "${REPO_DIR}" "${META_DIR}"
if ! check_repo_space 20480; then # Require at least 20MB free
    log_error "Backup aborted: Insufficient disk space in repository."
    exit 1
fi

# 4. Generate timestamp and archive filenames
TS="$(date +'%Y%m%d_%H%M%S')"
ARCHIVE_NAME="full_${TS}.tar.gz"
ARCHIVE_PATH="${REPO_DIR}/${ARCHIVE_NAME}"
CHECKSUM_FILE="${ARCHIVE_PATH}.sha256"
CYCLE_SNAR="${META_DIR}/${ARCHIVE_NAME}.snar"
META_FILE="${META_DIR}/${ARCHIVE_NAME}.meta"

log_info "Target Archive: ${ARCHIVE_NAME}"
log_info "Snapshot File : ${ACTIVE_SNAR}"

# 5. Reset snapshot file for pristine Level 0 baseline
# Removing active.snar instructs GNU tar to create a fresh Level 0 manifest
safe_rm_rf "${ACTIVE_SNAR}"

# 6. Execute GNU tar with --listed-incremental
START_TIME="$(date +%s)"
log_info "Executing GNU tar Level 0 baseline snapshot..."

tar --listed-incremental="${ACTIVE_SNAR}" \
    -czf "${ARCHIVE_PATH}" \
    -C "${SOURCE_DIR}" .

END_TIME="$(date +%s)"
DURATION=$((END_TIME - START_TIME))

# Preserve a dedicated copy of the initial snar file for this full backup cycle
cp -p "${ACTIVE_SNAR}" "${CYCLE_SNAR}"

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
    log_error "CRITICAL INTEGRITY FAILURE: Newly created archive failed SHA-256 verification!"
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
TYPE=FULL
TIMESTAMP=${TS}
ARCHIVE_NAME=${ARCHIVE_NAME}
ARCHIVE_PATH=${ARCHIVE_PATH}
SHA256=${CHECKSUM_VAL}
BYTES=${ARCHIVE_SIZE}
FILES_PROTECTED=${FILE_COUNT}
DURATION_SECONDS=${DURATION}
PARENT_FULL=SELF
EOF

log_success "FULL backup completed successfully in ${DURATION}s."
log_success "Archive: ${ARCHIVE_NAME} | Size: $(format_bytes "${ARCHIVE_SIZE}") | SHA256: ${CHECKSUM_VAL:0:16}..."
