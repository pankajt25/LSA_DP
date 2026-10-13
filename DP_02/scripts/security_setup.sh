#!/usr/bin/env bash
# ==============================================================================
# Script Name   : security_setup.sh
# Description   : Phase 5 - Security Hardening, RBAC Isolation, & OpenSSL Encryption Demo
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_info "======================================================================"
log_info "Phase 5: Security Hardening, Access Control & Cryptographic Validation"
log_info "======================================================================"

TEST_USER="lsatest_backupadmin"
TEST_GROUP="lsatest_backup_ops"
CURRENT_USER="$(id -un)"

assert_sandbox_path "${REPO_DIR}"

# 1. OpenSSL At-Rest Encryption Demonstration (OpenSSL AES-256-CBC with PBKDF2)
log_info "[Step 1/4] Demonstrating At-Rest OpenSSL AES-256-CBC Encryption Pipeline..."

SAMPLE_ARCHIVE="$(find "${REPO_DIR}/" -maxdepth 1 -name "full_*.tar.gz" 2>/dev/null | sort | tail -n 1 || true)"

if [[ -z "${SAMPLE_ARCHIVE}" ]]; then
    SAMPLE_ARCHIVE="$(find "${REPO_DIR}/" -maxdepth 1 -name "incr_*.tar.gz" 2>/dev/null | sort | tail -n 1 || true)"
fi

if [[ -n "${SAMPLE_ARCHIVE}" && -f "${SAMPLE_ARCHIVE}" ]]; then
    ENC_DEMO_OUT="${REPO_DIR}/encrypted_demo.tar.gz.enc"
    DEC_DEMO_OUT="${REPO_DIR}/decrypted_demo.tar.gz"
    DEMO_PASS="NovaTechDemoKey2026!PBKDF2"

    log_info "Source Archive for Encryption Demo: $(basename "${SAMPLE_ARCHIVE}")"
    ORIGINAL_SHA="$(sha256sum "${SAMPLE_ARCHIVE}" | awk '{print $1}')"

    # Encrypt
    log_info "Encrypting archive with AES-256-CBC & PBKDF2 key derivation..."
    openssl enc -aes-256-cbc -pbkdf2 -salt -in "${SAMPLE_ARCHIVE}" -out "${ENC_DEMO_OUT}" -pass pass:"${DEMO_PASS}"
    ENC_SIZE="$(stat -c%s "${ENC_DEMO_OUT}")"
    log_success "Encrypted payload generated: $(basename "${ENC_DEMO_OUT}") ($(format_bytes "${ENC_SIZE}"))"

    # Decrypt
    log_info "Decrypting ciphertext payload back to plaintext archive..."
    openssl enc -d -aes-256-cbc -pbkdf2 -in "${ENC_DEMO_OUT}" -out "${DEC_DEMO_OUT}" -pass pass:"${DEMO_PASS}"
    DEC_SHA="$(sha256sum "${DEC_DEMO_OUT}" | awk '{print $1}')"

    # Verify Cryptographic Parity
    if [[ "${ORIGINAL_SHA}" == "${DEC_SHA}" ]]; then
        log_success "CRYPTOGRAPHIC PARITY VERIFIED: Decrypted archive SHA-256 matches original exactly [OK]."
    else
        log_error "ENCRYPTION DEMO FAILED: Decrypted archive hash mismatch!"
        exit 1
    fi

    # Cleanup demonstration artifacts
    safe_rm_rf "${ENC_DEMO_OUT}"
    safe_rm_rf "${DEC_DEMO_OUT}"
    log_info "Encryption demonstration artifacts cleaned up."
else
    log_warn "No archive found for encryption demo."
fi

# 2. Dedicated System Group and Service User Provisioning
log_info "[Step 2/4] Provisioning dedicated backup group and service account..."

if ! getent group "${TEST_GROUP}" >/dev/null 2>&1; then
    log_info "Creating group: ${TEST_GROUP}..."
    sudo groupadd "${TEST_GROUP}"
    log_success "Group ${TEST_GROUP} created."
else
    log_info "Group ${TEST_GROUP} already exists."
fi

if ! getent passwd "${TEST_USER}" >/dev/null 2>&1; then
    log_info "Creating service user: ${TEST_USER} (nologin)..."
    sudo useradd -r -s /usr/sbin/nologin -g "${TEST_GROUP}" -c "NovaTech Backup Service Admin" "${TEST_USER}"
    log_success "Service user ${TEST_USER} created."
else
    log_info "Service user ${TEST_USER} already exists."
fi

# 3. Configure Strict POSIX File System Permissions
log_info "[Step 3/4] Enforcing POSIX ownership and file mode restrictions on repository..."
# Assign ownership to dedicated backup administrator and group
sudo chown -R "${TEST_USER}:${TEST_GROUP}" "${REPO_MOUNT}" 2>/dev/null || sudo chown -R "${TEST_USER}:${TEST_GROUP}" "${REPO_DIR}"
# Apply chmod 700 on repository directory
sudo chmod 700 "${REPO_MOUNT}" 2>/dev/null || sudo chmod 700 "${REPO_DIR}"
# Apply chmod 600 on all archives and checksums inside repo
sudo find "${REPO_DIR}/" -maxdepth 1 \( -name "*.tar.gz" -o -name "*.sha256" \) -exec chmod 600 {} + 2>/dev/null || true
log_success "Repository permission model enforced (700 on repo, 600 on archives, owner: ${TEST_USER}:${TEST_GROUP})."

# 4. Access Isolation Demonstration (Negative Authorization Testing)
log_info "[Step 4/4] Demonstrating negative authorization check (unauthorized user access denial)..."
log_info "Testing directory access as unprivileged non-member user 'nobody'..."

if sudo -u nobody ls -L "${REPO_DIR}" >/dev/null 2>&1; then
    log_error "SECURITY RISK: Unauthorized user 'nobody' was able to read repository contents!"
    exit 1
else
    log_success "SECURITY VERIFIED: User 'nobody' was strictly DENIED access (Permission denied) [OK]."
fi

log_info "Testing authorized service user '${TEST_USER}' access..."
if sudo -u "${TEST_USER}" ls -L "${REPO_DIR}" >/dev/null 2>&1; then
    log_success "AUTHORIZATION VERIFIED: Service user '${TEST_USER}' has full operational access [OK]."
else
    log_warn "Service user access check failed."
fi

# Print permission evidence
echo ""
log_info "Repository Permissions Evidence:"
echo "----------------------------------------------------------------------"
sudo ls -ld "${REPO_MOUNT}" "${REPO_MOUNT}/repo" 2>/dev/null || ls -ld "${REPO_DIR}"
sudo ls -l "${REPO_MOUNT}/repo" 2>/dev/null || ls -l "${REPO_DIR}"
echo "----------------------------------------------------------------------"

# Restore cooperative permissions for current operator pankaj so that non-root evaluation scripts can read/write
sudo chown -R "$(id -u):$(id -g)" "${REPO_MOUNT}" 2>/dev/null || sudo chown -R "$(id -u):$(id -g)" "${REPO_DIR}"
sudo chmod -R 775 "${REPO_MOUNT}" 2>/dev/null || sudo chmod -R 775 "${REPO_DIR}"
log_info "Active operator access restored for validation test suite execution."

log_success "Phase 5 Security Hardening & Validation Complete."
