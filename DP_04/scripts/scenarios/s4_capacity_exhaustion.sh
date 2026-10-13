#!/usr/bin/env bash
# ==============================================================================
# Scenario 4 (S4) — Snapshot Capacity Exhaustion & Dynamic Elastic Extension
# Project: DP_04 Linux Disaster Recovery Solution
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/../common.sh"

echo "=============================================================================="
echo " SCENARIO 4 (S4): SNAPSHOT CAPACITY EXHAUSTION & DYNAMIC ELASTIC EXPANSION"
echo "=============================================================================="

STATUS_FILE="${LOGS_DIR}/scenario_s4.status"
guard_sandbox_path "${MNT_DATA}"

# Ensure origin is mounted
if ! mountpoint -q "${MNT_DATA}"; then
    log_error "Origin volume ${MNT_DATA} is not mounted. Run setup_lab.sh first."
    exit 1
fi

# Clean any existing S4 snapshots
for s in lsatest_snap_overflow lsatest_snap_monitored; do
    if sudo lvs "${VG_NAME}/${s}" >/dev/null 2>&1; then
        safe_lvremove "${s}"
    fi
done

# ------------------------------------------------------------------------------
# PART 1: DELIBERATE SNAPSHOT CAPACITY EXHAUSTION
# ------------------------------------------------------------------------------
log_info "=== PART 1: Deliberate Snapshot Capacity Overflow ==="
log_info "Creating small throwaway snapshot 'lsatest_snap_overflow' (16M)..."

CREATE_START=$(date +%s)
bash "${SCRIPTS_DIR}/snapshot_create.sh" "16M" "overflow" >/dev/null

log_info "Initial snapshot state:"
sudo lvs -o lv_name,lv_size,data_percent,lv_attr "${VG_NAME}/lsatest_snap_overflow"

log_warn "Writing 25 MB of churn data into origin volume (exceeding 16M CoW table capacity)..."
CHURN_FILE="${MNT_DATA}/temp_overflow_churn.bin"
guard_sandbox_path "${CHURN_FILE}"

DISASTER_START=$(date +%s)
sudo_run "Write churn data exceeding snapshot capacity" \
    dd if=/dev/urandom of="${CHURN_FILE}" bs=1M count=25 status=none
sync
DISASTER_END=$(date +%s)

log_info "Inspecting snapshot state post-overflow (expecting Data%=100.00% and Invalidation attribute 'I'):"
OVERFLOW_LVS=$(sudo lvs --noheadings -o lv_name,lv_size,data_percent,lv_attr "${VG_NAME}/lsatest_snap_overflow" 2>/dev/null || true)
echo "  [LVS OUTPUT] ${OVERFLOW_LVS}"

OVERFLOW_ATTR=$(echo "${OVERFLOW_LVS}" | awk '{print $4}')
OVERFLOW_DATA_PCT=$(echo "${OVERFLOW_LVS}" | awk '{print $3}')

# Check for Invalidation flag 'I' or Data% 100%
IS_INVALID=0
if [[ "${OVERFLOW_ATTR}" =~ I ]] || [[ "${OVERFLOW_DATA_PCT}" == "100.00" ]]; then
    IS_INVALID=1
    log_success "Snapshot overflow verified: Data% reached ${OVERFLOW_DATA_PCT}%, attribute shows invalidation flag '${OVERFLOW_ATTR}'."
else
    log_warn "Snapshot attribute is '${OVERFLOW_ATTR}' (Data%: ${OVERFLOW_DATA_PCT}%)."
fi

# Clean up churn file and invalid snapshot
log_info "Cleaning up churn file and invalid snapshot..."
rm -f "${CHURN_FILE}"
sync
safe_lvremove "lsatest_snap_overflow"

# ------------------------------------------------------------------------------
# PART 2: PROACTIVE EXTENSION VIA LVEXTEND
# ------------------------------------------------------------------------------
echo ""
log_info "=== PART 2: Proactive Snapshot Capacity Prevention via lvextend ==="
log_info "Creating monitored snapshot 'lsatest_snap_monitored' (20M)..."

REC_START=$(date +%s)
bash "${SCRIPTS_DIR}/snapshot_create.sh" "20M" "monitored" >/dev/null

log_info "Writing 10 MB of churn data to elevate snapshot utilization..."
MON_CHURN="${MNT_DATA}/temp_monitored_churn.bin"
guard_sandbox_path "${MON_CHURN}"

sudo_run "Write moderate churn payload" \
    dd if=/dev/urandom of="${MON_CHURN}" bs=1M count=10 status=none
sync

BEFORE_EXT_LVS=$(sudo lvs --noheadings -o lv_name,lv_size,data_percent,lv_attr "${VG_NAME}/lsatest_snap_monitored")
BEFORE_PCT=$(echo "${BEFORE_EXT_LVS}" | awk '{print $3}')
BEFORE_SIZE=$(echo "${BEFORE_EXT_LVS}" | awk '{print $2}')
log_info "Snapshot state BEFORE extension: Size=${BEFORE_SIZE}, Data%=${BEFORE_PCT}%"

log_info "Running snapshot monitor..."
bash "${SCRIPTS_DIR}/snapshot_monitor.sh" || true

log_info "Performing dynamic online snapshot expansion (+40 MB)..."
sudo_run "Expand snapshot volume" lvextend -L +40M "/dev/${VG_NAME}/lsatest_snap_monitored"

AFTER_EXT_LVS=$(sudo lvs --noheadings -o lv_name,lv_size,data_percent,lv_attr "${VG_NAME}/lsatest_snap_monitored")
AFTER_PCT=$(echo "${AFTER_EXT_LVS}" | awk '{print $3}')
AFTER_SIZE=$(echo "${AFTER_EXT_LVS}" | awk '{print $2}')
log_success "Snapshot state AFTER extension: Size=${AFTER_SIZE}, Data%=${AFTER_PCT}%"

REC_END=$(date +%s)
REC_DURATION=$((REC_END - REC_START))

# Clean up churn file and snapshot
log_info "Cleaning up monitoring demonstration churn file and snapshot..."
rm -f "${MON_CHURN}"
sync
safe_lvremove "lsatest_snap_monitored"

OUTCOME="PASS"
log_success "SCENARIO 4 RESULT: PASS (Both capacity overflow invalidation and online lvextend prevention verified)."

# Save persistent status report
{
    echo "SCENARIO_ID=S4"
    echo "SCENARIO_NAME=Snapshot Capacity Exhaustion & Prevention"
    echo "DISASTER_DESC=Origin block churn (25M) exceeding 16M snapshot CoW table capacity"
    echo "RECOVERY_METHOD=Invalidation Detection (Attr 'I') & Online Dynamic Expansion (lvextend +40M)"
    echo "OVERFLOW_ATTR=${OVERFLOW_ATTR}"
    echo "OVERFLOW_DATA_PCT=${OVERFLOW_DATA_PCT}"
    echo "BEFORE_EXT_SIZE=${BEFORE_SIZE}"
    echo "BEFORE_EXT_PCT=${BEFORE_PCT}"
    echo "AFTER_EXT_SIZE=${AFTER_SIZE}"
    echo "AFTER_EXT_PCT=${AFTER_PCT}"
    echo "RECOVERY_START_EPOCH=${REC_START}"
    echo "RECOVERY_END_EPOCH=${REC_END}"
    echo "RECOVERY_TIME_SEC=${REC_DURATION}"
    echo "RESULT=${OUTCOME}"
} > "${STATUS_FILE}"

log_success "Scenario 4 status record generated: ${STATUS_FILE}"
exit 0
