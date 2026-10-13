#!/usr/bin/env bash
# ==============================================================================
# Script Name   : seed_data.sh
# Description   : Phase 1 - Fictional Department Dataset Generator (Demonstration Only)
# Project       : Centralized Backup & Recovery Server (DP_02)
# Course        : Linux System Administration (E1ITA307) - Modules: IV | CO4
# Organization  : NovaTech Solutions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

log_info "======================================================================"
log_info "Phase 1: Generating Fictional Department Dataset (Demonstration Data)"
log_info "======================================================================"

# Path guard on source directory
assert_sandbox_path "${SOURCE_DIR}"

mkdir -p "${SOURCE_DIR}"/{finance,hr,engineering,sales}

# ------------------------------------------------------------------------------
# 1. Finance Department Dataset (~12 files)
# ------------------------------------------------------------------------------
log_info "Populating Finance department files..."
cat << 'EOF' > "${SOURCE_DIR}/finance/q1_financial_summary.csv"
Quarter,Revenue,CostOfGoods,OperatingExpenses,NetIncome,EBITDA_Margin
2026-Q1,12450000,4320000,3890000,4240000,34.05%
2025-Q4,11890000,4150000,3780000,3960000,33.31%
2025-Q3,10950000,3980000,3610000,3360000,30.68%
EOF

cat << 'EOF' > "${SOURCE_DIR}/finance/annual_budget_2026.csv"
Department,AllocatedBudget,Capex,Opex,ApprovedBy,ReviewStatus
Engineering,4500000,1500000,3000000,CTO,Approved
Sales,3200000,400000,2800000,VP_Sales,Approved
Finance,1800000,200000,1600000,CFO,Approved
Human_Resources,1400000,150000,1250000,CHRO,Approved
EOF

cat << 'EOF' > "${SOURCE_DIR}/finance/payroll_ledger_2026.csv"
EmployeeID,Department,BaseSalary,TaxDeduction,HealthBenefits,NetPay
EMP0101,Finance,95000,22800,4500,67700
EMP0102,Finance,82000,19680,4500,57820
EMP0103,Finance,120000,28800,4500,86700
EMP0104,Finance,68000,16320,4500,47180
EOF

cat << 'EOF' > "${SOURCE_DIR}/finance/tax_filing_compliance.txt"
NovaTech Solutions - Corporate Tax Compliance Dossier FY2025-2026
Federal Tax ID: 84-9281923
Status: Form 1120 Filed Electronically
Jurisdiction: United States & European Subsidiary
Auditor: Deloitte & Touche LLP
Sign-off: Compliance Committee Verified
EOF

cat << 'EOF' > "${SOURCE_DIR}/finance/investor_deck_notes.md"
# Q1 2026 Board of Directors & Investor Presentation
- Year-over-Year ARR Growth: 42%
- Gross Margin Expansion: From 72% to 76.5%
- Net Retention Rate: 124%
- Target Acquisition Pipeline: 2 targets currently undergoing technical diligence
EOF

cat << 'EOF' > "${SOURCE_DIR}/finance/asset_depreciation_schedule.json"
{
  "fiscal_year": 2026,
  "asset_classes": [
    {"class": "Datacenter_Servers", "cost_basis": 1850000, "depreciation_method": "MACRS_5yr", "current_book_value": 740000},
    {"class": "Network_Infrastructure", "cost_basis": 450000, "depreciation_method": "StraightLine_5yr", "current_book_value": 270000},
    {"class": "Office_Leasehold_Improvements", "cost_basis": 620000, "depreciation_method": "StraightLine_15yr", "current_book_value": 537333}
  ]
}
EOF

cat << 'EOF' > "${SOURCE_DIR}/finance/accounts_payable_aging.csv"
Vendor,InvoiceID,AmountDue,DaysPastDue,PaymentTerms,Status
AWS_Cloud_Services,INV-99214,142500.50,12,Net30,Scheduled
Dell_Enterprise_Hardware,INV-88123,89400.00,0,Net45,Pending_Approval
Palo_Alto_Networks,INV-77391,34800.00,0,Net30,Approved
EOF

