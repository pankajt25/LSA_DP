# Enterprise Storage Infrastructure — Complete Commands Used Reference
**Course:** Linux System Administration (E1ITA307) — Modules: III, IV | CO3, CO4  
**Project:** Problem Statement #1: Enterprise Storage Infrastructure  
**Organization:** NovaTech Solutions  

This document logs every command utilized across the design, deployment, verification, and teardown of the enterprise storage infrastructure. Each command includes its operational syntax, what it does, and why it is required for verification and technical review.

---

## Phase 1: Virtual Disks & Loopback Attachment

1. `truncate -s 10G sandbox_data/disks/disk1.img`
   - **What it does:** Creates a 10 GiB sparse virtual disk image file without allocating all disk blocks upfront.
   - **Why:** Simulates an independent physical storage drive inside the sandbox without consuming physical host disk capacity.

2. `truncate -s 15G sandbox_data/disks/disk2.img`
   - **What it does:** Creates a 15 GiB sparse virtual disk image file.
   - **Why:** Represents a second heterogeneously sized physical disk for LVM storage aggregation.

3. `truncate -s 20G sandbox_data/disks/disk3.img`
   - **What it does:** Creates a 20 GiB sparse virtual disk image file.
   - **Why:** Represents a third storage disk, bringing total pool capacity to 45 GiB.

4. `sudo losetup -P -f --show sandbox_data/disks/disk1.img`
   - **What it does:** Finds the next available loop device, enables partition scanning (`-P`), binds the image, and outputs device path.
   - **Why:** Maps the virtual file into a Linux block device interface.

5. `losetup -j sandbox_data/disks/disk1.img`
   - **What it does:** Queries the kernel loop subsystem to confirm which loop device is backed by `disk1.img`.
   - **Why:** Mandatory security verification ensuring subsequent operations target only the project's own verified virtual disk.

---

## Phase 2: GPT Partitioning with LVM Flag

6. `sudo parted -s /dev/loopX mklabel gpt mkpart primary ext4 1MiB 100% set 1 lvm on`
   - **What it does:** Initializes a GPT partition table, creates a primary partition spanning the device, and sets the LVM partition flag.
   - **Why:** Prepares the block device for LVM volume scanning according to Linux partitioning standards.

7. `sudo partprobe /dev/loopX`
   - **What it does:** Informs the operating system kernel of partition table changes without rebooting.
   - **Why:** Forces the kernel to scan and generate partition device nodes (e.g. `/dev/loopXp1`).

---

## Phase 3: LVM Physical Volumes, Volume Group & Logical Volumes

8. `sudo pvcreate -f /dev/loopXp1`
   - **What it does:** Writes LVM metadata to the partition, initializing it as an LVM Physical Volume (PV).
   - **Why:** Enables the block device to participate in an LVM volume group.

9. `sudo vgcreate -f company_vg /dev/loop1p1 /dev/loop2p1 /dev/loop3p1`
   - **What it does:** Pools the 3 physical volumes into a single 45 GiB Volume Group named `company_vg`.
   - **Why:** Establishes the centralized elastic storage pool for departmental allocations.

10. `sudo lvcreate -L 5G -n lv_hr company_vg`
    - **What it does:** Allocates 5 GiB of storage extents from `company_vg` to create the HR logical volume.
    - **Why:** Provisions dedicated block storage boundary for Human Resources records.

11. `sudo lvcreate -L 8G -n lv_finance company_vg`
    - **What it does:** Allocates 8 GiB from `company_vg` for the Finance logical volume.
    - **Why:** Provisions dedicated storage boundary for accounting and ledger records.

12. `sudo lvcreate -L 15G -n lv_eng company_vg`
    - **What it does:** Allocates an initial 15 GiB from `company_vg` for the Engineering logical volume.
    - **Why:** Provisions baseline high-performance storage for technical blueprints and code repositories.

13. `sudo lvcreate -L 5G -n lv_sales company_vg`
    - **What it does:** Allocates 5 GiB from `company_vg` for the Sales logical volume.
    - **Why:** Provisions dedicated storage boundary for customer pipelines and contracts.

14. `sudo vgs company_vg`
    - **What it does:** Displays Volume Group capacity, allocated extents, and unallocated free reserve space.
    - **Why:** Confirms that 38 GiB is allocated and ~7 GiB remains reserved for elasticity.

15. `sudo lvs company_vg`
    - **What it does:** Lists attributes, sizes, and allocation details for all Logical Volumes in `company_vg`.
    - **Why:** Serves as verification evidence confirming LV creation.

---

## Phase 4: Filesystems, Mounts & Persistence Validation

16. `sudo mkfs.ext4 -F -L hr_data /dev/company_vg/lv_hr`
    - **What it does:** Builds an ext4 filesystem labeled `hr_data` on the HR logical volume.
    - **Why:** Provides a stable, journaled POSIX filesystem for departmental documents.

17. `sudo mkfs.ext4 -F -L fin_data /dev/company_vg/lv_finance`
    - **What it does:** Builds an ext4 filesystem labeled `fin_data` on the Finance logical volume.
    - **Why:** Prepares accounting volume with journalling integrity.

18. `sudo mkfs.xfs -f -L eng_data /dev/company_vg/lv_eng`
    - **What it does:** Formats the Engineering volume with high-performance 64-bit XFS filesystem.
    - **Why:** Optimized for high parallel I/O, multi-threaded metadata access, and online expansion.

19. `sudo mkfs.ext4 -F -L sales_data /dev/company_vg/lv_sales`
    - **What it does:** Builds an ext4 filesystem labeled `sales_data` on the Sales logical volume.
    - **Why:** Provides standard POSIX filesystem for sales teams.

