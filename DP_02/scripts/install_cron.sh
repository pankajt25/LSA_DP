#!/usr/bin/env bash
# ==============================================================================
# Script Name   : install_cron.sh
# Description   : Phase 4 - Automated Cron Scheduling & Live Execution Verification
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_info "======================================================================"
log_info "Phase 4: Installing Scheduled Backup Automation (cron)"
log_info "======================================================================"

CRON_TAG="# LSA_SPRINT_TEST"
BACKUP_FULL_BIN="$(realpath "${SCRIPT_DIR}/backup_full.sh")"
BACKUP_INCR_BIN="$(realpath "${SCRIPT_DIR}/backup_incremental.sh")"
CRON_LOG_PATH="$(realpath "${CRON_LOG}")"

# 1. Verify Cron Daemon Status
log_info "Checking cron daemon status..."
if service cron status >/dev/null 2>&1; then
    log_success "Cron service is active and running."
else
    log_warn "Cron daemon is not running. Attempting to start service..."
    if sudo service cron start >/dev/null 2>&1; then
        log_success "Cron service started successfully."
    else
        log_warn "Could not start cron service automatically. Please ensure cron daemon is active."
    fi
fi

# 2. Display existing crontab before modifications
log_info "Inspecting existing user crontab (BEFORE modifications):"
EXISTING_CRON="$(crontab -l 2>/dev/null || true)"
if [[ -n "${EXISTING_CRON}" ]]; then
    echo "----------------------------------------------------------------------"
    echo "${EXISTING_CRON}"
    echo "----------------------------------------------------------------------"
else
    echo "(No previous crontab found for current user)"
fi

# Filter out any prior tagged lines from previous test runs while strictly preserving user lines
FILTERED_CRON="$(echo "${EXISTING_CRON}" | grep -v "${CRON_TAG}" || true)"

# 3. Formulate Policy Schedule Entries
# Weekly Full: Sunday 01:00 AM
FULL_CRON_LINE="0 1 * * 0 /bin/bash ${BACKUP_FULL_BIN} >> ${CRON_LOG_PATH} 2>&1 ${CRON_TAG}"
# Daily Incremental: Every day 02:00 AM
INCR_CRON_LINE="0 2 * * * /bin/bash ${BACKUP_INCR_BIN} >> ${CRON_LOG_PATH} 2>&1 ${CRON_TAG}"
# Live Demo Line: Runs every minute for demonstration verification
DEMO_CRON_LINE="* * * * * /bin/bash ${BACKUP_INCR_BIN} >> ${CRON_LOG_PATH} 2>&1 ${CRON_TAG} (LIVE_DEMO)"

NEW_CRON="${FILTERED_CRON}
${FULL_CRON_LINE}
${INCR_CRON_LINE}
${DEMO_CRON_LINE}"

# Clean up empty leading/trailing lines
CLEAN_CRON="$(echo "${NEW_CRON}" | sed '/^$/d')"

echo "${CLEAN_CRON}" | crontab -
log_success "Crontab installed with NovaTech backup schedules and live demo monitor."

echo ""
log_info "Active Crontab with temporary live demo entry:"
echo "----------------------------------------------------------------------"
crontab -l
echo "----------------------------------------------------------------------"

# 4. Wait for Live Demonstration Execution
log_info "Monitoring ${CRON_LOG} for live execution triggered by cron daemon..."
log_info "Waiting up to 75 seconds for the next minute tick..."

INITIAL_LINES=0
if [[ -f "${CRON_LOG_PATH}" ]]; then
    INITIAL_LINES="$(wc -l < "${CRON_LOG_PATH}")"
fi

FIRED=false
WAIT_SECONDS=75
START_WAIT="$(date +%s)"

while true; do
    CURRENT_TIME="$(date +%s)"
    ELAPSED=$((CURRENT_TIME - START_WAIT))

    if [[ -f "${CRON_LOG_PATH}" ]]; then
        CURRENT_LINES="$(wc -l < "${CRON_LOG_PATH}")"
        if [[ "${CURRENT_LINES}" -gt "${INITIAL_LINES}" ]]; then
            FIRED=true
            log_success "CRON JOB FIRED SUCCESSFULLY! New output detected in ${CRON_LOG}:"
            echo "----------------------------------------------------------------------"
            tail -n 12 "${CRON_LOG_PATH}"
            echo "----------------------------------------------------------------------"
            break
        fi
    fi

    if [[ "${ELAPSED}" -ge "${WAIT_SECONDS}" ]]; then
        log_warn "Timeout reached (${WAIT_SECONDS}s). Cron daemon did not trigger within window or output buffered."
        break
    fi

    sleep 3
done

# 5. Remove temporary live demo line, keeping production weekly full and daily incremental lines
log_info "Removing temporary 1-minute live demo entry while preserving scheduled policies..."
FINAL_CRON="$(crontab -l | grep -v "(LIVE_DEMO)" | sed '/^$/d')"
echo "${FINAL_CRON}" | crontab -
log_success "Temporary demo schedule removed."

echo ""
log_info "Final Scheduled Crontab (AFTER removing demo line):"
echo "----------------------------------------------------------------------"
crontab -l
echo "----------------------------------------------------------------------"
log_success "Phase 4 Scheduling & Automation Complete."
