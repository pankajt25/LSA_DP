# Disaster Recovery Storage Infrastructure Architecture Plan
**Course:** Linux System Administration (E1ITA307) — Modules: IV | CO4  
**Project:** Linux Disaster Recovery Solution (DP_04)  
**Organization:** NovaTech Solutions Infrastructure Group  

---

## 1. Storage Architecture Overview

The disaster recovery infrastructure uses Linux Logical Volume Manager (LVM2) and the Device Mapper (`dm-snapshot`) subsystem to provide point-in-time state preservation, atomic rollback, and consistent external backup extraction.

All block storage is isolated within sparse virtual disk images mounted via Linux loop devices to guarantee strict sandboxing without touching physical host disks.

### ASCII Storage Topology Diagram

```text
+---------------------------------------------------------------------------------------------------+
|                                     HOST ENVIRONMENT (WSL2 / Linux)                               |
+---------------------------------------------------------------------------------------------------+
|                                                                                                   |
|  [ Virtual Disk 1 ] : sandbox_data/disk1.img (600 MB Sparse File)                                 |
|  [ Virtual Disk 2 ] : sandbox_data/disk2.img (600 MB Sparse File)                                 |
|          |                                                                                        |
|          v (losetup -f --show, verified via losetup -j)                                           |
|  [ Block Devices ]  : /dev/loop0 (600 MB)           /dev/loop1 (600 MB)                           |
|          |                                                  |                                     |
|          +-------------------------+------------------------+                                     |
|                                    v (pvcreate)                                                   |
|                         [ Physical Volumes (PVs) ]                                                |
|                                    |                                                              |
|                                    v (vgcreate)                                                   |
|  +---------------------------------------------------------------------------------------------+  |
|  | Volume Group: lsatest_dr_vg (Total Pool: ~1.16 GiB / 298 Physical Extents @ 4 MiB)         |  |
|  |                                                                                             |  |
|  |  +------------------------------------+  +-----------------------------------------------+  |  |
|  |  | Origin Volume: lsatest_data_lv     |  | Copy-on-Write Snapshots                       |  |  |
|  |  | (500 MB ext4 Filesystem)           |  | (Allocated from free extents in VG)           |  |  |
|  |  |                                    |  |  - lsatest_snap_s1 (100 MB)                   |  |  |
|  |  | Mount: sandbox_data/mnt/data       |  |  - lsatest_snap_s2 (100 MB)                   |  |  |
|  |  |                                    |  |  - lsatest_snap_s3 (100 MB - merged)          |  |  |
|  |  | Contains:                          |  |  - lsatest_snap_s5 (100 MB - backup src)     |  |  |
|  |  |   finance/     (25 files)          |  |                                               |  |  |
|  |  |   hr/          (25 files)          |  | Mount: sandbox_data/mnt/snap (ro)             |  |  |
|  |  |   engineering/ (30 files)          |  +-----------------------------------------------+  |  |
|  |  |   sales/       (25 files)          |  | Free Pool Headroom: ~692 MB (Extents for CoW) |  |  |
|  |  +------------------------------------+  +-----------------------------------------------+  |  |
|  +---------------------------------------------------------------------------------------------+  |
|                                                                                                   |
|  +---------------------------------------------------------------------------------------------+  |
|  | EXTERNAL ARCHIVE REPOSITORY (DELIBERATELY OUTSIDE THE VOLUME GROUP)                         |  |
|  | Path: sandbox_data/archive_store/                                                           |  |
|  | Files:                                                                                      |  |
|  |   - data_<TIMESTAMP>.tar.gz          (Gzip-compressed point-in-time archive)                 |  |
|  |   - data_<TIMESTAMP>.tar.gz.sha256   (Cryptographic SHA-256 verification digest)            |  |
|  +---------------------------------------------------------------------------------------------+  |
|                                                                                                   |
+---------------------------------------------------------------------------------------------------+
```

---

## 2. Theory of Operation: Copy-on-Write (CoW) Snapshots

### 2.1 The Copy-on-Write Mechanism
Classic LVM snapshots implement a differential block tracking mechanism managed by the kernel's `dm-snapshot` driver:

1. **Snapshot Creation (Metadata Only):** When `lvcreate -s` executes, LVM creates an empty exception table. No data blocks are copied from the origin volume. Creation completes in fractions of a second regardless of origin filesystem size.
2. **Read Operations on Snapshot:** When reading from the snapshot:
   - If a requested block has **not** been modified on the origin, the read request is redirected transparently to the origin volume.
   - If the requested block **has** been modified on the origin, the read request retrieves the preserved original block from the snapshot's allocated exception store.
3. **Write Operations on Origin (The "Write Penalty"):**
   - When a process writes new data to an unmodified block on the origin volume, the kernel intercepts the I/O.
   - The *original* block is read from the origin volume and written into the snapshot's exception store (the "Copy-on-Write" step).
   - Once the old block is safely recorded in the snapshot, the new write is committed to the origin volume.
   - Subsequent writes to that same block on the origin overwrite the origin block directly without copying again.

