#!/usr/bin/env bash
# ==============================================================================
# Script Name   : run.sh
# Description   : Master End-to-End Orchestrator for DP_01 Deployment, Validation & Reporting
# Project       : Enterprise Storage Infrastructure (DP_01)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

cd "$(dirname "$0")"
PROJECT_DIR="$(pwd -P)"

# shellcheck source=scripts/lib.sh
source "${PROJECT_DIR}/scripts/lib.sh"

echo -e "${COLOR_BOLD}${COLOR_CYAN}================================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}     NovaTech Solutions — Enterprise Storage Infrastructure Master Suite        ${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}================================================================================${COLOR_RESET}"
echo ""

# Ensure base sandbox and logs directories exist
mkdir -p "${SANDBOX_DIR}"/{disks,mnt,backup} "${PROJECT_DIR}/logs"

# 1. Execute Storage Setup Pipeline
log_info "[Phase 1] Executing Automated Storage Infrastructure Setup (storage_setup.sh)..."
bash "${PROJECT_DIR}/scripts/storage_setup.sh"

# 2. Execute Live Online Volume Elasticity Demonstration
log_info "[Phase 2] Executing Live Online LVM Elasticity Demonstration (live_elasticity_demo.sh)..."
bash "${PROJECT_DIR}/scripts/live_elasticity_demo.sh"

# 3. Execute Departmental Backup Pipeline
log_info "[Phase 3] Executing Multi-Departmental Backup Suite (backup_departments.sh)..."
bash "${PROJECT_DIR}/scripts/backup_departments.sh"

# 4. Execute Backup Integrity Verification
log_info "[Phase 4] Verifying Departmental Backup Archives (verify_backup.sh)..."
bash "${PROJECT_DIR}/scripts/verify_backup.sh"

# 5. Execute Comprehensive Infrastructure Validation Suite
log_info "[Phase 5] Executing Comprehensive Infrastructure Validation Suite (validate_infrastructure.sh)..."
bash "${PROJECT_DIR}/scripts/validate_infrastructure.sh"

# 6. Regenerate HTML Report from Scratch with Live State
log_info "Regenerating comprehensive HTML audit report from live state..."
bash "${PROJECT_DIR}/scripts/generate_report.sh"

echo ""
echo -e "${COLOR_BOLD}${COLOR_GREEN}================================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_GREEN}             DEPLOYMENT PROJECT 01 EXECUTION COMPLETE [PASS - 5/5 TESTS]        ${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_GREEN}================================================================================${COLOR_RESET}"
echo ""

# 7. Cross-Platform Report Opening
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
log_success "All infrastructure setup, elasticity, and validation tasks completed successfully."
log_info "View the live report in your browser or run: explorer.exe \"\$(wslpath -w report.html)\""