cat << 'EOF' > "${SOURCE_DIR}/finance/petty_cash_disbursements.csv"
VoucherID,Date,Custodian,Amount,Purpose,Authorized
PC-2026-001,2026-01-15,Sarah_Jenkins,145.20,Office_Hospitality,Manager
PC-2026-002,2026-02-03,Sarah_Jenkins,88.50,Courier_Services,Manager
PC-2026-003,2026-03-11,Sarah_Jenkins,210.00,Hardware_Cables_Emergency,Director
EOF

cat << 'EOF' > "${SOURCE_DIR}/finance/quarterly_forecast_q3.csv"
Segment,Projected_Low,Projected_Base,Projected_High,Confidence
SaaS_Subscriptions,8200000,8900000,9400000,0.85
Professional_Services,1400000,1650000,1900000,0.78
Enterprise_Support,1100000,1250000,1400000,0.92
EOF

cat << 'EOF' > "${SOURCE_DIR}/finance/procurement_contracts.csv"
ContractID,Supplier,ServiceScope,AnnualCommitment,ExpirationDate
CTR-801,Snowflake,Data_Warehouse,120000,2027-04-30
CTR-802,Datadog,Infrastructure_Monitoring,85000,2026-12-31
CTR-803,CrowdStrike,Endpoint_Protection,65000,2027-08-31
EOF

cat << 'EOF' > "${SOURCE_DIR}/finance/audit_trail_internal.log"
2026-01-02 08:30:11 INFO Journal entries posted for period close Dec-2025.
2026-01-15 14:22:05 AUDIT Reconciliation completed between GL and Bank of America treasury.
2026-02-01 09:15:33 AUDIT Fixed asset additions verified by internal controller.
2026-03-01 11:45:19 AUDIT SOX Section 404 access control audit concluded: No exceptions noted.
EOF

# Small simulated binary datastore
head -c 1024 /dev/urandom | base64 > "${SOURCE_DIR}/finance/executive_compensation_matrix.dat"

# ------------------------------------------------------------------------------
# 2. Human Resources Department Dataset (~12 files)
# ------------------------------------------------------------------------------
log_info "Populating Human Resources department files..."
cat << 'EOF' > "${SOURCE_DIR}/hr/employee_directory.csv"
EmpID,FullName,Title,Department,WorkEmail,OfficeLocation
EMP001,Alex_Morgan,Principal_Architect,Engineering,alex.m@novatech.internal,Austin_HQ
EMP002,Elena_Rostova,Senior_DevOps_Engineer,Engineering,elena.r@novatech.internal,Seattle_Remote
EMP003,Marcus_Vance,Director_Enterprise_Sales,Sales,marcus.v@novatech.internal,New_York
EMP004,Sarah_Jenkins,HR_Operations_Lead,Human_Resources,sarah.j@novatech.internal,Austin_HQ
EMP005,David_Chen,Chief_Financial_Officer,Finance,david.c@novatech.internal,Austin_HQ
EOF

cat << 'EOF' > "${SOURCE_DIR}/hr/onboarding_checklist_standard.md"
# NovaTech Solutions - Standard Employee Onboarding Workflow
1. Complete I-9 verification & direct deposit authorization.
2. Provision identity in FreeIPA / Active Directory with 2FA enforcement.
3. Assign role-based access groups (Engineering / Sales / Finance / HR).
4. Issue encrypted company laptop with MDM enrollment.
5. Complete Mandatory Information Security & Phishing Awareness module.
EOF

cat << 'EOF' > "${SOURCE_DIR}/hr/performance_review_rubrics.txt"
Engineering Career Growth Rubric:
- Level 1 (Associate): Delivers well-scoped tasks with peer supervision.
- Level 2 (Engineer): Independently designs modules, leads code reviews.
- Level 3 (Senior): Architects subsystems, mentors junior engineers, mitigates tech debt.
- Level 4 (Staff/Principal): Sets organizational technical direction, leads cross-team architecture.
EOF

