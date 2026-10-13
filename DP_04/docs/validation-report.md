# Linux Disaster Recovery Validation Report
**Course:** Linux System Administration (E1ITA307) — Modules: IV | CO4  
**Project:** Linux Disaster Recovery Solution (DP_04)  
**Execution Timestamp:** 2026-10-13 13:03:25 UTC  
**System Hostname:** `SP`  
**Kernel Release:** `6.18.40.1-microsoft-standard-WSL2`  

---

## Executive Engineering Summary

This technical validation report documents the empirical results of five disaster recovery scenarios executed on an LVM-backed storage infrastructure. All tests were executed within an isolated sandbox environment using loopback-backed physical volumes, an active Volume Group (`lsatest_dr_vg`), origin Logical Volume (`lsatest_data_lv`), Copy-on-Write snapshots (`lsatest_snap_*`), and an external archive repository (`sandbox_data/archive_store/`).

Every recovery duration, data-loss window, and integrity verification represents real kernel timestamps and cryptographic SHA-256 manifest comparisons.

---

## Disaster Recovery Scenario Summary Matrix

| ID | Scenario Name | Disaster Simulation | Recovery Method | Data Loss Window | Measured Recovery Time | Integrity Check | Status |
|:---:|---|---|---|:---:|:---:|:---:|:---:|
| **S1** | Accidental File Deletion | Accidental deletion of 5 departmental files across Finance, HR, Eng, Sales | Read-Only Snapshot Mount & Selective File Restore (cp -a) | **3s** | **0s** | 105/105 Matched (0 Mismatch) | **PASS** |
| **S2** | Accidental Overwrite or Corruption | Targeted overwrite and bit corruption of finance/ledger_entry_12.csv with bounded random payload | Read-Only Snapshot Mount & Targeted Single File Restore (cp -a) | **4s** | **0s** | Checksum Matched (0 Mismatch) | **PASS** |
| **S3** | Catastrophic Loss with Full Rollback | Catastrophic recursive deletion of 2 entire departments (engineering/ and sales/) | Full Block-Level Snapshot Rollback (lvconvert --merge offline) | **5s** | **33s** | 105/105 Matched (0 Mismatch) | **PASS** |
| **S4** | Snapshot Capacity Exhaustion & Prevention | Origin block churn (25M) exceeding 16M snapshot CoW table capacity | Invalidation Detection (Attr 'I') & Online Dynamic Expansion (lvextend +40M) | **N/A** | **6s** | Overflow & Elastic Extend Verified | **PASS** |
| **S5** | Loss Beyond Snapshots (Why Snapshots != Backups) | Total volume destruction: origin LV and all snapshots destroyed | External Point-in-Time Tarball Archive Restoration (Outside VG) | **5s** | **2s** | 105/105 Matched (0 Mismatch) | **PASS** |

---

## Detailed Scenario Validations

### Scenario 1: Accidental File Deletion
- **Disaster Action:** Selective deletion of 5 department files across Finance, HR, Engineering, and Sales (`finance/ledger_entry_1.csv`, `finance/payroll_summary_3.txt`, `hr/employee_roster_1.csv`, `engineering/dr_service_core_1.py`, `sales/pipeline_q2_run_1.csv`).
- **Recovery Action:** Mounted snapshot `lsatest_snap_s1` read-only at `sandbox_data/mnt/snap`. Copied missing files directly back into the live origin volume with preserved attributes using `cp -a`. Unmounted snapshot.
- **Data Loss Window (Disaster Time - Snapshot Time):** **3 seconds**
- **Measured Recovery Time:** **0 seconds**
- **Files Evaluated:** 105
- **Cryptographic Matches:** 105
- **Integrity Mismatches:** 0
- **Scenario Status:** **PASS**

### Scenario 2: Accidental Overwrite or Corruption
- **Disaster Action:** Bounded overwrite and pseudo-random bit corruption injected into critical financial model `finance/quarterly_forecast_2.dat` using `dd if=/dev/urandom ... bs=1k count=24 conv=notrunc`. Verified checksum deviated from baseline.
- **Recovery Action:** Mounted snapshot `lsatest_snap_s2` read-only at `sandbox_data/mnt/snap`. Extracted unaltered original block copy and restored single file via `cp -a`. Unmounted snapshot.
- **Data Loss Window (Disaster Time - Snapshot Time):** **4 seconds**
- **Measured Recovery Time:** **0 seconds**
- **Restored File:** `finance/quarterly_forecast_2.dat`
- **Files Evaluated:** 105
- **Cryptographic Matches:** 105
- **Integrity Mismatches:** 0
- **Scenario Status:** **PASS**

