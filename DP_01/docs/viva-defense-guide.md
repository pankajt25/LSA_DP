# NovaTech Solutions — Project Defense & Viva Voce Guide
**Course:** Linux System Administration (E1ITA307)  
**Project:** Linux Infrastructure Deployment Project  
**Problem Statement #1:** Enterprise Storage Infrastructure  
**Author:** Infrastructure Engineering & DevOps Team  

---

## 1. Technical Viva Voce Questions & Answers

### Q1: Why did you use LVM instead of standard GPT/MBR disk partitions?
**Answer:**
Standard partitions have rigid boundaries tied to physical disk sectors. Resizing requires adjacent unallocated space, often necessitating unmounting and causing service downtime. 
LVM2 abstracts physical storage into three layers:
1. **Physical Volumes (PVs):** Slices block devices into 4 MB Physical Extents (PE).
2. **Volume Group (VG):** Pools heterogeneous disks (`10G + 15G + 20G = 45G`) into a unified storage pool (`company_vg`).
3. **Logical Volumes (LVs):** Dynamically allocated virtual partitions.
This allows **online live expansion with zero downtime**, multi-disk aggregation, and point-in-time snapshotting.

---

### Q2: Why did you choose `xfs` for Engineering and `ext4` for the other departments?
**Answer:**
- **Engineering (`xfs`):** Engineering workloads deal with continuous integration, large repositories, compiler caches, and high I/O concurrency. XFS utilizes **Allocation Groups (AGs)**, B+ trees for inode and space tracking, and 64-bit scalability. It supports instant online resizing using `xfs_growfs`.
- **HR, Finance, Sales (`ext4`):** Stable, mature journaling filesystem with minimal metadata overhead, ideal for standard office documents, spreadsheets, and routine auditing.

---

### Q3: What is the difference between `lvextend -L +5G` and `xfs_growfs`?
**Answer:**
- `lvextend` operates at the **block device layer (LVM)**, increasing the logical volume boundary from 15 GiB to 20 GiB (allocating 1,280 additional 4MB PEs).
- `xfs_growfs` operates at the **filesystem layer**, expanding the filesystem structures to occupy the newly available blocks on the block device while the filesystem remains mounted and serving active traffic.
*(For ext4, `resize2fs` would be used instead).*

---

### Q4: How does SetGID (`chmod 2770`) ensure departmental security and collaboration?
**Answer:**
Under standard POSIX semantics, when a user creates a new file, it inherits the user's primary group. If Alice creates a file in `/data/hr`, it would normally be owned by `alice:alice`.
By setting the **SetGID bit** (`chmod 2770`, where `2` is the SetGID octal):
1. Any file or directory created within `/data/hr` automatically inherits the parent directory's group (`hr-team`).
2. The `770` mode ensures read/write/execute permissions for owner (`root`) and group (`hr-team`), while others have `0` (denying any access to non-group members).

---

### Q5: Why are POSIX Default ACLs necessary if you already used SetGID?
**Answer:**
SetGID only controls **group ownership**, not necessarily permissions on newly created files. If a user has a restrictive `umask` (e.g., `0077`), newly created files would have permissions `-rw-------` (denying group members read/write access).
Setting **Default ACLs** (`setfacl -d -m g::rwx,o::--- /data/<dept>`):
- Enforces an inherited access control template for all newly created subdirectories and files.
- Guarantees group members always receive `rwx` (or `rw-` for files) and foreign users always have `---`.

---

### Q6: How do virtual disk loop devices persist across system reboots?
**Answer:**
Loop block devices (`/dev/loop1`, `loop2`, `loop3`) are dynamic kernel objects that detach on shutdown. If `/etc/fstab` attempts to mount LVs before loop devices are bound, boot hangs or drops to emergency mode.
To solve this:
1. Implemented a custom systemd oneshot unit `/etc/systemd/system/attach-virtual-disks.service`.
2. Configured with `Before=lvm2-activation.service lvm2-pvscan@.service`.
3. The unit attaches the images via `losetup -P`, triggers `partprobe`, activates the VG via `vgchange -ay`, and executes `mount -a` prior to user login targets.

---

### Q7: Why do we use UUIDs instead of `/dev/company_vg/lv_*` in `/etc/fstab`?
**Answer:**
UUIDs (Universally Unique Identifiers) are stored directly inside the filesystem superblock. They provide immutable referencing that is persistent even if device names change or device mapper nodes are initialized in a different enumeration sequence at boot.

---

### Q8: What troubleshooting challenges did you encounter and resolve?
**Answer:**
1. **XFS Mount Failure with `acl` Option:** Modern Linux kernels (Linux 6.x) enable ACLs in XFS natively and remove `acl` as an explicit mount flag. Specifying `acl` in `/etc/fstab` caused `mount -a` to fail with error 64 (`Unknown parameter 'acl'`). Fixed by setting `defaults` for XFS in `/etc/fstab`.
2. **Bash Strict Mode (`set -e`) Termination on Arithmetic Expansion:** The increment `((success_count++))` evaluated to 0 on initial count, returning exit code 1 which triggered `set -e` script termination. Fixed by refactoring to `success_count=$((success_count + 1))`.

---

## 2. Live Demonstration Cheat Sheet

When demonstrating the deployment, run these commands in order:

```bash
# 1. Show overall storage pool & live elasticity
sudo vgs
sudo lvs company_vg
df -hT /data/*

# 2. Demonstrate security isolation between departments
sudo -u alice_hr cat /data/finance/q3_budget.txt
# -> Expected: Permission denied

sudo -u evan_eng cat /data/eng/architecture_spec.txt
# -> Expected: Success

# 3. Demonstrate automated backup and checksum verification
sudo /usr/local/bin/backup_departments.sh
sudo /usr/local/bin/verify_backup.sh

# 4. Run automated test suite
bash scripts/run_all_validation_tests.sh
```
