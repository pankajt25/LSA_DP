# NovaTech Solutions — Department File Server Infrastructure Architecture Plan
**Course:** Linux System Administration (E1ITA307)  
**Project:** Linux Infrastructure Deployment Project #3  
**Problem Statement:** Department File Server — Modules: III, IV | CO3, CO4  
**Author:** Infrastructure Engineering & Linux Administration Team  
**Organization:** NovaTech Solutions  

---

## 1. Executive Summary & Objective

NovaTech Solutions requires a centralized, secure, multi-departmental file server infrastructure supporting four distinct operational business units and an independent internal audit division:
1. **Finance (`finance/`)**: General ledgers, accounts payable/receivable, payroll registers, tax filings.
2. **Human Resources (`hr/`)**: Employee personnel records, compensation benchmarks, disciplinary dossiers.
3. **Engineering (`eng/`)**: Architectural design documents, system schematics, release manifests.
4. **Sales (`sales/`)**: Client pipeline proposals, contracts, revenue quota projections.
5. **Governance & Audit (`lsatest_grp_audit`)**: Independent internal audit committee requiring read-only visibility across all departmental assets without write, modify, or delete authorization.

The server architecture guarantees:
- **Intra-Department Collaboration**: Group members can seamlessly create, edit, and collaborate on shared department assets.
- **Strict Departmental Isolation**: Unauthorized cross-department traversal, listing, reading, and tampering are blocked at the filesystem kernel boundary.
- **POSIX Default & Access ACLs**: Access permissions and inheritance templates are enforced automatically for all future files and directories without manual administrator intervention.
- **Peer Deletion Protection**: Applying the directory sticky bit (`3770`) prevents departmental peers from deleting or unlinking colleagues' files while preserving collaborative write permissions.
- **Multi-Tiered Quota Allocations**: Granular per-user and per-group soft and hard quota boundaries backed by ext4 filesystem kernel quota accounting and a 7-day grace period.

---

## 2. Infrastructure Architecture Diagram

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

## 3. Storage Sizing & Quota Allocation Rationale

### 3.1 Allocation Matrix

| Department | Primary Group | Users Assigned | Shared Folder | Group Quota (Soft/Hard) | Per-User Quota (Soft/Hard) | Rationale |
|---|---|---|---|---|---|---|
| **Finance** | `lsatest_grp_finance` | `alice`, `bob` | `finance/` | 200 MB / 250 MB | 90 MB / 110 MB | Accommodates spreadsheets, PDF invoices, and general ledger databases. Two active users cannot exceed the 250 MB aggregate ceiling ($2 \times 110 = 220 \text{ MB} \le 250 \text{ MB}$). |
| **HR** | `lsatest_grp_hr` | `carol`, `dave` | `hr/` | 100 MB / 120 MB | 50 MB / 60 MB | Text documentation, compliance forms, and contracts have smaller storage footprints. $2 \times 60 = 120 \text{ MB}$ perfectly matches group ceiling. |
| **Engineering** | `lsatest_grp_eng` | `eve`, `frank` | `eng/` | 400 MB / 500 MB | 150 MB / 200 MB | High-volume binaries, source archives, schema blueprints, and container definitions require substantial overhead ($2 \times 200 = 400 \text{ MB} \le 500 \text{ MB}$ reserve). |
| **Sales** | `lsatest_grp_sales` | `grace`, `heidi` | `sales/` | 100 MB / 120 MB | 50 MB / 60 MB | Presentation decks, CRM prospect lists, and PDF contract archives. $2 \times 60 = 120 \text{ MB}$. |
| **Auditors** | `lsatest_grp_audit` | `ivan` | Global (Read-only) | N/A (Read-only) | N/A (Read-only) | Read-only governance role; consumes zero storage blocks. |

### 3.2 Volume Sizing Math
- Total Department Hard Allocations: $250 + 120 + 500 + 120 = 990 \text{ MB}$.
- Filesystem Overhead & Inode Tables: ext4 reserves $\sim 5\%$ metadata and block allocation structures ($\approx 100 \text{ MB}$).
- System Elasticity Reserve: $2048 \text{ MB} - (990 + 100) \text{ MB} \approx 958 \text{ MB}$ unallocated headroom for departmental volume expansion or emergency logs.

---

## 4. Permission Model & Security Governance

### 4.1 Mode 2770 vs 3770 (SetGID and Sticky Bit)
Standard Unix directory permissions use `chmod 2770`:
- **`2` (SetGID)**: Ensures that all files created within the directory inherit the directory's owning group (`lsatest_grp_<dept>`) rather than the user's primary group.
- **`770` (`rwxrwx---`)**: Grants the directory owner (`root`) and group members full read, write, and traverse permissions, while completely denying access to `others`.

**The Deletion Vulnerability in Pure Mode 2770**:
In POSIX filesystems, the ability to delete (`unlink()`) or rename a file is controlled by the **write permission on the parent directory**, NOT the file's own permissions. Consequently, under mode `2770`, any departmental peer could accidentally or maliciously delete a file owned by a colleague!

