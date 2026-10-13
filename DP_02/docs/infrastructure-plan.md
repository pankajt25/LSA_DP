# NovaTech Solutions — Centralized Backup & Recovery Infrastructure Plan
**Course:** Linux System Administration (E1ITA307) — Modules: IV | CO4  
**Project:** Centralized Backup & Recovery Server (DP_02)  
**Target Organization:** NovaTech Solutions  
**Author:** Linux Systems Administration Engineering Team  

---

## 1. Executive Summary & Problem Context

NovaTech Solutions operates a distributed multi-departmental Linux environment containing mission-critical records across Finance, Human Resources, Engineering, and Sales. To safeguard against accidental deletion, hardware failure, disk corruption, and ransomware scenarios, NovaTech requires an automated, robust, and verifiable backup and recovery server.

This plan details the architectural design, storage topology, backup automation engine, data retention policy, cryptographic validation pipelines, and disaster recovery verification procedures fulfilling Course Learning Outcome **CO4**.

---

## 2. Infrastructure Architecture & Topology

The centralized backup infrastructure enforces strict sandbox isolation, dedicated block storage mapping via Linux loopback devices, POSIX file permissions, and GNU tar listed-incremental state tracking.

```
+---------------------------------------------------------------------------------------------------+
|                                  NOVATECH BACKUP ARCHITECTURE                                     |
+---------------------------------------------------------------------------------------------------+
|                                                                                                   |
|  [ PROTECTED DATA SOURCE ]                                                                        |
|  sandbox_data/source/                                                                             |
|  +-- finance/     (Budgets, Payroll, Ledger, Tax, Audits)                                         |
|  +-- hr/          (Directories, Policies, Benefits, Rosters)                                      |
|  +-- engineering/ (ADRs, Schema SQL, Microservices, Configs)                                      |
|  +-- sales/       (Pipelines, CRM Leads, Quotas, Contracts)                                       |
|                                                                                                   |
|           |                                                                                       |
|           |   tar --listed-incremental=<snar>                                                     |
|           +---------------------------+---------------------------+                               |
|                                       |                           |                               |
|                                [WEEKLY FULL]               [DAILY INCR]                           |
|                               (Sunday 01:00)              (Daily 02:00)                           |
|                                       |                           |                               |
|                                       v                           v                               |
|  [ BACKUP SCHEDULING (CRON) ] ---> full_<TS>.tar.gz        incr_<TS>.tar.gz                       |
|  Tagged: # LSA_SPRINT_TEST            + SHA-256 Checksum          + SHA-256 Checksum              |
|                                       |                           |                               |
|                                       +-------------+-------------+                               |
|                                                     |                                             |
|                                                     v                                             |
|  [ DEDICATED STORAGE VOLUME ] <---------------------+                                             |
|  Sparse Image: sandbox_data/backup_disk.img (1 GiB)                                               |
|  Verified Loopback: /dev/loopX  (losetup -j verification)                                         |
|  Filesystem: ext4 (LABEL="NOVA_BACKUP")                                                           |
|  Mount Target: sandbox_data/repo_mount/                                                           |
|  Repository: sandbox_data/repo/ -> repo_mount/repo/ (chmod 700 / 600)                             |
|  Owner: lsatest_backupadmin : lsatest_backup_ops                                                  |
|                                                                                                   |
|                                                     |                                             |
|                                                     |  scripts/restore.sh                         |
|                                                     v  (Full baseline + Incremental chain)        |
|                                                                                                   |
|  [ DISASTER RECOVERY TARGET ] <---------------------+                                             |
|  sandbox_data/restore_target/                                                                     |
|  1. Pre-flight SHA-256 & tar structural validation                                                |
|  2. Full baseline extraction (tar -xzf ... -g /dev/null)                                          |
|  3. Sequential incremental replay in chronological order                                          |
|  4. Pre-disaster manifest validation (diff -r & SHA-256 parity)                                   |
|                                                                                                   |
+---------------------------------------------------------------------------------------------------+
```

---

## 3. Storage Sizing & Capacity Assumptions

### 3.1 Dataset Profile
- **Source Department Dataset:** ~50 fictional enterprise files totaling ~20–35 KB baseline.
- **Daily Mutation Velocity:** 2 additions, 2 modifications, 1 deletion per business day (~3–6 KB delta).
- **Weekly Full Backup Size:** ~15 KB compressed (gzip level 6 default in `tar -czf`).
- **Daily Incremental Backup Size:** ~2–3 KB compressed per day.

### 3.2 Sizing Projections (1-Month Production Model)
Assuming typical production scaling where 1 department share is 50 GB:
- Initial Baseline (Full): 50 GB
- Daily Delta (Incremental): 2.5 GB / day (5% daily change rate)
- Weekly Full + 6 Daily Incrementals = 50 GB + (6 * 2.5 GB) = 65 GB per cycle
- Active Retention (2 Fulls + associated Incrementals): `2 * 65 GB = 130 GB`
- Dedicated Volume Provisioned: 200 GB (35% growth / overhead headroom)

For our safe sandbox demonstration:
- A **1 GiB** sparse image file (`sandbox_data/backup_disk.img`) is allocated via `truncate -s 1G`.
- Format: `ext4` filesystem with default 4096-byte blocks and reserve blocks.
- Usable Volume Capacity: ~974 MiB, easily accommodating dozens of test backup cycles while exercising real filesystem block allocation.

