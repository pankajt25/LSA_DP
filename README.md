# Linux System Administration (E1ITA307) — Deployment Projects

Comprehensive repository of enterprise-grade Linux infrastructure deployment projects for Course **E1ITA307**.

---

## Deployment Projects Index

| Project | Title | Description | Status | Command to Execute | Folder |
|---|---|---|:---:|---|:---:|
| [**DP_01**](./DP_01/) | **Enterprise Storage Infrastructure** | Multi-disk LVM pooling, XFS/ext4 filesystems, live online volume elasticity, SetGID/POSIX ACL isolation, automated departmental backup suite with SHA-256 integrity checks, and reboot persistence. | **Completed** | `cd DP_01 && bash run.sh` | [DP_01](./DP_01/) |
| [**DP_02**](./DP_02/) | **Centralized Backup & Recovery Server** | Centralized backup server supporting GNU tar listed-incremental full & incremental backups, daily/weekly cron automation, 2-full retention policy, cryptographic SHA-256 manifests, RBAC permissions, and disaster recovery validation. | **Completed** | `cd DP_02 && bash run.sh` | [DP_02](./DP_02/) |
| [**DP_03**](./DP_03/) | **Department File Server** | Multi-department shared folders with ext4 kernel quotas (soft/hard user & group limits, 7-day grace period), POSIX default & access ACLs, SetGID (`2770`) inheritance, Sticky Bit (`3770`) peer deletion protection, auditor read-only governance, and automated security audit. | **Completed** | `cd DP_03 && bash run.sh` | [DP_03](./DP_03/) |

---

<details>
<summary><strong>DP_01 — Enterprise Storage Infrastructure (Click to expand)</strong></summary>

### Problem Statement
Design, deploy, and validate a secure, scalable, multi-departmental storage infrastructure for **NovaTech Solutions** (Course: E1ITA307, Modules: III, IV | CO3, CO4).

### Architecture Summary
- **Storage Pool Subsystem:** Three virtual block devices (10 GiB, 15 GiB, 20 GiB = 45 GiB total) attached via verified loopback (`losetup -j`) and pooled into Volume Group `company_vg` with 4 MiB Physical Extents.
- **Logical Volumes & Filesystems:** Dedicated LVs partitioned with GPT flags: `lv_hr` (5G ext4), `lv_finance` (8G ext4), `lv_eng` (15G $\to$ 20G XFS), and `lv_sales` (5G ext4) mounted under `sandbox_data/mnt/<dept>`.
- **Live Online Elasticity:** Dynamic online volume expansion of Engineering volume (`lv_eng`) from 15 GiB to 20 GiB using `lvextend -L 20G` and `xfs_growfs` while mounted and actively serving I/O with zero downtime.
- **Security & Access Control:** Strict departmental collaboration and isolation enforced via SetGID (`chmod 2770`) and POSIX Default ACLs (`setfacl -d -m g::rwx`), ensuring automatic group inheritance on new files while strictly denying cross-departmental access.
- **Automated Backup & Cryptographic Verification:** Production Bash automation generating timestamped `.tar.gz` departmental archives under `sandbox_data/backup/`, paired with SHA-256 manifests and tar header integrity validation.
- **Persistence Verification:** Host `/etc/fstab` preserved untouched; storage persistence fully demonstrated and verified via `sandbox_data/fstab.demo` with UUIDs from `blkid` and validated via `findmnt --verify --tab-file`.
- **Comprehensive Verification:** All 5 architectural criteria validated with 100% test pass rate.