### 2.2 Mathematical Sizing of Snapshots
A snapshot does not need to equal the size of the origin volume. Sizing is governed by the volume's block modification rate and the desired retention window:

$$\text{Required Snapshot Size} = (\text{Write Throughput / Change Rate per Unit Time}) \times (\text{Retention Window}) \times (\text{Safety Factor})$$

For example, on an origin volume with:
- **Write Churn Rate:** 15 MB / hour
- **Retention Lifetime:** 4 hours
- **Safety Margin:** 1.5 (50% overhead for filesystem metadata changes)

$$\text{Allocated Snapshot Size} = 15\text{ MB/hr} \times 4\text{ hr} \times 1.5 = 90\text{ MB}$$

In our deployment infrastructure:
- Origin Volume: 500 MB
- Snapshots: 100 MB allocation per snapshot (~20% of origin volume capacity)
- Free Volume Group Headroom: 692 MB (permits up to 6 concurrent 100 MB snapshots)

---

## 3. Classic Snapshots vs. Thin Snapshots

| Architectural Dimension | Classic LVM Snapshots (`dm-snapshot`) | Thin Provisioned Snapshots (`dm-thin-pool`) |
|---|---|---|
| **Underlying Architecture** | Dedicated exception store carved per snapshot from VG | Shared virtual data/metadata pool (`thin-pool`) |
| **Write Amplification** | Linear write amplification: $N$ snapshots require $N$ copies per write | Zero duplicate copies: new write allocates new block in thin pool (Allocate-on-Write) |
| **Scalability** | Practical limit: 3 to 10 snapshots per origin before I/O degradation | Supports hundreds of recursive snapshots with negligible I/O penalty |
| **Recursive Snapshotting** | Cannot snapshot an existing snapshot | Snapshots of snapshots are natively supported |
| **Failure Behavior** | Invalidation occurs isolated to overflowing snapshot | Thin pool exhaustion impacts all logical volumes in the pool |
| **Use Case in DP_04** | Selected for enterprise determinism, clear boundary isolation, and explicit capacity monitoring | Modern cloud VMs and container block storage |

---

## 4. Recovery Objectives: RPO & RTO Specifications

- **Recovery Point Objective (RPO):** The maximum tolerable data loss duration measured backwards in time from the disaster event.
  - *S1, S2, S3, S5 Measured RPO / Data-Loss Window:* **2 to 3 seconds** (representing instantaneous recovery back to the snapshot / archive commit timestamp).
- **Recovery Time Objective (RTO):** The maximum acceptable duration required to restore operational service after disaster declaration.
  - *S1 (Selective File Restore):* **~1 - 2 seconds**
  - *S2 (Single File Restore):* **~1 - 2 seconds**
  - *S3 (Full Block-Level Merge):* **~2 - 3 seconds**
  - *S5 (Bare-Metal Archive Rebuild):* **~2 - 4 seconds**

---

## 5. Storage Naming & Security Conventions

To prevent accidental modification of host storage, all resources adhere to immutable naming standards:

- **Volume Group:** `lsatest_dr_vg`
- **Origin Logical Volume:** `lsatest_data_lv`
- **Snapshot Logical Volumes:** `lsatest_snap_<IDENTIFIER>` (e.g. `lsatest_snap_s1`, `lsatest_snap_rot1`)
- **Origin Mount Point:** `sandbox_data/mnt/data`
- **Snapshot Mount Point:** `sandbox_data/mnt/snap`
- **Archive Store:** `sandbox_data/archive_store/` (Strictly external to LVM)

---

## 6. Filesystem-Specific Considerations (ext4 vs. XFS)

### ext4 Implementation (Current Lab Deployment)
- The origin filesystem uses `ext4`.
- When mounting snapshots read-only (`mount -o ro /dev/lsatest_dr_vg/lsatest_snap_* sandbox_data/mnt/snap`), ext4 allows mounting without conflicts because the snapshot is treated as a separate block device.

### XFS Implementation Guideline (Reference Only)
- XFS records a unique filesystem UUID in its superblock.
- Because an LVM snapshot contains an identical replica of the origin superblock, mounting an XFS snapshot on the same machine where the origin is already mounted causes the kernel to reject the mount:
  ```text
  XFS (dm-X): Filesystem has duplicate UUID <UUID> - can't mount
  ```
- **Operational Requirement for XFS:** System administrators must specify the `-o nouuid` mount option when mounting XFS snapshots alongside the origin volume:
  ```bash
  mount -o ro,nouuid /dev/lsatest_dr_vg/lsatest_snap_xfs sandbox_data/mnt/snap
  ```

---

## 7. Operational Safety Rules

1. **Path Guards:** Every script resolving filesystem paths executes `realpath -m` and verifies the target is prefixed by `DP_04/sandbox_data/`.
2. **Wildcard Ban:** `lvremove`, `vgremove`, and `pvremove` never accept wildcard tokens (`*`, `?`).
3. **Prefix Enforcement:** Destructive commands will strictly abort unless target names start with `lsatest_`.
4. **Host Isolation:** Host `/etc/fstab` and `/etc/lvm/` are never modified. Persistence is verified via `sandbox_data/fstab.demo` and `findmnt --verify`.
