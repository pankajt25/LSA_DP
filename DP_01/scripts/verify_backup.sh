#!/usr/bin/env bash
# ==============================================================================
# Script Name   : verify_backup.sh
# Description   : Cryptographic Integrity & Archive Readability Verification Engine
# Project       : Enterprise Storage Infrastructure (DP_01)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

assert_sandbox_path "${BACKUP_DIR}"

log_info "======================================================================"
log_info "Running NovaTech Departmental Backup Integrity Verification"
log_info "======================================================================"

mapfile -t ARCHIVES < <(find "${BACKUP_DIR}/" -maxdepth 1 -name "*_backup_*.tar.gz" | sort)

if [[ ${#ARCHIVES[@]} -eq 0 ]]; then
    log_warn "No departmental backup archives found in ${BACKUP_DIR}."
    exit 0
fi

log_info "Auditing ${#ARCHIVES[@]} archive(s) for SHA-256 parity and tar header health..."
echo ""
printf "%-32s | %-10s | %-15s | %-12s | %s\n" "ARCHIVE FILENAME" "SIZE" "SHA256 CHECKSUM" "TAR INTEGRITY" "RESULT"
printf "%s\n" "------------------------------------------------------------------------------------------------"

TOTAL_CHECKED=0
TOTAL_PASSED=0
TOTAL_FAILED=0

for archive_path in "${ARCHIVES[@]}"; do
    TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
    archive_filename="$(basename "${archive_path}")"
    checksum_file="${archive_path}.sha256"
    size_bytes="$(stat -c%s "${archive_path}" 2>/dev/null || echo 0)"
    size_formatted="$(format_bytes "${size_bytes}")"

    sha_status="FAIL"
    tar_status="FAIL"

    if [[ -f "${checksum_file}" ]]; then
        if (cd "${BACKUP_DIR}" && sha256sum -c "${archive_filename}.sha256" >/dev/null 2>&1); then
            sha_status="VALID"
        else
            sha_status="MISMATCH"
        fi
    else
        sha_status="NO_MANIFEST"
    fi

    if tar -tzf "${archive_path}" >/dev/null 2>&1; then
        tar_status="VALID"
    else
        tar_status="CORRUPT"
    fi

    if [[ "${sha_status}" == "VALID" && "${tar_status}" == "VALID" ]]; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
        printf "%-32s | %-10s | ${COLOR_GREEN}%-15s${COLOR_RESET} | ${COLOR_GREEN}%-12s${COLOR_RESET} | ${COLOR_GREEN}%s${COLOR_RESET}\n" \
            "${archive_filename}" "${size_formatted}" "${sha_status}" "${tar_status}" "[OK]"
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        printf "%-32s | %-10s | ${COLOR_RED}%-15s${COLOR_RESET} | ${COLOR_RED}%-12s${COLOR_RESET} | ${COLOR_RED}%s${COLOR_RESET}\n" \
            "${archive_filename}" "${size_formatted}" "${sha_status}" "${tar_status}" "[CORRUPT]"
    fi
done

echo ""
printf "%s\n" "------------------------------------------------------------------------------------------------"
log_info "Audit Summary: Total: ${TOTAL_CHECKED} | Passed: ${TOTAL_PASSED} | Failed: ${TOTAL_FAILED}"

if [[ "${TOTAL_FAILED}" -gt 0 ]]; then
    log_error "Integrity audit completed with ERRORS: ${TOTAL_FAILED} archive(s) CORRUPT."
    exit 1
else
    log_success "Integrity audit completed: ALL departmental archives verified intact and authentic [OK]."
    exit 0
fi
