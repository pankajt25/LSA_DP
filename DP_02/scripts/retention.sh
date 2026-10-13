#!/usr/bin/env bash
# ==============================================================================
# Script Name   : retention.sh
# Description   : Phase 2 - Backup Retention Policy Enforcement Engine
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

assert_sandbox_path "${REPO_DIR}"

log_info "======================================================================"
log_info "Running NovaTech Backup Retention Policy Enforcement"
log_info "Policy: Retain the 2 most recent Full backups and all associated incrementals"
log_info "Mode  : $(if $DRY_RUN; then echo "DRY-RUN (Simulated - No Deletions)"; else echo "LIVE (Active Deletion)"; fi)"
log_info "======================================================================"

if [[ ! -d "${REPO_DIR}" ]]; then
    log_warn "Repository directory does not exist: ${REPO_DIR}"
    exit 0
fi

# 1. Discover all full backups sorted by timestamp (oldest first)
mapfile -t ALL_FULLS < <(find "${REPO_DIR}/" -maxdepth 1 -name "full_*.tar.gz" -printf "%f\n" | sort)
TOTAL_FULLS=${#ALL_FULLS[@]}

log_info "Repository scan detected ${TOTAL_FULLS} full backup archive(s)."

if [[ ${TOTAL_FULLS} -le 2 ]]; then
    log_info "Repository full backup count (${TOTAL_FULLS}) is within retention limit (max 2 fulls)."
    log_success "No full or incremental archives require pruning at this time."
    exit 0
fi

# 2. Split into Kept vs Expired full backups
# Kept = Last 2 full backups
# Expired = All full backups prior to the last 2
EXPIRED_COUNT=$((TOTAL_FULLS - 2))
EXPIRED_FULLS=("${ALL_FULLS[@]:0:${EXPIRED_COUNT}}")
KEPT_FULLS=("${ALL_FULLS[@]:${EXPIRED_COUNT}:2}")

OLDEST_KEPT_FULL="${KEPT_FULLS[0]}"
log_info "Retention demarcation boundary:"
log_info "  Oldest retained full backup: ${OLDEST_KEPT_FULL}"
log_info "  Expired full backup count   : ${#EXPIRED_FULLS[@]}"

# 3. Identify files to prune (Expired fulls + associated incrementals + metadata)
FILES_TO_PRUNE=()

for exp_full in "${EXPIRED_FULLS[@]}"; do
    FILES_TO_PRUNE+=("${REPO_DIR}/${exp_full}")
    FILES_TO_PRUNE+=("${REPO_DIR}/${exp_full}.sha256")
    FILES_TO_PRUNE+=("${META_DIR}/${exp_full}.meta")
    FILES_TO_PRUNE+=("${META_DIR}/${exp_full}.snar")
done

# Discover incrementals that belong to expired fulls
# Any incremental whose timestamp is older than the oldest retained full backup
while IFS= read -r incr_file; do
    if [[ -n "${incr_file}" ]]; then
        incr_name="$(basename "${incr_file}")"
        # Compare alphanumeric timestamp (e.g., incr_20261010_100000.tar.gz vs full_20261010_110000.tar.gz)
        # Extract TS:
        incr_ts="${incr_name#incr_}"
        incr_ts="${incr_ts%.tar.gz}"
        kept_ts="${OLDEST_KEPT_FULL#full_}"
        kept_ts="${kept_ts%.tar.gz}"

        if [[ "${incr_ts}" < "${kept_ts}" ]]; then
            FILES_TO_PRUNE+=("${incr_file}")
            FILES_TO_PRUNE+=("${incr_file}.sha256")
            FILES_TO_PRUNE+=("${META_DIR}/${incr_name}.meta")
        fi
    fi
done < <(find "${REPO_DIR}/" -maxdepth 1 -name "incr_*.tar.gz" | sort)

echo ""
log_info "Retention Analysis Summary:"
echo "----------------------------------------------------------------------"
echo "Retained Full Archives:"
for kept in "${KEPT_FULLS[@]}"; do
    echo "  [KEEP] ${kept}"
done

echo ""
echo "Expired Archives & Manifests Marked for Purge (${#FILES_TO_PRUNE[@]} items):"
for target in "${FILES_TO_PRUNE[@]}"; do
    if [[ -f "${target}" ]]; then
        target_size="$(stat -c%s "${target}" 2>/dev/null || echo 0)"
        echo "  [PURGE] $(basename "${target}") ($(format_bytes "${target_size}"))"
    fi
done
echo "----------------------------------------------------------------------"

# 4. Perform Execution or Dry-run Reporting
DELETED_COUNT=0
DELETED_BYTES=0

for target_file in "${FILES_TO_PRUNE[@]}"; do
    if [[ -f "${target_file}" ]]; then
        file_bytes="$(stat -c%s "${target_file}" 2>/dev/null || echo 0)"
        if $DRY_RUN; then
            log_info "[DRY-RUN SIMULATION] Would delete: ${target_file}"
        else
            assert_sandbox_path "${target_file}"
            safe_rm_rf "${target_file}"
            DELETED_COUNT=$((DELETED_COUNT + 1))
            DELETED_BYTES=$((DELETED_BYTES + file_bytes))
            log_info "[PURGED] Deleted: $(basename "${target_file}")"
        fi
    fi
done

if $DRY_RUN; then
    log_success "Retention dry-run completed. No files were modified or deleted."
else
    log_success "Retention enforcement executed: Purged ${DELETED_COUNT} file(s), reclaimed $(format_bytes "${DELETED_BYTES}")."
fi
