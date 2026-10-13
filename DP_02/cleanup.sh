#!/usr/bin/env bash
# ==============================================================================
# Script Name   : cleanup.sh
# Description   : Deliberate Teardown of System Modifications & Privilege Artifacts
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="${SCRIPT_DIR}"
# shellcheck source=scripts/lib.sh
source "${PROJECT_ROOT}/scripts/lib.sh"

echo -e "${COLOR_BOLD}${COLOR_YELLOW}================================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_YELLOW}       NovaTech Centralized Backup Server — Deliberate Teardown Script          ${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_YELLOW}================================================================================${COLOR_RESET}"
echo ""

log_warn "This script safely purges external system modifications:"
log_warn "  1. Removes tagged crontab schedules (# LSA_SPRINT_TEST)"
log_warn "  2. Purges test service user 'lsatest_backupadmin' and group 'lsatest_backup_ops'"
log_warn "  3. Unmounts loop filesystem at sandbox_data/repo_mount/"
log_warn "  4. Detaches loop device and deletes backup_disk.img"
log_info "NOTE: Logs, documentation, scripts, and report.html are preserved as evidence."
echo ""

# 1. Crontab Cleanup (Preserve all user lines, remove only tagged lines)
log_info "[Step 1/4] Cleaning tagged crontab entries..."
CRON_TAG="# LSA_SPRINT_TEST"
if crontab -l >/dev/null 2>&1; then
    CURRENT_CRON="$(crontab -l 2>/dev/null || true)"
    CLEANED_CRON="$(echo "${CURRENT_CRON}" | grep -v "${CRON_TAG}" | sed '/^$/d' || true)"
    
    if [[ -n "${CLEANED_CRON}" ]]; then
        echo "${CLEANED_CRON}" | crontab -
        log_success "Crontab restored: Pre-existing user schedules preserved, tagged entries purged."
    else
        crontab -r 2>/dev/null || true
        log_success "Crontab cleared: No remaining non-tagged lines."
    fi
else
    log_info "No user crontab found to clean."
fi

# 2. Test User and Group Teardown
log_info "[Step 2/4] Removing test service account and group..."
if getent passwd lsatest_backupadmin >/dev/null 2>&1; then
    log_info "Deleting user lsatest_backupadmin..."
    sudo userdel lsatest_backupadmin 2>/dev/null || true
    log_success "User lsatest_backupadmin deleted."
else
    log_info "User lsatest_backupadmin does not exist."
fi

if getent group lsatest_backup_ops >/dev/null 2>&1; then
    log_info "Deleting group lsatest_backup_ops..."
    sudo groupdel lsatest_backup_ops 2>/dev/null || true
    log_success "Group lsatest_backup_ops deleted."
else
    log_info "Group lsatest_backup_ops does not exist."
fi

# 3. Storage Volume Unmount & Loop Device Teardown
log_info "[Step 3/4] Unmounting dedicated backup storage volume..."

if mountpoint -q "${REPO_MOUNT}" 2>/dev/null || grep -qs "${REPO_MOUNT}" /proc/mounts; then
    log_info "Unmounting ${REPO_MOUNT}..."
    sudo umount -f "${REPO_MOUNT}" 2>/dev/null || true
    log_success "Filesystem unmounted from ${REPO_MOUNT}."
else
    log_info "No active mount detected at ${REPO_MOUNT}."
fi

# Find attached loop device for the project disk image
if [[ -f "${DISK_IMG}" ]]; then
    ATTACHED_LOOP="$(losetup -j "${DISK_IMG}" 2>/dev/null | cut -d':' -f1 || true)"
    if [[ -n "${ATTACHED_LOOP}" ]]; then
        log_info "Detaching verified loop device: ${ATTACHED_LOOP}..."
        sudo losetup -d "${ATTACHED_LOOP}" 2>/dev/null || true
        log_success "Loop device ${ATTACHED_LOOP} detached."
    fi
    
    log_info "Deleting sparse image: ${DISK_IMG}..."
    safe_rm_rf "${DISK_IMG}"
    log_success "Disk image removed."
fi

# Remove repo symlink if it points to mount
if [[ -L "${REPO_DIR}" ]]; then
    rm -f "${REPO_DIR}"
fi

# 4. Final Teardown Verification Output
echo ""
log_info "======================================================================"
log_info "Teardown Verification Audit"
log_info "======================================================================"

echo -n "1. Crontab status: "
if crontab -l 2>/dev/null | grep -q "${CRON_TAG}"; then
    echo -e "${COLOR_RED}FAILED (Tagged entries still present)${COLOR_RESET}"
else
    echo -e "${COLOR_GREEN}CLEAN (Zero tagged entries)${COLOR_RESET}"
fi

echo -n "2. Active loop devices: "
REMAINING_LOOPS="$(losetup -a 2>/dev/null || true)"
if [[ -z "${REMAINING_LOOPS}" ]]; then
    echo -e "${COLOR_GREEN}CLEAN (Zero loop devices active)${COLOR_RESET}"
else
    echo -e "${COLOR_YELLOW}${REMAINING_LOOPS}${COLOR_RESET}"
fi

echo -n "3. Test accounts status: "
if getent passwd | grep -q "lsatest_"; then
    echo -e "${COLOR_RED}FAILED (lsatest user still exists)${COLOR_RESET}"
else
    echo -e "${COLOR_GREEN}CLEAN (No lsatest accounts found)${COLOR_RESET}"
fi

echo ""
log_success "Cleanup execution finished. System restored to pristine baseline."
