#!/usr/bin/env bash
# ==============================================================================
# Script Name   : run.sh
# Description   : Master End-to-End Orchestrator for DP_02 Verification & Reporting
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

# 1. Change to DP_02 project directory
cd "$(dirname "$0")"
PROJECT_DIR="$(pwd -P)"

# shellcheck source=scripts/lib.sh
source "${PROJECT_DIR}/scripts/lib.sh"

echo -e "${COLOR_BOLD}${COLOR_CYAN}================================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}     NovaTech Solutions — Centralized Backup & Recovery Verification Suite      ${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}================================================================================${COLOR_RESET}"
echo ""

# Ensure repository and sandbox structures exist
mkdir -p "${SANDBOX_DIR}"/{source,repo,restore_target}
mkdir -p "${PROJECT_DIR}/logs"

# 2. Ensure initial dataset exists
if [[ ! -d "${SOURCE_DIR}/finance" ]]; then
    log_info "[Phase 1] Seeding initial departmental dataset..."
    bash "${PROJECT_DIR}/scripts/seed_data.sh"
fi

# 3. Execute Core Disaster Recovery Verification Suite
# Performs full backup, mutations, incrementals, disaster simulation, restore, and diff verification
log_info "[Phase 3] Executing Disaster Recovery Validation Suite (recovery_test.sh)..."
bash "${PROJECT_DIR}/scripts/recovery_test.sh"

# 4. Execute Full Repository Archive Integrity Verification
log_info "[Phase 2] Executing Full Repository Integrity Verification (verify_backup.sh)..."
bash "${PROJECT_DIR}/scripts/verify_backup.sh"

# 5. Execute Retention Policy Dry-Run Evaluation
log_info "[Phase 2] Executing Retention Policy Dry-Run Evaluation (retention.sh --dry-run)..."
bash "${PROJECT_DIR}/scripts/retention.sh" --dry-run

# 6. Regenerate HTML Report from scratch with live system state
log_info "Regenerating comprehensive HTML audit report from live state..."
bash "${PROJECT_DIR}/scripts/generate_report.sh"

echo ""
echo -e "${COLOR_BOLD}${COLOR_GREEN}================================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_GREEN}               DEPLOYMENT PROJECT 02 EXECUTION COMPLETE [PASS]                  ${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_GREEN}================================================================================${COLOR_RESET}"
echo ""

# 7. Cross-Platform Report Opening
REPORT_FILE="${PROJECT_DIR}/report.html"
log_info "Opening HTML Report (${REPORT_FILE})..."

if grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL Environment detected: Use Windows explorer.exe via wslpath
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
log_success "All validation tasks executed successfully."
log_info "View the live report in your browser or run: explorer.exe \"\$(wslpath -w report.html)\""
