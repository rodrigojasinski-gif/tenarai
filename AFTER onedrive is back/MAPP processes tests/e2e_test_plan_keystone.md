# E2E Test Plan — Keystone chain (XAMR100 → 101 → 102)

Environment: RADD (dawapp7017l)
Test data location (TEMPORARY): /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev
Story: AES-XXXX

---

## 0. Files to request from Chuck

For the **full Keystone end-to-end**, you only need **ONE file** from Chuck:

| File | Used by | Why only this one |
|---|---|---|
| `keystone_combined.txt` | XAMR100 (xamref.ksh) | XAMR101 consumes what XAMR100 produces (`keystone_refproc.txt`); XAMR102 consumes what XAMR101 produces (`keystone_rpt_prov.txt`). The chain feeds itself after the first step. |

Ask Chuck for a **recent** `keystone_combined.txt` so the data is realistic.

> Note: Chuck is on Windows and this test folder is an NFS mount visible only
> from the Linux side. So the practical handoff is: Chuck sends you the file
> (email / shared drive / Teams), and YOU copy it into the test folder from
> the Linux side (step 2 below).

If you later test the NAPA chain, you will also need `COL.hdr` and `COLNW.hdr`
from Chuck — but those are not needed for the Keystone test.

---

## 1. Setup — create the test folder structure

On RADD (dawapp7017l), create the ALTP subtree inside the test location:

```
mkdir -p /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/NAPA
mkdir -p /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/Internal_Rpts
mkdir -p /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/Customer_Rpts
```

Verify:
```
ls -la /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/
```

---

## 2. Setup — deploy the modified scripts

Copy these into the RACE scripts directory on RADD (wherever race_altp.ksh /
setgdg.ksh / abndalrt.ksh live - check with: which setgdg.ksh):

| File | Status |
|---|---|
| `altp_ftp_data.ksh` | NEW config file - the single place to change the folder later |
| `xamref.ksh` | MODIFIED - migrated to NFS + AIX-to-RHEL fixes |

Make sure they are executable and have Unix line endings:
```
chmod +x altp_ftp_data.ksh xamref.ksh
file altp_ftp_data.ksh xamref.ksh    # must say "ASCII text", NOT "CRLF"
```

If a file shows "with CRLF line terminators", fix it:
```
dos2unix altp_ftp_data.ksh xamref.ksh
```

> For this first test you only need xamref.ksh (XAMR100). xamupd.ksh and
> xamrpt.ksh will be delivered next, before testing XAMR101 / XAMR102.

---

## 3. Setup — place the test input file

After Chuck sends you `keystone_combined.txt`:

```
cp keystone_combined.txt /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/
ls -la /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/keystone_combined.txt
```

---

## 4. Setup — redirect test emails (avoid spamming real recipients)

XAMR100 emails a "reformat done" notice (Step 600R) using `zxamrefa.prm`.
XAMR102 emails reports to actual suppliers. Before testing, edit the parm
files in $RACE/prm/ to point to YOUR email instead of the real distribution
list. Restore them after the test. Parm files involved:

  - zxamrefa.prm   (XAMR100 reformat notice)
  - zxamupda.prm   (XAMR101 update notice)
  - zxamrpta.prm   (XAMR102 - DATA_ANALYST recipient)

---

## 5. Run — XAMR100 (reformat)

```
xamr100.ksh
```

Checks after run:

| # | Check | Expected |
|---|---|---|
| 5.1 | Return code | 0 |
| 5.2 | Job log in $RACE/log/ | No "error" / no "abnd" lines |
| 5.3 | `$RACE/tmp/xamr100_keystone_ftp.tmp` | Empty (cp success) or no error text |
| 5.4 | Log shows "file copy counts are good" | Yes |
| 5.5 | `.../altp/keystone_refproc.txt` created | Yes |
| 5.6 | `.../altp/Internal_Rpts/keystone_referrs.txt` created | Yes |
| 5.7 | `.../altp/Internal_Rpts/keystone_refsum.txt` created | Yes |
| 5.8 | Oracle reformat ran (Step300R, PKG_ALTERNATE_PARTS_LOAD_TRANS) | Check $LOG for ORA- errors |

---

## 6. Simulate analyst review

In production, the data analyst opens `keystone_refproc.txt`, reviews/edits
it, and saves it back. For the test, just confirm the file is readable and
leave it as-is (or make a trivial edit):

```
ls -la /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/keystone_refproc.txt
head /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/keystone_refproc.txt
```

---

## 7. Run — XAMR101 (update)   [after xamupd.ksh is delivered]

```
xamr101.ksh
```

Checks:

| # | Check | Expected |
|---|---|---|
| 7.1 | Return code | 0 |
| 7.2 | Reads `keystone_refproc.txt` from `.../altp/` | Yes |
| 7.3 | Oracle `part_altpart_xref` updated | Validate via SQL |
| 7.4 | `.../altp/keystone_rpt_prov.txt` created | Yes |
| 7.5 | `.../altp/Internal_Rpts/keystone_partver_sum.txt` created | Yes |
| 7.6 | `.../altp/Internal_Rpts/keystone_updt_sum.txt` created | Yes |

---

## 8. Run — XAMR102 (report)    [after xamrpt.ksh is delivered]

```
xamr102.ksh
```

Checks:

| # | Check | Expected |
|---|---|---|
| 8.1 | Return code | 0 |
| 8.2 | Reads `keystone_rpt_prov.txt` from `.../altp/` | Yes |
| 8.3 | `mitch_exc_rpts.zip` generated | Yes |
| 8.4 | Test email received (PDF + zip + readme) | Yes |
| 8.5 | No FTP / file-access errors in log | Yes |

---

## 9. Evidence to capture for the story

  - Job logs for xamr100 / xamr101 / xamr102 (full $RACE/log/ files)
  - `ls -la` of the test folder before and after each run
  - Screenshots of the shell output (Start/End lines, "counts are good")
  - SQL validation output for part_altpart_xref
  - Test email screenshot

Bundle into a zip and attach to AES-XXXX, same pattern used in AES-3175.

---

## 10. Rollback / cleanup

  - Restore the email parm files (zxamrefa.prm, zxamupda.prm, zxamrpta.prm)
  - The original (unmodified) xamref.ksh stays in RCS - if anything fails,
    `co -l xamref.ksh` gets the original back
  - Test files in /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev can be
    left in place or cleaned up - they do not affect production
