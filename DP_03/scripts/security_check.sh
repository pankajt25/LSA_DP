#!/usr/bin/env bash
# ==============================================================================
# Script Name   : security_check.sh
# Description   : Phase 6 - Automated Security Audit, Permission & Integrity Check
# Project       : Department File Server (DP_03)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_section "Phase 6: File Server Security & Compliance Audit"

SECURITY_LOG="${LOGS_DIR}/security_audit.log"
{
    echo "================================================================================"
    echo "Phase 6 Security Audit Execution: $(get_iso_timestamp)"
    echo "================================================================================"
} > "${SECURITY_LOG}"

SECURITY_FINDINGS=0
SECURITY_FIXES=0

# Check 1: World-Writable Files Audit
log_info "[Audit 1/4] Scanning for world-writable files (o+w)..."
WORLD_WRITABLE_FILES="$(sudo find "${MNT_FILESERVER}" -type f -perm -0002 2>/dev/null || true)"
if [[ -n "${WORLD_WRITABLE_FILES}" ]]; then
    log_warn "SECURITY FINDING: Found world-writable files:"
    echo "${WORLD_WRITABLE_FILES}"
    echo "FINDING: World-writable files detected: ${WORLD_WRITABLE_FILES}" >> "${SECURITY_LOG}"
    SECURITY_FINDINGS=$((SECURITY_FINDINGS + 1))
    
    # Auto-remediation: revoke world write
    while IFS= read -r f; do
        if [[ -n "${f}" ]]; then
            sudo chmod o-w "${f}"
            SECURITY_FIXES=$((SECURITY_FIXES + 1))
        fi
    done <<< "${WORLD_WRITABLE_FILES}"
    log_success "Remediated: Revoked world-write permissions."
else
    log_success "Audit 1 PASSED: Zero world-writable files detected."
    echo "Audit 1: PASS (No world-writable files)" >> "${SECURITY_LOG}"
fi

# Check 2: World-Writable Directories without Sticky Bit
log_info "[Audit 2/4] Scanning for world-writable directories without sticky bit (+t)..."
WW_DIRS_NO_STICKY="$(sudo find "${MNT_FILESERVER}" -type d -perm -0002 ! -perm -1000 2>/dev/null || true)"
if [[ -n "${WW_DIRS_NO_STICKY}" ]]; then
    log_warn "SECURITY FINDING: Found world-writable directories lacking sticky bit: ${WW_DIRS_NO_STICKY}"
    echo "FINDING: World-writable dirs without sticky bit: ${WW_DIRS_NO_STICKY}" >> "${SECURITY_LOG}"
    SECURITY_FINDINGS=$((SECURITY_FINDINGS + 1))
    
    while IFS= read -r d; do
        if [[ -n "${d}" ]]; then
            sudo chmod +t "${d}"
            SECURITY_FIXES=$((SECURITY_FIXES + 1))
        fi
    done <<< "${WW_DIRS_NO_STICKY}"
    log_success "Remediated: Applied sticky bit."
else
    log_success "Audit 2 PASSED: Zero unprotected world-writable directories found."
    echo "Audit 2: PASS (No vulnerable directories)" >> "${SECURITY_LOG}"
fi

# Check 3: Orphan Files (No Valid User or Group)
log_info "[Audit 3/4] Scanning for orphaned files (-nouser or -nogroup)..."
ORPHAN_FILES="$(sudo find "${MNT_FILESERVER}" \( -nouser -o -nogroup \) 2>/dev/null || true)"
if [[ -n "${ORPHAN_FILES}" ]]; then
    log_warn "SECURITY FINDING: Orphan files detected lacking valid UID/GID:"
    echo "${ORPHAN_FILES}"
    echo "FINDING: Orphan files: ${ORPHAN_FILES}" >> "${SECURITY_LOG}"
    SECURITY_FINDINGS=$((SECURITY_FINDINGS + 1))
else
    log_success "Audit 3 PASSED: Zero orphaned files found; all files mapped to active directory identities."
    echo "Audit 3: PASS (No orphaned objects)" >> "${SECURITY_LOG}"
fi

# Check 4: Department Root Directory Permissions & Other Isolation
log_info "[Audit 4/4] Verifying department directory permissions (Others=0 / no access)..."
for d in "${DIR_FINANCE}" "${DIR_HR}" "${DIR_ENG}" "${DIR_SALES}"; do
    octal_perm="$(sudo stat -c "%a" "${d}")"
    other_digit="${octal_perm: -1}"
    if [[ "${other_digit}" != "0" ]]; then
        log_warn "SECURITY FINDING: Directory $(basename "${d}") has loose other-permissions: ${octal_perm}"
        echo "FINDING: Loose perms on $(basename "${d}"): ${octal_perm}" >> "${SECURITY_LOG}"
        SECURITY_FINDINGS=$((SECURITY_FINDINGS + 1))
        sudo chmod o-rwx "${d}"
        SECURITY_FIXES=$((SECURITY_FIXES + 1))
    else
        log_success "Directory $(basename "${d}")/ is strictly isolated (Mode: ${octal_perm}, Others: ---)."
        echo "Audit 4: PASS ($(basename "${d}") Mode ${octal_perm})" >> "${SECURITY_LOG}"
    fi
done

# Step 5: Summary Reporting
log_section "Security Audit Summary"
echo "Total Findings Discovered: ${SECURITY_FINDINGS}"
echo "Total Remediations Applied: ${SECURITY_FIXES}"
echo "Findings: ${SECURITY_FINDINGS}, Fixed: ${SECURITY_FIXES}" >> "${SECURITY_LOG}"

if [[ ${SECURITY_FINDINGS} -eq 0 ]] || [[ ${SECURITY_FINDINGS} -eq ${SECURITY_FIXES} ]]; then
    log_success "Phase 6 Security Audit COMPLETE: System complies 100% with enterprise security baseline."
else
    log_error "Unresolved security findings remain. Review ${SECURITY_LOG}"
    exit 1
fi