**The Enterprise Solution — Mode 3770**:
By combining **SetGID (`2000`)** and the **Sticky Bit (`1000`)** into octal mode `3770` (`chmod 3770`):
1. **SetGID (`2000`)**: Preserved group inheritance for all new files and directories.
2. **Sticky Bit (`1000`)**: Restricts file deletion and renaming strictly to the file's owner or `root`.
3. **Collaboration Allowed**: Peers can still collaborate, edit, and append to files if permissions permit, but cannot delete or hijack each other's work.

### 4.2 POSIX Default ACLs and the Effective Mask
POSIX Access Control Lists provide granular, multi-group access controls that supersede traditional Unix permissions:
- **Default ACL (`default:group:lsatest_grp_audit:r-x`)**: Automatically applies to all future children (files and subdirectories) upon creation.
- **Mask (`mask::rwx` or `mask::rw-`)**: Acts as a security ceiling. Even if a named group is granted `rwx`, if the mask is `r--`, the effective permission is clipped to `r--`. For directory collaboration, the mask is set to `rwx` on directories and `rw-` on files.

---

## 5. Quota Policies & Grace Periods

### 5.1 Soft vs Hard Limits
- **Soft Limit**: A quota threshold that a user or group may temporarily exceed. When exceeded, the filesystem warns the administrator/user, sets the warning flag (`+-` in `repquota`), and triggers the countdown timer.
- **Hard Limit**: An absolute, unyielding block ceiling. The Linux kernel immediately blocks any write attempt exceeding this limit (`dd: IO error: Disk quota exceeded`), terminating the process with an error code and capping file size.

### 5.2 Grace Period
- **Duration**: Configured to 7 days ($604,800$ seconds) for both block limits and inode limits.
- **Behavior**: If a user remains above the soft limit for longer than the grace period without freeing disk space, the soft limit transforms into a hard limit, immediately preventing further allocations until usage drops below the soft threshold.

---

## 6. Enterprise Share Export Configurations (Documentation Only)

Per project sandboxing guidelines, Samba and NFS services are not installed or active on the host. The following production-ready configurations illustrate how NovaTech Solutions would export these volumes in an enterprise deployment.

### 6.1 Samba Configuration (`/etc/samba/smb.conf`)

```ini
# /etc/samba/smb.conf — NovaTech Solutions Department File Server
[global]
    workgroup = NOVATECH
    server string = NovaTech Central File Server
    security = user
    passdb backend = tdbsam
    load printers = no
    printing = bsd
    printcap name = /dev/null
    map to guest = bad user
    vfs objects = acl_xattr
    map acl inherit = yes
    store dos attributes = yes

[finance]
    comment = NovaTech Finance Division Secure Share
    path = /mnt/data/fileserver/finance
    valid users = @lsatest_grp_finance, @lsatest_grp_audit
    read list = @lsatest_grp_audit
    write list = @lsatest_grp_finance
    browseable = yes
    read only = no
    create mask = 0660
    directory mask = 3770
    inherit permissions = yes
    inherit acls = yes

[hr]
    comment = NovaTech Human Resources Division
    path = /mnt/data/fileserver/hr
    valid users = @lsatest_grp_hr, @lsatest_grp_audit
    read list = @lsatest_grp_audit
    write list = @lsatest_grp_hr
    browseable = yes
    read only = no
    create mask = 0660
    directory mask = 3770
    inherit permissions = yes
    inherit acls = yes

[engineering]
    comment = NovaTech Engineering Architecture & Code Share
    path = /mnt/data/fileserver/eng
    valid users = @lsatest_grp_eng, @lsatest_grp_audit
    read list = @lsatest_grp_audit
    write list = @lsatest_grp_eng
    browseable = yes
    read only = no
    create mask = 0660
    directory mask = 3770
    inherit permissions = yes
    inherit acls = yes

[sales]
    comment = NovaTech Sales & Client Strategy Share
    path = /mnt/data/fileserver/sales
    valid users = @lsatest_grp_sales, @lsatest_grp_audit
    read list = @lsatest_grp_audit
    write list = @lsatest_grp_sales
    browseable = yes
    read only = no
    create mask = 0660
    directory mask = 3770
    inherit permissions = yes
    inherit acls = yes
```

### 6.2 NFSv4 Configuration (`/etc/exports`)

```text
# /etc/exports — NovaTech Solutions NFSv4 Secure Department Exports
/mnt/data/fileserver          192.168.10.0/24(rw,sync,no_subtree_check,fsid=0)
/mnt/data/fileserver/finance  192.168.10.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1016,anongid=1016)
/mnt/data/fileserver/hr       192.168.10.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1017,anongid=1017)
/mnt/data/fileserver/eng      192.168.10.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1018,anongid=1018)
/mnt/data/fileserver/sales    192.168.10.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1019,anongid=1019)
```

---

## 7. Operational Resilience & Disaster Recovery Validation

- **Idempotent Automation**: All setup scripts (`preflight.sh`, `setup_storage.sh`, `setup_identity.sh`, `setup_acl.sh`, `setup_quota.sh`) detect existing configurations and safely preserve active states without destructive reformatting.
- **Storage Persistence**: Validated using `sandbox_data/fstab.demo` and checked via `findmnt --verify --tab-file` ensuring reboot readiness.
- **Teardown Sanitization**: Dedicated `cleanup.sh` unmounts volumes, deactivates quotas, detaches verified loop devices, purges test identities, and leaves logs and audit reports intact.
