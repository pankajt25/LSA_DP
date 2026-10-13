#!/usr/bin/env bash
# ==============================================================================
# Script Name   : live_elasticity_demo.sh
# Description   : Live Online LVM Volume Elasticity Demonstration (lvextend & xfs_growfs)
# Project       : Enterprise Storage Infrastructure (DP_01)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_info "======================================================================"
log_info "Demonstrating Live Online LVM Elasticity on Engineering Volume (lv_eng)"
log_info "======================================================================"

assert_sandbox_path "${MNT_ENG}"

# Query current size before expansion
BEFORE_SIZE_GB="$(sudo lvs --noheadings -o lv_size --units g "${VG_NAME}/${LV_ENG}" 2>/dev/null | tr -d ' g' | cut -d'.' -f1)"
BEFORE_DF="$(df -h "${MNT_ENG}" | awk 'NR==2 {print $2}')"

log_info "Current Engineering Volume Capacity: ${BEFORE_SIZE_GB} GiB (Mounted Filesystem: ${BEFORE_DF})"

if [[ "${BEFORE_SIZE_GB}" -lt 20 ]]; then
    log_info "Executing live online expansion (+5 GiB): Extending to 20 GiB..."
    sudo lvextend -L 20G "/dev/${VG_NAME}/${LV_ENG}"
    
    log_info "Executing online XFS filesystem expansion (xfs_growfs)..."
    sudo xfs_growfs "${MNT_ENG}"
    
    log_success "Online expansion completed with zero downtime."
else
    log_info "Volume is already scaled to 20 GiB."
fi

# Query updated size after expansion
AFTER_SIZE_GB="$(sudo lvs --noheadings -o lv_size --units g "${VG_NAME}/${LV_ENG}" 2>/dev/null | tr -d ' g' | cut -d'.' -f1)"
AFTER_DF="$(df -h "${MNT_ENG}" | awk 'NR==2 {print $2}')"

log_success "Post-Expansion Capacity: ${AFTER_SIZE_GB} GiB (Mounted Filesystem: ${AFTER_DF})"
echo ""
sudo lvs "${VG_NAME}/${LV_ENG}"
df -h "${MNT_ENG}"

# Persist metrics for report generation
cat << EOF > "${LOGS_DIR}/elasticity_results.env"
ELASTICITY_STATUS="SUCCESS"
BEFORE_LV_SIZE="${BEFORE_SIZE_GB} GiB"
BEFORE_FS_SIZE="${BEFORE_DF}"
AFTER_LV_SIZE="${AFTER_SIZE_GB} GiB"
AFTER_FS_SIZE="${AFTER_DF}"
EXPANSION_DELTA="+5 GiB (Online)"
LAST_DEMO_TIME="$(get_iso_timestamp)"
EOF

log_success "Live elasticity demonstration finished and logged."