### Key Commands
```bash
# 1. Execute end-to-end deployment, elasticity demo, backup verification, and HTML report generation
cd DP_01 && bash run.sh

# 2. View live dark-themed HTML report (WSL / Windows)
explorer.exe "$(wslpath -w report.html)"

# 3. Dedicated storage setup & LVM volume provisioning
bash scripts/storage_setup.sh

# 4. Live online volume elasticity demonstration (+5 GiB XFS expansion)
bash scripts/live_elasticity_demo.sh

# 5. Execute departmental backup suite
bash scripts/backup_departments.sh

# 6. Verify backup cryptographic integrity (SHA-256 & tar health)
bash scripts/verify_backup.sh

# 7. Run comprehensive infrastructure validation suite
bash scripts/validate_infrastructure.sh

# 8. Deliberate teardown of mounts, LVM, loop devices, and test accounts
bash cleanup.sh
```

### Deliverables & Reports
- **Live HTML Audit Report:** [DP_01/report.html](./DP_01/report.html)
- **Execution Guide & Viva Q&A (8 Questions):** [DP_01/README.md](./DP_01/README.md)
- **Infrastructure Architecture Plan:** [DP_01/docs/infrastructure-plan.md](./DP_01/docs/infrastructure-plan.md)
- **Complete Commands Used Reference (42 Commands):** [DP_01/commands_used.md](./DP_01/commands_used.md)
- **Operational Execution Logs:** [DP_01/logs/storage_deploy.log](./DP_01/logs/storage_deploy.log)

</details>

---

<details>
<summary><strong>DP_02 — Centralized Backup & Recovery Server (Click to expand)</strong></summary>

### Problem Statement
Design a Linux backup server supporting full, incremental, and scheduled backups with recovery testing for **NovaTech Solutions** (Course: E1ITA307, Modules: IV | CO4).

### Architecture Summary
- **Storage Subsystem:** Dedicated 1 GiB sparse image (`backup_disk.img`) attached via verified loopback (`/dev/loop0`) with an `ext4` filesystem (`LABEL="NOVA_BACKUP"`) mounted at `sandbox_data/repo_mount/`. Includes live online volume elasticity demonstration (`lvextend +300M` & `resize2fs`).
- **Backup Engine:** GNU tar listed-incremental (`--listed-incremental`) tracking inode metadata in `.snar` files. Level 0 weekly full backups and daily incremental delta captures.
- **Cryptographic Assurance:** SHA-256 manifests generated post-creation and enforced pre-restoration. Corrupted archive bit-flip detection built into verification engine.
- **Automation:** Scheduled via cron with weekly full (`0 1 * * 0`) and daily incremental (`0 2 * * *`) tagged with `# LSA_SPRINT_TEST`.
- **Security & Access Control:** Repository owned by dedicated service user `lsatest_backupadmin` and group `lsatest_backup_ops` with mode 700/600. Negative authorization tests prove unprivileged user `nobody` is strictly denied access. At-rest OpenSSL `AES-256-CBC` encryption demo validated with SHA-256 parity.
- **Disaster Recovery Validation:** Simulates catastrophic loss (deleting `source/sales` and corrupting configuration), restores full baseline and replays incremental chain, verifying 100% bit-for-bit parity via `diff -r` (51/51 files matched, 0 missing, 0 mismatched -> PASS).

### Key Commands
```bash
# 1. Execute end-to-end recovery test, verification, and live HTML report generation
cd DP_02 && bash run.sh

# 2. View live dark-themed HTML report (WSL / Windows)
explorer.exe "$(wslpath -w report.html)"

# 3. Dedicated storage setup & LVM elasticity demonstration
bash scripts/storage_setup.sh --demo-lvm

# 4. Install & verify scheduled cron automation
bash scripts/install_cron.sh

# 5. Security RBAC, negative access check & OpenSSL encryption demo
bash scripts/security_setup.sh

# 6. Deliberate teardown of system privileges, loop devices, and cron
bash cleanup.sh
```

### Deliverables & Reports
- **Live HTML Audit Report:** [DP_02/report.html](./DP_02/report.html)
- **Execution Guide & Viva Q&A:** [DP_02/README.md](./DP_02/README.md)
- **Infrastructure Architecture Plan:** [DP_02/docs/infrastructure-plan.md](./DP_02/docs/infrastructure-plan.md)
- **Complete Commands Used Reference (50 Commands):** [DP_02/commands_used.md](./DP_02/commands_used.md)
- **Operational Execution Logs:** [DP_02/logs/backup.log](./DP_02/logs/backup.log) & [DP_02/logs/cron.log](./DP_02/logs/cron.log)