cat << 'EOF' > "${SOURCE_DIR}/hr/benefits_enrollment_guide.txt"
Comprehensive Benefits Package Overview (Plan Year 2026):
- Medical: BlueCross BlueShield PPO & HDHP options with HSA match ($1,000 employer contribution).
- Dental & Vision: Delta Dental Premier / VSP Choice.
- 401(k) Retirement: 100% match up to 5% of base compensation; immediate vesting.
- Wellness: $75 monthly reimbursement for fitness and mental wellness.
EOF

cat << 'EOF' > "${SOURCE_DIR}/hr/code_of_conduct_v4.md"
# NovaTech Solutions Professional Code of Conduct
All employees must uphold integrity, transparency, and equal opportunity:
- Zero tolerance for harassment or discriminatory behaviors.
- Mandatory disclosure of conflicts of interest.
- Rigorous protection of customer intellectual property and proprietary trade secrets.
EOF

cat << 'EOF' > "${SOURCE_DIR}/hr/leave_policy_handbook.txt"
Time Off & Leave Guidelines:
- Flexible Paid Time Off (FPTO) for exempt salaried personnel.
- Standard 12 Paid Company Holidays per calendar year.
- 16 Weeks Paid Parental Leave for primary and secondary caregivers.
- 5 Days Dedicated Bereavement Leave.
EOF

cat << 'EOF' > "${SOURCE_DIR}/hr/salary_bands_fy26.csv"
BandLevel,RoleCategory,MinSalary,Midpoint,MaxSalary
L1,Junior_Specialist,65000,75000,85000
L2,Mid_Specialist,85000,100000,115000
L3,Senior_Specialist,115000,135000,155000
L4,Lead_Staff,150000,175000,200000
L5,Director_Principal,190000,225000,260000
EOF

cat << 'EOF' > "${SOURCE_DIR}/hr/training_modules_catalog.json"
{
  "catalog_version": "2026.1",
  "mandatory_trainings": [
    {"id": "SEC-101", "name": "Cybersecurity Hygiene & Phishing Defense", "duration_minutes": 45, "frequency": "Annual"},
    {"id": "ETH-201", "name": "Business Ethics and Anti-Corruption", "duration_minutes": 30, "frequency": "Annual"},
    {"id": "PRIV-301", "name": "GDPR and CCPA Data Protection Principles", "duration_minutes": 60, "frequency": "Bi-Annual"}
  ]
}
EOF

cat << 'EOF' > "${SOURCE_DIR}/hr/exit_interview_summaries.csv"
CaseID,ExitQuarter,PrimaryReason,CareerDestination,RehireEligible
EXT-2025-01,2025-Q3,Relocation,Startup_Founder,Yes
EXT-2025-02,2025-Q4,Higher_Compensation,Big_Tech,Yes
EXT-2026-01,2026-Q1,Career_Transition,Academic_Research,Yes
EOF

cat << 'EOF' > "${SOURCE_DIR}/hr/remote_work_agreements.csv"
AgreementID,EmployeeID,DesignatedHomeState,StipendIssued,VPN_AccessApproved
RWA-101,EMP002,Washington,Yes,Yes
RWA-102,EMP003,New_York,Yes,Yes
RWA-103,EMP008,California,Yes,Yes
EOF

cat << 'EOF' > "${SOURCE_DIR}/hr/internship_program_roster.csv"
Cohort,InternName,University,Mentor,ProjectScope
Summer_2026,Jordan_Lee,UT_Austin,Alex_Morgan,Distributed_Tracing_Engine
Summer_2026,Mia_Patel,Georgia_Tech,Elena_Rostova,eBPF_Network_Probe
Summer_2026,Devon_Kim,Carnegie_Mellon,David_Chen,Automated_Reconciliation_Bot
EOF

