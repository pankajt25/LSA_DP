# Centralized Backup & Recovery Server — Complete Commands Used Reference
**Course:** Linux System Administration (E1ITA307) — Modules: IV | CO4  
**Project:** Problem Statement #2: Centralized Backup & Recovery Server  
**Organization:** NovaTech Solutions  

This document logs every command utilized across the design, deployment, verification, and teardown of the backup server infrastructure. Each command includes its operational syntax, what it does, and why it is required for system verification and technical review.

---

## Phase 0: Storage Infrastructure & Volume Setup

1. `truncate -s 1G sandbox_data/backup_disk.img`
   - **What it does:** Creates a 1 GiB sparse image file on the filesystem without allocating all disk blocks upfront.
   - **Why:** Simulates an isolated physical storage block device inside the sandbox without touching host disks.

2. `sudo losetup -f --show sandbox_data/backup_disk.img`
   - **What it does:** Discovers the next free loopback block device (e.g. `/dev/loop0`), attaches the sparse image, and outputs the assigned device name.
   - **Why:** Exposes a raw block device interface for filesystem creation.

3. `losetup -j sandbox_data/backup_disk.img`
   - **What it does:** Queries all active loop devices to verify which block device is backed by this specific image file.
   - **Why:** Mandatory security verification ensuring subsequent format and mount commands only target the project's own verified virtual disk.

4. `sudo pvcreate -f /dev/loop0`
   - **What it does:** Initializes the verified loopback block device as an LVM Physical Volume (PV).
   - **Why:** Demonstrates physical volume provisioning for the LVM storage implementation.

5. `sudo vgcreate -f backup_vg /dev/loop0`
   - **What it does:** Aggregates the physical volume into an LVM Volume Group named `backup_vg`.
   - **Why:** Enables storage virtualization and flexible logical volume pooling.

6. `sudo lvcreate -L 500M -n backup_lv backup_vg`
   - **What it does:** Carves out an initial 500 MiB Logical Volume named `backup_lv` from `backup_vg`.
   - **Why:** Allocates virtual partition boundaries for elastic filesystem creation.

7. `sudo mkfs.ext4 -F /dev/backup_vg/backup_lv`
   - **What it does:** Builds a 4th Extended Filesystem (ext4) on the logical volume with journalling enabled.
   - **Why:** Prepares the volume for POSIX filesystem storage.

8. `sudo lvextend -L +300M /dev/backup_vg/backup_lv`
   - **What it does:** Dynamically expands the logical volume by 300 MiB (from 500M to 800M) while mounted.
   - **Why:** Proves online LVM volume elasticity without service interruption.

9. `sudo resize2fs /dev/backup_vg/backup_lv`
   - **What it does:** Grows the ext4 filesystem to utilize the newly expanded block capacity of the underlying LV.
   - **Why:** Completes the live online storage expansion demonstration.

10. `sudo mkfs.ext4 -F -L "NOVA_BACKUP" /dev/loop0`
    - **What it does:** Formats the verified loop device directly with an ext4 filesystem labeled `NOVA_BACKUP`.
    - **Why:** Provisions the dedicated production storage volume for the backup repository.

11. `sudo mount /dev/loop0 sandbox_data/repo_mount/`
    - **What it does:** Mounts the verified loop block device onto the sandbox mount point directory.
    - **Why:** Makes the dedicated backup volume accessible in the Linux VFS directory tree.

12. `sudo chown -R $(id -u):$(id -g) sandbox_data/repo_mount/`
    - **What it does:** Transfers ownership of the mounted filesystem root to the active non-root user.
    - **Why:** Allows automated backup processes to create repositories without persistent root elevation.

13. `lsblk /dev/loop0`
    - **What it does:** Displays block device hierarchy, major:minor numbers, size, and mount points.
    - **Why:** Serves as verification evidence confirming loop device allocation.

14. `df -h sandbox_data/repo_mount/`
    - **What it does:** Displays filesystem capacity, used space, available space, and percentage utilization.
    - **Why:** Validates dedicated volume capacity and mount attachment.

15. `sudo blkid /dev/loop0`
    - **What it does:** Queries block device UUID, filesystem TYPE, and filesystem LABEL.
    - **Why:** Provides cryptographic UUID evidence for storage verification.

---

## Phase 1: Protected Dataset Management

16. `bash scripts/seed_data.sh`
    - **What it does:** Populates `sandbox_data/source/{finance,hr,engineering,sales}/` with 49 departmental files (CSV, JSON, SQL, logs, binaries).
    - **Why:** Generates an enterprise dataset safely isolated inside the sandbox for backup protection.

