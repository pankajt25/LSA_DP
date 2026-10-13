#!/usr/bin/env bash
# ==============================================================================
# Phase 1 — Dataset Seeding and Manifest Generation
# Project: DP_04 Linux Disaster Recovery Solution
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/common.sh"

echo "=============================================================================="
echo " PHASE 1: GENERATE PROTECTED DEPARTMENT DATASET AND BASELINE MANIFEST"
echo "=============================================================================="

guard_sandbox_path "${MNT_DATA}"

# Ensure mount point is mounted and owned by executing user
if ! mountpoint -q "${MNT_DATA}"; then
    log_error "${MNT_DATA} is not a mounted filesystem. Cannot seed data."
    exit 1
fi

sudo_run "Set ownership of origin mount to current user" chown -R "$(id -u):$(id -g)" "${MNT_DATA}"

log_info "Cleaning any existing demonstration data in ${MNT_DATA}..."
# Use path guard on mnt/data contents
for item in "${MNT_DATA}"/* "${MNT_DATA}"/.[!.]* "${MNT_DATA}"/..?*; do
    if [[ -e "${item}" ]] && [[ "$(basename "${item}")" != "lost+found" ]]; then
        guard_sandbox_path "${item}"
        rm -rf "${item}"
    fi
done

DEPARTMENTS=("finance" "hr" "engineering" "sales")
log_info "Creating department directory hierarchy..."
for dept in "${DEPARTMENTS[@]}"; do
    mkdir -p "${MNT_DATA}/${dept}"
    chmod 0755 "${MNT_DATA}/${dept}"
done

log_info "Generating structured department files (varied sizes, types, and modes)..."

# Helper to generate deterministic demonstration content
gen_file() {
    local rel_path="$1"
    local mode="$2"
    local size_kb="$3"
    local desc="$4"
    local target="${MNT_DATA}/${rel_path}"

    guard_sandbox_path "${target}"

    {
        echo "### GENERATED DEMONSTRATION DATA ###"
        echo "Organization: NovaTech Solutions"
        echo "Department File: ${rel_path}"
        echo "Category: ${desc}"
        echo "Timestamp: 2026-10-13T12:00:00Z"
        echo "Security Classification: Internal Enterprise Confident"
        echo "--------------------------------------------------------"
    } > "${target}"

    # Append deterministic padded content to reach desired size
    local current_size
    current_size=$(wc -c < "${target}")
    local target_bytes=$((size_kb * 1024))
    local padding_needed=$((target_bytes - current_size))

    if (( padding_needed > 0 )); then
        # Use python or awk or head /dev/zero with base64 to generate clean text data
        head -c "${padding_needed}" /dev/zero | tr '\0' 'A' >> "${target}"
    fi

    chmod "${mode}" "${target}"
}

# 1. Finance (25 files: spreadsheets, tax audits, general ledgers, forecast models)
log_info "Seeding Finance Department (25 files)..."
for i in {1..25}; do
    case $((i % 4)) in
        0) gen_file "finance/ledger_entry_${i}.csv" 0640 $((10 + i * 2)) "Finance General Ledger CSV" ;;
        1) gen_file "finance/tax_audit_report_${i}.json" 0600 $((15 + i * 3)) "Tax Compliance Audit JSON" ;;
        2) gen_file "finance/quarterly_forecast_${i}.dat" 0644 $((20 + i * 4)) "Quarterly Revenue Forecast Model" ;;
        3) gen_file "finance/payroll_summary_${i}.txt" 0640 $((8 + i * 2)) "Payroll Reconciliation Record" ;;
    esac
done

# 2. Human Resources (25 files: rosters, compensation bands, benefits, NDAs)
log_info "Seeding HR Department (25 files)..."
for i in {1..25}; do
    case $((i % 4)) in
        0) gen_file "hr/employee_roster_${i}.csv" 0600 $((12 + i * 2)) "HR Employee Records and Contact Roster" ;;
        1) gen_file "hr/comp_bands_tier_${i}.json" 0600 $((18 + i * 3)) "Salary Compensation Bands by Grade" ;;
        2) gen_file "hr/benefit_enrollment_${i}.txt" 0644 $((14 + i * 2)) "Health and Insurance Benefits Guide" ;;
        3) gen_file "hr/nda_policy_ack_${i}.md" 0640 $((6 + i * 1)) "Employee Non-Disclosure Form" ;;
    esac
done

# 3. Engineering (30 files: source files, scripts, architecture specs, manifests)
log_info "Seeding Engineering Department (30 files)..."
for i in {1..30}; do
    case $((i % 4)) in
        0) gen_file "engineering/dr_service_core_${i}.py" 0755 $((15 + i * 3)) "Disaster Recovery Automation Core Script" ;;
        1) gen_file "engineering/storage_adapter_${i}.c" 0644 $((22 + i * 4)) "C Storage Block Device Adapter" ;;
        2) gen_file "engineering/arch_spec_rev_${i}.md" 0644 $((10 + i * 2)) "System Infrastructure Blueprint" ;;
        3) gen_file "engineering/deploy_manifest_${i}.xml" 0644 $((12 + i * 2)) "Service Deployment Configuration XML" ;;
    esac
done

# 4. Sales (25 files: sales pipeline, client proposals, enterprise quotes)
log_info "Seeding Sales Department (25 files)..."
for i in {1..25}; do
    q_num=$(( (i % 4) + 1 ))
    case $((i % 4)) in
        0) gen_file "sales/pipeline_q${q_num}_run_${i}.csv" 0640 $((14 + i * 2)) "Global Opportunity Pipeline Metrics" ;;
        1) gen_file "sales/enterprise_quote_${i}.json" 0644 $((25 + i * 3)) "Enterprise Customer Quotation Proposal" ;;
        2) gen_file "sales/client_directory_${i}.txt" 0644 $((8 + i * 1)) "Key Account Contact Directory" ;;
        3) gen_file "sales/sla_terms_contract_${i}.md" 0640 $((16 + i * 2)) "Enterprise Service Level Agreement Terms" ;;
    esac
done

# Sync to storage device
sync

TOTAL_FILES=$(find "${MNT_DATA}" -type f ! -path '*/lost+found*' | wc -l)
log_success "Seeded ${TOTAL_FILES} demonstration files across 4 departments."

# Generate baseline manifest
MANIFEST_FILE="${SANDBOX_DATA}/baseline.manifest"
guard_sandbox_path "${MANIFEST_FILE}"
log_info "Generating cryptographic baseline manifest: ${MANIFEST_FILE}..."

# Format: <rel_path> <sha256> <octal_mode> <size_bytes> sorted by rel_path
(
    cd "${MNT_DATA}"
    find . -type f ! -path './lost+found*' | sort | while read -r f; do
        rel="${f#./}"
        hash=$(sha256sum "${rel}" | awk '{print $1}')
        mode=$(stat -c '%a' "${rel}")
        size=$(stat -c '%s' "${rel}")
        echo "${rel}  ${hash}  ${mode}  ${size}"
    done
) > "${MANIFEST_FILE}"

MANIFEST_COUNT=$(wc -l < "${MANIFEST_FILE}")
log_success "Baseline manifest created with ${MANIFEST_COUNT} verified entries."

# Print sample manifest entries
head -n 5 "${MANIFEST_FILE}" | sed 's/^/  [MANIFEST] /'

exit 0
