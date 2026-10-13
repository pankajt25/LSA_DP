#!/usr/bin/env bash
# ==============================================================================
# Script Name   : run.sh
# Description   : Master End-to-End Orchestrator for DP_03 Deployment, Validation & Reporting
# Project       : Department File Server (DP_03)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

cd "$(dirname "$0")"
PROJECT_DIR="$(pwd -P)"

# shellcheck source=scripts/lib.sh
source "${PROJECT_DIR}/scripts/lib.sh"

echo -e "${COLOR_BOLD}${COLOR_CYAN}================================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}     NovaTech Solutions — Department File Server Master Orchestrator            ${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}================================================================================${COLOR_RESET}"
echo ""

# Authenticate sudo early once so password is requested upfront
if sudo -n true 2>/dev/null; then
    log_info "Administrative sudo credentials verified."
else
    log_info "Verifying administrative sudo credentials..."
    sudo -v
fi

# Ensure base sandbox and logs directories exist
mkdir -p "${SANDBOX_DIR}/mnt" "${LOGS_DIR}" "${PROJECT_DIR}/docs"

# 1. Phase 0: Preflight Audit & Kernel Quota Detection
log_info "[Phase 0] Executing Preflight Environment & Kernel Quota Audit (preflight.sh)..."
bash "${PROJECT_DIR}/scripts/preflight.sh"

# 2. Phase 1: Storage Allocation & Mount Setup
log_info "[Phase 1] Executing Storage Allocation & Loopback Filesystem Mount (setup_storage.sh)..."
bash "${PROJECT_DIR}/scripts/setup_storage.sh"

# 3. Phase 2: RBAC Identities, Groups & Base Permissions
log_info "[Phase 2] Provisioning Department Identities, Groups & SetGID (setup_identity.sh)..."
bash "${PROJECT_DIR}/scripts/setup_identity.sh"

# 4. Phase 3: POSIX Access & Default ACLs
log_info "[Phase 3] Applying Departmental POSIX Access & Default ACLs (setup_acl.sh)..."
bash "${PROJECT_DIR}/scripts/setup_acl.sh"

# 5. Phase 4: Quota Allocation (Users & Groups)
log_info "[Phase 4] Provisioning Native Kernel Quotas & Grace Periods (setup_quota.sh)..."
bash "${PROJECT_DIR}/scripts/setup_quota.sh"

# 6. Phase 5: Comprehensive 8-Point Testing Suite
log_info "[Phase 5] Executing Comprehensive 8-Point File Server Test Suite (run_tests.sh)..."
bash "${PROJECT_DIR}/scripts/run_tests.sh"

# 7. Phase 6: Automated Security & Permission Baseline Audit
log_info "[Phase 6] Executing Security Review & Permission Audit (security_check.sh)..."
bash "${PROJECT_DIR}/scripts/security_check.sh"

# 8. HTML Audit Report Generation
log_info "Regenerating comprehensive self-contained HTML audit report from live state..."
bash "${PROJECT_DIR}/scripts/generate_report.sh"

echo ""
echo -e "${COLOR_BOLD}${COLOR_GREEN}================================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_GREEN}          DEPLOYMENT PROJECT 03 EXECUTION COMPLETE [PASS - 8/8 TESTS]           ${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_GREEN}================================================================================${COLOR_RESET}"
echo ""

# 9. Cross-Platform Report Launch
REPORT_FILE="${PROJECT_DIR}/report.html"
log_info "Opening HTML Report (${REPORT_FILE})..."

if grep -qi microsoft /proc/version 2>/dev/null; then
    WIN_PATH="$(wslpath -w "${REPORT_FILE}" 2>/dev/null || echo "")"
    if [[ -n "${WIN_PATH}" ]] && command -v explorer.exe >/dev/null 2>&1; then
        log_info "WSL detected. Launching Windows host browser via explorer.exe..."
        explorer.exe "${WIN_PATH}" >/dev/null 2>&1 || true
    else
        log_info "Report generated at: ${REPORT_FILE}"
    fi
elif [[ "$OSTYPE" == "darwin"* ]] && command -v open >/dev/null 2>&1; then
    open "${REPORT_FILE}"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "${REPORT_FILE}" >/dev/null 2>&1 || true
elif command -v start >/dev/null 2>&1; then
    start "" "${REPORT_FILE}" >/dev/null 2>&1 || true
else
    log_info "Report path: ${REPORT_FILE}"
fi

echo ""
log_success "All department shares, quotas, ACLs, and test verifications completed successfully."
log_info "View the live report in your browser or run: explorer.exe \"\$(wslpath -w report.html)\""