17. `bash scripts/mutate_data.sh 1`
    - **What it does:** Adds 2 files, modifies 2 existing files, and deletes 1 file in `sandbox_data/source/`.
    - **Why:** Simulates real operational business transactions so Incremental Backup 1 captures real changes.

18. `bash scripts/mutate_data.sh 2`
    - **What it does:** Applies a second wave of changes (2 additions, 2 modifications, 1 deletion) to `sandbox_data/source/`.
    - **Why:** Simulates progressive daily drift for Incremental Backup 2 verification.

---

## Phase 2: Backup Suite & Retention Enforcement

19. `tar --listed-incremental=active.snar -czf repo/full_TS.tar.gz -C source/ .`
    - **What it does:** Executes a Level 0 full backup using GNU tar listed-incremental, creating a baseline archive and initializing `active.snar`.
    - **Why:** Captures entire filesystem state and indexes inode metadata for future incremental diffing.

20. `cd repo && sha256sum full_TS.tar.gz > full_TS.tar.gz.sha256`
    - **What it does:** Computes the SHA-256 cryptographic hash of the archive and stores it in a companion manifest.
    - **Why:** Provides tamper-evidence and cryptographic verification before any future restoration.

21. `sha256sum -c full_TS.tar.gz.sha256`
    - **What it does:** Validates that the archive hash matches the recorded manifest.
    - **Why:** Immediate post-backup integrity validation ensuring archive was written without storage corruption.

22. `tar -tzf repo/full_TS.tar.gz`
    - **What it does:** Decompresses gzip stream and tests tar header structures without extracting files.
    - **Why:** Verifies structural readability of archive tables of contents.

23. `chmod 600 repo/full_TS.tar.gz repo/full_TS.tar.gz.sha256`
    - **What it does:** Restricts archive file permissions to owner read/write only.
    - **Why:** Prevents unauthorized viewing or modification of protected department records.

24. `bash scripts/backup_incremental.sh`
    - **What it does:** Inspects `active.snar`, archives only files modified/added since last backup, records deletions, and updates `active.snar`.
    - **Why:** Performs lightweight, rapid delta backups conserving storage bandwidth.

25. `bash scripts/verify_backup.sh`
    - **What it does:** Audits all full and incremental archives in the repository for SHA-256 checksum and tar integrity.
    - **Why:** Guarantees archive authenticity and health across the backup repository inventory.

26. `bash scripts/retention.sh --dry-run`
    - **What it does:** Analyzes repository archive history, identifies the 2 most recent full backups, and lists older fulls and incrementals marked for purging without deleting anything.
    - **Why:** Verifies retention boundary logic safely prior to active disk purges.

27. `bash scripts/retention.sh`
    - **What it does:** Enforces retention policy by permanently purging expired full backups and their incrementals via strict path guards.
    - **Why:** Prevents repository storage exhaustion while maintaining 2 complete disaster recovery cycles.

---

## Phase 3: Disaster Simulation & Recovery Engine

28. `cd source && find . -type f -exec sha256sum {} + | sort > pre_disaster_manifest.sha256`
    - **What it does:** Indexes all files in the protected source dataset with their cryptographic checksums prior to disaster.
    - **Why:** Creates an authoritative gold standard manifest to validate restore fidelity.

29. `rm -rf source/sales`
    - **What it does:** Deletes the entire Sales department folder inside the sandbox source.
    - **Why:** Simulates catastrophic catastrophic departmental data loss.

30. `echo "CORRUPTED" > source/engineering/architecture_decision_records.md`
    - **What it does:** Overwrites critical engineering documentation with garbage bytes.
    - **Why:** Simulates silent bit-rot / in-place file tampering.

31. `tar --listed-incremental=/dev/null -xzf repo/full_TS.tar.gz -C restore_target/`
    - **What it does:** Extracts baseline full backup into `restore_target/`.
    - **Why:** Restores original filesystem baseline state.

32. `tar --listed-incremental=/dev/null -xzf repo/incr_TS.tar.gz -C restore_target/`
    - **What it does:** Replays incremental changes in chronological order using `--listed-incremental=/dev/null`.
    - **Why:** Re-applies additions, modifications, and file deletions accurately.

33. `diff -r source restore_target/`
    - **What it does:** Recursively compares restored directory tree against source.
    - **Why:** Proves 100% bit-for-bit data fidelity and file structure match (PASS).

