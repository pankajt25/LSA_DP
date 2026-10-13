#!/usr/bin/env bash
# ==============================================================================
# Script Name   : setup_identity.sh
# Description   : Phase 2 - Provision RBAC Groups, Service Users & Base Ownership
# Project       : Department File Server (DP_03)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_section "Phase 2: Identity & Base Ownership Configuration"

# Step 1: Create Department and Auditor Groups (lsatest_ prefix)
log_info "Creating department and governance groups..."
for grp in "${ALL_GROUPS[@]}"; do
    if getent group "${grp}" >/dev/null 2>&1; then
        log_info "Group '${grp}' already exists (GID: $(getent group "${grp}" | cut -d: -f3))."
    else
        log_info "Creating group '${grp}'..."
        sudo groupadd "${grp}"
        log_success "Created group '${grp}' (GID: $(getent group "${grp}" | cut -d: -f3))."
    fi
done

# Helper function to provision a department user
create_dept_user() {
    local username="$1"
    local primary_group="$2"

    if id "${username}" >/dev/null 2>&1; then
        log_info "User '${username}' already exists. Updating primary group..."
        sudo usermod -g "${primary_group}" "${username}"
    else
        log_info "Creating user '${username}' (Group: ${primary_group}, No-Home, No-Login)..."
        # Sandboxing constraint: -M (no home dir), -s /usr/sbin/nologin
        sudo useradd -M -s /usr/sbin/nologin -g "${primary_group}" "${username}"
        # Lock user password
        sudo passwd -l "${username}" >/dev/null 2>&1 || true
        log_success "Created and locked user '${username}' (UID: $(id -u "${username}"))."
    fi
}

# Step 2: Provision Users per Department
log_info "Provisioning Finance team members..."
for usr in "${USERS_FINANCE[@]}"; do
    create_dept_user "${usr}" "${GRP_FINANCE}"
done

log_info "Provisioning HR team members..."
for usr in "${USERS_HR[@]}"; do
    create_dept_user "${usr}" "${GRP_HR}"
done

log_info "Provisioning Engineering team members..."
for usr in "${USERS_ENG[@]}"; do
    create_dept_user "${usr}" "${GRP_ENG}"
done

log_info "Provisioning Sales team members..."
for usr in "${USERS_SALES[@]}"; do
    create_dept_user "${usr}" "${GRP_SALES}"
done

log_info "Provisioning Governance Auditor..."
for usr in "${USERS_AUDIT[@]}"; do
    create_dept_user "${usr}" "${GRP_AUDIT}"
done

# Step 3: Configure Base Ownership and Permissions (2770 - SetGID)
# SetGID ensures newly created files inherit the department group automatically.
log_info "Applying base directory ownership (root:<group>) and SetGID permissions (2770)..."

set_dept_ownership() {
    local dir_path="$1"
    local group_name="$2"

    assert_sandbox_path "${dir_path}"
    log_info "Configuring $(basename "${dir_path}")/ -> root:${group_name} with mode 2770..."
    sudo chown root:"${group_name}" "${dir_path}"
    sudo chmod 2770 "${dir_path}"
}

set_dept_ownership "${DIR_FINANCE}" "${GRP_FINANCE}"
set_dept_ownership "${DIR_HR}" "${GRP_HR}"
set_dept_ownership "${DIR_ENG}" "${GRP_ENG}"
set_dept_ownership "${DIR_SALES}" "${GRP_SALES}"

# Step 4: Verification & Evidence Output
log_section "Phase 2 Identity & Ownership Evidence"
echo "=== 1. Active Test Groups ==="
for grp in "${ALL_GROUPS[@]}"; do
    getent group "${grp}" || true
done

echo ""
echo "=== 2. Active Test Users & Memberships ==="
for usr in "${ALL_USERS[@]}"; do
    id "${usr}" || true
done

echo ""
echo "=== 3. Department Directory Permissions (ls -ld) ==="
ls -ld "${DIR_FINANCE}" "${DIR_HR}" "${DIR_ENG}" "${DIR_SALES}"

log_success "Phase 2 Identity & Base Ownership configuration completed."
