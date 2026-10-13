#!/usr/bin/env bash
# ==============================================================================
# Script Name   : setup_acl.sh
# Description   : Phase 3 - POSIX Access & Default ACL Configuration
# Project       : Department File Server (DP_03)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_section "Phase 3: POSIX Access & Default ACL Configuration"

ACL_LOG="${LOGS_DIR}/acl_config.log"
{
    echo "================================================================================"
    echo "Phase 3 ACL Configuration Audit: $(get_iso_timestamp)"
    echo "================================================================================"
} > "${ACL_LOG}"

# Capture State BEFORE ACL Configuration
log_info "Capturing baseline ACL state (BEFORE modification)..."
echo "=== BASELINE GETFACL STATE (BEFORE) ===" >> "${ACL_LOG}"
for d in "${DIR_FINANCE}" "${DIR_HR}" "${DIR_ENG}" "${DIR_SALES}"; do
    echo "--- $(basename "${d}") ---" >> "${ACL_LOG}"
    sudo getfacl -p "${d}" >> "${ACL_LOG}"
done

# Function to configure departmental access and default ACLs
apply_department_acls() {
    local dir_path="$1"
    local dept_group="$2"
    local dept_name
    dept_name="$(basename "${dir_path}")"

    assert_sandbox_path "${dir_path}"
    log_info "Applying POSIX ACLs for [${dept_name}] (Dept Group: ${dept_group}, Auditor: ${GRP_AUDIT})..."

    # 1. Access ACL: Department group rwx, Auditor group r-x, Others ---
    sudo setfacl -m "g::rwx" "${dir_path}"
    sudo setfacl -m "g:${dept_group}:rwx" "${dir_path}"
    sudo setfacl -m "g:${GRP_AUDIT}:r-x" "${dir_path}"
    sudo setfacl -m "m::rwx" "${dir_path}"
    sudo setfacl -m "o::---" "${dir_path}"

    # 2. Default ACL: Guarantees future files/subdirectories inherit these exact permissions
    sudo setfacl -d -m "g::rwx" "${dir_path}"
    sudo setfacl -d -m "g:${dept_group}:rwx" "${dir_path}"
    sudo setfacl -d -m "g:${GRP_AUDIT}:r-x" "${dir_path}"
    sudo setfacl -d -m "m::rwx" "${dir_path}"
    sudo setfacl -d -m "o::---" "${dir_path}"

    log_success "ACLs configured successfully on ${dept_name}/"
}

apply_department_acls "${DIR_FINANCE}" "${GRP_FINANCE}"
apply_department_acls "${DIR_HR}" "${GRP_HR}"
apply_department_acls "${DIR_ENG}" "${GRP_ENG}"
apply_department_acls "${DIR_SALES}" "${GRP_SALES}"

# Capture State AFTER ACL Configuration
log_info "Capturing updated ACL state (AFTER modification)..."
echo "" >> "${ACL_LOG}"
echo "=== UPDATED GETFACL STATE (AFTER) ===" >> "${ACL_LOG}"
for d in "${DIR_FINANCE}" "${DIR_HR}" "${DIR_ENG}" "${DIR_SALES}"; do
    echo "--- $(basename "${d}") ---" >> "${ACL_LOG}"
    sudo getfacl -p "${d}" >> "${ACL_LOG}"
done

# Step 3: Demonstrate ACL Inheritance on a New File
log_info "Demonstrating dynamic ACL & group inheritance on file creation..."
DEMO_FILE="${DIR_FINANCE}/acl_inheritance_demo.txt"
# Remove demo file if present from prior runs
if [[ -f "${DEMO_FILE}" ]]; then
    sudo rm -f "${DEMO_FILE}"
fi

# Create file as finance user lsatest_fin_alice
sudo -u "${USERS_FINANCE[0]}" touch "${DEMO_FILE}"
sudo -u "${USERS_FINANCE[0]}" bash -c "echo 'Inheritance demonstration token: $(date)' > '${DEMO_FILE}'"

echo "" >> "${ACL_LOG}"
echo "=== DYNAMIC INHERITANCE TEST FILE GETFACL ===" >> "${ACL_LOG}"
sudo getfacl -p "${DEMO_FILE}" >> "${ACL_LOG}"

# Step 4: Display Output Evidence
log_section "Phase 3 POSIX ACL Evidence & Mask Explanation"
echo "=== 1. Active ACL State: ${DIR_FINANCE} ==="
sudo getfacl "${DIR_FINANCE}"

echo ""
echo "=== 2. Inherited File ACL & Group Ownership: ${DEMO_FILE} ==="
sudo ls -l "${DEMO_FILE}"
sudo getfacl "${DEMO_FILE}"

echo ""
echo "=== 3. POSIX Mask Entry Explanation ==="
cat << 'EOF'
[NOTE ON POSIX ACL MASK]
The 'mask' entry defines the maximum effective permission ceiling granted to any named
users, additional groups, and the owning group. If a group has 'rwx' but the mask is 'r-x',
the effective permission is reduced to 'r-x'. In our configuration:
- Access mask: rwx (allows full departmental collaboration)
- Auditor group: r-x (read and execute/traverse only)
- Default ACLs: propagate these constraints to all newly created files and subdirectories.
EOF

log_success "Phase 3 POSIX ACL configuration verified."
