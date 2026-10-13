# NovaTech Solutions — Department File Server Commands Used
**Course:** Linux System Administration (E1ITA307)  
**Project:** Deployment Project #3 — Department File Server  
**Modules:** III, IV | CO3, CO4  
**Date:** 2026-10-12  

---

## 1. Phase 0: Preflight & Environment Audit

| # | Command Executed | Purpose / Explanation |
|---|---|---|
| 1 | `uname -r` | Identify running Linux kernel release and determine WSL2 / standard environment. |
| 2 | `sudo -v` | Validate and refresh administrative sudo credentials for script execution. |
| 3 | `dpkg -s acl quota` | Query Debian package database to verify installation status of ACL and quota toolkits. |
| 4 | `sudo apt-get update -qq && sudo apt-get install -y quota` | Install standard Linux quota administration utilities without starting background services. |
| 5 | `systemctl list-units --type=service --state=running` | Verify no unauthorized daemon services (e.g. rpcbind or quotarpc) were started. |
| 6 | `command -v setquota quotacheck quotaon repquota getfacl setfacl` | Confirm all necessary binary executables are available in system PATH. |
| 7 | `ls -la /proc/sys/fs/quota` | Inspect Linux kernel procfs interface to verify active kernel quota subsystem support. |
| 8 | `grep -E "(ext4|xfs)" /proc/filesystems` | Verify that the ext4 filesystem driver is supported and loaded in the kernel. |
| 9 | `sudo losetup -f` | Discover next available unused loopback block device node in `/dev/`. |

---

## 2. Phase 1: Storage Allocation & Loopback Provisioning

| # | Command Executed | Purpose / Explanation |
|---|---|---|
| 10 | `truncate -s 2G sandbox_data/fileserver.img` | Create a 2 GiB sparse virtual disk image file within the project sandbox. |
| 11 | `sudo losetup -f --show sandbox_data/fileserver.img` | Attach virtual image to the first free loopback device (`/dev/loop0`) and display name. |
| 12 | `sudo losetup -j sandbox_data/fileserver.img` | Mandatory sandboxing verification: confirm `/dev/loop0` points strictly to this project's image. |
| 13 | `sudo mkfs.ext4 -F -q -L "NOVA_FILESRV" /dev/loop0` | Format loopback volume with ext4 filesystem labeled `NOVA_FILESRV`. |
| 14 | `sudo tune2fs -O quota -Q usrquota,grpquota /dev/loop0` | Enable internal ext4 kernel quota feature flags and quota inodes in filesystem superblock. |
| 15 | `mkdir -p sandbox_data/mnt/fileserver` | Create local mount directory structure inside project sandbox. |
| 16 | `sudo mount -o acl,usrquota,grpquota /dev/loop0 sandbox_data/mnt/fileserver` | Mount virtual block device with POSIX ACLs and user/group quota options enabled. |
| 17 | `sudo mkdir -p sandbox_data/mnt/fileserver/{finance,hr,eng,sales}` | Provision departmental shared folder hierarchy on mounted volume. |
| 18 | `sudo blkid -s UUID -o value /dev/loop0` | Extract filesystem Universally Unique Identifier (UUID) for persistent mounting. |
| 19 | `findmnt --verify --tab-file sandbox_data/fstab.demo` | Validate persistence configuration file syntax against system mount rules without touching `/etc/fstab`. |
| 20 | `lsblk /dev/loop0` | Display block device tree hierarchy and mount status. |
| 21 | `df -h sandbox_data/mnt/fileserver` | Display filesystem disk capacity, used blocks, and available headroom. |
| 22 | `mount \| grep fileserver` | Confirm active mount flags including `acl`, `usrquota`, and `grpquota`. |

---

## 3. Phase 2: RBAC Identities, Groups & Ownership Configuration

