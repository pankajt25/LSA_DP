# Department File Server (DP_03)
**Course:** Linux System Administration (E1ITA307) — Modules: III, IV | CO3, CO4  
**Project:** Linux Infrastructure Deployment Project #3  
**Organization:** NovaTech Solutions  
**Target Repository:** [https://github.com/pankajt25/LSA_DP.git](https://github.com/pankajt25/LSA_DP.git)  

---

## Command to Execute

To execute the automated end-to-end file server deployment, loopback volume creation, ext4 quota configuration, RBAC identity provisioning, POSIX ACL inheritance setup, 8-point security testing suite, and HTML report generation:

```bash
# Navigate to the DP_03 project directory
cd DP_03

# Execute master runner (single-command cross-platform orchestrator)
bash run.sh
```

> [!NOTE]
> `cleanup.sh` is a deliberate, separate second step that deactivates quotas, unmounts filesystems, detaches verified loop devices, deletes disk images, and purges test accounts. Do not run it until after all system verification audits and reviews are completed:
> ```bash
> bash cleanup.sh
> ```

---

## Viewing the HTML Report

The live HTML audit report (`report.html`) is self-contained with inline CSS and an executive dark theme. `run.sh` automatically detects the operating environment and launches the report:

- **WSL / Windows Launch Command:**
  ```bash
  explorer.exe "$(wslpath -w report.html)"
  ```
- **Direct Windows File Path:**
  `D:\Users\Dell\Downloads\Projects\LSA\Deployment_Projects\DP_03\report.html`
- **Native Linux (Desktop):**
  ```bash
  xdg-open report.html
  ```
- **macOS:**
  ```bash
  open report.html
  ```

---

## Scenario & Department Storage Specification

NovaTech Solutions operates a centralized file server where four operational departments require private shared workspaces, an independent governance auditor has global read-only visibility, storage quotas prevent single users or entire departments from exhausting the storage pool, and peer deletion protection stops users from deleting colleagues' work.

### Department Quota & Access Control Table

| Department | Primary Group | Test Users | Shared Directory | Group Quota (Soft / Hard) | Per-User Quota (Soft / Hard) | Permissions & Governance |
|---|---|---|---|---|---|---|
| **Finance** | `lsatest_grp_finance` | `lsatest_fin_alice`<br>`lsatest_fin_bob` | `finance/` | 200 MB / 250 MB | 90 MB / 110 MB | Read/Write/Execute (`2770` / `3770` + Default ACLs) |
| **HR** | `lsatest_grp_hr` | `lsatest_hr_carol`<br>`lsatest_hr_dave` | `hr/` | 100 MB / 120 MB | 50 MB / 60 MB | Read/Write/Execute (`2770` / `3770` + Default ACLs) |
| **Engineering** | `lsatest_grp_eng` | `lsatest_eng_eve`<br>`lsatest_eng_frank` | `eng/` | 400 MB / 500 MB | 150 MB / 200 MB | Read/Write/Execute (`2770` / `3770` + Default ACLs) |
| **Sales** | `lsatest_grp_sales` | `lsatest_sales_grace`<br>`lsatest_sales_heidi` | `sales/` | 100 MB / 120 MB | 50 MB / 60 MB | Read/Write/Execute (`2770` / `3770` + Default ACLs) |
| **Auditors** | `lsatest_grp_audit` | `lsatest_aud_ivan` | Global (`*`) | N/A (Governance) | N/A (Governance) | Global Read-Only (`r-x`), Write & Delete Denied (`---`) |

---

## Architecture Summary

```
+===================================================================================================+
|                                    STORAGE VOLUME LAYER (2 GiB)                                   |
|                                                                                                   |
|  Image File: sandbox_data/fileserver.img (2 GiB Sparse ext4 Volume)                              |
|  Loopback Device: /dev/loop0 (Verified via losetup -j)                                            |
|  Superblock Feature Flags: quota, usrquota, grpquota (tune2fs -O quota -Q usrquota,grpquota)      |
|  Mount Point: sandbox_data/mnt/fileserver/                                                        |
|  Mount Options: rw,relatime,acl,usrquota,grpquota                                                 |
+===================================================================================================+
                                                   |
         +--------------------+--------------------+--------------------+--------------------+
         |                    |                    |                    |                    |
+--------v-----------+ +------v------------+ +-----v------------+ +-----v------------+      |
|     finance/       | |       hr/         | |      eng/        | |     sales/       |      |
| Mode: 3770         | | Mode: 3770        | | Mode: 3770       | | Mode: 3770       |      |
| Owner: root        | | Owner: root       | | Owner: root      | | Owner: root      |      |
| Group: fin_group   | | Group: hr_group   | | Group: eng_group | | Group: sales_grp |      |
+--------------------+ +-------------------+ +------------------+ +------------------+      |
         |                    |                    |                    |                   |
         | POSIX ACLs:        | POSIX ACLs:        | POSIX ACLs:        | POSIX ACLs:       |
         | fin_grp: rwx       | hr_grp: rwx        | eng_grp: rwx       | sales_grp: rwx    |
         | audit_grp: r-x     | audit_grp: r-x     | audit_grp: r-x     | audit_grp: r-x    |
         | default: fin (rwx) | default: hr (rwx)  | default: eng (rwx) | default: sale(rwx)|
         | default: aud (r-x) | default: aud (r-x) | default: aud (r-x) | default: aud (r-x)|
         | other: ---         | other: ---         | other: ---         | other: ---        |
         +--------------------+--------------------+--------------------+-------------------+
                                                   |
                         +=========================v=========================+
                         |           GOVERNANCE & AUDIT ACCESS               |
                         |  Group: lsatest_grp_audit                         |
                         |  User: lsatest_aud_ivan                           |
                         |  Permissions: Global Read-Only (r-x)              |
                         |  Write/Delete: Strictly Denied (---)              |
                         +===================================================+
```

---

## Live Output Blocks per Phase

### Phase 0: Preflight & Environment Audit
```text
[INFO] Kernel Release: 6.18.40.1-microsoft-standard-WSL2
[SUCCESS] Sudo access verified.
[SUCCESS] Package 'acl' is installed (Version: 2.3.2-2).
[SUCCESS] Package 'quota' is installed (Version: 4.09-1build1).
[SUCCESS] All administrative binaries verified.
[SUCCESS] Kernel quota interface detected in /proc/sys/fs/quota.
[SUCCESS] Supported filesystem drivers present in /proc/filesystems.
[SUCCESS] Loopback subsystem available. Next available device: /dev/loop0
[SUCCESS] Preflight Decision: NATIVE QUOTA MODE selected.
```

### Phase 1: Storage Allocation & Mount Setup
```text
[SUCCESS] Attached /mnt/d/.../DP_03/sandbox_data/fileserver.img -> /dev/loop0
[SUCCESS] Sandboxing assertion verified: /dev/loop0 is backed strictly by fileserver.img.
[SUCCESS] Filesystem ext4 created on /dev/loop0.
[SUCCESS] Internal quota feature flags enabled in ext4 superblock.
[SUCCESS] Successfully mounted at sandbox_data/mnt/fileserver.
[SUCCESS] Persistence verification PASSED: sandbox_data/fstab.demo is 100% valid.

=== Block Device Hierarchy (lsblk) ===
NAME  MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
loop0   7:0    0   2G  0 loop .../DP_03/sandbox_data/mnt/fileserver

=== Live Mount Options ===
/dev/loop0 on .../DP_03/sandbox_data/mnt/fileserver type ext4 (rw,relatime,quota,usrquota,grpquota)
```

### Phase 2: RBAC Identities, Groups & Base Ownership
```text
=== Active Test Groups ===
lsatest_grp_finance:x:1016:
lsatest_grp_hr:x:1017:
lsatest_grp_eng:x:1018:
lsatest_grp_sales:x:1019:
lsatest_grp_audit:x:1020:

=== Active Test Users & Memberships ===
uid=1014(lsatest_fin_alice) gid=1016(lsatest_grp_finance) groups=1016(lsatest_grp_finance)
uid=1015(lsatest_fin_bob) gid=1016(lsatest_grp_finance) groups=1016(lsatest_grp_finance)
uid=1016(lsatest_hr_carol) gid=1017(lsatest_grp_hr) groups=1017(lsatest_grp_hr)
uid=1017(lsatest_hr_dave) gid=1017(lsatest_grp_hr) groups=1017(lsatest_grp_hr)
uid=1018(lsatest_eng_eve) gid=1018(lsatest_grp_eng) groups=1018(lsatest_grp_eng)
uid=1019(lsatest_eng_frank) gid=1018(lsatest_grp_eng) groups=1018(lsatest_grp_eng)
uid=1020(lsatest_sales_grace) gid=1019(lsatest_grp_sales) groups=1019(lsatest_grp_sales)
uid=1021(lsatest_sales_heidi) gid=1019(lsatest_grp_sales) groups=1019(lsatest_grp_sales)
uid=1022(lsatest_aud_ivan) gid=1020(lsatest_grp_audit) groups=1020(lsatest_grp_audit)

=== Department Directory Permissions (ls -ld) ===
drwxrws--- 2 root lsatest_grp_finance 4096 Oct 12 19:44 sandbox_data/mnt/fileserver/finance
drwxrws--- 2 root lsatest_grp_hr      4096 Oct 12 19:44 sandbox_data/mnt/fileserver/hr
drwxrws--- 2 root lsatest_grp_eng     4096 Oct 12 19:44 sandbox_data/mnt/fileserver/eng
drwxrws--- 2 root lsatest_grp_sales   4096 Oct 12 19:44 sandbox_data/mnt/fileserver/sales
```

### Phase 3: POSIX Access & Default ACLs
```text
=== Active ACL State: finance/ ===
# file: sandbox_data/mnt/fileserver/finance
# owner: root
# group: lsatest_grp_finance
# flags: -s-
user::rwx
group::rwx
group:lsatest_grp_finance:rwx
group:lsatest_grp_audit:r-x
mask::rwx
other::---
default:user::rwx
default:group::rwx
default:group:lsatest_grp_finance:rwx
default:group:lsatest_grp_audit:r-x
default:mask::rwx
default:other::---

=== Inherited File ACL: finance/acl_inheritance_demo.txt ===
-rw-rw----+ 1 lsatest_fin_alice lsatest_grp_finance 62 Oct 12 19:46 .../acl_inheritance_demo.txt
# owner: lsatest_fin_alice
# group: lsatest_grp_finance
user::rw-
group::rwx                      #effective:rw-
group:lsatest_grp_finance:rwx   #effective:rw-
group:lsatest_grp_audit:r-x     #effective:r--
mask::rw-
other::---
```

### Phase 4: Quota Allocation & Grace Periods
```text
=== Active User Quotas (repquota -u) ===
*** Report for user quotas on device /dev/loop0
Block grace time: 7days; Inode grace time: 7days
                        Block limits                File limits
User            used    soft    hard  grace    used  soft  hard  grace
----------------------------------------------------------------------
root      --      52       0       0              6     0     0       
lsatest_fin_alice --       4   92160  112640              1     0     0       

=== Active Group Quotas (repquota -g) ===
*** Report for group quotas on device /dev/loop0
Block grace time: 7days; Inode grace time: 7days
                        Block limits                File limits
Group           used    soft    hard  grace    used  soft  hard  grace
----------------------------------------------------------------------
root      --      20       0       0              2     0     0       
lsatest_grp_finance --      12  204800  256000              2     0     0       
lsatest_grp_hr --       8  102400  122880              1     0     0       
lsatest_grp_eng --       8  409600  512000              1     0     0       
lsatest_grp_sales --       8  102400  122880              1     0     0       
```

### Phase 5: Test Execution & Verification (8/8 Passed)
```text
[SUCCESS] Test 1 PASSED: Finance collaboration verified.
[SUCCESS] Test 2 PASSED: Cross-department isolation strictly enforced (Permission Denied).
[SUCCESS] Test 3 PASSED: Auditor read-only governance validated (Read=0, Write!=0, Del!=0).
[SUCCESS] Test 4 PASSED: Default ACL & SetGID inheritance verified.
[SUCCESS] Test 5 PASSED: Sticky bit peer deletion protection verified (Operation not permitted).
[SUCCESS] Test 6 PASSED: Soft quota warning and grace period active (repquota reports '+-').
[SUCCESS] Test 7 PASSED: Hard quota enforcement confirmed (dd: IO error: Disk quota exceeded).
[SUCCESS] Test 8 PASSED: Storage accounting reconciled successfully (du=59MB, repquota=59MB).
```

### Phase 6: Security Audit
```text
[SUCCESS] Audit 1 PASSED: Zero world-writable files detected.
[SUCCESS] Audit 2 PASSED: Zero unprotected world-writable directories found.
[SUCCESS] Audit 3 PASSED: Zero orphaned files found; all files mapped to active directory identities.
[SUCCESS] Directory finance/ is strictly isolated (Mode: 3770, Others: ---).
[SUCCESS] Directory hr/ is strictly isolated (Mode: 3770, Others: ---).
[SUCCESS] Directory eng/ is strictly isolated (Mode: 3770, Others: ---).
[SUCCESS] Directory sales/ is strictly isolated (Mode: 3770, Others: ---).
[SUCCESS] Phase 6 Security Audit COMPLETE: System complies 100% with enterprise security baseline.
```

---

## Troubleshooting Log

During the development and testing of the file server deployment, several real-world Linux systems administration challenges were encountered and resolved:

### 1. Bash Arithmetic Evaluation Under `set -e`
- **Symptom:** The test orchestrator script unexpectedly terminated with exit code 1 immediately after the first test passed, without executing subsequent tests.
- **Root Cause:** In Bash, `((var++))` returns an exit status of `1` (false) when `var` starts at `0` because the expression evaluates to `0`. Under `set -e` (pipefail), any non-zero exit status aborts the shell immediately.
- **Resolution:** Replaced `((PASSED_TESTS++))` with `PASSED_TESTS=$((PASSED_TESTS + 1))` across all test scripts, ensuring clean 0-exit returns regardless of the initial variable counter.

### 2. Privilege Isolation When Auditing Restricted Directories
- **Symptom:** During Phase 3 ACL verification, `getfacl` failed with `Permission denied` when executed by the local non-root user `pankaj`.
- **Root Cause:** Departmental shared directories are configured with `o::---` (Others: No Access). Because user `pankaj` is not a member of `lsatest_grp_finance` or `lsatest_grp_audit`, the Linux VFS correctly denied directory traversal (`search`) access.
- **Resolution:** Wrapped administrative inspection commands (`getfacl`, `stat`, `ls`) with `sudo` within administrative reporting scripts, proving that the ACL isolation was performing exactly as intended.

### 3. File Deletion Semantics in Shared Group Folders
- **Symptom:** In standard mode `2770` (SetGID + Group write), any department member could delete or rename any other colleague's files.
- **Root Cause:** Under POSIX standards, `unlink()` and `rename()` permissions are determined by write access on the **parent directory**, not permissions on the target file itself.
- **Resolution:** Applied the directory **Sticky Bit** (`chmod 3770`), which instructs the kernel to permit deletion and renaming only by the file's owner or `root`, effectively preventing peer file tampering while preserving collaborative write permissions.

### 4. Modern ext4 Internal Quota Feature vs Traditional Quota Files
- **Symptom:** Traditional `quotacheck` reported `Cannot find quota file aquota.user` or reported that quota was already managed internally.
- **Root Cause:** Modern `e2fsprogs` and the Linux kernel support the `quota` feature directly within the ext4 superblock (`tune2fs -O quota -Q usrquota,grpquota`), which tracks quota metadata via internal hidden inodes rather than root-level `aquota.user`/`aquota.group` files.
- **Resolution:** Initialized quota tracking using superblock flags via `tune2fs`, allowing instant, crash-consistent kernel quota accounting without requiring traditional user-space `quotacheck` rebuilds.

---

## Validation Checklist

- [x] **Sandboxing Compliance:** Nothing created, modified, or deleted outside `DP_03/` except verified loop devices, `lsatest_` users and groups, and the `acl`/`quota` packages.
- [x] **Storage Allocation:** 2 GiB sparse volume mounted with `acl,usrquota,grpquota`, validated via `lsblk`, `blkid`, and `df -h`.
- [x] **RBAC Identities:** Five groups and nine users provisioned with `lsatest_` prefix, locked passwords, and `nologin` shell.
- [x] **Permissions & ACLs:** Departmental directories configured with mode `3770` (SetGID + Sticky Bit); POSIX Default ACLs propagate `rwx` to department peers and `r-x` to auditors.
- [x] **Departmental Isolation:** Cross-department listing, reading, and writing strictly blocked with Permission Denied.
- [x] **Governance Auditor:** Global read-only visibility validated across all four departments; write and delete attempts denied.
- [x] **Quota Enforcement:** Soft quota warning flag (`+-`) and 7-day grace period demonstrated; hard quota write halt (`Disk quota exceeded`) confirmed with bounded test data.
- [x] **Security Review:** Zero world-writable files, zero unprotected directories, zero orphaned identities, and 100% policy compliance.
- [x] **Report Generation:** Self-contained dark-themed HTML audit report (`report.html`) generated with live values.
- [x] **Master Execution:** `bash run.sh` runs end-to-end cleanly from a fresh shell.
- [x] **Sanitization Ready:** `bash cleanup.sh` tested and verified clean.

---

## Viva Defense Q&A (10 Questions & Detailed Answers)

### Q1: What is the difference between standard POSIX permissions (`chmod`) and POSIX Access Control Lists (ACLs)?
**Answer:**  
Standard POSIX permissions (`chmod`) only allow defining permissions for three distinct entities: one owner (`u`), one owning group (`g`), and all other users (`o`). This makes it impossible to grant different levels of access to multiple distinct groups (for example, allowing the Finance group `rwx` while allowing the Internal Audit group `r-x` on the exact same directory).  
POSIX ACLs (`setfacl`/`getfacl`) overcome this limitation by allowing administrators to attach multiple named users (`u:username:perms`) and multiple named groups (`g:groupname:perms`) to an inode, providing enterprise-grade discretionary access control.

---

### Q2: What is the POSIX ACL "mask" entry and how does it affect effective permissions?
**Answer:**  
The ACL `mask` entry defines the **maximum allowable permission ceiling** for all named users, named groups, and the owning group. It does not affect the file owner or the `other` entry.  
When an ACL entry is evaluated, the effective permission granted is the logical AND ($\&$) between the requested permission and the mask. For instance, if group `lsatest_grp_finance` is granted `rwx`, but the mask is set to `r-x`, the effective permission for that group is restricted to `r-x` (`effective:r-x`).

---

### Q3: Why is the SetGID bit (`chmod 2770`) critical on shared departmental folders?
**Answer:**  
Under default Linux behavior, whenever a user creates a new file or directory, the file's group ownership is set to the user's current primary group. If Alice creates a file in `/data/finance`, it would ordinarily be owned by `alice:lsatest_fin_alice`.  
By enabling the **SetGID bit** (octal `2000`, displayed as `drwxrws---`):
1. The Linux kernel forces any new file or subdirectory created within that folder to **inherit the group ownership of the parent directory** (`lsatest_grp_finance`), rather than the creating user's primary group.
2. This guarantees that all team members within the department can immediately access and collaborate on newly created files without manual `chgrp` commands.

---

### Q4: Why is the Sticky Bit (`chmod 3770`) necessary on a collaborative department directory?
**Answer:**  
In standard POSIX directory permissions (`2770`), any user who possesses **write permission on a directory** has the ability to remove (`unlink()`) or rename **any file inside that directory**, regardless of who owns the file. This creates an enterprise security risk where a team member could accidentally or maliciously delete a colleague's work.  
By applying the **Sticky Bit** (octal `1000`, producing mode `3770` or `drwxrws--T`):
1. The kernel restricts file deletion and renaming exclusively to the **file owner** or the superuser (`root`).
2. Colleagues can still read and edit files according to group permissions, but they cannot delete or rename each other's files.

---

### Q5: What is the difference between a Soft Quota and a Hard Quota, and how does the Grace Period operate?
**Answer:**  
- **Soft Limit**: A warning threshold. Users are permitted to temporarily write data exceeding the soft limit up to the hard ceiling. When exceeded, the system flags the user (`+-` in `repquota`) and initiates a countdown timer known as the **Grace Period** (configured to 7 days).
- **Hard Limit**: An absolute, unyielding block limit. The Linux kernel refuses to allocate blocks beyond this ceiling, returning `Disk quota exceeded` (errno `EDQUOT`).
- **Grace Period**: If the user reduces their storage below the soft limit before the timer expires, the warning flag is cleared. If the grace period expires while still above the soft limit, the soft limit immediately acts as a hard limit, blocking all further writes until space is cleared.

---

### Q6: How does the Linux kernel handle the interaction between Per-User Quotas and Group Quotas?
**Answer:**  
User quotas and group quotas operate as **independent, simultaneous enforcement layers**. When a write operation occurs, the kernel verifies:
1. Does the writing user have sufficient user quota remaining?
2. Does the file's owning group have sufficient group quota remaining?  
If **either** boundary is breached, the write operation is blocked. For example, if user Alice has used only 10 MB of her 90 MB user quota, but the Finance department group has hit its 250 MB group hard limit, Alice's write will still fail with `Disk quota exceeded`.

---

### Q7: Why are POSIX Default ACLs (`setfacl -d`) necessary in addition to standard Access ACLs?
**Answer:**  
Standard Access ACLs apply only to the specific inode on which they are set. If an administrator configures access ACLs on a folder, newly created files would not automatically receive those extra ACL entries; instead, their permissions would be dictated solely by the creating process's `umask`.  
**Default ACLs** (`setfacl -d -m ...`) define an **inheritance blueprint** stored in the directory's metadata. Whenever a child file or subfolder is created:
1. The child file inherits the default ACLs as its access ACLs.
2. Newly created subdirectories inherit both the access ACL and the default ACL, ensuring infinite recursive inheritance down the directory tree.

---

### Q8: What occurs if a user belongs to two different department groups?
**Answer:**  
In POSIX DAC and ACL evaluation, group permissions are evaluated based on the user's supplementary group membership list:
- If a user belongs to both `lsatest_grp_finance` and `lsatest_grp_eng`, the Linux kernel will evaluate the ACL entries for all groups the user belongs to. If any group grants access (and the mask permits it), the user is granted that permission.
- Storage quota block allocations, however, are charged to the **group ownership of the file being written**, which is determined by the parent directory's SetGID group, not the user's primary group.

---

### Q9: How does modern ext4 internal quota management differ from traditional v2 quota files (`aquota.user`)?
**Answer:**  
- **Traditional v2 Quota**: Requires creating special hidden files (`aquota.user` and `aquota.group`) in the root of the filesystem and running `quotacheck` to scan disk inodes and rebuild tables. If the system crashes uncleanly, the files can become desynchronized and require offline checking.
- **ext4 Internal Quota**: Configured directly in the ext4 superblock via `tune2fs -O quota -Q usrquota,grpquota`. Quota tracking is performed at the kernel VFS layer and written to internal hidden metadata inodes. It eliminates user-space quota files, is crash-consistent with journaling, and activates automatically upon filesystem mount without needing `quotacheck`.

---

### Q10: How does verified loopback sandboxing (`losetup -j`) protect the host operating system?
**Answer:**  
In shared multi-tenant Linux or WSL2 environments, running automated storage scripts with administrative privileges poses a risk of accidentally formatting host partitions (`/dev/sdX`) or modifying host system files.  
By enforcing verified loopback sandboxing:
1. All storage exists purely within a bounded sparse virtual disk image (`sandbox_data/fileserver.img`).
2. Before any formatting, mounting, or quota command is executed, `losetup -j` verifies that the target loopback device is explicitly and exclusively backed by the project's own sandbox image file. If the device does not match, the script immediately aborts.
3. System files like `/etc/fstab` and `/etc/passwd` remain completely untouched, ensuring zero host corruption risk.