head -c 1024 /dev/urandom | base64 > "${SOURCE_DIR}/hr/health_insurance_claims_batch.dat"

# ------------------------------------------------------------------------------
# 3. Engineering Department Dataset (~13 files)
# ------------------------------------------------------------------------------
log_info "Populating Engineering department files..."
cat << 'EOF' > "${SOURCE_DIR}/engineering/architecture_decision_records.md"
# ADR-001: Centralized Backup Strategy with GNU Tar Listed Incremental
- Status: Accepted
- Context: We require a reliable, POSIX-compliant backup mechanism across department shares.
- Decision: Utilize GNU tar `--listed-incremental` (.snar) with weekly full backups and daily incrementals.
- Consequences: Low overhead, deduplication of unchanged files, rapid disaster recovery.
EOF

cat << 'EOF' > "${SOURCE_DIR}/engineering/api_v2_specifications.json"
{
  "openapi": "3.1.0",
  "info": {"title": "NovaTech Cloud Control API", "version": "2.4.0"},
  "servers": [{"url": "https://api.novatech.internal/v2"}],
  "paths": {
    "/backups": {
      "get": {"summary": "List available backup archives", "responses": {"200": {"description": "Array of backup manifests"}}},
      "post": {"summary": "Trigger asynchronous backup snapshot", "responses": {"202": {"description": "Job queued"}}}
    }
  }
}
EOF

cat << 'EOF' > "${SOURCE_DIR}/engineering/microservices_inventory.csv"
ServiceID,Language,Runtime,DockerImage,ReplicaCount,HealthCheckPort
auth-service,Go,1.24,registry.novatech.internal/auth:v2.1,4,8081
billing-engine,Rust,1.85,registry.novatech.internal/billing:v1.9,3,8082
telemetry-collector,C++,GCC14,registry.novatech.internal/telemetry:v3.0,6,8083
backup-coordinator,Python,3.12,registry.novatech.internal/backup-agent:v2.0,2,8084
EOF

