#!/usr/bin/env bash
# ==============================================================================
# Phase 2 — Snapshot Capacity Monitor
# Project: DP_04 Linux Disaster Recovery Solution
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

echo "=============================================================================="
echo " LVM SNAPSHOT CAPACITY MONITORING (Thresholds: 70% WARN, 90% CRITICAL)"
echo "=============================================================================="

WARN_THRESHOLD=70.0
CRIT_THRESHOLD=90.0

RAW_LVS=$(sudo lvs --noheadings --separator ';' \
    -o lv_name,origin,lv_size,data_percent,lv_attr \
    "${VG_NAME}" 2>/dev/null || true)

SNAPSHOT_COUNT=0
ALERTS_TRIGGERED=0

while IFS=';' read -r lv_name origin lv_size data_pct lv_attr; do
    lv_name="$(echo "${lv_name:-}" | tr -d ' ')"
    origin="$(echo "${origin:-}" | tr -d ' ')"
    lv_size="$(echo "${lv_size:-}" | tr -d ' ')"
    data_pct="$(echo "${data_pct:-}" | tr -d ' ')"
    lv_attr="$(echo "${lv_attr:-}" | tr -d ' ')"

    if [[ -n "${origin}" ]] && [[ "${lv_name}" == lsatest_snap_* ]]; then
        SNAPSHOT_COUNT=$((SNAPSHOT_COUNT + 1))
        if [[ -z "${data_pct}" ]]; then data_pct="0.00"; fi

        # Evaluate threshold using awk floating point comparison
        STATUS="HEALTHY"
        COLOR="${GREEN}"

        IS_CRIT=$(awk -v d="${data_pct}" -v c="${CRIT_THRESHOLD}" 'BEGIN {print (d >= c) ? 1 : 0}')
        IS_WARN=$(awk -v d="${data_pct}" -v w="${WARN_THRESHOLD}" 'BEGIN {print (d >= w) ? 1 : 0}')

        if [[ "${IS_CRIT}" -eq 1 ]]; then
            STATUS="CRITICAL (>90%)"
            COLOR="${RED}"
            ALERTS_TRIGGERED=$((ALERTS_TRIGGERED + 1))
            log_error "ALERT [CRITICAL]: Snapshot '${lv_name}' Data% is at ${data_pct}% (>= ${CRIT_THRESHOLD}%). Immediate lvextend required!"
        elif [[ "${IS_WARN}" -eq 1 ]]; then
            STATUS="WARNING (>70%)"
            COLOR="${YELLOW}"
            ALERTS_TRIGGERED=$((ALERTS_TRIGGERED + 1))
            log_warn "ALERT [WARNING]: Snapshot '${lv_name}' Data% is at ${data_pct}% (>= ${WARN_THRESHOLD}%). Plan capacity expansion."
        else
            echo -e "  [${COLOR}${STATUS}${NC}] ${lv_name} | Size: ${lv_size} | Data: ${data_pct}% | Attr: ${lv_attr}"
        fi
    fi
done <<< "${RAW_LVS}"

if [[ "${SNAPSHOT_COUNT}" -eq 0 ]]; then
    echo "  (No active snapshots currently in volume group ${VG_NAME})"
else
    echo "------------------------------------------------------------------------------"
    echo "  Monitored Snapshots : ${SNAPSHOT_COUNT}"
    echo "  Threshold Alerts    : ${ALERTS_TRIGGERED}"
fi
echo "=============================================================================="

exit 0
