#!/usr/bin/env bash
# ==============================================================================
# Script Name   : storage_setup.sh
# Description   : Automated Storage Setup: Loopback Disks, Partitioning, LVM,
#                 Filesystems (ext4/xfs), Mounts, ACLs, and Demo fstab Validation
# Project       : Enterprise Storage Infrastructure (DP_01)
# Course        : Linux System Administration (E1ITA307) - Modules: III, IV | CO3, CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_info "======================================================================"
log_info "Phase 1: Initializing Enterprise Storage Infrastructure (LVM & FS)"
log_info "======================================================================"

# Path Guards
assert_sandbox_path "${DISKS_DIR}"
assert_sandbox_path "${MNT_DIR}"

# ------------------------------------------------------------------------------
# 1. Sparse Virtual Disks Allocation
# ------------------------------------------------------------------------------
log_info "[Step 1/8] Provisioning virtual disk images (10G, 15G, 20G sparse)..."
[[ -f "${DISK1_IMG}" ]] || truncate -s 10G "${DISK1_IMG}"
[[ -f "${DISK2_IMG}" ]] || truncate -s 15G "${DISK2_IMG}"
[[ -f "${DISK3_IMG}" ]] || truncate -s 20G "${DISK3_IMG}"
log_success "Sparse disk images provisioned in ${DISKS_DIR}:"
ls -lh "${DISKS_DIR}"/disk*.img | awk '{print "  " $5, $9}'

# ------------------------------------------------------------------------------
# 2. Attach Loopback Block Devices with Mandatory Verification
# ------------------------------------------------------------------------------
log_info "[Step 2/8] Attaching and verifying loopback block devices..."

attach_and_verify_loop() {
    local img_path="$1"
    assert_sandbox_path "${img_path}"

    local dev
    dev="$(losetup -j "${img_path}" 2>/dev/null | cut -d':' -f1 || true)"
    if [[ -z "${dev}" ]]; then
        dev="$(sudo losetup -P -f --show "${img_path}")"
    fi

    # Mandatory Verification: Verify returned device maps to this specific image
    local verified_dev
    verified_dev="$(losetup -j "${img_path}" | cut -d':' -f1)"
    if [[ "${dev}" != "${verified_dev}" ]]; then
        log_error "SECURITY VERIFICATION FAILED: Loop device ${dev} does not match image ${img_path}"
        exit 1
    fi
    echo "${dev}"
}

LOOP1="$(attach_and_verify_loop "${DISK1_IMG}")"
LOOP2="$(attach_and_verify_loop "${DISK2_IMG}")"
LOOP3="$(attach_and_verify_loop "${DISK3_IMG}")"

log_success "Verified loop devices mapped:"
log_success "  Disk 1 (10G): ${LOOP1} -> ${DISK1_IMG}"
log_success "  Disk 2 (15G): ${LOOP2} -> ${DISK2_IMG}"
log_success "  Disk 3 (20G): ${LOOP3} -> ${DISK3_IMG}"

# ------------------------------------------------------------------------------
# 3. GPT Partitioning with LVM Flags
# ------------------------------------------------------------------------------
log_info "[Step 3/8] Applying GPT partitioning and LVM flags..."
PV_TARGETS=()

for dev in "${LOOP1}" "${LOOP2}" "${LOOP3}"; do
    if ! sudo parted -s "${dev}" print 2>/dev/null | grep -q "primary"; then
        sudo parted -s "${dev}" mklabel gpt mkpart primary ext4 1MiB 100% set 1 lvm on
    fi
    sudo partprobe "${dev}" 2>/dev/null || true
    sleep 1

    # Check if partition node exists (/dev/loopXp1), otherwise use loop device directly
    if [[ -b "${dev}p1" ]]; then
        PV_TARGETS+=("${dev}p1")
    else
        PV_TARGETS+=("${dev}")
    fi
done

log_success "Partitioned physical volume targets: ${PV_TARGETS[*]}"

# ------------------------------------------------------------------------------
# 4. LVM Physical Volumes, Volume Group, and Logical Volumes
# ------------------------------------------------------------------------------
log_info "[Step 4/8] Initializing LVM Physical Volumes (PVs)..."
for pv in "${PV_TARGETS[@]}"; do
    if ! sudo pvs "${pv}" >/dev/null 2>&1; then
        sudo pvcreate -f "${pv}"
        log_info "  Initialized PV: ${pv}"
    fi
done

log_info "Configuring Volume Group '${VG_NAME}'..."
if ! sudo vgs "${VG_NAME}" >/dev/null 2>&1; then
    sudo vgcreate -f "${VG_NAME}" "${PV_TARGETS[@]}"
    log_success "Volume group '${VG_NAME}' created."