</details>

---

<details>
<summary><strong>DP_03 — Department File Server (Click to expand)</strong></summary>

### Problem Statement
Configure secure shared directories with quotas, ACLs, ownership, and storage allocation for different departments in **NovaTech Solutions** (Course: E1ITA307, Modules: III, IV | CO3, CO4).

### Architecture Summary
- **Storage Subsystem:** Dedicated 2 GiB sparse image (`fileserver.img`) attached via verified loopback (`/dev/loop0`) with an `ext4` filesystem (`LABEL="NOVA_FILESRV"`), configured with internal kernel quota tracking (`tune2fs -O quota -Q usrquota,grpquota`), mounted at `sandbox_data/mnt/fileserver` with options `acl,usrquota,grpquota`.
- **Departmental Layout & Storage Allocation:** Dedicated directories `finance/` (200M/250M group, 90M/110M user), `hr/` (100M/120M group, 50M/60M user), `eng/` (400M/500M group, 150M/200M user), and `sales/` (100M/120M group, 50M/60M user).
- **Identity & Collaboration:** 5 distinct `lsatest_` groups and 9 unprivileged service accounts (`-M -s /usr/sbin/nologin`) with locked passwords. Base directories configured with SetGID (`2770`) for automatic group inheritance.
- **POSIX Access & Default ACLs:** Access and Default ACLs ensure department groups have `rwx`, Internal Auditor has global read-only (`r-x`), and others have zero permissions (`---`), propagating automatically to all newly created child files and directories.
- **Peer Deletion Protection:** Enforced via directory Sticky Bit (`chmod 3770`), preventing users from deleting colleagues' files while allowing collaborative group writes.
- **Kernel Quotas & Enforcement:** Verified 7-day grace periods. Bounded write testing proves soft limit warning (`+-` in `repquota`) and hard limit kernel write termination (`dd: IO error: Disk quota exceeded`).
- **Comprehensive Verification:** All 8 architectural criteria validated (8 / 8 Tests Passed).

### Key Commands
```bash
# 1. Execute end-to-end file server setup, ACL configuration, quota testing, and HTML report generation
cd DP_03 && bash run.sh

# 2. View live dark-themed HTML report (WSL / Windows)
explorer.exe "$(wslpath -w report.html)"

# 3. Environment preflight check & kernel quota audit
bash scripts/preflight.sh

# 4. Storage volume provisioning & loopback mounting
bash scripts/setup_storage.sh

# 5. RBAC identity provisioning & SetGID configuration
bash scripts/setup_identity.sh

# 6. Apply POSIX Access & Default ACLs
bash scripts/setup_acl.sh

# 7. Apply native kernel quotas & grace periods
bash scripts/setup_quota.sh

# 8. Run 8-point automated test suite
bash scripts/run_tests.sh

# 9. Automated security & compliance audit
bash scripts/security_check.sh

# 10. Deliberate teardown of mounts, quotas, loop devices, and test accounts
bash cleanup.sh
```

### Deliverables & Reports
- **Live HTML Audit Report:** [DP_03/report.html](./DP_03/report.html)
- **Execution Guide & Viva Q&A (10 Questions):** [DP_03/README.md](./DP_03/README.md)
- **Infrastructure Architecture Plan:** [DP_03/docs/infrastructure-plan.md](./DP_03/docs/infrastructure-plan.md)
- **Complete Commands Used Reference (90 Commands):** [DP_03/commands_used.md](./DP_03/commands_used.md)
- **Comprehensive Testing Report:** [DP_03/docs/testing-report.md](./DP_03/docs/testing-report.md)
- **Operational Execution Logs:** [DP_03/logs/fileserver.log](./DP_03/logs/fileserver.log)

</details>

