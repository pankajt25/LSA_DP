# NovaTech Solutions — Enterprise Storage Infrastructure Plan
**Course:** Linux System Administration (E1ITA307)  
**Project:** Linux Infrastructure Deployment Project #1  
**Problem Statement:** Enterprise Storage Infrastructure (Modules: III, IV | CO3, CO4)  
**Author:** Infrastructure Engineering & DevOps Team  
**Organization:** NovaTech Solutions  

---

## 1. Executive Summary & Objective

NovaTech Solutions operates a multi-departmental Linux environment requiring enterprise-grade, secure, scalable, and isolated storage infrastructure for four core business divisions:
- **Human Resources (HR)**: Personnel records, compliance forms, benefits rosters.
- **Finance**: General ledgers, accounts payable/receivable, audit trails.
- **Engineering**: High-performance architecture diagrams, microservices schemas, container repositories.
- **Sales**: CRM prospect pipelines, client contracts, quota models.

Each department requires dedicated directory space accessible strictly to authorized team members, with full isolation against unauthorized cross-departmental access. To avoid storage fragmentation, eliminate planned downtime during capacity expansions, and guarantee data resilience, the storage hierarchy is implemented using Linux Logical Volume Manager version 2 (`LVM2`), partitioned with POSIX Access Control Lists (`ACLs`), automated daily backups, and persistent configuration.

---

## 2. Storage Layout Diagram

The architecture follows the standard LVM2 layered hierarchy: physical block devices are partitioned, initialized as Physical Volumes (`PV`), aggregated into a unified Volume Group (`company_vg`), carved into departmental Logical Volumes (`LV`), formatted with specialized filesystems (`ext4` and `XFS`), and mounted to isolated sandbox directory structures.

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
|  |  Alloc: 1280PE|   |  Alloc: 2048PE|   | Alloc: 5120PE |   | Alloc: 1280PE |                    |
|  +-------+-------+   +-------+-------+   +-------+-------+   +-------+-------+                    |
+----------|-------------------|-------------------|-------------------|----------------------------+
           |                   |                   |                   |