| # | Command Executed | Purpose / Explanation |
|---|---|---|
| 23 | `sudo groupadd lsatest_grp_finance` | Create dedicated Linux group for Finance department members. |
| 24 | `sudo groupadd lsatest_grp_hr` | Create dedicated Linux group for HR department members. |
| 25 | `sudo groupadd lsatest_grp_eng` | Create dedicated Linux group for Engineering department members. |
| 26 | `sudo groupadd lsatest_grp_sales` | Create dedicated Linux group for Sales department members. |
| 27 | `sudo groupadd lsatest_grp_audit` | Create dedicated Linux group for Governance & Internal Audit team. |
| 28 | `sudo useradd -M -s /usr/sbin/nologin -g lsatest_grp_finance lsatest_fin_alice` | Create unprivileged Finance user Alice without home directory or interactive login shell. |
| 29 | `sudo useradd -M -s /usr/sbin/nologin -g lsatest_grp_finance lsatest_fin_bob` | Create unprivileged Finance user Bob without home directory or interactive login shell. |
| 30 | `sudo useradd -M -s /usr/sbin/nologin -g lsatest_grp_hr lsatest_hr_carol` | Create unprivileged HR user Carol without home directory or interactive login shell. |
| 31 | `sudo useradd -M -s /usr/sbin/nologin -g lsatest_grp_hr lsatest_hr_dave` | Create unprivileged HR user Dave without home directory or interactive login shell. |
| 32 | `sudo useradd -M -s /usr/sbin/nologin -g lsatest_grp_eng lsatest_eng_eve` | Create unprivileged Engineering user Eve without home directory or interactive login shell. |
| 33 | `sudo useradd -M -s /usr/sbin/nologin -g lsatest_grp_eng lsatest_eng_frank` | Create unprivileged Engineering user Frank without home directory or interactive login shell. |
| 34 | `sudo useradd -M -s /usr/sbin/nologin -g lsatest_grp_sales lsatest_sales_grace` | Create unprivileged Sales user Grace without home directory or interactive login shell. |
| 35 | `sudo useradd -M -s /usr/sbin/nologin -g lsatest_grp_sales lsatest_sales_heidi` | Create unprivileged Sales user Heidi without home directory or interactive login shell. |
| 36 | `sudo useradd -M -s /usr/sbin/nologin -g lsatest_grp_audit lsatest_aud_ivan` | Create unprivileged Internal Auditor Ivan without home directory or interactive login shell. |
| 37 | `sudo passwd -l <username>` | Lock passwords for all nine provisioned service accounts to prevent interactive login. |
| 38 | `sudo chown root:lsatest_grp_<dept> <dept_path>` | Assign root ownership and departmental group ownership to each department folder. |
| 39 | `sudo chmod 2770 <dept_path>` | Set base directory permissions to SetGID (`2`), Owner full (`7`), Group full (`7`), Others none (`0`). |

---

## 4. Phase 3: POSIX Access & Default ACLs

| # | Command Executed | Purpose / Explanation |
|---|---|---|
| 40 | `sudo getfacl -p <dept_path>` | Audit initial baseline ACL permissions on departmental shared directories. |
| 41 | `sudo setfacl -m g::<dept_grp>:rwx <dept_path>` | Grant departmental group full read, write, and traverse permissions via Access ACL. |
| 42 | `sudo setfacl -m g:lsatest_grp_audit:r-x <dept_path>` | Grant Governance Auditor group read and execute/traverse permissions across all shares. |
| 43 | `sudo setfacl -m m::rwx,o::--- <dept_path>` | Set ACL effective mask ceiling to `rwx` and strictly deny any permissions to others. |
| 44 | `sudo setfacl -d -m g::<dept_grp>:rwx <dept_path>` | Configure Default ACL ensuring newly created objects automatically inherit group `rwx`. |
| 45 | `sudo setfacl -d -m g:lsatest_grp_audit:r-x <dept_path>` | Configure Default ACL ensuring newly created objects automatically inherit auditor `r-x`. |
| 46 | `sudo setfacl -d -m m::rwx,o::--- <dept_path>` | Establish default mask and deny permissions for others on all future child objects. |
| 47 | `sudo -u lsatest_fin_alice touch <dept_path>/demo.txt` | Create test file as Finance user Alice to test dynamic inheritance. |
| 48 | `sudo getfacl -p <dept_path>/demo.txt` | Inspect inherited ACL entries on newly created file to verify propagation. |