### Scenario 3: Catastrophic Loss with Full Rollback
- **Disaster Action:** Total recursive deletion of two complete departmental hierarchies (`engineering/` and `sales/`).
- **Recovery Action:** Unmounted live origin filesystem to prevent metadata cache collision. Executed offline block rollback using `lvconvert --merge /dev/lsatest_dr_vg/lsatest_snap_s3`. Reactivated origin volume (`lvchange -ay`) and remounted at `sandbox_data/mnt/data`.
- **Architectural Rationale:** The merge operation replaces modified extents on the origin with the snapshot's baseline extents. The origin filesystem MUST be unmounted prior to merge because in-place modification of mounted ext4 superblock and block groups by the kernel block layer causes filesystem corruption and kernel panics. The merge operation inherently consumes the snapshot.
- **Data Loss Window (Disaster Time - Snapshot Time):** **5 seconds**
- **Measured Recovery Time:** **33 seconds**
- **Files Evaluated:** 105
- **Cryptographic Matches:** 105
- **Integrity Mismatches:** 0
- **Scenario Status:** **PASS**

### Scenario 4: Snapshot Capacity Exhaustion & Dynamic Prevention
- **Part 1 — Capacity Overflow:** Created an undersized snapshot (`lsatest_snap_overflow`, 16 MiB). Generated 25 MiB of dirty write churn on the origin volume. When the snapshot copy-on-write table filled completely:
  - **Data% Utilization:** Reached **100.00%**
  - **Volume Attributes:** Transitioned to **`swi-I-s---`** (flag `I` designates an invalid snapshot dropped by the device mapper).
  - Snapshot was cleanly removed using name-guarded `safe_lvremove`.
- **Part 2 — Proactive Dynamic Expansion:** Created monitored snapshot (`lsatest_snap_monitored`, 20 MiB). Injected 10 MiB write churn.
  - **Pre-Expansion State:** Size: **20.00m**, Data%: **50.59%**
  - **Action Taken:** Executed live online volume expansion: `lvextend -L +40M /dev/lsatest_dr_vg/lsatest_snap_monitored`
  - **Post-Expansion State:** Size: **60.00m**, Data%: **16.86%** (headroom restored, preventing snapshot invalidation).
- **Measured Recovery / Extension Time:** **6 seconds**
- **Scenario Status:** **PASS**

### Scenario 5: Loss Beyond Snapshots (Why Snapshots != Backups)
- **Architectural Principle:** A snapshot is not an independent backup. Because LVM copy-on-write snapshots store only differential blocks and depend entirely on the origin Volume Group, total physical drive failure or origin LV deletion permanently destroys all associated snapshots simultaneously.
- **Disaster Action:** Point-in-time snapshot was created and mounted read-only while the origin remained online. A full compressed tarball archive was generated into `sandbox_data/archive_store/data_20261013_183244.tar.gz` (outside the VG) along with an external SHA-256 manifest. Then, total catastrophic loss was executed: the origin volume and its snapshots were completely destroyed via `safe_lvremove`.
- **Recovery Action:** Recreated origin volume from bare pool (`lvcreate -L 500M`), formatted clean ext4 filesystem, mounted, verified external archive checksum (`8250d16cb3babdf7...`), and extracted entire tree via `tar -xzf`.
- **Data Loss Window (Disaster Time - Snapshot Time):** **5 seconds**
- **Measured Recovery Time:** **2 seconds**
- **Archive File:** `data_20261013_183244.tar.gz` (26K)
- **Files Evaluated:** 105
- **Cryptographic Matches:** 105
- **Integrity Mismatches:** 0
- **Scenario Status:** **PASS**

---

## Limits of Snapshots

While LVM snapshots provide instantaneous, space-efficient recovery points, system administrators must understand their inherent architectural boundaries:

1. **Lack of Hardware Fault Tolerance:** Snapshots reside within the same Volume Group and storage media as the origin volume. If the physical disk, RAID array, or storage controller fails, both the origin and all snapshots are lost.
2. **CoW Write Amplification:** Every new write to an uncopied block on the origin volume incurs a read-before-write penalty (reading the old block and writing it to the snapshot CoW store before committing the new block). Multiple active snapshots multiply this I/O penalty.
3. **Catastrophic Invalidation on Overflow:** Classic LVM snapshots that exhaust their allocated space become permanently invalid (attribute `I`). Once invalid, the snapshot cannot be repaired or read, and any subsequent merge operation will fail.
4. **No Protection Against Volume Group Corruption:** Corruption of LVM metadata, physical volume headers, or underlying block devices invalidates both the origin and all snapshot structures.
5. **Lack of Geographic Separation:** Snapshots cannot protect against facility-level disasters (fire, flood, power loss, ransomware wiping local block devices). Only independent, immutable backups exported to geographically separated, off-site storage provide true disaster survivability.

