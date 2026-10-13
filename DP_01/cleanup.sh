#!/usr/bin/env bash
# ==============================================================================
# Script Name   : cleanup.sh
# Description   : Deliberate Teardown of Storage Infrastructure, LVM, Loops & Accounts
# Project       : Enterprise Storage Infrastructure (DP_01)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="${SCRIPT_DIR}"
# shellcheck source=scripts/lib.sh
source "${PROJECT_ROOT}/scripts/lib.sh"

echo -e "${COLOR_BOLD}${COLOR_YELLOW}================================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_YELLOW}       NovaTech Enterprise Storage — Deliberate Teardown Script                 ${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_YELLOW}================================================================================${COLOR_RESET}"
echo ""

log_warn "This script cleanly tears down virtual storage infrastructure:"
log_warn "  1. Unmounts filesystems at sandbox_data/mnt/{hr,finance,eng,sales}"
log_warn "  2. Deletes Logical Volumes (lv_hr, lv_finance, lv_eng, lv_sales)"
log_warn "  3. Removes Volume Group (company_vg) and Physical Volumes"
log_warn "  4. Detaches verified loop devices and deletes virtual disk images"
log_warn "  5. Purges test user accounts and groups prefixed with lsatest_"
log_info "NOTE: Logs, documentation, scripts, and report.html are preserved as evidence."
echo ""

# ------------------------------------------------------------------------------
# 1. Unmount Active Filesystems
# ------------------------------------------------------------------------------
log_info "[Step 1/5] Unmounting departmental filesystems..."
for mnt in "${MNT_HR}" "${MNT_FIN}" "${MNT_ENG}" "${MNT_SALES}"; do
    if mountpoint -q "${mnt}" 2>/dev/null || grep -qs "${mnt}" /proc/mounts; then
        log_info "  Unmounting ${mnt}..."
        sudo umount -f "${mnt}" 2>/dev/null || true
    fi
done
log_success "Departmental mount points unmounted."

# ------------------------------------------------------------------------------
# 2. LVM Teardown (LVs, VG, PVs)
# ------------------------------------------------------------------------------
log_info "[Step 2/5] Tearing down LVM Logical Volumes and Volume Group..."
if sudo vgs "${VG_NAME}" >/dev/null 2>&1; then
    log_info "  Removing Logical Volumes in ${VG_NAME}..."
    sudo lvremove -f "/dev/${VG_NAME}/${LV_HR}" 2>/dev/null || true
    sudo lvremove -f "/dev/${VG_NAME}/${LV_FIN}" 2>/dev/null || true
    sudo lvremove -f "/dev/${VG_NAME}/${LV_ENG}" 2>/dev/null || true
    sudo lvremove -f "/dev/${VG_NAME}/${LV_SALES}" 2>/dev/null || true

    log_info "  Removing Volume Group ${VG_NAME}..."
    sudo vgremove -f "${VG_NAME}" 2>/dev/null || true
    log_success "Volume group ${VG_NAME} removed."
fi

# ------------------------------------------------------------------------------
# 3. Detach Loop Devices and Wipe Physical Volumes
# ------------------------------------------------------------------------------
log_info "[Step 3/5] Detaching loop devices and wiping Physical Volumes..."
for img in "${DISK1_IMG}" "${DISK2_IMG}" "${DISK3_IMG}"; do
    if [[ -f "${img}" ]]; then
        dev="$(losetup -j "${img}" 2>/dev/null | cut -d':' -f1 || true)"
        if [[ -n "${dev}" ]]; then
            log_info "  Wiping PV and detaching loop device: ${dev}..."
            sudo pvremove -f "${dev}p1" 2>/dev/null || sudo pvremove -f "${dev}" 2>/dev/null || true
            sudo losetup -d "${dev}" 2>/dev/null || true
            log_success "  Loop device ${dev} detached."
        fi
        
        log_info "  Deleting disk image: $(basename "${img}")..."
        safe_rm_rf "${img}"
    fi
done

# ------------------------------------------------------------------------------
# 4. Purge lsatest_ User Accounts and Groups
# ------------------------------------------------------------------------------
log_info "[Step 4/5] Removing lsatest_ test user accounts and groups..."
TEST_USERS=(
    "lsatest_alice_hr" "lsatest_bob_hr"
    "lsatest_charlie_fin" "lsatest_diana_fin"
    "lsatest_evan_eng" "lsatest_fiona_eng"
    "lsatest_george_sales" "lsatest_hannah_sales"
)

for u in "${TEST_USERS[@]}"; do
    if id -u "${u}" >/dev/null 2>&1; then
        sudo userdel "${u}" 2>/dev/null || true
    fi
done

for g in lsatest_hr_team lsatest_finance_team lsatest_eng_team lsatest_sales_team; do
    if getent group "${g}" >/dev/null 2>&1; then
        sudo groupdel "${g}" 2>/dev/null || true
    fi
done
log_success "All lsatest_ test users and groups purged."

# ------------------------------------------------------------------------------
# 5. Clean Tagged Cron Lines if Any
# ------------------------------------------------------------------------------
log_info "[Step 5/5] Purging tagged crontab lines (# LSA_SPRINT_TEST)..."
CRON_TAG="# LSA_SPRINT_TEST"
if crontab -l >/dev/null 2>&1; then
    CURRENT_CRON="$(crontab -l 2>/dev/null || true)"
    if echo "${CURRENT_CRON}" | grep -q "${CRON_TAG}"; then
        CLEANED_CRON="$(echo "${CURRENT_CRON}" | grep -v "${CRON_TAG}" | sed '/^$/d' || true)"
        if [[ -n "${CLEANED_CRON}" ]]; then
            echo "${CLEANED_CRON}" | crontab -
        else
            crontab -r 2>/dev/null || true
        fi
        log_success "Crontab purged of tagged entries."
    fi
fi

# Final Audit Verification
echo ""
log_info "======================================================================"
log_info "Teardown Verification Audit"
log_info "======================================================================"
echo -n "1. Volume Group status: "
if sudo vgs company_vg >/dev/null 2>&1; then
    echo -e "${COLOR_RED}FAILED (company_vg still exists)${COLOR_RESET}"
else
    echo -e "${COLOR_GREEN}CLEAN (Zero company_vg resources active)${COLOR_RESET}"
fi

echo -n "2. Department mount status: "
ACTIVE_MOUNTS="$(df -h | grep "${MNT_DIR}" || true)"
if [[ -z "${ACTIVE_MOUNTS}" ]]; then
    echo -e "${COLOR_GREEN}CLEAN (Zero departmental mounts active)${COLOR_RESET}"
else
    echo -e "${COLOR_RED}FAILED (Mounts still active)${COLOR_RESET}"
fi

echo -n "3. lsatest_ accounts status: "
if getent passwd | grep -q "lsatest_"; then
    echo -e "${COLOR_RED}FAILED (lsatest users still present)${COLOR_RESET}"
else
    echo -e "${COLOR_GREEN}CLEAN (Zero lsatest accounts found)${COLOR_RESET}"
fi

echo ""
log_success "Teardown finished cleanly. System restored to baseline."