---

## 5. Phase 4: Quota Allocation & Grace Periods

| # | Command Executed | Purpose / Explanation |
|---|---|---|
| 49 | `sudo quotaon -u -g sandbox_data/mnt/fileserver` | Activate user and group quota enforcement on the mounted ext4 filesystem. |
| 50 | `sudo setquota -u -t 604800 604800 sandbox_data/mnt/fileserver` | Set user block and inode quota grace periods to 7 days (604,800 seconds). |
| 51 | `sudo setquota -g -t 604800 604800 sandbox_data/mnt/fileserver` | Set group block and inode quota grace periods to 7 days (604,800 seconds). |
| 52 | `sudo setquota -g lsatest_grp_finance 204800 256000 0 0 ...` | Set Finance group quota: Soft=200 MB (204,800k), Hard=250 MB (256,000k). |
| 53 | `sudo setquota -g lsatest_grp_hr 102400 122880 0 0 ...` | Set HR group quota: Soft=100 MB (102,400k), Hard=122880k (120M). |
| 54 | `sudo setquota -g lsatest_grp_eng 409600 512000 0 0 ...` | Set Engineering group quota: Soft=400 MB (409,600k), Hard=500 MB (512,000k). |
| 55 | `sudo setquota -g lsatest_grp_sales 102400 122880 0 0 ...` | Set Sales group quota: Soft=100 MB (102,400k), Hard=120 MB (122,880k). |
| 56 | `sudo setquota -u lsatest_fin_alice 92160 112640 0 0 ...` | Set Alice user quota: Soft=90 MB (92,160k), Hard=110 MB (112,640k). |
| 57 | `sudo setquota -u lsatest_hr_carol 51200 61440 0 0 ...` | Set Carol user quota: Soft=50 MB (51,200k), Hard=60 MB (61,440k). |
| 58 | `sudo setquota -u lsatest_eng_eve 153600 204800 0 0 ...` | Set Eve user quota: Soft=150 MB (153,600k), Hard=200 MB (204,800k). |
| 59 | `sudo setquota -u lsatest_sales_grace 51200 61440 0 0 ...` | Set Grace user quota: Soft=50 MB (51,200k), Hard=60 MB (61,440k). |
| 60 | `sudo repquota -u sandbox_data/mnt/fileserver` | Generate summary report of active user quota block usage, limits, and grace status. |
| 61 | `sudo repquota -g sandbox_data/mnt/fileserver` | Generate summary report of active group quota block usage, limits, and grace status. |

---

## 6. Phase 5: Test Execution & Verification

