# Linux Disaster Recovery Solution — Complete Commands Used Reference
**Course:** Linux System Administration (E1ITA307) — Modules: IV | CO4  
**Project:** Problem Statement #4: Linux Disaster Recovery Solution  
**Organization:** NovaTech Solutions Infrastructure Group  

This document provides a complete sequential log of every terminal and administrative command executed across the deployment, snapshot lifecycle management, disaster simulations, recovery verification, and cleanup phases.

---

## Phase 0: System & Kernel Preflight Validation

1. `uname -r`
   - **What it does:** Displays the active Linux kernel release version.
   - **Why:** Verifies kernel compatibility with Device Mapper snapshot modules.

2. `grep PRETTY_NAME /etc/os-release`
   - **What it does:** Extracts the human-readable operating system distribution name and version.
   - **Why:** Confirms running OS environment for reporting and script execution.

3. `sudo -v`
   - **What it does:** Validates and refreshes administrative sudo credentials in memory.
   - **Why:** Prevents interactive password prompts during non-interactive orchestrator execution.

4. `dpkg -s lvm2`
   - **What it does:** Inspects the package management database to determine if `lvm2` is installed.
   - **Why:** Guarantees LVM user-space utilities (`lvcreate`, `vgcreate`, `lvs`) are available.

5. `sudo losetup -f`
   - **What it does:** Queries the kernel for the first free loop device node path.
   - **Why:** Confirms loopback block device functionality without modifying system state.

6. `sudo modprobe dm-snapshot`
   - **What it does:** Loads the Device Mapper snapshot kernel module (`dm_snapshot.ko`).
   - **Why:** Activates the kernel target required for LVM copy-on-write snapshot allocation.

7. `sudo dmsetup targets`
   - **What it does:** Lists all active device-mapper target drivers supported by the running kernel.
   - **Why:** Formally proves that `snapshot`, `snapshot-origin`, and `snapshot-merge` targets are active.

8. `lsmod | grep dm_`
   - **What it does:** Filters loaded kernel modules for device mapper drivers.
   - **Why:** Provides kernel-level verification that `dm_snapshot` is active in kernel space.

---

## Phase 1: Lab Storage Provisioning & Data Seeding

9. `truncate -s 600M sandbox_data/disk1.img`
   - **What it does:** Allocates a 600 MB sparse virtual disk image file.
   - **Why:** Simulates the first physical drive in the storage sandbox without consuming upfront disk space.

10. `truncate -s 600M sandbox_data/disk2.img`
    - **What it does:** Allocates a second 600 MB sparse virtual disk image file.
    - **Why:** Simulates the second physical drive for Volume Group storage pooling.

11. `sudo losetup -f --show sandbox_data/disk1.img`
    - **What it does:** Attaches `disk1.img` to the next free loop device and returns the device node (e.g. `/dev/loop0`).
    - **Why:** Exposes the virtual file as a block device interface.

12. `sudo losetup -f --show sandbox_data/disk2.img`
    - **What it does:** Attaches `disk2.img` to the next free loop device (e.g. `/dev/loop1`).
    - **Why:** Exposes the second virtual drive to the block subsystem.

13. `sudo losetup -j sandbox_data/disk1.img`
    - **What it does:** Queries the kernel to verify which loop device is bound to `disk1.img`.
    - **Why:** Mandatory sandboxing security check confirming the loop device belongs strictly to this project.

14. `sudo losetup -j sandbox_data/disk2.img`
    - **What it does:** Verifies loop device binding for `disk2.img`.
    - **Why:** Ensures safety guard compliance before physical volume initialization.

15. `sudo pvcreate -f /dev/loop0`
    - **What it does:** Formats `/dev/loop0` with LVM Physical Volume metadata.
    - **Why:** Prepares the first block device for inclusion in an LVM volume group.

16. `sudo pvcreate -f /dev/loop1`
    - **What it does:** Formats `/dev/loop1` with LVM Physical Volume metadata.
    - **Why:** Prepares the second block device for inclusion in an LVM volume group.

17. `sudo vgcreate lsatest_dr_vg /dev/loop0 /dev/loop1`
    - **What it does:** Aggregates `/dev/loop0` and `/dev/loop1` into Volume Group `lsatest_dr_vg` (~1.16 GiB total capacity).
    - **Why:** Establishes the elastic block storage pool for the origin volume and snapshots.

18. `sudo lvcreate -L 500M -n lsatest_data_lv lsatest_dr_vg`
    - **What it does:** Carves a 500 MB Logical Volume named `lsatest_data_lv` from the volume group.
    - **Why:** Allocates the protected origin volume while leaving ~692 MB of free extents for snapshots.