34. `printf "\xDE\xAD\xBE\xEF" | dd of=corrupt_tamper_demo.tar.gz bs=1 count=4 seek=128 conv=notrunc`
    - **What it does:** Deliberately modifies 4 bytes at offset 128 of an archive clone.
    - **Why:** Simulates storage sector corruption / ransomware tampering.

35. `bash scripts/verify_backup.sh corrupt_tamper_demo.tar.gz`
    - **What it does:** Scans the tampered archive with SHA-256 validation.
    - **Why:** Proves that the integrity verification engine detects corruption promptly and blocks unsafe restore.

---

## Phase 4: Automation & Cron Scheduling

36. `service cron status`
    - **What it does:** Checks whether the system background cron processing daemon is running.
    - **Why:** Ensures cron is active to execute scheduled tasks.

37. `crontab -l`
    - **What it does:** Lists active scheduled crontab entries for the current user.
    - **Why:** Enables inspecting schedules before and after automated installation.

38. `echo "$CLEAN_CRON" | crontab -`
    - **What it does:** Installs the updated crontab with tagged `# LSA_SPRINT_TEST` backup jobs.
    - **Why:** Schedules weekly full backup (Sunday 01:00) and daily incremental backup (Daily 02:00).

39. `tail -n 12 logs/cron.log`
    - **What it does:** Reads the latest lines from the cron execution log file.
    - **Why:** Captures live execution evidence of the automated demo cron trigger.

---

## Phase 5: Security Hardening & Access Control

40. `sudo groupadd lsatest_backup_ops`
    - **What it does:** Creates dedicated Linux system group for backup operators.
    - **Why:** Establishes Role-Based Access Control (RBAC) boundaries.

41. `sudo useradd -r -s /usr/sbin/nologin -g lsatest_backup_ops lsatest_backupadmin`
    - **What it does:** Creates a non-login system service account dedicated to backup management.
    - **Why:** Principle of Least Privilege: backup daemon runs under dedicated service user rather than root.

42. `sudo chown -R lsatest_backupadmin:lsatest_backup_ops sandbox_data/repo_mount/`
    - **What it does:** Assigns dedicated ownership of the repository volume.
    - **Why:** Restricts repository filesystem access to authorized personnel and daemons.

43. `sudo chmod 700 sandbox_data/repo_mount/repo`
    - **What it does:** Configures repository directory permissions to owner-only (`rwx------`).
    - **Why:** Prevents unauthorized local users from browsing or modifying backup archives.

44. `sudo -u nobody ls -L sandbox_data/repo/`
    - **What it does:** Attempts directory traversal as the unprivileged system user `nobody`.
    - **Why:** Negative authorization test proving non-members are strictly denied access (`Permission denied`).

45. `sudo -u lsatest_backupadmin ls -L sandbox_data/repo/`
    - **What it does:** Attempts directory listing as the dedicated backup administrator.
    - **Why:** Positive authorization test proving authorized daemon access succeeds with exit code 0.

46. `openssl enc -aes-256-cbc -pbkdf2 -salt -in full.tar.gz -out full.tar.gz.enc -pass pass:"..."`
    - **What it does:** Encrypts backup archive using AES-256 in CBC mode with PBKDF2 key derivation and random salt.
    - **Why:** Demonstrates at-rest cryptographic data protection.

47. `openssl enc -d -aes-256-cbc -pbkdf2 -in full.tar.gz.enc -out decrypted.tar.gz -pass pass:"..."`
    - **What it does:** Decrypts ciphertext payload back to plaintext tar archive.
    - **Why:** Validates end-to-end cryptographic restoration and checksum parity.

---

## Orchestration & Teardown

48. `bash run.sh`
    - **What it does:** Master end-to-end runner that executes recovery tests, archive verification, retention dry-run, report generation, and browser launch.
    - **Why:** Single-command cross-platform validation required by project specification.

49. `explorer.exe "$(wslpath -w report.html)"`
    - **What it does:** Translates WSL Linux path to Windows UNC path and opens `report.html` in the host browser.
    - **Why:** Delivers immediate graphical presentation on Windows/WSL environments.

50. `bash cleanup.sh`
    - **What it does:** Separate teardown script removing tagged cron entries, deleting test accounts, unmounting the loop filesystem, detaching the loop device, and removing the sparse image.
    - **Why:** Safely restores host operating system to pristine condition without deleting logs or reports.
