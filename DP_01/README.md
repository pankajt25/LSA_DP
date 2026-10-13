# Enterprise Storage Infrastructure (DP_01)
**Course:** Linux System Administration (E1ITA307) — Modules: III, IV | CO3, CO4  
**Project:** Linux Infrastructure Deployment Project #1  
**Organization:** NovaTech Solutions  
**Target Repository:** [https://github.com/pankajt25/LSA_DP.git](https://github.com/pankajt25/LSA_DP.git)  

---

## Command to Execute

To execute the automated end-to-end storage provisioning, LVM pooling, filesystem mounting, live online elasticity demonstration, backup generation, integrity verification, and HTML report generation:

```bash
# Navigate to the DP_01 project directory
cd DP_01

# Execute master runner (single-command cross-platform orchestrator)
bash run.sh
```

> [!NOTE]
> `cleanup.sh` is a deliberate, separate second step that cleanly unmounts filesystems, tears down LVM volumes/groups, detaches loop devices, deletes disk images, and purges test accounts. Do not run it until after all system verification screenshots and reviews are completed:
> ```bash
> bash cleanup.sh
> ```

---

## Viewing the HTML Report

The HTML audit report is self-contained with inline CSS and a high-contrast dark theme. `run.sh` automatically detects the operating environment and opens the report:

- **WSL / Windows Launch Command:**
  ```bash
  explorer.exe "$(wslpath -w report.html)"
  ```
- **Direct Windows File Path:**
  `D:\Users\Dell\Downloads\Projects\LSA\Deployment_Projects\DP_01\report.html`
- **Native Linux (Desktop):**
  ```bash
  xdg-open report.html
  ```

---

## Scenario & Storage Architecture Specification

NovaTech Solutions operates a multi-departmental Linux environment requiring enterprise-grade, secure, scalable, and isolated storage infrastructure for four core divisions: **Human Resources (HR)**, **Finance**, **Engineering**, and **Sales**.

### Storage Allocation & Sizing Architecture

| Department | Logical Volume | Initial Size | Filesystem | Post-Extension Size | Mount Point | Group Owner | Mode & ACLs |
|---|---|---|---|---|---|---|---|
| **Human Resources** | `lv_hr` | 5.0 GiB | `ext4` | 5.0 GiB | `sandbox_data/mnt/hr` | `lsatest_hr_team` | `2770` + Default ACLs |
| **Finance** | `lv_finance` | 8.0 GiB | `ext4` | 8.0 GiB | `sandbox_data/mnt/finance` | `lsatest_finance_team` | `2770` + Default ACLs |
| **Engineering** | `lv_eng` | 15.0 GiB | `xfs` | **20.0 GiB** (+5 GiB online) | `sandbox_data/mnt/eng` | `lsatest_eng_team` | `2770` + Default ACLs |
| **Sales** | `lv_sales` | 5.0 GiB | `ext4` | 5.0 GiB | `sandbox_data/mnt/sales` | `lsatest_sales_team` | `2770` + Default ACLs |
| **Unallocated Pool** | *Reserve* | — | *N/A* | **~6.99 GiB** Free Pool | *N/A* | *Root* | Dynamic Expansion Buffer |

```
+---------------------------------------------------------------------------------------------------+
|                                  PHYSICAL DISK LAYER (45 GB)                                      |
|                                                                                                   |
|  +--------------------+    +--------------------+    +--------------------+                       |
|  |   Disk 1 (10 GB)   |    |   Disk 2 (15 GB)   |    |   Disk 3 (20 GB)   |                       |
|  |     /dev/loopX     |    |     /dev/loopY     |    |     /dev/loopZ     |                       |
|  +---------+----------+    +---------+----------+    +---------+----------+                       |
+------------|-------------------------|-------------------------|----------------------------------+
             |                         |                         |
+------------v-------------------------v-------------------------v----------------------------------+
|                                PHYSICAL VOLUMES (PV LAYER)                                        |
|                                                                                                   |
|  +--------------------+    +--------------------+    +--------------------+                       |
|  |    /dev/loopXp1    |    |    /dev/loopYp1    |    |    /dev/loopZp1    |                       |
|  |     Size: 10 GB    |    |     Size: 15 GB    |    |     Size: 20 GB    |                       |
|  +---------+----------+    +---------+----------+    +---------+----------+                       |
+------------|-------------------------|-------------------------|----------------------------------+
             \                         |                         /
              \                        |                        /
+--------------v-----------------------v-----------------------v------------------------------------+
|                                 VOLUME GROUP (VG LAYER)                                           |
|                                                                                                   |
|                                       company_vg                                                  |
|                        Total Capacity: 44.99 GiB (11,517 PEs)                                     |
|                        PE (Physical Extent) Size: 4.00 MiB                                        |
|                        Allocated: 38.00 GiB | Free Reserve: 6.99 GiB                              |
+------+-----------------------+-----------------------+--------------------------------------+-----+
       |                       |                       |                                      |
+------v-----------------------v-----------------------v--------------------------------------v-----+
|                                LOGICAL VOLUMES (LV LAYER)                                         |
|                                                                                                   |
|  +---------------+   +---------------+   +---------------+   +---------------+                    |
|  |     lv_hr     |   |  lv_finance   |   |    lv_eng     |   |   lv_sales    |                    |
|  |  Size: 5 GB   |   |  Size: 8 GB   |   | 15G -> 20 GB  |   |  Size: 5 GB   |                    |
|  +-------+-------+   +-------+-------+   +-------+-------+   +-------+-------+                    |
+----------|-------------------|-------------------|-------------------|----------------------------+
           |                   |                   |                   |
+----------v-------------------v-------------------v-------------------v----------------------------+
|                               FILESYSTEM & MOUNT POINT LAYER                                      |
|                                                                                                   |
|       ext4                ext4                XFS                 ext4                            |
|  .../mnt/hr          .../mnt/finance     .../mnt/eng         .../mnt/sales                        |
+---------------------------------------------------------------------------------------------------+
```

### Key Architectural Decisions:
1. **LVM2 Multi-Disk Storage Pool:** Three virtual block devices (10 GiB, 15 GiB, 20 GiB = 45 GiB total) are aggregated into Volume Group `company_vg` with 4 MiB Physical Extent (PE) granularity.
2. **Zero-Downtime Elasticity:** The high-growth Engineering volume uses `xfs` and expands online live from 15 GiB to 20 GiB via `lvextend` and `xfs_growfs` while mounted and actively serving files.
3. **Departmental Isolation & Collaboration:** Directories enforce SetGID (`chmod 2770`) and POSIX Default ACLs (`setfacl -d -m g::rwx`), guaranteeing group inheritance on new files while strictly denying cross-departmental access.
4. **Automated Departmental Backup Engine:** Production-grade Bash automation (`backup_departments.sh` and `verify_backup.sh`) creates timestamped gzip archives under `sandbox_data/backup/`, calculates SHA-256 digests, and validates archive headers.

---

## Safety & Sandboxing Guarantee

To ensure total host operating system stability and data protection:
- **Loopback Disks Only:** Storage block devices are virtual disk images (`10G`, `15G`, `20G` sparse files) stored under `DP_01/sandbox_data/disks/`. Every loop device is validated with `losetup -j` before initialization. Real drives (`/dev/sdX`, `/dev/nvmeX`) are never touched.
- **Sandbox Mount Hierarchy:** Mount points live strictly under `DP_01/sandbox_data/mnt/<dept>`. No mounts occur on `/data` or root paths.
- **Host `/etc/fstab` Protection:** The host system's `/etc/fstab` is never edited. For persistence verification, a sandbox manifest is generated at `DP_01/sandbox_data/fstab.demo` with UUIDs from `blkid` and validated using `findmnt --verify --tab-file`.
- **Sandbox Accounts:** All test users (`lsatest_alice_hr`, etc.) and groups (`lsatest_hr_team`, etc.) are namespaced with the `lsatest_` prefix and purged on `cleanup.sh`.
- **Path Guard Verification:** All scripts import `scripts/lib.sh` which enforces `assert_sandbox_path` and `set -euo pipefail`.

---

## Phase-by-Phase Real Execution Outputs

### Phase 1: Virtual Disks, LVM Provisioning & Mounting
Executed via `scripts/storage_setup.sh`:

```text
[INFO] Provisioning virtual disk images (10G, 15G, 20G sparse)...
[SUCCESS] Sparse disk images provisioned in sandbox_data/disks:
  10G disk1.img
  15G disk2.img
  20G disk3.img
[INFO] Attaching and verifying loopback block devices...
[SUCCESS] Verified loop devices mapped:
  Disk 1 (10G): /dev/loop1 -> sandbox_data/disks/disk1.img
  Disk 2 (15G): /dev/loop2 -> sandbox_data/disks/disk2.img
  Disk 3 (20G): /dev/loop3 -> sandbox_data/disks/disk3.img
[INFO] Applying GPT partitioning and LVM flags...
[SUCCESS] Partitioned physical volume targets: /dev/loop1p1 /dev/loop2p1 /dev/loop3p1
[INFO] Initializing LVM Physical Volumes (PVs)...
[INFO] Configuring Volume Group 'company_vg'...
[SUCCESS] Volume group 'company_vg' created.
[INFO] Creating Logical Volumes in company_vg...
[SUCCESS] Logical Volumes verified in company_vg:
  LV         VG         Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  lv_eng     company_vg -wi-a----- 15.00g
  lv_finance company_vg -wi-a-----  8.00g
  lv_hr      company_vg -wi-a-----  5.00g
  lv_sales   company_vg -wi-a-----  5.00g
[INFO] Formatting filesystems (ext4 for HR, Finance, Sales; XFS for Engineering)...
[SUCCESS] Filesystems formatted successfully.
[INFO] Mounting filesystems under sandbox_data/mnt...
[SUCCESS] Filesystems mounted:
Filesystem                         Size  Used Avail Use% Mounted on
/dev/mapper/company_vg-lv_hr       4.9G   24K  4.6G   1% sandbox_data/mnt/hr
/dev/mapper/company_vg-lv_finance  7.9G   24K  7.4G   1% sandbox_data/mnt/finance
/dev/mapper/company_vg-lv_eng       15G  140M   15G   1% sandbox_data/mnt/eng
/dev/mapper/company_vg-lv_sales    4.9G   24K  4.6G   1% sandbox_data/mnt/sales
[INFO] Generating sandbox persistence manifest: sandbox_data/fstab.demo...
[INFO] Validating fstab.demo syntax via findmnt --verify --tab-file...
[SUCCESS] Persistence verification PASSED: fstab.demo is 100% valid.
[INFO] Provisioning lsatest_ groups, users, SetGID, and POSIX ACLs...
[SUCCESS] Storage infrastructure setup completed successfully.
```

---

### Phase 2: Live Online Volume Elasticity (Engineering Volume)
Executed via `scripts/live_elasticity_demo.sh`:

```text
[INFO] Demonstrating Live Online LVM Elasticity on Engineering Volume (lv_eng)
[INFO] Current Engineering Volume Capacity: 15 GiB (Mounted Filesystem: 15G)
[INFO] Executing live online expansion (+5 GiB): Extending to 20 GiB...
  Size of logical volume company_vg/lv_eng changed from 15.00 GiB (3840 extents) to 20.00 GiB (5120 extents).
  Logical volume company_vg/lv_eng successfully resized.
[INFO] Executing online XFS filesystem expansion (xfs_growfs)...
meta-data=/dev/mapper/company_vg-lv_eng isize=512    agcount=4, agsize=983040 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=1, inobtcount=1, nrext64=1
data     =                       bsize=4096   blocks=3932160, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=16384, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
data blocks changed from 3932160 to 5242880
[SUCCESS] Online expansion completed with zero downtime.
[SUCCESS] Post-Expansion Capacity: 20 GiB (Mounted Filesystem: 20G)
```

---

### Phase 3 & 4: Multi-Departmental Backup & Integrity Verification
Executed via `scripts/backup_departments.sh` and `scripts/verify_backup.sh`:

```text
[INFO] Initiating NovaTech Multi-Departmental Backup Suite
[INFO] Processing department: [hr]...
[SUCCESS]   Backup created & verified: hr_backup_20261010_200145.tar.gz (280 B)
[INFO] Processing department: [finance]...
[SUCCESS]   Backup created & verified: finance_backup_20261010_200145.tar.gz (312 B)
[INFO] Processing department: [eng]...
[SUCCESS]   Backup created & verified: eng_backup_20261010_200145.tar.gz (324 B)
[INFO] Processing department: [sales]...
[SUCCESS]   Backup created & verified: sales_backup_20261010_200145.tar.gz (305 B)
[INFO] Backup Summary: 4/4 departments archived successfully.

------------------------------------------------------------------------------------------------
ARCHIVE FILENAME                 | SIZE       | SHA256 CHECKSUM | TAR INTEGRITY| RESULT
------------------------------------------------------------------------------------------------
eng_backup_20261010_200145.tar.gz| 324 B      | VALID           | VALID        | [OK]
finance_backup_20261010_200145.tar.gz| 312 B  | VALID           | VALID        | [OK]
hr_backup_20261010_200145.tar.gz | 280 B      | VALID           | VALID        | [OK]
sales_backup_20261010_200145.tar.gz| 305 B    | VALID           | VALID        | [OK]
------------------------------------------------------------------------------------------------
[SUCCESS] Integrity audit completed: ALL departmental archives verified intact and authentic [OK].
```

---

### Phase 5: Automated Infrastructure Validation Test Suite
Executed via `scripts/validate_infrastructure.sh`:

```text
================================================================================
   NovaTech Solutions — Storage Infrastructure Validation Suite
================================================================================
Timestamp: 2026-10-10 20:02:18

[Verification 1] Infrastructure Planning & Documentation
  [✓] Plan document verified: .../docs/infrastructure-plan.md
  [✓] Covers storage layout, sizing table, LVM justification, naming schema
  --> PASS: Validated

[Verification 2] Storage & LVM Implementation
  [✓] Volume group 'company_vg' exists and is active
  [✓] Logical Volume 'lv_hr' found (Allocated: 5.00g)
  [✓] Logical Volume 'lv_finance' found (Allocated: 8.00g)
  [✓] Logical Volume 'lv_eng' found (Allocated: 20.00g)
  [✓] Logical Volume 'lv_sales' found (Allocated: 5.00g)
  --> PASS: Validated

[Verification 3] Filesystem Creation & Mounting
  [✓] /dev/company_vg/lv_hr formatted with ext4
  [✓] /dev/company_vg/lv_finance formatted with ext4
  [✓] /dev/company_vg/lv_sales formatted with ext4
  [✓] /dev/company_vg/lv_eng formatted with xfs
  [✓] Mount point .../sandbox_data/mnt/hr is actively mounted
  [✓] Mount point .../sandbox_data/mnt/finance is actively mounted
  [✓] Mount point .../sandbox_data/mnt/eng is actively mounted
  [✓] Mount point .../sandbox_data/mnt/sales is actively mounted
  [✓] Persistence manifest fstab.demo verified
  --> PASS: Validated

[Verification 4] Access Control & Permissions
  [✓] .../sandbox_data/mnt/hr: permissions=2770, group=lsatest_hr_team (Isolation enforced)
  [✓] .../sandbox_data/mnt/finance: permissions=2770, group=lsatest_finance_team (Isolation enforced)
  [✓] .../sandbox_data/mnt/eng: permissions=2770, group=lsatest_eng_team (Isolation enforced)
  [✓] .../sandbox_data/mnt/sales: permissions=2770, group=lsatest_sales_team (Isolation enforced)
  --> PASS: Validated

[Verification 5] Automation, Elasticity & Integrity
  [✓] Live online elasticity verified: Engineering LV scaled to 20G
  [✓] Departmental backup suite verified: 4 archive(s) present
  --> PASS: Validated

================================================================================
FINAL VALIDATION AUDIT: ALL TESTS PASSED
================================================================================
VERDICT: ALL REQUIREMENTS SATISFIED [PASS]
```

---

## Troubleshooting Log

### Incident 1: Host `/etc/fstab` Sandboxing vs WSL Boot Safety
- **Symptom / Risk:** Editing the real `/etc/fstab` inside WSL with loopback devices can cause WSL init boot errors if loop devices are unmounted at shutdown.
- **Root Cause:** Loop devices are dynamic kernel objects that detach on shutdown. If `/etc/fstab` tries to mount loopback LVs before devices attach, boot drops to emergency shell.
- **Resolution:** Left real `/etc/fstab` completely untouched. Created sandbox persistence manifest at `DP_01/sandbox_data/fstab.demo` containing verified UUIDs from `blkid`. Validated syntax using `findmnt --verify --tab-file DP_01/sandbox_data/fstab.demo`.
- **Verification:** `findmnt --verify` confirmed 100% valid fstab syntax with zero host risk.

### Incident 2: Kernel 6.x Deprecation of Explicit `acl` Mount Option for XFS
- **Symptom:** `mount` failed with `wrong fs type, bad option, bad superblock` when mounting `/dev/company_vg/lv_eng` with `defaults,acl`.
- **Root Cause:** In modern Linux kernels (Linux 6.x+), XFS enables POSIX ACLs natively in its filesystem driver; specifying `acl` as an explicit mount flag is deprecated and rejected with kernel error 64 (`Unknown parameter 'acl'`).
- **Resolution:** Configured XFS mount options with `defaults` while retaining `defaults,acl` for `ext4` filesystems.
- **Verification:** `findmnt` and `dmesg` confirmed XFS mounts cleanly with full POSIX ACL functionality enabled.

### Incident 3: Multi-Disk Loop Device Collisions
- **Symptom:** Calling `losetup -f` concurrently or repeatedly risk re-binding an already bound disk image to multiple loop devices.
- **Root Cause:** Unsynchronized loop attachment without checking existing bindings (`losetup -j`).
- **Resolution:** Implemented `attach_and_verify_loop()` in `storage_setup.sh`. Checks `losetup -j <image>` first to reuse an existing loop node. After attaching, validates that `losetup -j <image>` matches the allocated device path before performing any disk operations.
- **Verification:** Successfully and deterministically maps `/dev/loop1`, `/dev/loop2`, `/dev/loop3` to `disk1.img`, `disk2.img`, `disk3.img`.

### Incident 4: SetGID Mode 2770 and Default ACL Inheritance
- **Symptom:** Files created by a user with a restrictive `umask` (e.g. `0077`) were unreadable by fellow team members despite SetGID group inheritance.
- **Root Cause:** SetGID sets directory group ownership inheritance on newly created files, but does not override user umask bit masks.
- **Resolution:** Combined SetGID (`chmod 2770`) with POSIX Default ACLs (`setfacl -d -m g::rwx <dir>`). Default ACL templates automatically grant `rwx` permissions to group members on all future subdirectories and files.
- **Verification:** Files created by test accounts inherit group ownership and receive `rw-rw----` permissions regardless of caller umask.

### Incident 5: Online Filesystem Scaling (XFS Growfs vs Ext4 Resize2fs)
- **Symptom:** Running `resize2fs` against the Engineering volume failed with `Bad magic number in super-block`.
- **Root Cause:** Engineering volume is formatted with `XFS`, which requires `xfs_growfs` instead of `resize2fs`. Additionally, XFS can only be expanded while actively mounted.
- **Resolution:** Automated `lvextend -L 20G /dev/company_vg/lv_eng` followed immediately by `xfs_growfs sandbox_data/mnt/eng`.
- **Verification:** Capacity increased from 15 GiB to 20 GiB live while actively mounted with zero I/O downtime.

---

## Final Validation Checklist

| # | Architectural Component | Implementation Evidence | Status |
|---|---|---|:---:|
| **1** | **Infrastructure Planning & Documentation** | `docs/infrastructure-plan.md` includes storage layout ASCII diagram, sizing table, LVM justification, and naming convention. | **PASS** |
| **2** | **Storage & LVM Implementation** | Virtual disks partitioned with GPT LVM flags, aggregated into `company_vg` (45 GiB), carved into 4 LVs (`lv_hr`, `lv_finance`, `lv_eng`, `lv_sales`). | **PASS** |
| **3** | **Filesystem Creation & Mounting** | `ext4` created on HR, Finance, Sales; `xfs` created on Engineering; mounted under `sandbox_data/mnt/<dept>`; persistence verified via `fstab.demo` and `findmnt`. | **PASS** |
| **4** | **Access Control & Permissions** | Strict SetGID `2770`, POSIX Default ACLs (`setfacl -d -m g::rwx`), isolated departmental group ownership (`lsatest_*_team`). | **PASS** |
| **5** | **Automation, Elasticity & Integrity** | Live online expansion of `lv_eng` (15G $\to$ 20G) via `lvextend` + `xfs_growfs`; automated backup scripts with SHA-256 manifests; HTML audit report generator. | **PASS** |

---

## Viva Voce Q&A (Defense Guide)

### Q1: Why did you use LVM instead of standard GPT/MBR disk partitions?
**Answer:**  
Standard disk partitions have fixed sector boundaries tied to individual physical drives. Resizing requires adjacent unallocated sectors on the same drive, often forcing filesystem unmounting and causing service downtime.  
LVM2 abstracts physical storage into three decoupled layers:
1. **Physical Volumes (PVs):** Divides underlying block devices into uniform 4 MiB Physical Extents (PEs).
2. **Volume Group (VG):** Pools heterogeneous disks (`10G + 15G + 20G = 45G`) into an aggregated storage pool (`company_vg`).
3. **Logical Volumes (LVs):** Dynamically allocates storage blocks across any available PEs in the VG.  
This architecture allows **live online volume expansion with zero downtime**, multi-disk aggregation, and flexible storage allocation.

---

### Q2: Why did you choose `xfs` for Engineering and `ext4` for the other departments?
**Answer:**  
- **Engineering (`xfs`):** Engineering workloads involve heavy compiler caches, container layers, large binary artifacts, and concurrent I/O. XFS uses Allocation Groups (AGs), B+ trees for inode and space tracking, and 64-bit scalability. It supports instant online scaling via `xfs_growfs` without unmounting.
- **HR, Finance, Sales (`ext4`):** Stable, mature journaling filesystem with minimal metadata overhead, highly optimized for standard office documents, spreadsheets, and routine auditing.

---

### Q3: What is the difference between `lvextend -L 20G` and `xfs_growfs`?
**Answer:**  
- `lvextend` operates at the **block device layer (LVM)**: It adds 1,280 Physical Extents (4 MiB each = 5 GiB) to `/dev/company_vg/lv_eng`, expanding the underlying virtual block device from 15 GiB to 20 GiB.
- `xfs_growfs` operates at the **filesystem layer**: It expands the filesystem structures (allocation groups, inodes, free space trees) to recognize and utilize the newly added blocks while the filesystem remains mounted and serving active traffic.

---

### Q4: How does SetGID (`chmod 2770`) ensure departmental security and collaboration?
**Answer:**  
Under standard POSIX semantics, when a user creates a new file, the file's group ownership is set to the user's primary group. If Alice creates a file in `/data/hr`, it would normally be owned by `alice:alice`, preventing other HR members from modifying it.  
By applying the **SetGID bit** (`chmod 2770`, where `2` is the octal SetGID flag):
1. Any file or directory created within the directory automatically inherits the parent directory's group (`lsatest_hr_team`).
2. Mode `770` grants read/write/execute permissions to owner (`root`) and group members (`lsatest_hr_team`), while completely denying access to others (`0`).

---

### Q5: Why are POSIX Default ACLs necessary if SetGID is already applied?
**Answer:**  
SetGID only controls **group ownership**, not permission bits on newly created files. If a user's shell session has a restrictive `umask` (e.g. `0077`), newly created files would receive permissions `-rw-------`, preventing group members from reading or writing.  
Setting **POSIX Default ACLs** (`setfacl -d -m g::rwx <dir>`):
- Establishes an inherited access control template for all newly created subdirectories and files.
- Guarantees that group members always receive `rwx` (or `rw-` for files) and foreign users always have `---`, overriding restrictive user umasks.

---

### Q6: How does storage persistence work without modifying the host's `/etc/fstab`?
**Answer:**  
To safeguard the WSL host against boot hangs caused by detached loop devices, the production `/etc/fstab` is intentionally left untouched. Storage persistence is validated using an isolated manifest at `sandbox_data/fstab.demo` populated with filesystem UUIDs extracted via `blkid`. We validate this manifest using `findmnt --verify --tab-file sandbox_data/fstab.demo`, proving that all filesystem parameters, mount flags, and dump/pass frequencies adhere to Linux production mounting standards.

---

### Q7: Why use UUIDs instead of `/dev/company_vg/lv_*` device nodes in `fstab`?
**Answer:**  
UUIDs (Universally Unique Identifiers) are stored directly inside the filesystem superblock. They provide immutable referencing that is persistent even if device mapper naming conventions change, device nodes are re-enumerated in a different sequence during system initialization, or underlying disks are moved to different controller channels.

---

### Q8: How does LVM live elasticity work under active I/O without data corruption?
**Answer:**  
LVM maps logical extents (LEs) to physical extents (PEs) via the Linux kernel device-mapper framework (`dm-linear` target). When `lvextend` is executed, the kernel device-mapper table is updated atomically with new PE mapping ranges. Existing extents remain untouched, so in-flight reads and writes continue without interruption. Once the device mapper boundary expands, `xfs_growfs` appends new allocation groups to the end of the filesystem structure without taking the filesystem offline.

---

## Screenshot Capture Checklist

Before executing `cleanup.sh`, capture the following live evidence for viva presentation and report submission:

1. **LVM Layout & Volume Group:**
   ```bash
   sudo pvs && sudo vgs && sudo lvs company_vg
   ```
2. **Mounts & File System Capacities:**
   ```bash
   df -hT sandbox_data/mnt/*
   ```
3. **Live Online Elasticity (20 GiB Engineering Volume):**
   ```bash
   sudo lvs company_vg/lv_eng && df -h sandbox_data/mnt/eng
   ```
4. **Access Control & SetGID Verification:**
   ```bash
   ls -ld sandbox_data/mnt/*
   getfacl sandbox_data/mnt/hr
   ```
5. **Departmental Backup Archives & SHA-256 Manifests:**
   ```bash
   ls -lh sandbox_data/backup/
   bash scripts/verify_backup.sh
   ```
6. **Automated Infrastructure Validation Summary:**
   ```bash
   bash scripts/validate_infrastructure.sh
   ```
7. **Interactive HTML Audit Report:**
   Open `report.html` in browser via `explorer.exe "$(wslpath -w report.html)"`.