---

## 4. Backup Strategy: Full vs. Incremental vs. Differential Tradeoffs

| Backup Strategy | Storage Utilization | Backup Speed | Recovery Complexity | RTO Performance | RPO Capability |
|---|---|---|---|---|---|
| **Full Backup** | Very High (Duplicates entire dataset each run) | Slowest (Reads all files on disk) | Simplest (Single archive extraction) | Fastest RTO (1 archive) | High (only feasible weekly) |
| **Differential Backup** | Moderate (Stores all changes since last Full) | Medium (Grows daily until next Full) | Moderate (Full + 1 latest Differential) | Fast RTO (2 archives) | Moderate |
| **GNU Tar Listed-Incremental** *(Selected)* | **Optimal (Lowest footprint; stores changes since last backup)** | **Fastest (Only reads/writes modified inodes)** | **Chained (Full + ordered replay of Incrementals)** | **High RTO with automated scripts** | **Superior RPO (Daily / Hourly feasible)** |

### Why GNU Tar Listed-Incremental (`--listed-incremental`)?
GNU tar provides kernel-level filesystem inspection via snapshot files (`.snar`). During Level 0 full backup, tar indexes directory mtimes and inode metadata into the `.snar` file. On subsequent incremental executions, tar compares live filesystem state against the snapshot file:
- **Modified files:** Archived with new content.
- **Added files:** Archived with new content.
- **Deleted files:** Recorded as GNU tar directory removal records.
When extracting during disaster recovery with `--listed-incremental=/dev/null`, tar accurately deletes obsolete files and updates modified files without leaving orphaned artifacts.

---

## 5. Retention Policy Rationale

### Policy Definition
- **Retain the 2 most recent Full backups and all associated incremental generations.**
- **Prune any Full backup older than the 2nd newest, along with any incremental whose ancestor is the expired Full backup.**

### Rationale
1. **Redundancy & Rollback Assurance:** If the most recent backup cycle suffers from silent bit-rot or was taken during an unnoticed operational error, the administrator can seamlessly fall back to the preceding full backup cycle.
2. **Storage Boundedness:** Without automated retention, disk utilization grows unbounded until `ENOSPC` causes backup jobs to fail silently.
3. **Audit Safety:** `retention.sh` enforces `--dry-run` simulation before destructive purging, requiring validation logs.

---

## 6. Recovery Point Objective (RPO) & Recovery Time Objective (RTO)

| Metric | Target SLA | Implementation Mechanism | Validation in DP_02 |
|---|---|---|---|
| **RPO (Recovery Point Objective)** | **<= 24 Hours** | Daily incremental backups scheduled at 02:00 AM via cron | Data loss is strictly bounded to transactions since 02:00 AM. Demonstrated via Stage 1 and Stage 2 incremental mutations. |
| **RTO (Recovery Time Objective)** | **< 15 Minutes** | Automated script-driven restore pipeline (`restore.sh`) | Full baseline extraction + 2 incrementals executed and verified in under **10 seconds** on the test server. |

---

## 7. Cryptographic Integrity & Security Model

1. **Pre-Restoration SHA-256 Manifest Verification:**
   - Every archive generates a companion `.sha256` manifest upon creation (`sha256sum archive > archive.sha256`).
   - Before `restore.sh` extracts a single byte, it executes `sha256sum -c` and `tar -tzf` on every archive in the recovery chain. If any checksum fails or archive header is malformed, recovery halts immediately.
2. **Access Control & RBAC Isolation:**
   - Dedicated service user: `lsatest_backupadmin`
   - Dedicated operations group: `lsatest_backup_ops`
   - Repository directory mode: `chmod 700` (or `770` for ops team)
   - Archive files: `chmod 600` (or `660`)
   - Negative access test: Non-member user `nobody` is strictly denied directory traversal (`Permission denied`).
3. **At-Rest Encryption:**
   - Evaluated using OpenSSL `AES-256-CBC` with PBKDF2 key derivation and salt (`openssl enc -aes-256-cbc -pbkdf2`).
   - Decrypted payload achieves 100% SHA-256 checksum parity.

---

## 8. Archive Naming Conventions & Metadata Architecture

| Artifact Type | Naming Standard | Example |
|---|---|---|
| Full Backup Archive | `full_<YYYYMMDD_HHMMSS>.tar.gz` | `full_20261010_194622.tar.gz` |
| Full Backup Checksum | `full_<YYYYMMDD_HHMMSS>.tar.gz.sha256` | `full_20261010_194622.tar.gz.sha256` |
| Incremental Archive | `incr_<YYYYMMDD_HHMMSS>.tar.gz` | `incr_20261010_194632.tar.gz` |
| Incremental Checksum | `incr_<YYYYMMDD_HHMMSS>.tar.gz.sha256` | `incr_20261010_194632.tar.gz.sha256` |
| Active Snapshot Manifest | `sandbox_data/repo/.meta/active.snar` | Binary GNU tar snapshot state |
| Cycle Baseline Snapshot | `sandbox_data/repo/.meta/<ARCHIVE>.snar` | Preserved copy of cycle baseline |
| Backup Audit Metadata | `sandbox_data/repo/.meta/<ARCHIVE>.meta` | Key-value execution audit trail |
