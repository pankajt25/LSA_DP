#!/usr/bin/env bash
# ==============================================================================
# Master Orchestrator — DP_04: Linux Disaster Recovery Solution
# Course: Linux System Administration (E1ITA307) — Modules: IV | CO4
# ==============================================================================

set -euo pipefail

# Always run from the project root directory
cd "$(dirname "$0")"
PROJECT_ROOT="$(pwd -P)"

# Source safety guards and logging helpers
source "${PROJECT_ROOT}/scripts/common.sh"

echo "=============================================================================="
echo " NOVA-TECH ENTERPRISE INFRASTRUCTURE — DISASTER RECOVERY ORCHESTRATOR (DP_04)"
echo "=============================================================================="

# 1. Request sudo credential validation once upfront
log_info "Requesting administrative privileges upfront..."
if ! sudo -n true 2>/dev/null; then
    sudo -v
fi

# Keep sudo timestamp updated during the execution
while true; do
    sudo -n true 2>/dev/null || true
    sleep 50
    kill -0 "$$" 2>/dev/null || exit
done 2>/dev/null &
SUDO_KEEP_ALIVE_PID=$!
trap 'kill "${SUDO_KEEP_ALIVE_PID}" 2>/dev/null || true' EXIT

# 2. Phase 0: Preflight Validation
log_info "=== [Phase 0] Running System & Kernel Preflight Validation ==="
bash "${PROJECT_ROOT}/scripts/preflight.sh"

# 3. Phase 1: Storage Lab Provisioning & Data Seeding
log_info "=== [Phase 1] Provisioning Storage Lab & Seeding Protected Dataset ==="
bash "${PROJECT_ROOT}/scripts/setup_lab.sh"

# 4. Phase 3: Disaster Recovery Scenarios (S1 through S5)
log_info "=== [Phase 3] Executing Scenario 1: Accidental File Deletion ==="
bash "${PROJECT_ROOT}/scripts/scenarios/s1_file_deletion.sh"

log_info "=== [Phase 3] Executing Scenario 2: Accidental Overwrite / Corruption ==="
bash "${PROJECT_ROOT}/scripts/scenarios/s2_overwrite_corruption.sh"

log_info "=== [Phase 3] Executing Scenario 3: Catastrophic Loss with Full Rollback ==="
bash "${PROJECT_ROOT}/scripts/scenarios/s3_catastrophic_merge.sh"

log_info "=== [Phase 3] Executing Scenario 4: Snapshot Capacity Exhaustion ==="
bash "${PROJECT_ROOT}/scripts/scenarios/s4_capacity_exhaustion.sh"

log_info "=== [Phase 3] Executing Scenario 5: Loss Beyond Snapshots (Why Snapshots != Backups) ==="
bash "${PROJECT_ROOT}/scripts/scenarios/s5_loss_beyond_snapshots.sh"

# 5. Phase 2 Demo: Snapshot Rotation Policy
log_info "=== [Phase 2] Executing Snapshot Rotation & Retention Policy Demo ==="
bash "${PROJECT_ROOT}/scripts/snapshot_rotate.sh" --demo

# 6. Phase 4: Validation Documentation Generation
log_info "=== [Phase 4] Generating Disaster Recovery Validation Report ==="
bash "${PROJECT_ROOT}/scripts/generate_validation.sh"

# 7. Generate Live HTML Audit Report
log_info "=== [Phase 4] Regenerating Live HTML Audit Report ==="
bash "${PROJECT_ROOT}/scripts/generate_html.sh"

REPORT_PATH="${PROJECT_ROOT}/report.html"

echo ""
echo "=============================================================================="
echo " DISASTER RECOVERY SUITE EXECUTION COMPLETED SUCCESSFULLY"
echo "=============================================================================="
echo "  Validation Report : ${PROJECT_ROOT}/docs/validation-report.md"
echo "  Live Audit Report : ${REPORT_PATH}"
echo "  Execution Log     : ${PROJECT_ROOT}/logs/dr_solution.log"
echo "=============================================================================="

# 8. Launch Report via Cross-Platform OS Detection
if grep -qi microsoft /proc/version 2>/dev/null && command -v explorer.exe >/dev/null 2>&1; then
    WIN_PATH="$(wslpath -w "${REPORT_PATH}" 2>/dev/null || echo "${REPORT_PATH}")"
    log_info "Detected Windows Subsystem for Linux (WSL). Launching report in default browser..."
    echo "  Windows Path: ${WIN_PATH}"
    explorer.exe "${WIN_PATH}" 2>/dev/null || true
elif [[ "$OSTYPE" == "darwin"* ]] && command -v open >/dev/null 2>&1; then
    log_info "Detected macOS. Launching report in default browser..."
    open "${REPORT_PATH}" || true
elif command -v xdg-open >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    log_info "Detected Linux Desktop. Launching report via xdg-open..."
    xdg-open "${REPORT_PATH}" >/dev/null 2>&1 || true
elif command -v start >/dev/null 2>&1; then
    start "" "${REPORT_PATH}" || true
else
    log_info "Headless / Server environment. View report at: file://${REPORT_PATH}"
fi

exit 0
