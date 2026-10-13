#!/usr/bin/env bash
# ==============================================================================
# Script Name   : mutate_data.sh
# Description   : Phase 1 - Department Data Mutation Engine (Add, Modify, Delete)
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

STAGE="${1:-1}"

assert_sandbox_path "${SOURCE_DIR}"

if [[ ! -d "${SOURCE_DIR}" ]]; then
    log_error "Source directory does not exist. Run seed_data.sh first."
    exit 1
fi

log_info "======================================================================"
log_info "Phase 1: Mutating Departmental Data (Stage ${STAGE})"
log_info "======================================================================"

case "${STAGE}" in
    1)
        log_info "Applying Mutation Set 1 (for Incremental Backup 1)..."
        
        # 1. ADD: Two new files
        log_info "  [ADD] finance/audit_addendum_q1.csv"
        cat << 'EOF' > "${SOURCE_DIR}/finance/audit_addendum_q1.csv"
AuditRef,Finding,Severity,RemediationDate,AuditorSign
AUD-2026-X1,Unreconciled Petty Cash Receipts under $50,Low,2026-03-25,Deloitte_Senior
AUD-2026-X2,Secondary S3 Replication Latency Spike,Medium,2026-03-28,CloudSec_Lead
EOF

        log_info "  [ADD] engineering/hotfix_release_notes_2.4.1.md"
        cat << 'EOF' > "${SOURCE_DIR}/engineering/hotfix_release_notes_2.4.1.md"
# Hotfix Release Notes v2.4.1 (Patch Tuesday)
- Fixed memory leak in connection pooler when handling persistent keep-alive websockets.
- Upgraded libssl3 dependency to resolve CVE-2026-1192.
EOF

        # 2. MODIFY: Update two existing files
        log_info "  [MODIFY] sales/crm_leads_enterprise_q1.csv"
        cat << 'EOF' >> "${SOURCE_DIR}/sales/crm_leads_enterprise_q1.csv"
LEAD-905,Cyberdyne_Systems,Miles_Dyson,2100000,Contract_Signed,1.00
LEAD-906,Weyland_Yutani,Peter_Weyland,3400000,Initial_Discovery,0.25
EOF

        log_info "  [MODIFY] hr/employee_directory.csv"
        cat << 'EOF' >> "${SOURCE_DIR}/hr/employee_directory.csv"
EMP006,Rachel_Green,Staff_Compensation_Analyst,Human_Resources,rachel.g@novatech.internal,Austin_HQ
EMP007,Tariq_Mansoor,Site_Reliability_Engineer,Engineering,tariq.m@novatech.internal,Austin_HQ
EOF

        # 3. DELETE: Remove obsolete file
        log_info "  [DELETE] sales/win_loss_analysis_q2.csv"
        safe_rm_rf "${SOURCE_DIR}/sales/win_loss_analysis_q2.csv"
        log_success "Mutation Stage 1 applied cleanly: 2 added, 2 modified, 1 deleted."
        ;;

    2)
        log_info "Applying Mutation Set 2 (for Incremental Backup 2)..."
        
        # 1. ADD: Two new files
        log_info "  [ADD] hr/wellness_initiative_feedback.csv"
        cat << 'EOF' > "${SOURCE_DIR}/hr/wellness_initiative_feedback.csv"
SurveyID,ParticipationRate,SatisfactionScore,TopRequestedBenefit
SURV-2026-W1,78.5%,4.6/5.0,Onsite_Ergonomic_Assessments
SURV-2026-W2,82.1%,4.8/5.0,Mental_Health_Dedicated_Recharge_Days
EOF

        log_info "  [ADD] engineering/api_gateway_routes.json"
        cat << 'EOF' > "${SOURCE_DIR}/engineering/api_gateway_routes.json"
{
  "gateway_version": "v3.1",
  "routes": [
    {"path": "/v2/auth/*", "service": "auth-service", "timeout_ms": 1500},
    {"path": "/v2/billing/*", "service": "billing-engine", "timeout_ms": 3000},
    {"path": "/v2/telemetry/*", "service": "telemetry-collector", "timeout_ms": 500}
  ]
}
EOF

        # 2. MODIFY: Update two existing files
        log_info "  [MODIFY] engineering/architecture_decision_records.md"
        cat << 'EOF' >> "${SOURCE_DIR}/engineering/architecture_decision_records.md"

# ADR-002: LVM Storage Elasticity for Backup Volume
- Status: Accepted
- Decision: Place backup repository on dedicated LVM logical volume to enable zero-downtime online expansion via `lvextend` and `resize2fs`.
EOF

        log_info "  [MODIFY] finance/petty_cash_disbursements.csv"
        cat << 'EOF' >> "${SOURCE_DIR}/finance/petty_cash_disbursements.csv"
PC-2026-004,2026-03-18,Sarah_Jenkins,94.20,Offsite_Team_Lunch,Director
EOF

        # 3. DELETE: Remove obsolete file
        log_info "  [DELETE] finance/investor_deck_notes.md"
        safe_rm_rf "${SOURCE_DIR}/finance/investor_deck_notes.md"
        log_success "Mutation Stage 2 applied cleanly: 2 added, 2 modified, 1 deleted."
        ;;

    *)
        log_error "Unknown mutation stage: ${STAGE}. Expected 1 or 2."
        exit 1
        ;;
esac