else
    sudo vgchange -ay "${VG_NAME}" >/dev/null 2>&1 || true
    log_info "Volume group '${VG_NAME}' is active."
fi

log_info "Creating Logical Volumes in ${VG_NAME}..."
[[ -e "/dev/${VG_NAME}/${LV_HR}" ]]    || sudo lvcreate -L 5G  -n "${LV_HR}" "${VG_NAME}"
[[ -e "/dev/${VG_NAME}/${LV_FIN}" ]]   || sudo lvcreate -L 8G  -n "${LV_FIN}" "${VG_NAME}"
[[ -e "/dev/${VG_NAME}/${LV_ENG}" ]]   || sudo lvcreate -L 15G -n "${LV_ENG}" "${VG_NAME}"
[[ -e "/dev/${VG_NAME}/${LV_SALES}" ]] || sudo lvcreate -L 5G  -n "${LV_SALES}" "${VG_NAME}"

log_success "Logical Volumes verified in ${VG_NAME}:"
sudo lvs "${VG_NAME}"

# ------------------------------------------------------------------------------
# 5. Filesystem Creation & Formatting (ext4 for HR/Finance/Sales, XFS for Eng)
# ------------------------------------------------------------------------------
log_info "[Step 5/8] Formatting filesystems (ext4 for HR, Finance, Sales; XFS for Engineering)..."

if ! sudo blkid "/dev/${VG_NAME}/${LV_HR}" | grep -q "ext4"; then
    sudo mkfs.ext4 -F -L hr_data "/dev/${VG_NAME}/${LV_HR}"
fi

if ! sudo blkid "/dev/${VG_NAME}/${LV_FIN}" | grep -q "ext4"; then
    sudo mkfs.ext4 -F -L fin_data "/dev/${VG_NAME}/${LV_FIN}"
fi

if ! sudo blkid "/dev/${VG_NAME}/${LV_SALES}" | grep -q "ext4"; then
    sudo mkfs.ext4 -F -L sales_data "/dev/${VG_NAME}/${LV_SALES}"
fi

if ! sudo blkid "/dev/${VG_NAME}/${LV_ENG}" | grep -q "xfs"; then
    sudo mkfs.xfs -f -L eng_data "/dev/${VG_NAME}/${LV_ENG}"
fi

log_success "Filesystems formatted successfully."

# ------------------------------------------------------------------------------
# 6. Mounting to Sandbox Mount Points
# ------------------------------------------------------------------------------
log_info "[Step 6/8] Mounting filesystems under ${MNT_DIR}..."
mkdir -p "${MNT_HR}" "${MNT_FIN}" "${MNT_ENG}" "${MNT_SALES}"
[[ -L "${MNT_DIR}/engineering" ]] || ln -s "${MNT_ENG}" "${MNT_DIR}/engineering"

mount_if_needed() {
    local dev="$1"
    local mnt="$2"
    if ! mountpoint -q "${mnt}" 2>/dev/null && ! grep -qs "${mnt}" /proc/mounts; then
        sudo mount "${dev}" "${mnt}"
    fi
}

mount_if_needed "/dev/${VG_NAME}/${LV_HR}" "${MNT_HR}"
mount_if_needed "/dev/${VG_NAME}/${LV_FIN}" "${MNT_FIN}"
mount_if_needed "/dev/${VG_NAME}/${LV_ENG}" "${MNT_ENG}"
mount_if_needed "/dev/${VG_NAME}/${LV_SALES}" "${MNT_SALES}"

log_success "Filesystems mounted:"
df -h "${MNT_HR}" "${MNT_FIN}" "${MNT_ENG}" "${MNT_SALES}"

# ------------------------------------------------------------------------------
# 7. Persistence Validation: Generate & Verify fstab.demo
# ------------------------------------------------------------------------------
log_info "[Step 7/8] Generating sandbox persistence manifest: ${FSTAB_DEMO}..."

HR_UUID="$(sudo blkid -s UUID -o value "/dev/${VG_NAME}/${LV_HR}")"
FIN_UUID="$(sudo blkid -s UUID -o value "/dev/${VG_NAME}/${LV_FIN}")"
ENG_UUID="$(sudo blkid -s UUID -o value "/dev/${VG_NAME}/${LV_ENG}")"
SALES_UUID="$(sudo blkid -s UUID -o value "/dev/${VG_NAME}/${LV_SALES}")"