+----------v-------------------v-------------------v-------------------v----------------------------+
|                               FILESYSTEM & MOUNT POINT LAYER                                      |
|                                                                                                   |
|    Filesystem:         Filesystem:         Filesystem:         Filesystem:                        |
|       ext4                ext4                XFS                 ext4                            |
|                                                                                                   |
|    Mount Point:        Mount Point:        Mount Point:        Mount Point:                       |
|  sandbox_data/mnt/hr sandbox_data/mnt/fin  sandbox_data/mnt/eng sandbox_data/mnt/sales            |
|                                                                                                   |
|  Access Control:     Access Control:     Access Control:     Access Control:                      |
|  Group: hr_team      Group: finance_team Group: eng_team     Group: sales_team                    |
|  Mode: 2770 + ACL    Mode: 2770 + ACL    Mode: 2770 + ACL    Mode: 2770 + ACL                     |
+---------------------------------------------------------------------------------------------------+
```

---

## 3. Department Storage Sizing Table

| Department | Logical Volume | Initial Size | Filesystem | Mount Point | Department Group | Primary Workload / Data Profile |
|---|---|---|---|---|---|---|
| **Human Resources** | `lv_hr` | **5 GiB** | `ext4` | `sandbox_data/mnt/hr` | `lsatest_hr_team` | Personnel directories, I-9 verification, payroll rosters, benefits documents |
| **Finance** | `lv_finance` | **8 GiB** | `ext4` | `sandbox_data/mnt/finance` | `lsatest_finance_team` | General ledgers, accounts payable/receivable, quarterly tax filings, audit trails |
| **Engineering** | `lv_eng` | **15 GiB &rarr; 20 GiB** | `XFS` | `sandbox_data/mnt/eng` | `lsatest_eng_team` | High-throughput build artifacts, SQL schemas, microservice configs, container bundles |
| **Sales** | `lv_sales` | **5 GiB** | `ext4` | `sandbox_data/mnt/sales` | `lsatest_sales_team` | CRM lead databases, enterprise client proposals, regional pipeline trackers |
| **Unallocated Reserve** | — | **6.99 GiB** | — | — | — | Reserved inside `company_vg` for dynamic runtime expansion (`lvextend`) |

---

## 4. Why LVM (Technical Justification)

1. **Elimination of Fixed Partition Boundaries:** Traditional MBR/GPT partitioning binds filesystems to rigid, contiguous disk sectors. Extending a partition requires risky re-partitioning, rebooting, or unmounting. LVM aggregates physical disks into a unified storage pool (`company_vg`) from which logical volumes draw 4 MiB Physical Extents (`PE`) as needed.
2. **Zero-Downtime Online Volume Elasticity:** Production systems cannot tolerate maintenance outages to grow filesystems. LVM supports dynamic runtime expansion (`lvextend -L +5G`) while applications are actively reading and writing. When paired with filesystems like `XFS` (`xfs_growfs`) or `ext4` (`resize2fs`), volumes scale online without unmounting.
3. **Multi-Disk Pooling & Redundancy:** Disks of varying physical capacities (10G, 15G, 20G) are aggregated into a unified 45G storage fabric, eliminating wasted slack space across independent block devices.
4. **Snapshot Capabilities:** LVM supports point-in-time read-only or read-write copy-on-write snapshots, providing rapid pre-migration rollbacks and consistent backup freezing.

---

## 5. Filesystem Selection Rationale: ext4 vs. XFS

- **ext4 for HR, Finance, and Sales:**
  - Mature, reliable POSIX-compliant journaling filesystem.
  - Excellent performance on small-to-medium files (documents, CSVs, logs).
  - Supports full POSIX Access Control Lists (`ACLs`), SetGID bit propagation, and online expansion via `resize2fs`.
- **XFS for Engineering:**
  - High-performance 64-bit journaling filesystem designed for high parallel I/O and large file throughput.
  - Allocation groups allow simultaneous metadata operations across multi-core processors.
  - Native online capacity expansion via `xfs_growfs` while mounted.

---

## 6. Access Control & RBAC Security Model

1. **Ownership & SetGID Bit (Mode 2770):**
   - Each mount point is configured with permissions `drwxrws---` (`2770`).
   - The SetGID bit (`2`) guarantees that any newly created file or subdirectory automatically inherits the department group ownership rather than the primary group of the creating user.
2. **POSIX Access Control Lists (ACLs):**
   - Default ACLs are enforced: `setfacl -d -m g::rwx <mount>`.
   - Ensures newly created files inherit read, write, and execute permissions for group members automatically.
3. **Cross-Departmental Isolation (Negative Access Check):**
   - Non-members are strictly denied directory traversal (`rwx` only for owner and group; zero permissions for others `---`).

---

## 7. Storage Persistence Architecture

To guarantee safe testing in a sandbox environment:
- Real `/etc/fstab` is never modified during test runs.
- Storage persistence is demonstrated and validated using a dedicated manifest at `DP_01/sandbox_data/fstab.demo`:
  ```fstab
  UUID=<hr_uuid>     sandbox_data/mnt/hr       ext4  defaults,acl  0  2
  UUID=<fin_uuid>    sandbox_data/mnt/finance  ext4  defaults,acl  0  2
  UUID=<eng_uuid>    sandbox_data/mnt/eng      xfs   defaults      0  2
  UUID=<sales_uuid>  sandbox_data/mnt/sales    ext4  defaults,acl  0  2
  ```
- Validated via `findmnt --verify --tab-file sandbox_data/fstab.demo`.

---

## 8. Naming Convention Schema

To ensure deterministic administration and strict compliance with organizational standards, the infrastructure adheres to the following unified naming schema:

| Entity Type | Convention Schema | Production Instances | Rationale |
|---|---|---|---|
| **Volume Group** | `<scope>_vg` | `company_vg` | Unambiguous storage pool identification |
| **Logical Volume** | `lv_<department>` | `lv_hr`, `lv_finance`, `lv_eng`, `lv_sales` | Identifies departmental ownership at the block layer |
| **Filesystem Label** | `<dept>_data` | `hr_data`, `fin_data`, `eng_data`, `sales_data` | Human-readable filesystem labels for blkid/e2label |
| **Mount Points** | `sandbox_data/mnt/<dept>` | `sandbox_data/mnt/{hr,finance,eng,sales}` | Isolated departmental mount points inside project sandbox |
| **Department Groups** | `lsatest_<dept>_team` | `lsatest_hr_team`, `lsatest_finance_team`, `lsatest_eng_team`, `lsatest_sales_team` | Namespaced RBAC groups to prevent system collisions |
| **User Accounts** | `lsatest_<name>_<dept>` | `lsatest_alice_hr`, `lsatest_charlie_fin`, `lsatest_evan_eng`, `lsatest_george_sales`, etc. | Namespaced system test accounts for negative access checks |
| **Backup Archives** | `<dept>_backup_<TS>.tar.gz` | e.g. `hr_backup_20261011_001423.tar.gz` | Deterministic point-in-time departmental identification |
| **Checksum Manifest** | `<archive>.sha256` | e.g. `hr_backup_20261011_001423.tar.gz.sha256` | Cryptographic SHA-256 integrity digest files |
