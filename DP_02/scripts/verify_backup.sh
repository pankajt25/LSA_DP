#!/usr/bin/env bash
# ==============================================================================
# Script Name   : verify_backup.sh
# Description   : Phase 2 - Archive Integrity and Decompression Verification Engine
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

SPECIFIC_ARCHIVE="${1:-}"

assert_sandbox_path "${REPO_DIR}"

log_info "======================================================================"
log_info "Running NovaTech Backup Integrity Verification"
log_info "======================================================================"

ARCHIVES_TO_CHECK=()

if [[ -n "${SPECIFIC_ARCHIVE}" ]]; then
    if [[ ! -f "${SPECIFIC_ARCHIVE}" ]]; then
        log_error "Specified archive does not exist: ${SPECIFIC_ARCHIVE}"
        exit 1
    fi
    ARCHIVES_TO_CHECK+=("${SPECIFIC_ARCHIVE}")
else
    # Discover all archives in repository
    while IFS= read -r archive_file; do
        if [[ -n "${archive_file}" ]]; then
            ARCHIVES_TO_CHECK+=("${archive_file}")
        fi
    done < <(find "${REPO_DIR}/" -maxdepth 1 \( -name "full_*.tar.gz" -o -name "incr_*.tar.gz" \) | sort)
fi

if [[ ${#ARCHIVES_TO_CHECK[@]} -eq 0 ]]; then
    log_warn "No backup archives found in repository (${REPO_DIR})."
    exit 0
fi

log_info "Evaluating ${#ARCHIVES_TO_CHECK[@]} archive(s) for cryptographic and structural validity..."
echo ""
printf "%-32s | %-10s | %-12s | %-12s | %s\n" "ARCHIVE FILENAME" "SIZE" "SHA256 CHECKSUM" "TAR INTEGRITY" "RESULT"
printf "%s\n" "------------------------------------------------------------------------------------------------"

TOTAL_CHECKED=0
TOTAL_PASSED=0
TOTAL_FAILED=0

for archive_path in "${ARCHIVES_TO_CHECK[@]}"; do
    TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
    archive_filename="$(basename "${archive_path}")"
    archive_dir="$(dirname "${archive_path}")"
    checksum_file="${archive_path}.sha256"
    size_bytes="$(stat -c%s "${archive_path}" 2>/dev/null || echo 0)"
    size_formatted="$(format_bytes "${size_bytes}")"

    sha_status="FAIL"
    tar_status="FAIL"
    final_verdict="CORRUPT"

    # Step 1: Check if .sha256 manifest exists and verify checksum
    if [[ -f "${checksum_file}" ]]; then
        if (cd "${archive_dir}" && sha256sum -c "${archive_filename}.sha256" >/dev/null 2>&1); then
            sha_status="VALID"
        else
            sha_status="MISMATCH"
        fi
    else
        sha_status="NO_MANIFEST"
    fi

    # Step 2: Test tar structural integrity and decompression
    if tar -tzf "${archive_path}" >/dev/null 2>&1; then
        tar_status="VALID"
    else
        tar_status="CORRUPT"
    fi

    # Determine final verdict
    if [[ "${sha_status}" == "VALID" && "${tar_status}" == "VALID" ]]; then
        final_verdict="OK"
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
        printf "%-32s | %-10s | ${COLOR_GREEN}%-15s${COLOR_RESET} | ${COLOR_GREEN}%-13s${COLOR_RESET} | ${COLOR_GREEN}%s${COLOR_RESET}\n" \
            "${archive_filename}" "${size_formatted}" "${sha_status}" "${tar_status}" "[OK]"
        log_info "VERIFICATION PASS: ${archive_filename} (SHA256: VALID, TAR: VALID)"
    else
        final_verdict="CORRUPT"
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        printf "%-32s | %-10s | ${COLOR_RED}%-15s${COLOR_RESET} | ${COLOR_RED}%-13s${COLOR_RESET} | ${COLOR_RED}%s${COLOR_RESET}\n" \
            "${archive_filename}" "${size_formatted}" "${sha_status}" "${tar_status}" "[CORRUPT]"
        log_error "VERIFICATION FAILED: ${archive_filename} (SHA256: ${sha_status}, TAR: ${tar_status})"
    fi
done

echo ""
printf "%s\n" "------------------------------------------------------------------------------------------------"
log_info "Verification Summary: Total: ${TOTAL_CHECKED} | Passed: ${TOTAL_PASSED} | Failed: ${TOTAL_FAILED}"

if [[ "${TOTAL_FAILED}" -gt 0 ]]; then
    log_error "Integrity audit completed with ERRORS: ${TOTAL_FAILED} archive(s) CORRUPT."
    exit 1
else
    log_success "Integrity audit completed: ALL archives verified intact and authentic [OK]."
    exit 0
fi
