#!/usr/bin/env bash
# ==============================================================================
# Phase 2 — Snapshot Creation Utility
# Project: DP_04 Linux Disaster Recovery Solution
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

# Default snapshot sizing and name prefix
SNAP_SIZE="${1:-100M}"
CUSTOM_SUFFIX="${2:-}"

if [[ -n "${CUSTOM_SUFFIX}" ]]; then
    # Sanitize suffix
    SAN_SUFFIX="$(echo "${CUSTOM_SUFFIX}" | tr -cd 'a-zA-Z0-9_')"
    SNAP_NAME="lsatest_snap_${SAN_SUFFIX}"
else
    TS="$(date +%Y%m%d_%H%M%S)"
    SNAP_NAME="lsatest_snap_${TS}"
fi

SNAP_PATH="/dev/${VG_NAME}/${SNAP_NAME}"

log_info "Creating LVM snapshot '${SNAP_NAME}' (Allocated Size: ${SNAP_SIZE})..."

# Flush filesystem dirty buffers to ensure consistent point-in-time state
log_info "Flushing filesystem buffers (sync)..."
sync

# Record creation start timestamp
CREATE_START=$(date +%s)
CREATE_TIME_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

sudo_run "Create CoW snapshot ${SNAP_NAME}" \
    lvcreate -s -n "${SNAP_NAME}" -L "${SNAP_SIZE}" "${VG_NAME}/${LV_ORIGIN}"

CREATE_END=$(date +%s)
DURATION=$((CREATE_END - CREATE_START))

log_success "Snapshot '${SNAP_NAME}' created in ${DURATION}s."
echo "  Device Path    : ${SNAP_PATH}"
echo "  Origin Volume  : ${ORIGIN_DEV}"
echo "  Allocated Size : ${SNAP_SIZE}"
echo "  Creation Time  : ${CREATE_TIME_ISO}"

# Print snapshot details via lvs
sudo lvs -o lv_name,origin,lv_size,data_percent,lv_attr "${SNAP_PATH}"

# Output the snapshot name on the last line for programmatic consumption
echo "${SNAP_NAME}"