19. `sudo mkfs.ext4 -F -L DR_ORIGIN /dev/lsatest_dr_vg/lsatest_data_lv`
    - **What it does:** Formats the origin logical volume with an ext4 filesystem labeled `DR_ORIGIN`.
    - **Why:** Initializes block filesystem structures and inode tables.

20. `sudo mount /dev/lsatest_dr_vg/lsatest_data_lv sandbox_data/mnt/data`
    - **What it does:** Mounts the origin filesystem at the sandbox data directory.
    - **Why:** Provides filesystem access for application data seeding and daily I/O.

21. `sudo chown -R $(id -u):$(id -g) sandbox_data/mnt/data`
    - **What it does:** Grants read/write ownership of the mounted filesystem to the current non-root user.
    - **Why:** Allows deterministic dataset generation without requiring elevated root permissions for individual file writes.

22. `sudo blkid -s UUID -o value /dev/lsatest_dr_vg/lsatest_data_lv`
    - **What it does:** Retrieves the unique filesystem UUID of the origin volume.
    - **Why:** Used to construct persistent mount entries in `sandbox_data/fstab.demo`.

23. `findmnt --verify --tab-file sandbox_data/fstab.demo`
    - **What it does:** Verifies syntax, UUID validity, and options of the demo fstab file.
    - **Why:** Proves persistence readiness without risking host `/etc/fstab` integrity.

24. `sha256sum <file>`
    - **What it does:** Computes the cryptographic SHA-256 digest of each protected file.
    - **Why:** Establishes the baseline cryptographic manifest (`sandbox_data/baseline.manifest`).

---

## Phase 2: Snapshot Management & Retention

25. `sync`
    - **What it does:** Flushes dirty filesystem buffers from RAM cache to block storage.
    - **Why:** Guarantees point-in-time filesystem consistency prior to taking an LVM snapshot.

26. `sudo lvcreate -s -n lsatest_snap_<TS> -L 100M lsatest_dr_vg/lsatest_data_lv`
    - **What it does:** Creates a copy-on-write snapshot of `lsatest_data_lv` with 100 MB of exception storage.
    - **Why:** Captures a frozen point-in-time block state of the origin volume.

27. `sudo lvs -o lv_name,origin,lv_size,data_percent,lv_attr,lv_time lsatest_dr_vg`
    - **What it does:** Displays snapshot names, parent origin, allocated size, percentage of CoW table used, attributes, and creation timestamp.
    - **Why:** Provides live operational metrics for snapshot inventory and health tracking.

28. `sudo lvs --sort +lv_time -o lv_name,origin,lv_time lsatest_dr_vg`
    - **What it does:** Lists snapshots ordered by creation time ascending (oldest first).
    - **Why:** Identifies expired snapshots exceeding the retention policy threshold (e.g., keeping newest 3).

29. `sudo lvremove -y /dev/lsatest_dr_vg/<snapshot>`
    - **What it does:** Removes an expired or unneeded snapshot volume by exact name.
    - **Why:** Reclaims Physical Extents in the Volume Group for future snapshots.

---

## Phase 3: Recovery Scenarios (S1 through S5)

### Scenario 1 (S1): Accidental File Deletion
30. `rm -f sandbox_data/mnt/data/<target_files>`
    - **What it does:** Simulates user error by deleting critical department files.
    - **Why:** Triggers the accidental file loss scenario.

31. `sudo mount -o ro /dev/lsatest_dr_vg/lsatest_snap_s1 sandbox_data/mnt/snap`
    - **What it does:** Mounts the snapshot read-only at the snapshot mount point.
    - **Why:** Allows granular file-level access to the frozen pre-disaster filesystem state.

32. `cp -a sandbox_data/mnt/snap/<file> sandbox_data/mnt/data/<file>`
    - **What it does:** Restores deleted files while preserving ownership, modes, and timestamps (`-a`).
    - **Why:** Accomplishes selective granular file recovery without requiring origin volume downtime.

33. `sudo umount sandbox_data/mnt/snap`
    - **What it does:** Unmounts the snapshot filesystem.
    - **Why:** Releases the device node so the snapshot can be managed or removed.

### Scenario 2 (S2): Accidental Overwrite / Corruption
34. `dd if=/dev/urandom of=sandbox_data/mnt/data/finance/quarterly_forecast_2.dat bs=1k count=24 conv=notrunc`
    - **What it does:** Overwrites the middle of a critical finance file with random noise.
    - **Why:** Injects bounded bit corruption to simulate accidental overwrite or malware corruption.

35. `cp -a sandbox_data/mnt/snap/finance/quarterly_forecast_2.dat sandbox_data/mnt/data/finance/quarterly_forecast_2.dat`
    - **What it does:** Copies the pristine original file blocks back from the read-only snapshot.
    - **Why:** Restores single-file integrity with 100% cryptographic parity against baseline.

