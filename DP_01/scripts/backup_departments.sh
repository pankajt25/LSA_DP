#!/usr/bin/env bash
# ==============================================================================
# Script Name   : backup_departments.sh
# Description   : Automated Backup Engine for NovaTech Departmental Storage
# Project       : Enterprise Storage Infrastructure (DP_01)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_info "======================================================================"
log_info "Initiating NovaTech Multi-Departmental Backup Suite"
log_info "======================================================================"

# Path guards
assert_sandbox_path "${MNT_DIR}"
assert_sandbox_path "${BACKUP_DIR}"

mkdir -p "${BACKUP_DIR}"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
DEPARTMENTS=("hr" "finance" "eng" "sales")

TOTAL_DEPT=${#DEPARTMENTS[@]}
SUCCESSFUL=0
FAILED=0

for dept in "${DEPARTMENTS[@]}"; do
    dept_src="${MNT_DIR}/${dept}"
    archive_name="${dept}_backup_${TIMESTAMP}.tar.gz"
    archive_path="${BACKUP_DIR}/${archive_name}"
    checksum_path="${archive_path}.sha256"

    log_info "Processing department: [${dept}]..."
    if [[ ! -d "${dept_src}" ]]; then
        log_error "Source directory does not exist: ${dept_src}"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Create compressed archive
    log_info "  Archiving ${dept_src} -> ${archive_name}..."
    sudo tar -czf "${archive_path}" -C "${dept_src}" .

    # Generate SHA-256 manifest
    (
        cd "${BACKUP_DIR}"
        sha256sum "${archive_name}" > "${archive_name}.sha256"
    )

    # Validate post-backup integrity
    if (cd "${BACKUP_DIR}" && sha256sum -c "${archive_name}.sha256" >/dev/null 2>&1) && tar -tzf "${archive_path}" >/dev/null 2>&1; then
        sudo chmod 600 "${archive_path}" "${checksum_path}"
        sudo chown "$(id -u):$(id -g)" "${archive_path}" "${checksum_path}"
        archive_size="$(stat -c%s "${archive_path}")"
        log_success "  Backup created & verified: ${archive_name} ($(format_bytes "${archive_size}"))"
        SUCCESSFUL=$((SUCCESSFUL + 1))
    else
        log_error "  Integrity verification failed for ${archive_name}"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
log_info "======================================================================"
log_info "Backup Summary: ${SUCCESSFUL}/${TOTAL_DEPT} departments archived successfully."
log_info "======================================================================"

if [[ "${FAILED}" -gt 0 ]]; then
    exit 1
fi
exit 0
