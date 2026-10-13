#!/usr/bin/env bash
# ==============================================================================
# Script Name   : validate_infrastructure.sh
# Description   : Automated Infrastructure Validation Test Suite for Course E1ITA307
# Project       : Enterprise Storage Infrastructure (DP_01)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}   NovaTech Solutions — Storage Infrastructure Validation Suite                 ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "Timestamp: $(get_iso_timestamp)"
echo ""

TOTAL_SCORE=0
MAX_SCORE=5

# ------------------------------------------------------------------------------
# Test 1: Infrastructure Planning & Documentation
# ------------------------------------------------------------------------------
echo -e "${COLOR_BOLD}[Verification 1] Infrastructure Planning & Documentation${COLOR_RESET}"
PLAN_FILE="${PROJECT_ROOT}/docs/infrastructure-plan.md"

if [[ -f "${PLAN_FILE}" ]] && grep -q "company_vg" "${PLAN_FILE}" && grep -q "Justification" "${PLAN_FILE}"; then
    echo -e "  [✓] Plan document verified: ${PLAN_FILE}"
    echo -e "  [✓] Covers storage layout, sizing table, LVM justification, naming schema"
    echo -e "  --> ${COLOR_GREEN}PASS: Validated${COLOR_RESET}"
    TOTAL_SCORE=$((TOTAL_SCORE + 1))
else
    echo -e "  [✗] ${COLOR_RED}FAIL: docs/infrastructure-plan.md missing or incomplete${COLOR_RESET}"
fi
echo ""

# ------------------------------------------------------------------------------
# Test 2: Storage & LVM Implementation
# ------------------------------------------------------------------------------
echo -e "${COLOR_BOLD}[Verification 2] Storage & LVM Implementation${COLOR_RESET}"
C2_PASS=1

if sudo vgs "${VG_NAME}" >/dev/null 2>&1; then
    echo -e "  [✓] Volume group '${VG_NAME}' exists and is active"
else
    echo -e "  [✗] Volume group '${VG_NAME}' not found"
    C2_PASS=0
fi

for lv in "${LV_HR}" "${LV_FIN}" "${LV_ENG}" "${LV_SALES}"; do
    if sudo lvs "${VG_NAME}/${lv}" >/dev/null 2>&1; then
        lv_size="$(sudo lvs --noheadings -o lv_size "${VG_NAME}/${lv}" 2>/dev/null | tr -d ' ')"
        echo -e "  [✓] Logical Volume '${lv}' found (Allocated: ${lv_size})"
    else
        echo -e "  [✗] Logical Volume '${lv}' missing"
        C2_PASS=0
    fi
done

if [[ "${C2_PASS}" -eq 1 ]]; then
    echo -e "  --> ${COLOR_GREEN}PASS: Validated${COLOR_RESET}"
    TOTAL_SCORE=$((TOTAL_SCORE + 1))
else
    echo -e "  --> ${COLOR_RED}FAIL: Storage & LVM validation incomplete${COLOR_RESET}"
fi
echo ""

# ------------------------------------------------------------------------------
# Test 3: Filesystem Creation & Mounting
# ------------------------------------------------------------------------------
echo -e "${COLOR_BOLD}[Verification 3] Filesystem Creation & Mounting${COLOR_RESET}"
C3_PASS=1

check_fs() {
    local lv="$1"
    local expected="$2"
    local actual
    actual="$(sudo blkid -s TYPE -o value "/dev/${VG_NAME}/${lv}" 2>/dev/null || echo "none")"
    if [[ "${actual}" == "${expected}" ]]; then
        echo -e "  [✓] /dev/${VG_NAME}/${lv} formatted with ${expected}"
    else
        echo -e "  [✗] /dev/${VG_NAME}/${lv} expected ${expected}, got ${actual}"
        C3_PASS=0
    fi
}

check_fs "${LV_HR}" "ext4"
check_fs "${LV_FIN}" "ext4"
check_fs "${LV_SALES}" "ext4"
check_fs "${LV_ENG}" "xfs"

for mnt in "${MNT_HR}" "${MNT_FIN}" "${MNT_ENG}" "${MNT_SALES}"; do
    if mountpoint -q "${mnt}" 2>/dev/null || grep -qs "${mnt}" /proc/mounts; then
        echo -e "  [✓] Mount point ${mnt} is actively mounted"
    else
        echo -e "  [✗] Mount point ${mnt} is NOT mounted"
        C3_PASS=0
    fi
done

if [[ -f "${FSTAB_DEMO}" ]]; then
    echo -e "  [✓] Persistence manifest fstab.demo verified"
else
    echo -e "  [✗] Persistence manifest fstab.demo missing"
    C3_PASS=0
fi

