#!/usr/bin/env bash
# ==============================================================================
# Script Name   : quota_monitor.sh
# Description   : Departmental Storage Usage & Quota Monitoring Engine
# Project       : Department File Server (DP_03)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_section "Departmental Storage Quota Monitor"

echo -e "${COLOR_BOLD}Directory / Dept          Used      Soft Limit   Hard Limit   Status       Threshold Bar${COLOR_RESET}"
echo "--------------------------------------------------------------------------------------------------"

monitor_department() {
    local dept_name="$1"
    local dept_dir="$2"
    local soft_mb="$3"
    local hard_mb="$4"

    local used_bytes=0
    if [[ -d "${dept_dir}" ]]; then
        used_bytes="$(sudo du -sb "${dept_dir}" 2>/dev/null | awk '{print $1}' || echo 0)"
    fi
    local used_mb=$(( used_bytes / (1024 * 1024) ))

    local status="OK"
    local color="${COLOR_GREEN}"

    if (( used_mb >= hard_mb )); then
        status="HARD_EXCEEDED"
        color="${COLOR_RED}"
    elif (( used_mb >= soft_mb )); then
        status="SOFT_EXCEEDED"
        color="${COLOR_YELLOW}"
    fi

    # Create 20-character visual progress bar relative to hard limit
    local percent=$(( (used_mb * 100) / (hard_mb > 0 ? hard_mb : 1) ))
    if (( percent > 100 )); then percent=100; fi
    local bar_len=$(( percent / 5 ))
    local bar=""
    for (( i=0; i<bar_len; i++ )); do bar+="#"; done
    for (( i=bar_len; i<20; i++ )); do bar+="-"; done

    printf "%-24s %5dMB    %5dMB       %5dMB        ${color}%-12s${COLOR_RESET} [%s] %3d%%\n" \
        "${dept_name}" "${used_mb}" "${soft_mb}" "${hard_mb}" "${status}" "${bar}" "${percent}"
}

monitor_department "Finance (finance/)"     "${DIR_FINANCE}" 200 250
monitor_department "HR (hr/)"               "${DIR_HR}"      100 120
monitor_department "Engineering (eng/)"     "${DIR_ENG}"     400 500
monitor_department "Sales (sales/)"         "${DIR_SALES}"   100 120

echo ""
log_info "Active repquota overview:"
sudo repquota -ug "${MNT_FILESERVER}" 2>/dev/null || true