| # | Command Executed | Purpose / Explanation |
|---|---|---|
| 62 | `sudo -u lsatest_fin_alice touch finance/report.txt` | Test 1: Verify Finance member can create files in `finance/`. |
| 63 | `sudo -u lsatest_fin_bob bash -c "echo ... >> finance/report.txt"` | Test 1: Verify Finance colleague Bob can edit/append to Alice's report. |
| 64 | `sudo -u lsatest_hr_carol ls finance/` | Test 2: Verify HR user Carol is blocked from listing `finance/` (Permission denied). |
| 65 | `sudo -u lsatest_hr_carol cat finance/report.txt` | Test 2: Verify HR user Carol is blocked from reading Finance documents. |
| 66 | `sudo -u lsatest_hr_carol touch finance/leak.txt` | Test 2: Verify HR user Carol is blocked from writing to `finance/`. |
| 67 | `sudo -u lsatest_aud_ivan ls <dept_folders>` | Test 3: Verify Auditor Ivan can read all four departmental shared directories. |
| 68 | `sudo -u lsatest_aud_ivan touch finance/tamper.txt` | Test 3: Verify Auditor Ivan is strictly blocked from writing to `finance/`. |
| 69 | `sudo -u lsatest_aud_ivan rm -f finance/report.txt` | Test 3: Verify Auditor Ivan is strictly blocked from deleting Finance files. |
| 70 | `sudo -u lsatest_eng_eve touch eng/blueprint.txt` | Test 4: Create new file as Engineering member Eve. |
| 71 | `stat -c "%G" eng/blueprint.txt` | Test 4: Confirm new file inherited department group `lsatest_grp_eng` via SetGID. |
| 72 | `sudo chmod 3770 sandbox_data/mnt/fileserver/*` | Test 5: Apply directory sticky bit (`3770`) to protect against peer file deletion. |
| 73 | `sudo -u lsatest_fin_bob rm finance/alice_ledger.txt` | Test 5: Verify peer Bob cannot delete Alice's file under mode 3770 (Operation not permitted). |
| 74 | `sudo -u lsatest_fin_alice rm finance/alice_ledger.txt` | Test 5: Verify owner Alice can delete her own file under mode 3770. |
| 75 | `sudo -u lsatest_sales_grace dd if=/dev/zero of=sales/soft.dat bs=1M count=55` | Test 6: Write 55 MB bounded file exceeding 50 MB soft limit to activate grace period. |
| 76 | `sudo repquota -u sandbox_data/mnt/fileserver \| grep sales_grace` | Test 6: Verify `+-` warning flag and 7-day grace countdown are active in repquota. |
| 77 | `sudo -u lsatest_sales_grace dd if=/dev/zero of=sales/hard.dat bs=1M count=10` | Test 7: Attempt write past 60 MB hard ceiling; verify write fails with Disk quota exceeded. |
| 78 | `sudo du -sb sales/ && sudo repquota -u ...` | Test 8: Reconcile disk usage metrics across `du` and `repquota` for exact parity. |

---

## 7. Phase 6 & Reporting

| # | Command Executed | Purpose / Explanation |
|---|---|---|
| 79 | `sudo find sandbox_data/mnt/fileserver -type f -perm -0002` | Search volume for insecure world-writable files (`o+w`). |
| 80 | `sudo find sandbox_data/mnt/fileserver -type d -perm -0002 ! -perm -1000` | Search volume for world-writable directories lacking sticky bit protection. |
| 81 | `sudo find sandbox_data/mnt/fileserver \( -nouser -o -nogroup \)` | Search volume for orphaned files without mapped user or group IDs. |
| 82 | `sudo stat -c "%a" sandbox_data/mnt/fileserver/*` | Audit department directory permissions to confirm other permissions are zero (`---`). |
| 83 | `explorer.exe "$(wslpath -w report.html)"` | Launch Windows default browser to view dark-themed HTML audit report. |

---

## 8. Teardown & Sanitation

| # | Command Executed | Purpose / Explanation |
|---|---|---|
| 84 | `sudo quotaoff -u -g sandbox_data/mnt/fileserver` | Disable kernel filesystem quota accounting prior to unmounting. |
| 85 | `sudo umount sandbox_data/mnt/fileserver` | Safely unmount loopback filesystem. |
| 86 | `sudo losetup -d /dev/loop0` | Detach verified loopback device after confirming backing file association. |
| 87 | `rm -f sandbox_data/fileserver.img sandbox_data/fstab.demo` | Delete sandbox image file and persistence demo file. |
| 88 | `sudo userdel -f <lsatest_user>` | Safely purge test user accounts from system passwd database. |
| 89 | `sudo groupdel <lsatest_group>` | Safely purge test departmental groups from system group database. |
| 90 | `losetup -a && getent passwd \| grep lsatest_` | Audit system to verify zero lingering block devices or test accounts remain. |