cat << 'EOF' > "${SOURCE_DIR}/engineering/database_schema_v3.sql"
-- NovaTech Production Schema Migration v3.4.0
CREATE TABLE IF NOT EXISTS backup_jobs (
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_type VARCHAR(16) NOT NULL CHECK (job_type IN ('FULL', 'INCREMENTAL', 'DIFFERENTIAL')),
    archive_name VARCHAR(255) NOT NULL UNIQUE,
    checksum_sha256 CHAR(64) NOT NULL,
    bytes_written BIGINT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'IN_PROGRESS',
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_backup_jobs_status ON backup_jobs(status, started_at);
EOF

cat << 'EOF' > "${SOURCE_DIR}/engineering/incident_postmortem_202603.md"
# Postmortem: Database Replica Lag on Cluster 04 (March 2026)
- Impact: 12 minutes of read-only fallback mode.
- Root Cause: Massive bulk analytics import saturated NVMe write queue.
- Remediation: Throttle background batch queries, implement proactive queue depth monitoring.
EOF

cat << 'EOF' > "${SOURCE_DIR}/engineering/ci_cd_pipeline_config.yml"
version: 2.1
workflows:
  build-and-verify:
    jobs:
      - lint-scripts
      - static-analysis:
          requires: [lint-scripts]
      - unit-tests:
          requires: [static-analysis]
      - integration-backup-test:
          requires: [unit-tests]
EOF

cat << 'EOF' > "${SOURCE_DIR}/engineering/kubernetes_cluster_topology.json"
{
  "clusters": [
    {"name": "us-east-prod-k8s", "region": "us-east-1", "worker_nodes": 48, "cni": "cilium", "k8s_version": "v1.31.2"},
    {"name": "eu-central-prod-k8s", "region": "eu-central-1", "worker_nodes": 32, "cni": "cilium", "k8s_version": "v1.31.2"}
  ]
}
EOF

cat << 'EOF' > "${SOURCE_DIR}/engineering/security_hardening_checklist.md"
# Linux Server Security Hardening Standards
1. SSH: Disable password authentication (`PasswordAuthentication no`), enforce ed25519 keys.
2. Kernel: Disable unnecessary module loading (`kernel.modules_disabled = 1`).
3. Firewall: Default DROP on INPUT and FORWARD chains; explicit whitelist for management subnet.
4. Audit: Enforce auditd rules on `/etc/shadow`, `/etc/sudoers`, and backup repository directories.
EOF

cat << 'EOF' > "${SOURCE_DIR}/engineering/backend_service_endpoints.csv"
Endpoint,Method,AuthRequired,RateLimitPerMin,SLA_Target
/api/v2/health,GET,false,10000,99.999%
/api/v2/metrics,GET,true,600,99.95%
/api/v2/snapshot/create,POST,true,60,99.99%
/api/v2/restore/verify,POST,true,30,99.99%
EOF

cat << 'EOF' > "${SOURCE_DIR}/engineering/caching_strategy_rfc.md"
# RFC-042: Multi-Tier Distributed Caching Strategy
Proposes utilizing local Redis cluster replicas for high-frequency session validation, with write-through consistency guaranteed by message bus publishing.
EOF

cat << 'EOF' > "${SOURCE_DIR}/engineering/observability_metrics_dictionary.json"
{
  "metrics": [
    {"name": "backup_duration_seconds", "type": "histogram", "help": "Execution latency for backup runs"},
    {"name": "backup_bytes_transferred", "type": "counter", "help": "Total volume in bytes archived"},
    {"name": "backup_verification_failures_total", "type": "counter", "help": "Count of archive integrity verification errors"}
  ]
}
EOF

cat << 'EOF' > "${SOURCE_DIR}/engineering/encryption_key_rotation_policy.txt"
Key Management Policy:
- Master encryption keys rotated every 90 days.
- Backup archive encryption keys derived per session using PBKDF2 with SHA-256 and minimum 100,000 iterations.
- Old keys archived in secure HSM for retroactive recovery validation.
EOF

head -c 2048 /dev/urandom | base64 > "${SOURCE_DIR}/engineering/compiled_diagnostics_bundle.bin"

# ------------------------------------------------------------------------------
# 4. Sales Department Dataset (~12 files)
# ------------------------------------------------------------------------------
log_info "Populating Sales department files..."
cat << 'EOF' > "${SOURCE_DIR}/sales/crm_leads_enterprise_q1.csv"
LeadID,Company,ContactPerson,DealSize,LeadStage,Probability
LEAD-901,Acme_Industries,Robert_Smith,450000,Proposal_Review,0.70
LEAD-902,Globex_Corporation,Hank_Scorpio,850000,Contract_Negotiation,0.90
LEAD-903,Initech_LLC,Peter_Gibbons,220000,Technical_Validation,0.50
LEAD-904,Umbrella_Holdings,Albert_Wesker,1200000,Discovery_Call,0.30
EOF

cat << 'EOF' > "${SOURCE_DIR}/sales/customer_pipeline_funnel.csv"
Stage,TotalDeals,PipelineValue,WeightedValue
Discovery,42,12500000,2500000
Evaluation,28,9800000,3920000
Proposal,18,7400000,5180000
Negotiation,9,4100000,3690000
Closed_Won,14,5800000,5800000
EOF

cat << 'EOF' > "${SOURCE_DIR}/sales/pricing_calculator_tiers.csv"
Tier,BaseFeeMonthly,PerNodeRate,StoragePerGB,SupportTier
Startup,199,15,0.08,Standard_BusinessHours
Growth,799,12,0.06,Priority_24x7
Enterprise,2499,9,0.04,Dedicated_TAM_SLA_1hr
EOF

cat << 'EOF' > "${SOURCE_DIR}/sales/partner_reseller_agreements.md"
# Global Reseller Distribution Terms
- Certified Premier Partners receive 22% margin on recurring SaaS licenses.
- Tier 1 distributor commitment: minimum $1.5M ARR booked annually.
- Joint marketing fund (MDF) allocated at 3% of booked revenue.
EOF

cat << 'EOF' > "${SOURCE_DIR}/sales/client_case_studies.txt"
Case Study 1: FinTech MegaCorp
- Problem: Daily database snapshots took 6 hours, saturating storage I/O.
- Solution: Deployed NovaTech GNU-tar listed incremental backup architecture.
- Result: Backup duration reduced to 18 minutes; RTO cut by 78%.
EOF

cat << 'EOF' > "${SOURCE_DIR}/sales/competitor_matrix_analysis.csv"
Feature,NovaTech,Competitor_A,Competitor_B
Incremental_Backup,Native_GNU_Tar,Proprietary_Agent,Block_Level_Snap
Restoration_Speed,Ultra_Fast,Moderate,Slow
Platform_Lock_in,Zero_OpenStandards,High,Moderate
Storage_Elasticity,LVM_Resize,Fixed_Appliance,Cloud_Only
EOF

cat << 'EOF' > "${SOURCE_DIR}/sales/contract_templates_master.md"
# Master Services Agreement (MSA) Template
Standard warranty: 99.9% service availability guarantee.
Confidentiality obligations survive termination for a period of 5 calendar years.
Data sovereignty: Customer data remains strictly in customer-designated geopolitical jurisdiction.
EOF

cat << 'EOF' > "${SOURCE_DIR}/sales/revenue_attribution_model.json"
{
  "fiscal_year": 2026,
  "channels": [
    {"name": "Inbound_Organic", "share_percent": 34.5, "cac": 1200},
    {"name": "Outbound_SDR", "share_percent": 28.0, "cac": 2800},
    {"name": "Partner_Channel", "share_percent": 24.5, "cac": 1600},
    {"name": "Executive_Events", "share_percent": 13.0, "cac": 4500}
  ]
}
EOF

cat << 'EOF' > "${SOURCE_DIR}/sales/sales_territory_mapping.csv"
Territory,RegionalVP,TargetQuota,ActiveReps
North_America_East,Marcus_Vance,14000000,12
North_America_West,Clara_Oswald,16000000,14
EMEA_Central,Hans_Gruber,9500000,8
APAC_South,Kenji_Sato,7500000,6
EOF

cat << 'EOF' > "${SOURCE_DIR}/sales/annual_quota_targets.csv"
Year,TargetTotal,DirectSales,ChannelSales,ExpansionRevenue
2026,47000000,28000000,11000000,8000000
2025,35000000,22000000,8000000,5000000
EOF

cat << 'EOF' > "${SOURCE_DIR}/sales/win_loss_analysis_q2.csv"
DealID,Outcome,PrimaryFactor,CompetitorInvolved
DEAL-401,Won,Superior_Backup_Speed_And_Open_Format,Competitor_A
DEAL-402,Won,Transparent_Pricing_And_LVM_Flexibility,Competitor_B
DEAL-403,Lost,Missing_Legacy_Tape_Hardware_Driver,Competitor_A
EOF

cat << 'EOF' > "${SOURCE_DIR}/sales/marketing_campaign_roas.csv"
Campaign,Spend,AttributedPipeline,ROAS_Multiple
KubeCon_2026_Keynote,85000,920000,10.8x
Cloud_Native_Webinar_Series,15000,185000,12.3x
Google_Search_AdWords_Q1,42000,310000,7.3x
EOF

TOTAL_FILES="$(find "${SOURCE_DIR}" -type f | wc -l)"
TOTAL_BYTES="$(du -sb "${SOURCE_DIR}" | awk '{print $1}')"

log_success "Seeding complete: Created ${TOTAL_FILES} fictional enterprise files across 4 departments."
log_success "Total Source Dataset Size: $(format_bytes "${TOTAL_BYTES}")"
