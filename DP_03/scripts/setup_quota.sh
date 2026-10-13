#!/usr/bin/env bash
# ==============================================================================
# Script Name   : setup_quota.sh
# Description   : Phase 4 - Configure Departmental User & Group Quota Allocations
# Project       : Department File Server (DP_03)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_section "Phase 4: Departmental Quota Allocation"

QUOTA_LOG="${LOGS_DIR}/quota_setup.log"
{
    echo "================================================================================"
    echo "Phase 4 Quota Allocation Audit: $(get_iso_timestamp)"
    echo "================================================================================"
} > "${QUOTA_LOG}"

# Read preflight decision
QUOTA_MODE_FILE="${SANDBOX_DIR}/quota_mode.env"
QUOTA_MODE="native"
if [[ -f "${QUOTA_MODE_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${QUOTA_MODE_FILE}"
fi

log_info "Active Quota Operational Mode: [${QUOTA_MODE}]"

if [[ "${QUOTA_MODE}" == "native" ]]; then
    # Ensure quota accounting is active on the filesystem
    log_info "Ensuring quota subsystem is enabled on ${MNT_FILESERVER}..."
    sudo quotaon -u -g "${MNT_FILESERVER}" 2>/dev/null || true

    # Configure 7-day grace period for both users and groups
    # 7 days = 604800 seconds
    log_info "Setting 7-day (604,800s) grace period for block and inode limits..."
    sudo setquota -u -t 604800 604800 "${MNT_FILESERVER}"
    sudo setquota -g -t 604800 604800 "${MNT_FILESERVER}"
    log_success "Grace periods configured (7 days)."

    # 1. Configure Group Quotas
    log_info "Applying Departmental Group Quotas (Soft / Hard)..."

    # Finance: 200M / 250M
    sudo setquota -g "${GRP_FINANCE}" "${QUOTA_GRP_FIN_SOFT}" "${QUOTA_GRP_FIN_HARD}" "${QUOTA_INODE_SOFT}" "${QUOTA_INODE_HARD}" "${MNT_FILESERVER}"
    log_success "Group Quota set for ${GRP_FINANCE}: Soft=${QUOTA_GRP_FIN_SOFT}k (200M), Hard=${QUOTA_GRP_FIN_HARD}k (250M)"

    # HR: 100M / 120M
    sudo setquota -g "${GRP_HR}" "${QUOTA_GRP_HR_SOFT}" "${QUOTA_GRP_HR_HARD}" "${QUOTA_INODE_SOFT}" "${QUOTA_INODE_HARD}" "${MNT_FILESERVER}"
    log_success "Group Quota set for ${GRP_HR}: Soft=${QUOTA_GRP_HR_SOFT}k (100M), Hard=${QUOTA_GRP_HR_HARD}k (120M)"

    # Engineering: 400M / 500M
    sudo setquota -g "${GRP_ENG}" "${QUOTA_GRP_ENG_SOFT}" "${QUOTA_GRP_ENG_HARD}" "${QUOTA_INODE_SOFT}" "${QUOTA_INODE_HARD}" "${MNT_FILESERVER}"
    log_success "Group Quota set for ${GRP_ENG}: Soft=${QUOTA_GRP_ENG_SOFT}k (400M), Hard=${QUOTA_GRP_ENG_HARD}k (500M)"

    # Sales: 100M / 120M
    sudo setquota -g "${GRP_SALES}" "${QUOTA_GRP_SALES_SOFT}" "${QUOTA_GRP_SALES_HARD}" "${QUOTA_INODE_SOFT}" "${QUOTA_INODE_HARD}" "${MNT_FILESERVER}"
    log_success "Group Quota set for ${GRP_SALES}: Soft=${QUOTA_GRP_SALES_SOFT}k (100M), Hard=${QUOTA_GRP_SALES_HARD}k (120M)"

    # 2. Configure Per-User Quotas
    log_info "Applying Per-User Quotas (Soft / Hard)..."

    # Finance Users: 90M / 110M
    for u in "${USERS_FINANCE[@]}"; do
        sudo setquota -u "${u}" "${QUOTA_USR_FIN_SOFT}" "${QUOTA_USR_FIN_HARD}" "${QUOTA_INODE_SOFT}" "${QUOTA_INODE_HARD}" "${MNT_FILESERVER}"
        log_success "User Quota set for ${u}: Soft=${QUOTA_USR_FIN_SOFT}k (90M), Hard=${QUOTA_USR_FIN_HARD}k (110M)"
    done

    # HR Users: 50M / 60M
    for u in "${USERS_HR[@]}"; do
        sudo setquota -u "${u}" "${QUOTA_USR_HR_SOFT}" "${QUOTA_USR_HR_HARD}" "${QUOTA_INODE_SOFT}" "${QUOTA_INODE_HARD}" "${MNT_FILESERVER}"
        log_success "User Quota set for ${u}: Soft=${QUOTA_USR_HR_SOFT}k (50M), Hard=${QUOTA_USR_HR_HARD}k (60M)"
    done

    # Engineering Users: 150M / 200M
    for u in "${USERS_ENG[@]}"; do
        sudo setquota -u "${u}" "${QUOTA_USR_ENG_SOFT}" "${QUOTA_USR_ENG_HARD}" "${QUOTA_INODE_SOFT}" "${QUOTA_INODE_HARD}" "${MNT_FILESERVER}"
        log_success "User Quota set for ${u}: Soft=${QUOTA_USR_ENG_SOFT}k (150M), Hard=${QUOTA_USR_ENG_HARD}k (200M)"
    done

    # Sales Users: 50M / 60M
    for u in "${USERS_SALES[@]}"; do
        sudo setquota -u "${u}" "${QUOTA_USR_SALES_SOFT}" "${QUOTA_USR_SALES_HARD}" "${QUOTA_INODE_SOFT}" "${QUOTA_INODE_HARD}" "${MNT_FILESERVER}"
        log_success "User Quota set for ${u}: Soft=${QUOTA_USR_SALES_SOFT}k (50M), Hard=${QUOTA_USR_SALES_HARD}k (60M)"
    done

    # Auditor User: Read-only governance role, unlimited / no quotas
    log_info "Auditor user ${USERS_AUDIT[0]} is granted read-only governance without quotas."

    # Evidence Output
    log_section "Phase 4 Native Quota Allocation Evidence"
    echo "=== 1. Active User Quota Report (repquota -u) ==="
    sudo repquota -u "${MNT_FILESERVER}" | tee -a "${QUOTA_LOG}"

    echo ""
    echo "=== 2. Active Group Quota Report (repquota -g) ==="
    sudo repquota -g "${MNT_FILESERVER}" | tee -a "${QUOTA_LOG}"

else
    log_warn "Fallback Mode Active: Filesystem-size allocation plus monitoring, not kernel user quotas."
    echo "Fallback mode active" >> "${QUOTA_LOG}"
fi

log_success "Phase 4 Quota Configuration completed."
