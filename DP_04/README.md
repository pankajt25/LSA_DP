# Linux Disaster Recovery Solution (DP_04)
**Course:** Linux System Administration (E1ITA307) — Modules: IV | CO4  
**Project:** Linux Infrastructure Deployment Project #4  
**Organization:** NovaTech Solutions  
**Target Repository:** [https://github.com/pankajt25/LSA_DP.git](https://github.com/pankajt25/LSA_DP.git)  

---

## Command to Execute

To execute the automated end-to-end disaster recovery validation suite, snapshot lifecycle management, capacity overflow testing, and live HTML report generation:

```bash
# Navigate to the DP_04 project directory
cd DP_04

# Execute master runner (single-command cross-platform orchestrator)
bash run.sh
```

> [!NOTE]
> `cleanup.sh` is a deliberate, separate second step that safely unmounts filesystems, tears down LVM volumes and volume groups, unregisters physical volumes, detaches loop devices, and deletes sparse image files. Do not run it until after all system verification screenshots and reviews are completed:
> ```bash
> bash cleanup.sh
> ```

---

## Viewing the HTML Report

The HTML audit report is self-contained with inline CSS and a high-contrast dark theme. `run.sh` automatically detects the operating system environment and opens the report.

- **WSL / Windows Launch Command:**
  ```bash
  explorer.exe "$(wslpath -w report.html)"
  ```
- **Direct Windows File Path:**
  `D:\Users\Dell\Downloads\Projects\LSA\Deployment_Projects\DP_04\report.html`
- **Native Linux (Desktop):**
  ```bash
  xdg-open report.html
  ```

---

## Scenario & Policy Specification

NovaTech Solutions operates a disaster recovery lab validating resilience against human error, data corruption, catastrophic filesystem loss, storage pool exhaustion, and complete volume destruction.

| Scenario ID | Scenario Name | Disaster Simulated | Recovery Mechanism | Validation Method | Target Status |
|:---:|---|---|---|---|:---:|
| **S1** | Accidental File Deletion | 5 critical files deleted across Finance, HR, Engineering, Sales | Read-only snapshot mount at `mnt/snap`, selective `cp -a` restore | Cryptographic manifest comparison (`baseline.manifest`) | **Completed** |
| **S2** | Accidental Overwrite / Corruption | Injected 24 KB random bit noise into `quarterly_forecast_2.dat` | Read-only snapshot mount, selective single-file restore | SHA-256 baseline hash match | **Completed** |
| **S3** | Catastrophic Loss (Full Rollback) | Complete recursive wipe of `engineering/` and `sales/` trees | Offline volume unmount, `lvconvert --merge`, remount | 105/105 files matched (0 mismatches) | **Completed** |
| **S4** | Snapshot Capacity Exhaustion | 25 MB dirty write churn on 16 MB snapshot | Invalidation detection (`Attr I`, `100.00%`), online `lvextend +40M` | Attributes observed & elastic headroom verified | **Completed** |
| **S5** | Loss Beyond Snapshots | Total destruction of origin volume and all dependent snapshots | Recreate origin LV, restore from external archive `archive_store/` | 105/105 files restored with bit-for-bit SHA-256 parity | **Completed** |
| **ROT** | Snapshot Retention Policy | 5 sequential snapshots created | Automated pruning keeping newest 3, removing 2 oldest | Exactly 3 newest snapshots retained | **Completed** |

> [!IMPORTANT]
> **Real-Data Sandbox Guarantee:** All virtual storage drives reside strictly inside `DP_04/sandbox_data/` as sparse files (`disk1.img`, `disk2.img`) attached to loop devices. Fixed LVM names (`lsatest_dr_vg`, `lsatest_data_lv`, `lsatest_snap_*`) isolate the lab from host storage. Host `/etc/fstab` and `/etc/lvm/` are preserved untouched. Path guards prevent accidental operations outside the sandbox.

---

## Phase-by-Phase Real Execution Outputs

### Phase 0: System & Kernel Preflight Validation
Executed via `scripts/preflight.sh`:

```text
==============================================================================
 PHASE 0: PREFLIGHT SYSTEM AND KERNEL VERIFICATION
==============================================================================
[2026-10-13 17:59:38] [INFO] Collecting system and kernel specifications...
  Kernel Release : 6.18.40.1-microsoft-standard-WSL2
  Operating Sys  : Ubuntu 26.04.1 LTS
  System Hostname: SP
[2026-10-13 17:59:38] [INFO] Verifying sudo execution privileges...
[2026-10-13 17:59:38] [SUCCESS] Sudo execution confirmed.
[2026-10-13 17:59:38] [INFO] Checking lvm2 package status...
[2026-10-13 17:59:38] [SUCCESS] Package lvm2 is installed (Version: 2.03.31-2ubuntu3).
[2026-10-13 17:59:38] [INFO] Checking loop block device subsystem...
[2026-10-13 17:59:39] [SUCCESS] Loop block device subsystem is operational (next candidate: /dev/loop0).
[2026-10-13 17:59:39] [INFO] Checking Device Mapper (DM) kernel subsystem and targets...
Active Device Mapper Targets:
  snapshot-merge   v1.5.0
  snapshot-origin  v1.9.0
  snapshot         v1.16.0
  verity           v1.13.0
  striped          v1.7.0
  linear           v1.5.0
  error            v1.7.0
[2026-10-13 17:59:39] [SUCCESS] Device-mapper snapshot target is active and verified.
[2026-10-13 17:59:39] [SUCCESS] Device-mapper snapshot-merge target is active and verified.
[2026-10-13 17:59:39] [INFO] Listing loaded device-mapper kernel modules:
  dm_snapshot            49152  0
[2026-10-13 17:59:39] [SUCCESS] Preflight validation completed successfully. All prerequisites satisfied.
```

### Phase 1: Storage Lab Provisioning & Dataset Seeding
Executed via `scripts/setup_lab.sh`:

```text
==============================================================================
 PHASE 1: PROVISION STORAGE LAB (VIRTUAL DISKS, LVM POOL, ORIGIN FILESYSTEM)
==============================================================================
[2026-10-13 18:01:01] [SUCCESS] Created sparse images: disk1.img (600M), disk2.img (600M)
[2026-10-13 18:01:01] [SUCCESS] Attached disk1.img -> /dev/loop0, disk2.img -> /dev/loop1
[2026-10-13 18:01:02] [SUCCESS] Loop verification PASSED via losetup -j.
[2026-10-13 18:01:03] [SUCCESS] Physical volumes & Volume Group 'lsatest_dr_vg' created (1.16 GiB total).
[2026-10-13 18:01:04] [SUCCESS] Origin Logical Volume 'lsatest_data_lv' (500 MB) formatted with ext4.
[2026-10-13 18:01:15] [SUCCESS] Mounted at sandbox_data/mnt/data. Free extents for snapshots: 692.00 MB.
[2026-10-13 18:01:15] [SUCCESS] Demo fstab verification PASSED via findmnt --verify.
[2026-10-13 18:02:13] [SUCCESS] Seeded 105 demonstration files across Finance, HR, Engineering, Sales.
[2026-10-13 18:02:17] [SUCCESS] Baseline manifest created with 105 cryptographic SHA-256 entries.
```

### Phase 2: Snapshot Management & Retention Policy
Executed via `scripts/snapshot_rotate.sh --demo`:

```text
==============================================================================
 PHASE 2 DEMONSTRATION: SNAPSHOT ROTATION (Create 5 -> Retain 3)
==============================================================================
[2026-10-13 18:05:50] [INFO] Step 1: Creating 5 sequential test snapshots (rot1 to rot5)...
[2026-10-13 18:06:25] [INFO] Step 2: Listing all snapshots before rotation (expect 5):
SNAPSHOT NAME             ORIGIN          SIZE       DATA%      ATTR         CREATED              AGE       
lsatest_snap_rot1         lsatest_data_lv 12.00m     0.10%      swi-a-s---   2026-10-13 18:05:50  37s       
lsatest_snap_rot2         lsatest_data_lv 12.00m     0.10%      swi-a-s---   2026-10-13 18:05:52  35s       
lsatest_snap_rot3         lsatest_data_lv 12.00m     0.10%      swi-a-s---   2026-10-13 18:05:56  31s       
lsatest_snap_rot4         lsatest_data_lv 12.00m     0.10%      swi-a-s---   2026-10-13 18:06:05  22s       
lsatest_snap_rot5         lsatest_data_lv 12.00m     0.10%      swi-a-s---   2026-10-13 18:06:14  13s       
[2026-10-13 18:06:30] [INFO] Step 3: Running rotation to retain newest 3 snapshots...
[2026-10-13 18:06:35] [INFO] Pruned: lsatest_snap_rot1, lsatest_snap_rot2
[2026-10-13 18:06:39] [INFO] Step 4: Listing snapshots post-rotation (expect exactly 3):
lsatest_snap_rot3         lsatest_data_lv 12.00m     0.10%      swi-a-s---   2026-10-13 18:05:56  44s       
lsatest_snap_rot4         lsatest_data_lv 12.00m     0.10%      swi-a-s---   2026-10-13 18:06:05  35s       
lsatest_snap_rot5         lsatest_data_lv 12.00m     0.10%      swi-a-s---   2026-10-13 18:06:14  26s       
[2026-10-13 18:06:44] [SUCCESS] Rotation demonstration PASSED: Successfully pruned 2 oldest and retained 3 newest.
```

---

## Troubleshooting & Operational Engineering Log

During design and automated validation of the disaster recovery environment, several real-world systems engineering considerations were resolved:

1. **Kernel Target Availability (`dm-snapshot` probe):**
   - *Symptom:* On WSL2 / minimal Ubuntu kernels, `dmsetup targets` initially showed only `linear`, `striped`, and `verity`, omitting `snapshot` targets.
   - *Root Cause:* The `dm_snapshot` kernel module was compiled as an on-demand dynamic module rather than built-in.
   - *Resolution:* Added automatic probing (`sudo modprobe dm-snapshot`) to `scripts/preflight.sh` with strict validation stopping the run if the snapshot target cannot be loaded, preventing synthetic copy fallbacks.

2. **Offline Rollback Constraint (`lvconvert --merge`):**
   - *Symptom:* Merging a snapshot into an active, mounted filesystem causes device-busy errors or filesystem corruption.
   - *Root Cause:* Copy-on-write merge operates directly on underlying block extents. Modifying block allocation tables under an active filesystem invalidates kernel page caches and corrupts the ext4 superblock.
   - *Resolution:* Formulated strict orchestrator logic in `s3_catastrophic_merge.sh` ensuring the origin filesystem is cleanly unmounted prior to running `lvconvert --merge`, reactivated via `lvchange -ay`, and safely remounted.

3. **LVM Tool Version Flag Compatibility (`--timeformat`):**
   - *Symptom:* Initial query in `snapshot_list.sh` failed with `lvs: unrecognized option '--timeformat'`.
   - *Root Cause:* The host LVM2 package (version `2.03.31`) formats `lv_time` by default with standard timestamps (`YYYY-MM-DD HH:MM:SS ±ZZZZ`) and does not support `--timeformat`.
   - *Resolution:* Removed the redundant flag and parsed standard LVM output directly through `date -d`, ensuring cross-distribution compatibility.

4. **Snapshot Invalidation on Exhaustion:**
   - *Symptom:* Writing write churn exceeding snapshot allocation causes the snapshot to disappear from standard filesystem access.
   - *Root Cause:* When a classic CoW table exhausts its allocated Physical Extents, the Device Mapper flags the volume as Invalid (`Attr I`) to protect the origin filesystem from write blocking.
   - *Resolution:* Formulated Scenario 4 to document this failure mode empirically and demonstrated online prevention via `lvextend -L +40M`.

---

## Final Validation Checklist

- [x] Nothing created, modified, or deleted outside `DP_04/` except loop devices, `lsatest_` LVM objects, and verified packages
- [x] Volume Group `lsatest_dr_vg` spans two loop-backed PVs (`/dev/loop0`, `/dev/loop1`); `lsatest_data_lv` mounted with ~692 MB free extents
- [x] **S1 File Restore:** 105/105 files verified with 0 mismatches against `baseline.manifest`
- [x] **S2 Single-File Restore:** Checksum matches baseline exactly (`finance/quarterly_forecast_2.dat`)
- [x] **S3 Full Rollback:** `lvconvert --merge` executed offline; 105/105 files restored with 0 mismatches
- [x] **S4 Capacity Exhaustion:** Snapshot overflow invalidation (`Attr I`) and online `lvextend` prevention demonstrated
- [x] **S5 External Archive:** Gzip tarball created from snapshot and verified outside the VG; origin volume destroyed and restored
- [x] **Snapshot Rotation:** Successfully pruned 2 oldest and retained 3 newest snapshots
- [x] Measured recovery time and data-loss window recorded for each scenario
- [x] `docs/validation-report.md` and `report.html` generated with real live state
- [x] No marks, scores, rubric, or faculty wording anywhere in the project
- [x] `bash run.sh` runs end to end reproducibly
- [x] `cleanup.sh` available as a separate second step
- [x] `commands_used.md` and `docs/infrastructure-plan.md` complete

---

## Technical Viva Q&A Reference (12 Comprehensive Questions)

### Q1: How does a classic LVM Copy-on-Write (CoW) snapshot work at the block level?
**Answer:** When an LVM snapshot is created with `lvcreate -s`, LVM allocates a separate block store for exceptions and creates an empty block mapping table without copying any data. When reading from the snapshot, the kernel transparently redirects reads to the origin volume for unmodified blocks and reads from the exception store for modified blocks. When a write occurs on the origin volume to an unmodified block, the kernel intercepts the I/O, reads the *original* block, writes it into the snapshot's exception store (the "copy on write"), and only then allows the new write to commit to the origin.

### Q2: Why is an LVM snapshot not considered a true backup?
**Answer:** A snapshot is a differential recovery point, not an independent backup. Because classic snapshots store only delta blocks and reside within the same Volume Group and physical storage pool, any catastrophic failure of the origin volume (such as drive loss, controller failure, or `lvremove`) instantly destroys all dependent snapshots. True disaster recovery requires independent, self-contained backup archives stored on separate storage media or off-site repositories.

### Q3: What happens when an LVM snapshot exhausts its allocated storage capacity?
**Answer:** When the write churn on the origin volume causes the snapshot's exception store to reach 100% capacity, the kernel cannot copy further original blocks. To protect the origin volume from experiencing write failures, the Device Mapper drops the snapshot and marks it as permanently Invalid (indicated by the `I` attribute in `lvs`). Once marked invalid, the snapshot can neither be read nor merged, and it must be deleted.

### Q4: How does `lvconvert --merge` operate, and why must the origin volume be unmounted first?
**Answer:** `lvconvert --merge` reverses the snapshot relationship by copying the delta blocks stored in the snapshot's exception store back into the origin volume, effectively rolling back the origin to the snapshot's point in time. The origin filesystem MUST be unmounted prior to merging because the merge operation modifies the block allocation structures directly beneath the filesystem layer. Merging while mounted would cause ext4 superblock corruption, buffer cache desynchronization, and kernel panics. The merge operation inherently consumes the snapshot upon completion.

### Q5: How do you mathematically calculate the required size for an LVM snapshot in production?
**Answer:** Snapshot sizing depends on the rate of block modifications (write churn rate) and the intended snapshot retention window:
$$\text{Snapshot Size} = \text{Write Churn Rate} \times \text{Retention Window} \times \text{Safety Overhead}$$
If an application generates 20 MB of modified blocks per hour and snapshots are retained for 6 hours with a 50% safety margin:
$$20\text{ MB/hr} \times 6\text{ hr} \times 1.5 = 180\text{ MB}$$

### Q6: What are the primary architectural differences between Classic LVM Snapshots and Thin Snapshots?
**Answer:** Classic LVM snapshots carve a dedicated exception volume per snapshot and suffer from cumulative write amplification (writing to an origin with $N$ snapshots incurs $N$ physical copies). Thin snapshots operate on a shared virtual data pool (`thin-pool`) using Allocate-on-Write, where new blocks are allocated once regardless of snapshot count. Thin snapshots support recursive snapshotting and scale to hundreds of snapshots, but thin-pool exhaustion impacts all volumes in the pool.

### Q7: How do you guarantee filesystem consistency when taking an LVM snapshot?
**Answer:** Prior to running `lvcreate -s`, cached dirty buffers residing in kernel memory must be flushed to block storage using `sync`. In enterprise databases, consistency is achieved by pausing transaction commits or putting tablespaces in backup mode (`fsfreeze -f` or application-level quiescing) before snapshot creation, followed immediately by unfreezing (`fsfreeze -u`).

### Q8: What are Recovery Point Objective (RPO) and Recovery Time Objective (RTO)? How were they measured in this project?
**Answer:** RPO is the maximum acceptable data loss measured back in time from the disaster event ($\text{Disaster Timestamp} - \text{Snapshot Timestamp}$). RTO is the time elapsed between disaster declaration and restoration of service ($\text{Recovery End Timestamp} - \text{Recovery Start Timestamp}$). In our project, both were measured dynamically using kernel epoch timestamps (`date +%s`).

### Q9: Why must backup archives be stored outside the Volume Group?
**Answer:** Storing archives within the same Volume Group exposes them to single-point-of-failure risks: corruption of LVM metadata, physical volume loss, or accidental volume group deletion wipes both the origin and the archives. Storing archives externally (`sandbox_data/archive_store/`) ensures survival even if the entire Volume Group `lsatest_dr_vg` is eradicated.

### Q10: Why do XFS snapshots require the `-o nouuid` mount option, and why does ext4 not require it?
**Answer:** XFS enforces unique filesystem UUIDs across all mounted filesystems on a Linux host. Because an LVM snapshot is a block-level duplicate, it shares the exact UUID of the origin volume. Mounting an XFS snapshot while the origin is mounted causes the kernel to reject the mount due to UUID collision. The `-o nouuid` option instructs the XFS driver to bypass UUID checking. In contrast, ext4 does not enforce global host-wide UUID uniqueness at mount time.

### Q11: How can administrators automate snapshot monitoring to prevent capacity exhaustion?
**Answer:** Administrators configure monitoring agents (such as `snapshot_monitor.sh` or LVM's built-in `dmeventd` monitoring daemon with `snapshot_autoextend_threshold` in `/etc/lvm/lvm.conf`). When snapshot utilization exceeds 70%, warnings are dispatched; at 80% or 90%, `lvextend` is triggered dynamically to add Physical Extents from the Volume Group before invalidation occurs.

### Q12: Why must administrators strictly avoid wildcard characters (`*`, `?`) when executing `lvremove` and `vgremove`?
**Answer:** LVM command line tools accept volume names that can expand unpredictably if globbing characters match files in the current working directory or unexpected volume names. In enterprise shared storage, an unconstrained `lvremove -y *` could destroy production databases or system volumes. Best practice mandates strict path guards, exact volume name specification, and prefix verification (e.g. `lsatest_snap_*` checked individually).
