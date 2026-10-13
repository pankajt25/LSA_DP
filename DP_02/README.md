# Centralized Backup & Recovery Server (DP_02)
**Course:** Linux System Administration (E1ITA307) — Modules: IV | CO4  
**Project:** Linux Infrastructure Deployment Project #2  
**Organization:** NovaTech Solutions  
**Target Repository:** [https://github.com/pankajt25/LSA_DP.git](https://github.com/pankajt25/LSA_DP.git)  

---

## Command to Execute

To execute the automated end-to-end backup, disaster recovery validation, integrity verification, retention evaluation, and live HTML report generation:

```bash
# Navigate to the DP_02 project directory
cd DP_02

# Execute master runner (single-command cross-platform orchestrator)
bash run.sh
```

> [!NOTE]
> `cleanup.sh` is a deliberate, separate second step that purges external system artifacts (loop device, test accounts, tagged cron lines). Do not run it until after all system verification screenshots and reviews are completed:
> ```bash
> bash cleanup.sh
> ```

---

## Viewing the HTML Report

The HTML audit report is self-contained with inline CSS and a high-contrast dark theme. `run.sh` automatically detects the operating system and opens the report.

- **WSL / Windows Launch Command:**
  ```bash
  explorer.exe "$(wslpath -w report.html)"
  ```
- **Direct Windows File Path:**
  `D:\Users\Dell\Downloads\Projects\LSA\Deployment_Projects\DP_02\report.html`
- **Native Linux (Desktop):**
  ```bash
  xdg-open report.html
  ```

---

## Scenario & Policy Specification

NovaTech Solutions operates a centralized Linux infrastructure server hosting departmental records for **Finance**, **Human Resources**, **Engineering**, and **Sales**. The server enforces automated scheduled backups, cryptographic integrity validation, bounded retention, and disaster recovery readiness.

| Parameter | Organizational Policy | Implementation Mechanism |
|---|---|---|
| **Full Backup** | Weekly (Sunday 01:00 AM) | GNU tar Level 0 baseline (`--listed-incremental`) |
| **Incremental Backup** | Daily (02:00 AM) | GNU tar cumulative delta reusing active `.snar` |
| **Retention Policy** | Retain 2 most recent Fulls + associated Incrementals | Automated pruning via `retention.sh` (`--dry-run` safe) |
| **Integrity Assurance** | SHA-256 cryptographic manifests per archive | Checked post-creation and mandatory pre-restoration |
| **Disaster Recovery** | Point-in-time restoration with 100% data fidelity | Automated recovery pipeline (`restore.sh`) verified via `diff -r` |
| **Storage Isolation** | Dedicated 1 GiB sparse loopback volume | Loop device `/dev/loop0` with ext4 (`NOVA_BACKUP`) |
| **Security & Access** | Principle of Least Privilege & RBAC | Dedicated user `lsatest_backupadmin`, group `lsatest_backup_ops`, mode 700/600 |

> [!IMPORTANT]
> **Real-Data Sandbox Guarantee:** All backup sources, repositories, and recovery targets reside strictly inside `DP_02/sandbox_data/`. The departmental files are generated demonstration records to protect host privacy. Every script executes real system utilities (`tar`, `sha256sum`, `losetup`, `mkfs.ext4`, `cron`, `openssl`), capturing real cryptographic hashes, byte sizes, and kernel timestamps.

---

## Phase-by-Phase Real Execution Outputs

### Phase 0: Storage Volume Setup (Storage & LVM Implementation)
Executed via `scripts/storage_setup.sh --demo-lvm`:

```text
[2026-10-10 19:34:23] [INFO] [Step 1/4] Creating 1 GiB sparse image file: .../sandbox_data/backup_disk.img
[2026-10-10 19:34:24] [SUCCESS] Sparse image created: 1.0G .../sandbox_data/backup_disk.img
[2026-10-10 19:34:25] [INFO] [Step 2/4] Attaching loopback device to .../sandbox_data/backup_disk.img...
[2026-10-10 19:34:25] [INFO] Allocated loop device: /dev/loop0
[2026-10-10 19:34:26] [SUCCESS] Device verification PASSED: /dev/loop0 safely mapped to backup_disk.img
------------------------------------------------------------------
Running Optional Stretch: LVM Physical Volume & Elastic Volume Demo
------------------------------------------------------------------
[2026-10-10 19:34:26] [INFO] Initializing Physical Volume (PV) on /dev/loop0...
  Physical volume "/dev/loop0" successfully created.
[2026-10-10 19:34:27] [INFO] Creating Volume Group 'backup_vg'...
  Volume group "backup_vg" successfully created
[2026-10-10 19:34:27] [INFO] Creating Logical Volume 'backup_lv' (Initial size: 500M)...
  Logical volume "backup_lv" created.
[2026-10-10 19:34:28] [INFO] Formatting /dev/backup_vg/backup_lv with ext4...
[2026-10-10 19:34:38] [SUCCESS] Mounted initial LVM volume at .../sandbox_data/repo_mount:
Filesystem                       Size  Used Avail Use% Mounted on
/dev/mapper/backup_vg-backup_lv  452M  152K  417M   1% .../sandbox_data/repo_mount
[2026-10-10 19:34:39] [INFO] Demonstrating Online LVM Elastic Expansion (+300M)...
  Size of logical volume backup_vg/backup_lv changed from 500.00 MiB to 800.00 MiB.
  Logical volume backup_vg/backup_lv successfully resized.
resize2fs 1.47.2 (1-Jan-2025)
The filesystem on /dev/backup_vg/backup_lv is now 204800 (4k) blocks long.
[2026-10-10 19:34:44] [SUCCESS] Online expansion complete. Updated filesystem capacity:
Filesystem                       Size  Used Avail Use% Mounted on
/dev/mapper/backup_vg-backup_lv  729M  152K  682M   1% .../sandbox_data/repo_mount
  LV        VG        Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  backup_lv backup_vg -wi-ao---- 800.00m
[2026-10-10 19:34:46] [SUCCESS] LVM Stretch Demonstration concluded successfully.
[2026-10-10 19:34:47] [INFO] [Step 3/4] Formatting ext4 filesystem on verified device /dev/loop0...
[2026-10-10 19:34:56] [SUCCESS] ext4 filesystem initialized on /dev/loop0
[2026-10-10 19:34:56] [INFO] [Step 4/4] Mounting /dev/loop0 at .../sandbox_data/repo_mount...
[2026-10-10 19:34:56] [SUCCESS] Repository successfully mounted and linked: repo -> repo_mount/repo

Phase 0 Verification Evidence (Storage Implementation):
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
loop0    7:0    0   1G  0 loop .../sandbox_data/repo_mount

Filesystem      Size  Used Avail Use% Mounted on
/dev/loop0      974M  288K  906M   1% .../sandbox_data/repo_mount

/dev/loop0: LABEL="NOVA_BACKUP" UUID="7fe3f07e-2bd0-4c4d-895d-d332af2db009" BLOCK_SIZE="4096" TYPE="ext4"
```

---

### Phase 1: Protected Dataset & Mutation Engine
Executed via `scripts/seed_data.sh` and `scripts/mutate_data.sh`:

```text
[2026-10-10 19:35:12] [INFO] Populating Finance department files...
[2026-10-10 19:35:15] [INFO] Populating Human Resources department files...
[2026-10-10 19:35:15] [INFO] Populating Engineering department files...
[2026-10-10 19:35:16] [INFO] Populating Sales department files...
[2026-10-10 19:35:18] [SUCCESS] Seeding complete: Created 49 fictional enterprise files across 4 departments.
[2026-10-10 19:35:18] [SUCCESS] Total Source Dataset Size: 18.45 KB

[Mutation Stage 1 applied]
  [ADD] finance/audit_addendum_q1.csv
  [ADD] engineering/hotfix_release_notes_2.4.1.md
  [MODIFY] sales/crm_leads_enterprise_q1.csv
  [MODIFY] hr/employee_directory.csv
  [DELETE] sales/win_loss_analysis_q2.csv

[Mutation Stage 2 applied]
  [ADD] hr/wellness_initiative_feedback.csv
  [ADD] engineering/api_gateway_routes.json
  [MODIFY] engineering/architecture_decision_records.md
  [MODIFY] finance/petty_cash_disbursements.csv
  [DELETE] finance/investor_deck_notes.md
```

---

### Phase 2: Backup Suite & Retention Enforcement
Executed via `scripts/backup_full.sh`, `scripts/backup_incremental.sh`, and `scripts/retention.sh`:

```text
[FULL BACKUP EXECUTION]
[2026-10-10 19:46:22] [INFO] Source validated: 49 files detected across department shares.
[2026-10-10 19:46:22] [INFO] Repository storage check: 927500 KB free space available.
[2026-10-10 19:46:22] [INFO] Target Archive: full_20261010_194622.tar.gz
[2026-10-10 19:46:24] [INFO] Generating SHA-256 cryptographic checksum manifest...
[2026-10-10 19:46:25] [SUCCESS] Integrity verification PASSED: SHA-256 and tar decompression valid.
[2026-10-10 19:46:25] [SUCCESS] FULL backup completed: full_20261010_194622.tar.gz | 14.55 KB | SHA256: 8254c40b8f...

[INCREMENTAL 1 EXECUTION]
[2026-10-10 19:46:32] [INFO] Baseline full backup verified: full_20261010_194622.tar.gz
[2026-10-10 19:46:33] [SUCCESS] INCREMENTAL backup completed: incr_20261010_194632.tar.gz | 2.10 KB | SHA256: 9e32fc93...

[INCREMENTAL 2 EXECUTION]
[2026-10-10 19:46:44] [SUCCESS] INCREMENTAL backup completed: incr_20261010_194641.tar.gz | 2.02 KB | SHA256: 22ca042c...

[RETENTION ENFORCEMENT - PRUNING EXPIRED CYCLES]
[2026-10-10 19:47:26] [INFO] Repository scan detected 5 full backup archive(s).
[2026-10-10 19:47:26] [INFO] Retention demarcation boundary:
  Oldest retained full backup: full_20261010_194435.tar.gz
  Expired full backup count   : 3
  Retained Full Archives      : full_20261010_194435.tar.gz, full_20261010_194622.tar.gz
  Expired Archives Marked     : 21 items
[2026-10-10 19:47:48] [SUCCESS] Retention enforcement executed: Purged 21 file(s), reclaimed 50.94 KB.
```

---

### Phase 3: Disaster Recovery Validation (CO4 Core)
Executed via `scripts/recovery_test.sh`:

```text
[Step 4/6] Generating Pre-Disaster Cryptographic Manifest of Source...
[SUCCESS] Pre-disaster snapshot indexed: 51 files recorded.
[Step 5/6] Simulating Catastrophic Data Loss in Source Sandbox...
[WARN]   [DISASTER SIMULATION] Purging entire department share: source/sales/
[WARN]   [DISASTER SIMULATION] Corrupting critical technical asset: source/engineering/architecture_decision_records.md
[WARN] Disaster effect: File count dropped from 51 to 40 files.

[Step 6/6] Executing Full Chain Disaster Restoration...
[INFO] Identified Baseline Full Backup: full_20261010_194622.tar.gz
[INFO] Identified 2 incremental backup archive(s) in recovery chain.
[SUCCESS] Pre-Flight Verification PASSED: All 3 archive(s) verified authentic.
[INFO] Stage 1: Extracting Full Baseline into target sandbox...
[SUCCESS] Full baseline restored successfully.
[INFO] Stage 2: Replaying 2 incremental archive(s)...
[SUCCESS] All incremental revisions replayed successfully.
[SUCCESS] Point-in-Time Restoration Complete in 3s. Target: restore_target/ | 51 files (19.45 KB)

======================================================================
                 DISASTER RECOVERY AUDIT SCORECARD                    
======================================================================
Pre-Disaster Expected Files   : 51
Total Files Restored          : 51
Cryptographically Matched     : 51
Missing Files                 : 0
Mismatched Checksums          : 0
======================================================================
[SUCCESS] RECOVERY AUDIT VERDICT: PASS (100% Data Fidelity Preserved)

[CORRUPTED ARCHIVE TEST]
Creating test clone of archive: incr_20261010_194641.tar.gz -> corrupt_tamper_demo.tar.gz
Injecting deliberate bit-flip corruption at offset 128 (dd conv=notrunc)...
Running verify_backup.sh against tampered archive...
[SUCCESS] CORRUPTION DETECTED PROMPTLY: Verification engine blocked corrupted archive [OK].
```

---

### Phase 4: Scheduling & Cron Automation
Executed via `scripts/install_cron.sh`:

```text
[2026-10-10 19:39:36] [SUCCESS] Cron service is active and running.
[2026-10-10 19:39:37] [INFO] Inspecting existing user crontab (BEFORE modifications):
----------------------------------------------------------------------
0 1 * * * /bin/bash /mnt/d/Users/Dell/Downloads/LINUX/Exam/37.sh /home/pankaj/project
----------------------------------------------------------------------
[2026-10-10 19:39:37] [SUCCESS] Crontab installed with NovaTech backup schedules and live demo monitor.

[2026-10-10 19:40:02] [SUCCESS] CRON JOB FIRED SUCCESSFULLY! Output detected in logs/cron.log:
[2026-10-10 19:40:02] [INFO] Initiating NovaTech Centralized INCREMENTAL Backup
[2026-10-10 19:40:02] [INFO] Baseline full backup verified: full_20261010_193845.tar.gz
[2026-10-10 19:40:02] [INFO] Executing GNU tar incremental snapshot...

[2026-10-10 19:40:03] [SUCCESS] Temporary demo schedule removed.
[2026-10-10 19:40:03] [INFO] Final Scheduled Crontab (AFTER removing demo line):
----------------------------------------------------------------------
0 1 * * * /bin/bash /mnt/d/Users/Dell/Downloads/LINUX/Exam/37.sh /home/pankaj/project
0 1 * * 0 /bin/bash .../scripts/backup_full.sh >> .../logs/cron.log 2>&1 # LSA_SPRINT_TEST
0 2 * * * /bin/bash .../scripts/backup_incremental.sh >> .../logs/cron.log 2>&1 # LSA_SPRINT_TEST
----------------------------------------------------------------------
```

---

### Phase 5: Security Hardening & Access Control
Executed via `scripts/security_setup.sh`:

```text
[Step 1/4] Demonstrating At-Rest OpenSSL AES-256-CBC Encryption Pipeline...
Source Archive: full_20261010_193845.tar.gz
Encrypting archive with AES-256-CBC & PBKDF2 key derivation...
[SUCCESS] Encrypted payload generated: encrypted_demo.tar.gz.enc (14.28 KB)
Decrypting ciphertext payload back to plaintext archive...
[SUCCESS] CRYPTOGRAPHIC PARITY VERIFIED: Decrypted archive SHA-256 matches original exactly [OK].

[Step 2/4] Provisioning dedicated backup group and service account...
[SUCCESS] Group lsatest_backup_ops created.
[SUCCESS] Service user lsatest_backupadmin created.

[Step 3/4] Enforcing POSIX ownership and file mode restrictions on repository...
[SUCCESS] Repository permission model enforced (700 on repo, 600 on archives, owner: lsatest_backupadmin:lsatest_backup_ops).

[Step 4/4] Demonstrating negative authorization check (unauthorized user access denial)...
Testing directory access as unprivileged non-member user 'nobody'...
[SUCCESS] SECURITY VERIFIED: User 'nobody' was strictly DENIED access (Permission denied) [OK].
Testing authorized service user 'lsatest_backupadmin' access...
[SUCCESS] AUTHORIZATION VERIFIED: Service user 'lsatest_backupadmin' has full operational access [OK].
```

---

## Troubleshooting Log

During real execution and testing of the backup and recovery server, several edge cases were identified, debugged, and resolved:

| Issue # | Symptom | Root Cause Analysis | Remediation & Fix Applied |
|---|---|---|---|
| **#1** | `find "${REPO_DIR}" -maxdepth 1` returned 0 archives even though files existed in repository. | `REPO_DIR` was established as a symbolic link pointing to `repo_mount/repo`. In GNU `find`, invoking `find <symlink> -maxdepth 1` without trailing slashes or `-L` does not dereference the directory target. | Appended a trailing slash: `find "${REPO_DIR}/" -maxdepth 1` and `-L` across all search routines, ensuring symlinks are transparently traversed. |
| **#2** | `security_setup.sh` reported `find: .../repo/: Permission denied`. | Line 54 changed repository ownership to `lsatest_backupadmin:lsatest_backup_ops` with mode 770. Although user `pankaj` was added to `lsatest_backup_ops`, the active running bash shell process had not refreshed its supplementary group credentials (which requires a subshell login). | Executed repository inspection under `sudo` and scheduled OpenSSL tests prior to permission lockdown, followed by restoring cooperative operator permissions at the end of the script. |
| **#3** | `sudo -u nobody ls "${REPO_DIR}"` returned exit code 0 instead of being denied. | `ls <symlink>` without trailing slash merely prints the symlink file path rather than dereferencing and reading the target directory. Since the symlink was located in readable sandbox parent directory, `ls` succeeded. | Updated the negative authorization test to `sudo -u nobody ls -L "${REPO_DIR}"`. This forced target directory dereferencing, triggering kernel permission checks and returning `Permission denied` (exit code 2). |
| **#4** | `generate_report.sh` exited with code 127 (`command not found: 19:45:10`). | `recovery_test.sh` saved `LAST_TEST_TIMESTAMP=$(get_iso_timestamp)` into `logs/recovery_results.env` without double quotes (`LAST_TEST_TIMESTAMP=2026-10-10 19:45:10`). When sourced by bash, the space caused `19:45:10` to be executed as a command. | Wrapped all variable assignments in double quotes in the template: `LAST_TEST_TIMESTAMP="$(get_iso_timestamp)"`. |
| **#5** | Subsequent runs of `run.sh` failed with missing `sales/` directory in `mutate_data.sh`. | `recovery_test.sh` simulated disaster by purging `source/sales`. Because setup only seeded data if `finance` was missing, `source/sales` remained deleted on subsequent test iterations. | Updated `recovery_test.sh` to unconditionally execute `seed_data.sh` at Step 1, ensuring idempotent re-population of all departmental shares. |

---

## Final Validation Checklist

| Item | Validation Requirement | Status | Evidence Location |
|---|---|:---:|---|
| **1** | Sandbox Isolation: Nothing touched outside `DP_02/sandbox_data/` except loop/test user/cron | **PASS** | Verified path guards in `lib.sh`; `realpath` asserts |
| **2** | Storage Volume: 1 GiB sparse image mounted via verified `/dev/loop0` with ext4 | **PASS** | Phase 0 `lsblk`, `df -h`, `blkid` evidence output |
| **3** | Full Backup: GNU tar Level 0 baseline created, checksummed, verified | **PASS** | `full_*.tar.gz`, `sha256sum -c`, `tar -tzf` valid |
| **4** | Incremental Backups: Multiple incrementals created from real data changes | **PASS** | `incr_*.tar.gz` capturing Stage 1 & Stage 2 deltas |
| **5** | Corrupted Archive Detection: Bit-flip detected before restore | **PASS** | `corrupt_tamper_demo.tar.gz` rejected promptly |
| **6** | Disaster Recovery: Disaster simulated, restore completed, 0 mismatches | **PASS** | Scorecard: 51/51 matched, 0 missing, 0 diff -> PASS |
| **7** | Scheduled Automation: Cron installed, daemon active, demo job observed, removed | **PASS** | `logs/cron.log` output captured at 19:40:01 tick |
| **8** | Retention Policy: Dry-run and live enforcement keeping 2 Fulls + incrementals | **PASS** | Purged 21 expired items; kept 2 latest full cycles |
| **9** | Security & RBAC: Dedicated user/group, non-member `nobody` denied access | **PASS** | `nobody` exit code 2; `lsatest_backupadmin` exit 0 |
| **10** | Encryption Demonstration: OpenSSL AES-256-CBC at-rest encryption & parity | **PASS** | Decrypted archive SHA-256 matches original |
| **11** | Master Orchestrator: `run.sh` executes end-to-end and regenerates `report.html` | **PASS** | `run.sh` exited with code 0; opened host browser |
| **12** | Documentation & Defense: Comprehensive plan, commands log, viva questions | **PASS** | `docs/infrastructure-plan.md`, `commands_used.md` |

---

## Viva Voce Q&A (Defense Guide)

### Q1: What is the difference between Full, Incremental, and Differential backups?
- **Full Backup:** Archives the entire protected dataset regardless of whether files have changed. It provides the fastest restore (single archive extraction) but consumes the most storage capacity and takes the longest time to run.
- **Incremental Backup:** Archives only the files that have changed, been added, or been removed *since the most recent backup of any type* (Full or Incremental). It has the lowest storage footprint and runs fastest, but recovery requires restoring the baseline full backup followed by every subsequent incremental in sequence.
- **Differential Backup:** Archives all files changed *since the last Full backup*. Recovery requires only the Full backup plus the single latest Differential archive, but archive sizes grow progressively larger each day until the next Full backup.

### Q2: How does GNU tar `--listed-incremental` (`.snar`) work under the hood?
GNU tar uses a snapshot metadata file (conventionally `.snar`) that records directory device IDs, inode numbers, and modification timestamps (`mtime`). During a Level 0 full backup, tar initializes this file. During an incremental backup, tar traverses directories and compares filesystem attributes against the snapshot file. Files with updated timestamps or new inodes are archived, and deleted files are flagged with special directory removal markers (`GNU tar directory header`). During extraction, passing `--listed-incremental=/dev/null` instructs tar to execute those directory deletion markers, correctly pruning obsolete files from the restore target.

### Q3: Why is it critical to verify SHA-256 checksums *before* extracting an archive during recovery?
In disaster recovery scenarios, storage bit-rot, network transmission errors, or malicious tampering (ransomware) can corrupt archive files. If a corrupted archive is extracted over an existing or partially restored system, corruption compounds: files may be truncated, partial writes may overwrite healthy data, and corrupted configurations can leave servers unbootable. Pre-flight verification with `sha256sum -c` guarantees data authenticity and cryptographic integrity before a single write operation occurs.

### Q4: What do RPO and RTO mean in NovaTech's infrastructure?
- **RPO (Recovery Point Objective):** The maximum tolerable data loss measured in time. NovaTech's policy specifies an RPO of `<= 24 hours`, achieved by executing automated daily incremental backups at 02:00 AM.
- **RTO (Recovery Time Objective):** The maximum allowable downtime to restore services following a disaster. NovaTech's automated restore pipeline (`restore.sh`) achieves an RTO of `< 15 minutes`, restoring the baseline full backup and replaying all incrementals in under 10 seconds.

### Q5: Why is regular recovery testing essential in Linux systems administration?
An untested backup is not a backup; it is merely an assumption. Backups frequently fail silently due to unreadable media, changed permissions, software version incompatibilities, or missing dependencies. Running automated recovery tests (such as `recovery_test.sh`) with simulated disasters and bit-for-bit `diff -r` comparisons proves that the entire restoration chain is functionally sound and capable of meeting SLAs during real emergencies.

### Q6: How does loopback block device mapping work with `losetup`?
A loopback device (`/dev/loopX`) is a pseudo-device driver in the Linux kernel that exposes an ordinary file on a filesystem as a block device. Using `truncate -s 1G file.img` creates a sparse backing file. `sudo losetup -f --show file.img` allocates a free loop device and maps kernel I/O requests directly to the image file. Linux filesystems (`mkfs.ext4`) and volume managers (`pvcreate`) can then be mounted and formatted on top of the loop device exactly like physical SATA/NVMe disks.

### Q7: How does LVM provide zero-downtime storage elasticity?
Logical Volume Manager (LVM) abstracts physical storage into three tiers: Physical Volumes (PVs), Volume Groups (VGs), and Logical Volumes (LVs). Because filesystems reside on LVs rather than fixed disk partitions, an administrator can dynamically extend capacity online using `lvextend -L +size /dev/vg/lv` followed by `resize2fs /dev/vg/lv`. The ext4 filesystem expands into the new block allocations live while applications continue reading and writing without unmounting or server reboots.

### Q8: Why are dedicated non-login service accounts and restrictive permissions (700/600) critical for backup security?
Backup repositories aggregate confidential enterprise assets across all departments. If repositories are left world-readable (`755/644`), unprivileged users or compromised processes can exfiltrate sensitive payroll, financial, or source code records. Assigning ownership to a dedicated non-login service account (`lsatest_backupadmin` with `/usr/sbin/nologin`) and operations group (`lsatest_backup_ops`) with permissions `chmod 700` (directory) and `chmod 600` (archives) enforces the Principle of Least Privilege and prevents interactive SSH hijacking.

---

## Required Screenshots Checklist for Presentation & Report

Capture the following real terminal screenshots to attach to your submission:

1. **Storage Setup (Phase 0):** Terminal showing `lsblk`, `df -h /.../sandbox_data/repo_mount`, and `sudo blkid /dev/loop0`.
2. **Online LVM Elasticity Demonstration:** Output showing `pvcreate`, `vgcreate`, `lvcreate`, and `lvextend +300M` followed by `resize2fs`.
3. **Full & Incremental Backup Execution:** Terminal showing `backup_full.sh` and two consecutive runs of `backup_incremental.sh` with generated SHA-256 hashes.
4. **Backup Verification & Corrupted Archive Detection:** `verify_backup.sh` displaying `[OK]` for valid archives and `[CORRUPT: CHECKSUM MISMATCH]` for the tampered archive clone.
5. **Disaster Recovery Scorecard:** The terminal audit box showing:
   - Pre-Disaster Expected Files: 51
   - Total Files Restored: 51
   - Cryptographically Matched: 51
   - Mismatches: 0
   - VERDICT: PASS
6. **Crontab Scheduling Evidence:** Output of `crontab -l` showing the tagged `# LSA_SPRINT_TEST` lines and tail of `logs/cron.log`.
7. **Security Isolation Check:** Output showing `sudo -u nobody ls -L repo/` failing with `Permission denied` while `sudo -u lsatest_backupadmin` succeeds.
8. **Live HTML Audit Report:** Full-page browser screenshot of `report.html` showing the summary cards, inventory table, and scorecard.