### Scenario 3 (S3): Catastrophic Directory Loss with Full Rollback
36. `rm -rf sandbox_data/mnt/data/engineering sandbox_data/mnt/data/sales`
    - **What it does:** Recursively wipes two complete department directory trees.
    - **Why:** Simulates massive data loss requiring full volume rollback rather than individual file restores.

37. `sudo umount sandbox_data/mnt/data`
    - **What it does:** Unmounts the origin filesystem.
    - **Why:** Mandatory requirement before merging; merging a live mounted filesystem causes metadata collisions and kernel panics.

38. `sudo lvconvert --merge /dev/lsatest_dr_vg/lsatest_snap_s3`
    - **What it does:** Merges the snapshot exception blocks back into the origin logical volume, consuming the snapshot.
    - **Why:** Executes atomic, block-level rollback to the snapshot instant in seconds.

39. `sudo lvchange -ay /dev/lsatest_dr_vg/lsatest_data_lv`
    - **What it does:** Reactivates the merged logical volume in the kernel device-mapper table.
    - **Why:** Ensures block table consistency following offline merge completion.

40. `sudo mount /dev/lsatest_dr_vg/lsatest_data_lv sandbox_data/mnt/data`
    - **What it does:** Re-attaches the restored origin filesystem to its production mount point.
    - **Why:** Returns the restored volume to active service.

### Scenario 4 (S4): Snapshot Capacity Exhaustion & Dynamic Prevention
41. `sudo lvcreate -s -n lsatest_snap_overflow -L 16M lsatest_dr_vg/lsatest_data_lv`
    - **What it does:** Provisions a deliberately undersized 16 MB snapshot.
    - **Why:** Prepares the testbed for capacity overflow demonstration.

42. `dd if=/dev/urandom of=sandbox_data/mnt/data/temp_overflow_churn.bin bs=1M count=25`
    - **What it does:** Writes 25 MB of new data to the origin volume, exceeding the 16 MB CoW table capacity.
    - **Why:** Forces snapshot exhaustion to demonstrate device-mapper failure behavior.

43. `sudo lvs -o lv_name,lv_size,data_percent,lv_attr lsatest_dr_vg/lsatest_snap_overflow`
    - **What it does:** Inspects snapshot attributes and Data% post-churn.
    - **Why:** Proves that Data% reached 100% and attribute flag transitioned to `I` (Invalid).

44. `sudo lvextend -L +40M /dev/lsatest_dr_vg/lsatest_snap_monitored`
    - **What it does:** Dynamically increases the snapshot's allocated exception storage by 40 MB online.
    - **Why:** Demonstrates proactive prevention of snapshot overflow without unmounting or pausing I/O.

### Scenario 5 (S5): Loss Beyond Snapshots (Why Snapshots != Backups)
45. `tar -czf sandbox_data/archive_store/data_<TS>.tar.gz -C sandbox_data/mnt/snap .`
    - **What it does:** Creates a compressed tarball archive of the snapshot while the origin volume stays online.
    - **Why:** Captures a point-in-time external backup independent of the LVM Volume Group.

46. `sha256sum data_<TS>.tar.gz > data_<TS>.tar.gz.sha256`
    - **What it does:** Generates a cryptographic digest file for the archive.
    - **Why:** Guarantees cryptographic immutability and corruption detection for external backups.

47. `sudo lvremove -y /dev/lsatest_dr_vg/lsatest_data_lv`
    - **What it does:** Removes the origin Logical Volume.
    - **Why:** Proves that deleting the origin volume instantly destroys all dependent snapshots.

48. `tar -xzf sandbox_data/archive_store/data_<TS>.tar.gz -C sandbox_data/mnt/data`
    - **What it does:** Extracts the verified external archive onto a newly recreated volume.
    - **Why:** Demonstrates complete disaster recovery from bare-metal when all snapshots have perished.

---

## Phase 4: Validation & Teardown

49. `explorer.exe "$(wslpath -w report.html)"`
    - **What it does:** Translates WSL Linux paths to Windows format and opens `report.html` in the host browser.
    - **Why:** Provides instant interactive technical review of the live audit report.

50. `sudo vgremove -y lsatest_dr_vg`
    - **What it does:** Deletes the sandboxed Volume Group `lsatest_dr_vg`.
    - **Why:** Teardown of LVM storage pool.

51. `sudo pvremove -y /dev/loop0 /dev/loop1`
    - **What it does:** Clears LVM metadata from loop block devices.
    - **Why:** Unregisters physical volumes.

52. `sudo losetup -d /dev/loop0 /dev/loop1`
    - **What it does:** Detaches loop block devices from the kernel.
    - **Why:** Restores system block device state to original clean condition.