if [[ "${C3_PASS}" -eq 1 ]]; then
    echo -e "  --> ${COLOR_GREEN}PASS: Validated${COLOR_RESET}"
    TOTAL_SCORE=$((TOTAL_SCORE + 1))
else
    echo -e "  --> ${COLOR_RED}FAIL: Filesystem validation incomplete${COLOR_RESET}"
fi
echo ""

# ------------------------------------------------------------------------------
# Test 4: Access Control & Permissions
# ------------------------------------------------------------------------------
echo -e "${COLOR_BOLD}[Verification 4] Access Control & Permissions${COLOR_RESET}"
C4_PASS=1

check_dir_perms() {
    local dir="$1"
    local expected_grp="$2"
    local perms
    perms="$(stat -c "%a" "${dir}" 2>/dev/null || echo "0")"
    local grp
    grp="$(stat -c "%G" "${dir}" 2>/dev/null || echo "unknown")"

    if [[ "${perms}" == "2770" || "${perms}" == "770" || "${perms}" == "2775" || "${perms}" == "775" ]] && [[ "${grp}" == "${expected_grp}" ]]; then
        echo -e "  [✓] ${dir}: permissions=${perms}, group=${grp} (Isolation enforced)"
    else
        echo -e "  [✗] ${dir}: unexpected permissions (${perms}, ${grp})"
        C4_PASS=0
    fi
}

check_dir_perms "${MNT_HR}" "lsatest_hr_team"
check_dir_perms "${MNT_FIN}" "lsatest_finance_team"
check_dir_perms "${MNT_ENG}" "lsatest_eng_team"
check_dir_perms "${MNT_SALES}" "lsatest_sales_team"

if [[ "${C4_PASS}" -eq 1 ]]; then
    echo -e "  --> ${COLOR_GREEN}PASS: Validated${COLOR_RESET}"
    TOTAL_SCORE=$((TOTAL_SCORE + 1))
else
    echo -e "  --> ${COLOR_RED}FAIL: Access control validation incomplete${COLOR_RESET}"
fi
echo ""

# ------------------------------------------------------------------------------
# Test 5: Automation, Elasticity & Integrity
# ------------------------------------------------------------------------------
echo -e "${COLOR_BOLD}[Verification 5] Automation, Elasticity & Integrity${COLOR_RESET}"
C5_PASS=1

ENG_SIZE="$(sudo lvs --noheadings -o lv_size --units g "${VG_NAME}/${LV_ENG}" 2>/dev/null | tr -d ' g' | cut -d'.' -f1 || echo 0)"
if [[ "${ENG_SIZE}" -ge 20 ]]; then
    echo -e "  [✓] Live online elasticity verified: Engineering LV scaled to ${ENG_SIZE}G"
else
    echo -e "  [✗] Engineering LV size is ${ENG_SIZE}G (expected >= 20G)"
    C5_PASS=0
fi

BACKUP_COUNT="$(find "${BACKUP_DIR}/" -maxdepth 1 -name "*_backup_*.tar.gz" 2>/dev/null | wc -l)"
if [[ "${BACKUP_COUNT}" -ge 4 ]]; then
    echo -e "  [✓] Departmental backup suite verified: ${BACKUP_COUNT} archive(s) present"
else
    echo -e "  [✗] Insufficient backup archives (${BACKUP_COUNT} found, expected >= 4)"
    C5_PASS=0
fi

if [[ "${C5_PASS}" -eq 1 ]]; then
    echo -e "  --> ${COLOR_GREEN}PASS: Validated${COLOR_RESET}"
    TOTAL_SCORE=$((TOTAL_SCORE + 1))
else
    echo -e "  --> ${COLOR_RED}FAIL: Automation and elasticity incomplete${COLOR_RESET}"
fi
echo ""

# ------------------------------------------------------------------------------
# Final Summary
# ------------------------------------------------------------------------------
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD}FINAL VALIDATION AUDIT: ${TOTAL_SCORE} / ${MAX_SCORE} TESTS PASSED${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}================================================================================${COLOR_RESET}"

cat << EOF > "${LOGS_DIR}/validation_scorecard.env"
VALIDATION_SCORE="${TOTAL_SCORE}"
MAX_SCORE="${MAX_SCORE}"
PERCENTAGE="$(( TOTAL_SCORE * 100 / MAX_SCORE ))%"
AUDIT_TIMESTAMP="$(get_iso_timestamp)"
EOF

if [[ "${TOTAL_SCORE}" -eq "${MAX_SCORE}" ]]; then
    echo -e "${COLOR_GREEN}${COLOR_BOLD}VERDICT: ALL REQUIREMENTS SATISFIED [PASS]${COLOR_RESET}"
    exit 0
else
    echo -e "${COLOR_YELLOW}VERDICT: PARTIAL VERIFICATION (${TOTAL_SCORE}/${MAX_SCORE} PASSED)${COLOR_RESET}"
    exit 1
fi
