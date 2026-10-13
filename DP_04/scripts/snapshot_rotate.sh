#!/usr/bin/env bash
# ==============================================================================
# Phase 2 — Snapshot Retention & Rotation Policy
# Project: DP_04 Linux Disaster Recovery Solution
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

KEEP_COUNT="${1:-3}"
RUN_DEMO=0

if [[ "${KEEP_COUNT}" == "--demo" ]]; then
    RUN_DEMO=1
    KEEP_COUNT=3
elif [[ "${2:-}" == "--demo" ]]; then
    RUN_DEMO=1
fi

rotate_snapshots() {
    local max_keep="$1"
    log_info "Evaluating snapshot retention policy: Keeping newest ${max_keep} snapshot(s)..."

    # Query snapshots ordered by lv_time ascending (oldest first)
    # Output: lv_name;lv_time
    local raw_list
    raw_list=$(sudo lvs --noheadings --separator ';' \
        --sort +lv_time \
        -o lv_name,origin,lv_time \
        "${VG_NAME}" 2>/dev/null || true)

    local snap_array=()
    while IFS=';' read -r lv_name origin lv_time; do
        lv_name="$(echo "${lv_name:-}" | tr -d ' ')"
        origin="$(echo "${origin:-}" | tr -d ' ')"
        if [[ -n "${origin}" ]] && [[ "${lv_name}" == lsatest_snap_* ]]; then
            snap_array+=("${lv_name}")
        fi
    done <<< "${raw_list}"

    local total_snaps=${#snap_array[@]}
    log_info "Found ${total_snaps} active snapshot(s) in ${VG_NAME}."

    if (( total_snaps <= max_keep )); then
        log_success "Active snapshots (${total_snaps}) <= retention threshold (${max_keep}). No pruning required."
        return 0
    fi

    local prune_count=$((total_snaps - max_keep))
    log_info "Pruning ${prune_count} expired snapshot(s) to enforce retention limit (${max_keep})..."

    for ((i=0; i<prune_count; i++)); do
        local target_snap="${snap_array[i]}"
        log_info "Target for pruning: ${target_snap}"
        safe_lvremove "${target_snap}"
    done

    log_success "Snapshot rotation complete. Retained newest ${max_keep} snapshot(s)."
}

if (( RUN_DEMO == 1 )); then
    echo "=============================================================================="
    echo " PHASE 2 DEMONSTRATION: SNAPSHOT ROTATION (Create 5 -> Retain 3)"
    echo "=============================================================================="
    
    # Clean any lingering rotation test snapshots first
    for s in rot1 rot2 rot3 rot4 rot5; do
        if sudo lvs "${VG_NAME}/lsatest_snap_${s}" >/dev/null 2>&1; then
            safe_lvremove "lsatest_snap_${s}"
        fi
    done

    log_info "Step 1: Creating 5 sequential test snapshots..."
    for i in {1..5}; do
        log_info "Creating snapshot ${i}/5: lsatest_snap_rot${i} (10M)..."
        bash "${SCRIPT_DIR}/snapshot_create.sh" "10M" "rot${i}" >/dev/null
        sleep 1
    done

    log_info "Step 2: Listing all snapshots before rotation (expect 5):"
    bash "${SCRIPT_DIR}/snapshot_list.sh"

    log_info "Step 3: Running rotation to retain newest 3 snapshots..."
    rotate_snapshots 3

    log_info "Step 4: Listing snapshots post-rotation (expect exactly 3: rot3, rot4, rot5):"
    bash "${SCRIPT_DIR}/snapshot_list.sh"

    # Verify that rot1 and rot2 were deleted, and rot3, rot4, rot5 remain
    if sudo lvs "${VG_NAME}/lsatest_snap_rot1" >/dev/null 2>&1 || sudo lvs "${VG_NAME}/lsatest_snap_rot2" >/dev/null 2>&1; then
        log_error "Rotation verification failed: older snapshots still exist!"
        exit 1
    fi
    if ! sudo lvs "${VG_NAME}/lsatest_snap_rot3" >/dev/null 2>&1 || \
       ! sudo lvs "${VG_NAME}/lsatest_snap_rot4" >/dev/null 2>&1 || \
       ! sudo lvs "${VG_NAME}/lsatest_snap_rot5" >/dev/null 2>&1; then
        log_error "Rotation verification failed: expected retained snapshots are missing!"
        exit 1
    fi

    log_success "Rotation demonstration PASSED: Successfully pruned 2 oldest and retained 3 newest."

    # Clean up the demo snapshots
    log_info "Cleaning up rotation demonstration snapshots..."
    safe_lvremove "lsatest_snap_rot3"
    safe_lvremove "lsatest_snap_rot4"
    safe_lvremove "lsatest_snap_rot5"
else
    rotate_snapshots "${KEEP_COUNT}"
fi

exit 0