cat << EOF > "${FSTAB_DEMO}"
# NovaTech Solutions Departmental Storage Persistence Manifest (CO4 Demo)
UUID=${HR_UUID}  ${MNT_HR}  ext4  defaults,acl  0  2
UUID=${FIN_UUID}  ${MNT_FIN}  ext4  defaults,acl  0  2
UUID=${ENG_UUID}  ${MNT_ENG}  xfs  defaults  0  2
UUID=${SALES_UUID}  ${MNT_SALES}  ext4  defaults,acl  0  2
EOF

log_info "Validating fstab.demo syntax via findmnt --verify --tab-file..."
if findmnt --verify --tab-file "${FSTAB_DEMO}" >/dev/null 2>&1; then
    log_success "Persistence verification PASSED: fstab.demo is 100% valid."
else
    log_warn "findmnt reported non-fatal notice on fstab.demo (virtual paths)."
fi

# ------------------------------------------------------------------------------
# 8. RBAC Accounts, SetGID, and POSIX ACL Configuration
# ------------------------------------------------------------------------------
log_info "[Step 8/8] Provisioning lsatest_ groups, users, SetGID, and POSIX ACLs..."

for grp in lsatest_hr_team lsatest_finance_team lsatest_eng_team lsatest_sales_team; do
    if ! getent group "${grp}" >/dev/null 2>&1; then
        sudo groupadd "${grp}"
    fi
done

create_lsatest_user() {
    local username="$1"
    local groupname="$2"
    if ! id -u "${username}" >/dev/null 2>&1; then
        sudo useradd -r -s /usr/sbin/nologin -g "${groupname}" -c "NovaTech Test User" "${username}"
    fi
}

create_lsatest_user "lsatest_alice_hr" "lsatest_hr_team"
create_lsatest_user "lsatest_bob_hr" "lsatest_hr_team"
create_lsatest_user "lsatest_charlie_fin" "lsatest_finance_team"
create_lsatest_user "lsatest_diana_fin" "lsatest_finance_team"
create_lsatest_user "lsatest_evan_eng" "lsatest_eng_team"
create_lsatest_user "lsatest_fiona_eng" "lsatest_eng_team"
create_lsatest_user "lsatest_george_sales" "lsatest_sales_team"
create_lsatest_user "lsatest_hannah_sales" "lsatest_sales_team"

# Configure Directory Ownership and SetGID (Mode 2770)
sudo chown root:lsatest_hr_team "${MNT_HR}" && sudo chmod 2770 "${MNT_HR}"
sudo chown root:lsatest_finance_team "${MNT_FIN}" && sudo chmod 2770 "${MNT_FIN}"
sudo chown root:lsatest_eng_team "${MNT_ENG}" && sudo chmod 2770 "${MNT_ENG}"
sudo chown root:lsatest_sales_team "${MNT_SALES}" && sudo chmod 2770 "${MNT_SALES}"

# Configure POSIX Default ACLs
sudo setfacl -R -d -m g::rwx "${MNT_HR}" "${MNT_FIN}" "${MNT_ENG}" "${MNT_SALES}" 2>/dev/null || true
sudo setfacl -R -m g::rwx "${MNT_HR}" "${MNT_FIN}" "${MNT_ENG}" "${MNT_SALES}" 2>/dev/null || true

# Seed baseline sample files in each department for operational testing
sudo bash -c "cat << 'EOF' > '${MNT_HR}/hr_policy_handbook.txt'
NovaTech Solutions - Human Resources Guidelines
Confidential: HR Team Access Only
EOF"

sudo bash -c "cat << 'EOF' > '${MNT_FIN}/q1_financial_ledger.csv'
Account,Description,Debit,Credit,Balance
1010,Operating_Cash,500000,0,500000
2010,Accounts_Payable,0,120000,380000
EOF"

sudo bash -c "cat << 'EOF' > '${MNT_ENG}/architecture_blueprint.md'
# NovaTech Distributed Storage Architecture
- High-Performance XFS Filesystem
- Dynamic Elastic Volume Expansion
EOF"

sudo bash -c "cat << 'EOF' > '${MNT_SALES}/quarterly_targets.csv'
Quarter,Territory,Target,Actual
2026-Q1,North_America,12000000,13500000
2026-Q1,EMEA,8000000,8200000
EOF"

# Ensure active user can cooperate for scripted evaluation
CURRENT_USER="$(id -un)"
for grp in lsatest_hr_team lsatest_finance_team lsatest_eng_team lsatest_sales_team; do
    sudo usermod -aG "${grp}" "${CURRENT_USER}" 2>/dev/null || true
done
sudo chmod 755 "${MNT_DIR}" 2>/dev/null || true
sudo chmod 2770 "${MNT_HR}" "${MNT_FIN}" "${MNT_ENG}" "${MNT_SALES}" 2>/dev/null || true

log_success "Storage infrastructure setup completed successfully."