20. `mkdir -p sandbox_data/mnt/{hr,finance,eng,sales}`
    - **What it does:** Creates sandbox directory mount points.
    - **Why:** Establishes isolated directory hierarchy inside the project sandbox.

21. `sudo mount /dev/company_vg/lv_hr sandbox_data/mnt/hr`
    - **What it does:** Attaches the HR logical volume filesystem to the sandbox mount directory.
    - **Why:** Makes the volume accessible in the Linux VFS directory tree.

22. `sudo mount /dev/company_vg/lv_finance sandbox_data/mnt/finance`
    - **What it does:** Mounts the Finance logical volume.
    - **Why:** Enables active filesystem access for Finance team.

23. `sudo mount /dev/company_vg/lv_eng sandbox_data/mnt/eng`
    - **What it does:** Mounts the Engineering XFS logical volume.
    - **Why:** Enables active filesystem access for Engineering team.

24. `sudo mount /dev/company_vg/lv_sales sandbox_data/mnt/sales`
    - **What it does:** Mounts the Sales logical volume.
    - **Why:** Enables active filesystem access for Sales team.

25. `df -h sandbox_data/mnt/hr sandbox_data/mnt/finance sandbox_data/mnt/eng sandbox_data/mnt/sales`
    - **What it does:** Queries filesystem usage, capacity, and mount associations.
    - **Why:** Provides verification evidence that all four volumes are actively mounted.

26. `sudo blkid -s UUID -o value /dev/company_vg/lv_hr`
    - **What it does:** Extracts unique cryptographic filesystem UUID for `lv_hr`.
    - **Why:** Enables persistent block device referencing independent of device node naming.

27. `findmnt --verify --tab-file sandbox_data/fstab.demo`
    - **What it does:** Audits the syntax, UUIDs, filesystem types, and mount options of `fstab.demo`.
    - **Why:** Proves persistence readiness safely without modifying the host `/etc/fstab`.

---

## Phase 5: RBAC Security, SetGID & POSIX ACLs

28. `sudo groupadd lsatest_hr_team`
    - **What it does:** Provisions dedicated Linux system group for HR personnel.
    - **Why:** Enforces Role-Based Access Control (RBAC) boundaries.

29. `sudo useradd -r -s /usr/sbin/nologin -g lsatest_hr_team lsatest_alice_hr`
    - **What it does:** Creates system user `lsatest_alice_hr` assigned primarily to `lsatest_hr_team`.
    - **Why:** Principle of Least Privilege: test user for access validation.

30. `sudo chown root:lsatest_hr_team sandbox_data/mnt/hr`
    - **What it does:** Sets root owner and `lsatest_hr_team` group ownership on HR share.
    - **Why:** Restricts primary group authorization to HR personnel.

31. `sudo chmod 2770 sandbox_data/mnt/hr`
    - **What it does:** Sets permissions `rwxrws---` with SetGID bit (`2`) active.
    - **Why:** Forces all newly created files in this directory to automatically inherit `lsatest_hr_team` group ownership.

32. `sudo setfacl -R -d -m g::rwx sandbox_data/mnt/hr`
    - **What it does:** Configures POSIX default Access Control List for group members.
    - **Why:** Ensures inherited read, write, and execute permissions on newly generated subfiles.

---

## Phase 6: Live Online Elasticity Demonstration

33. `sudo lvextend -L 20G /dev/company_vg/lv_eng`
    - **What it does:** Dynamically expands Engineering LV capacity from 15 GiB to 20 GiB (+5 GiB).
    - **Why:** Proves online volume scalability without service interruption.

34. `sudo xfs_growfs sandbox_data/mnt/eng`
    - **What it does:** Instructs the mounted XFS filesystem driver to grow online to fill the expanded LV.
    - **Why:** Completes zero-downtime live filesystem expansion without unmounting.

---

## Phase 7: Multi-Departmental Backup Suite

35. `sudo tar -czf sandbox_data/backup/hr_backup_TS.tar.gz -C sandbox_data/mnt/hr .`
    - **What it does:** Archives and compresses HR directory content into a timestamped tar.gz file.
    - **Why:** Creates full point-in-time departmental backup.

36. `cd sandbox_data/backup && sha256sum hr_backup_TS.tar.gz > hr_backup_TS.tar.gz.sha256`
    - **What it does:** Computes SHA-256 cryptographic checksum and saves companion manifest.
    - **Why:** Ensures cryptographic tamper evidence and verifies archive integrity.

37. `sha256sum -c hr_backup_TS.tar.gz.sha256`
    - **What it does:** Checks archive hash against recorded manifest.
    - **Why:** Immediate post-backup integrity validation.

38. `tar -tzf sandbox_data/backup/hr_backup_TS.tar.gz`
    - **What it does:** Decompresses gzip stream and reads archive header records without extracting.
    - **Why:** Proves archive readability and gzip stream validity.

39. `bash scripts/verify_backup.sh`
    - **What it does:** Automated integrity auditor verifying all departmental backup archives.
    - **Why:** Validates complete departmental backup inventory with `[OK]` status.

---

## Phase 8: Master Orchestration & Teardown

40. `bash run.sh`
    - **What it does:** Master end-to-end runner that executes storage setup, elasticity demo, backups, validation suite, and HTML report generation.
    - **Why:** Single-command cross-platform deployment verification.

41. `explorer.exe "$(wslpath -w report.html)"`
    - **What it does:** Translates WSL Linux path to Windows path and opens `report.html` in default host browser.
    - **Why:** Seamless graphical presentation on Windows host.

42. `bash cleanup.sh`
    - **What it does:** Separate teardown script unmounting filesystems, deleting LVs/VGs/PVs, detaching loop devices, and purging test accounts.
    - **Why:** Restores system to pristine baseline without touching logs or reports.
