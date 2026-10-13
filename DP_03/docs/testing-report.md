# NovaTech Solutions — Department File Server Testing Report
**Course:** Linux System Administration (E1ITA307) — Modules: III, IV | CO3, CO4  
**Project:** Deployment Project #3 — Department File Server  
**Test Date:** 2026-10-12 20:00:43  
**Host:** SP  
**Kernel:** 6.18.40.1-microsoft-standard-WSL2  
**Execution Summary:** 8 / 8 Tests Passed

---

## 1. Test Summary Matrix

| ID | Test Case | Target Subject | Expected Behavior | Actual Outcome | Status |
|---|---|---|---|---|:---:|
| 1 | Intra-Department Collaboration | Finance (`finance/`) | Alice creates/edits; Bob appends; list succeeds | Both members read/write with exit 0 | **PASS** |
| 2 | Cross-Department Isolation | HR -> Finance | Carol cannot list, read, or write in finance/ | All access blocked with Permission Denied | **PASS** |
| 3 | Auditor Read-Only Governance | Auditor (`ivan`) | Ivan reads all 4 depts; write/delete denied | Global read exit 0; write/delete exit != 0 | **PASS** |
| 4 | Default ACL & Group Inheritance | Engineering (`eng/`) | New file inherits `lsatest_grp_eng` & auditor ACL | Group SetGID & auditor `r-x` ACL present | **PASS** |
| 5 | Peer Deletion Protection | Finance (`finance/`) | Mode 3770 blocks Bob from deleting Alice's file | Deletion blocked with Operation not permitted | **PASS** |
| 6 | Soft Quota Warning | Sales (`sales/`) | Writing 55M triggers grace period & `+-` flag | Repquota shows `+-` with 7-day grace timer | **PASS** |
| 7 | Hard Quota Write Halt | Sales (`sales/`) | Writing past 60M ceiling fails with quota error | Write stopped: Disk quota exceeded | **PASS** |
| 8 | Storage Accounting Parity | File Server Volume | `repquota`, `du`, and `df` match real disk allocations | Discovered exact block parity (~60 MB capped) | **PASS** |

---

## 2. Detailed Test Logs & Raw Terminal Evidence

### Test 1: Finance Intra-Department Collaboration
- **Command Executed:** `sudo -u lsatest_fin_alice touch ... && sudo -u lsatest_fin_bob echo ...`
- **Expected:** Create, append, and list operations succeed (exit 0) for finance members alice and bob.
- **Actual:** File successfully created and edited by alice, verified and appended by bob. Content: 'Q1 Financial Summary: Revenue $1.5M
Verified and approved by Bob' (Exit: 0).
- **Verdict:** **PASS**

### Test 2: Cross-Department Access Isolation
- **Command Executed:** `sudo -u lsatest_hr_carol ls /.../finance`
- **Expected:** HR member carol is strictly denied listing, reading, or writing in finance/ (exit != 0, Permission denied).
- **Actual:** All unauthorized attempts blocked with Permission Denied. ls exit=2 ('ls: cannot open directory '/mnt/d/Users/Dell/Downloads/Projects/LSA/Deployment_Projects/DP_03/sandbox_data/mnt/fileserver/finance': Permission denied'), read exit=1 ('cat: /mnt/d/Users/Dell/Downloads/Projects/LSA/Deployment_Projects/DP_03/sandbox_data/mnt/fileserver/finance/test_report_q1.txt: Permission denied'), write exit=1 ('touch: setting times of '/mnt/d/Users/Dell/Downloads/Projects/LSA/Deployment_Projects/DP_03/sandbox_data/mnt/fileserver/finance/unauthorized_hr.txt': Permission denied').
- **Verdict:** **PASS**

### Test 3: Governance Auditor Global Read-Only Access
- **Command Executed:** `sudo -u lsatest_aud_ivan ls <depts> && touch <depts>/tamper`
- **Expected:** Auditor ivan can read all department directories, but write and delete attempts are strictly denied.
- **Actual:** Auditor read succeeded across all 4 departments (exits=0). Write blocked (exit=1: 'touch: cannot touch '/mnt/d/Users/Dell/Downloads/Projects/LSA/Deployment_Projects/DP_03/sandbox_data/mnt/fileserver/finance/audit_tamper.txt': Permission denied'). Delete blocked (exit=1: 'rm: cannot remove '/mnt/d/Users/Dell/Downloads/Projects/LSA/Deployment_Projects/DP_03/sandbox_data/mnt/fileserver/finance/test_report_q1.txt': Permission denied').
- **Verdict:** **PASS**

### Test 4: Default ACL & SetGID Inheritance
- **Command Executed:** `sudo -u lsatest_eng_eve touch eng_blueprint.txt && getfacl ...`
- **Expected:** New file/folder created by eng member inherits owning group lsatest_grp_eng and auditor read ACL automatically.
- **Actual:** File & dir group: 'lsatest_grp_eng' (SetGID inheritance). File ACL has 'group:lsatest_grp_audit:r-x	#effective:r--'. Subdir inherited default ACL: 'default:group:lsatest_grp_audit:r-x'.
- **Verdict:** **PASS**

### Test 5: Peer Deletion Protection & Sticky Bit Policy
- **Command Executed:** `sudo -u lsatest_fin_bob rm alice_private_ledger.txt`
- **Expected:** Under directory sticky bit (3770), peer bob cannot delete alice's file (exit != 0, Operation not permitted), while alice can delete it.
- **Actual:** Sticky bit (3770) blocked peer deletion: bob exit=1 ('rm: cannot remove '/mnt/d/Users/Dell/Downloads/Projects/LSA/Deployment_Projects/DP_03/sandbox_data/mnt/fileserver/finance/alice_private_ledger.txt': Operation not permitted'). Owner alice successfully deleted her own file (exit=0).
- **Verdict:** **PASS**

### Test 6: Soft Quota Exceeded (Grace Period Activated)
- **Command Executed:** `sudo -u lsatest_sales_grace dd if=/dev/zero of=... bs=1M count=55`
- **repquota Output:**
```
lsatest_sales_grace +-   60420   51200   61440  7days       2     0     0       
```
- **Verdict:** **PASS**

### Test 7: Hard Quota Exceeded (Kernel Write Halt)
- **Command Executed:** `sudo -u lsatest_sales_grace dd if=/dev/zero of=... bs=1M count=10`
- **Kernel Response:** `dd: IO error: Disk quota exceeded`
- **Resulting File Size:** `0`
- **Verdict:** **PASS**

### Test 8: Storage Accounting Parity & Audit Reconciliation
- **Reported du:** `59 MB`
- **Reported repquota:** `59 MB` (60420 1-KiB blocks)
- **Verdict:** **PASS**

---
