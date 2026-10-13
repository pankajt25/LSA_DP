#!/usr/bin/env bash
# ==============================================================================
# Phase 2 — Snapshot Inventory & Status Utility
# Project: DP_04 Linux Disaster Recovery Solution
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

echo "=============================================================================="
echo " LVM SNAPSHOT INVENTORY (Volume Group: ${VG_NAME})"
echo "=============================================================================="

# Query LVM for all snapshots belonging to lsatest_dr_vg
NOW_EPOCH=$(date +%s)

# Header
printf "%-25s %-15s %-10s %-10s %-12s %-20s %-10s\n" \
    "SNAPSHOT NAME" "ORIGIN" "SIZE" "DATA%" "ATTR" "CREATED" "AGE"
printf "%-25s %-15s %-10s %-10s %-12s %-20s %-10s\n" \
    "-------------------------" "---------------" "----------" "----------" "------------" "--------------------" "----------"

# Extract fields using lvs with semicolon separator
RAW_LVS=$(sudo lvs --noheadings --separator ';' \
    -o lv_name,origin,lv_size,data_percent,lv_attr,lv_time \
    "${VG_NAME}" 2>/dev/null || true)

SNAPSHOT_FOUND=0

while IFS=';' read -r lv_name origin lv_size data_pct lv_attr lv_time; do
    # Trim leading/trailing whitespace
    lv_name="$(echo "${lv_name:-}" | tr -d ' ')"
    origin="$(echo "${origin:-}" | tr -d ' ')"
    lv_size="$(echo "${lv_size:-}" | tr -d ' ')"
    data_pct="$(echo "${data_pct:-}" | tr -d ' ')"
    lv_attr="$(echo "${lv_attr:-}" | tr -d ' ')"
    lv_time="$(echo "${lv_time:-}" | sed 's/^[ \t]*//;s/[ \t]*$//')"

    # Check if this volume is a snapshot (origin is not empty and name starts with lsatest_snap_)
    if [[ -n "${origin}" ]] && [[ "${lv_name}" == lsatest_snap_* ]]; then
        SNAPSHOT_FOUND=1
        if [[ -z "${data_pct}" ]]; then data_pct="0.00"; fi
        
        # Calculate human-readable age
        AGE="0s"
        if [[ -n "${lv_time}" ]]; then
            CREATE_EPOCH=$(date -d "${lv_time}" +%s 2>/dev/null || echo 0)
            if (( CREATE_EPOCH > 0 )); then
                DIFF_SEC=$((NOW_EPOCH - CREATE_EPOCH))
                if (( DIFF_SEC < 60 )); then
                    AGE="${DIFF_SEC}s"
                elif (( DIFF_SEC < 3600 )); then
                    AGE="$((DIFF_SEC / 60))m $((DIFF_SEC % 60))s"
                else
                    AGE="$((DIFF_SEC / 3600))h $(((DIFF_SEC % 3600) / 60))m"
                fi
            fi
        fi

        printf "%-25s %-15s %-10s %-10s %-12s %-20s %-10s\n" \
            "${lv_name}" "${origin}" "${lv_size}" "${data_pct}%" "${lv_attr}" "${lv_time}" "${AGE}"
    fi
done <<< "${RAW_LVS}"

if [[ "${SNAPSHOT_FOUND}" -eq 0 ]]; then
    echo "  (No active snapshots found in Volume Group ${VG_NAME})"
fi
echo "=============================================================================="
