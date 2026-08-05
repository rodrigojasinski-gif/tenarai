# Deploy & Run — ALTP/MAPP E2E test (Keystone chain)

Environment: RADD (dawapp7017l)
Story: AES-XXXX
Date: 2026-04-24

This package contains everything needed to run the Keystone end-to-end test
(XAMR100 -> XAMR101 -> XAMR102) on the new AWS RHEL server, using a temporary
test folder until the final NAS share is provisioned.

---

## Package contents

| File | Type | Purpose |
|---|---|---|
| `altp_ftp_data.ksh` | NEW config | Single place that defines the MAPP/ALTP folder location |
| `xamref.ksh` | MODIFIED | XAMR100 sub-script - reformat. prod3nt -> NFS, AIX -> RHEL |
| `xamupd.ksh` | MODIFIED | XAMR101 sub-script - update. prod3nt -> NFS, AIX -> RHEL |
| `xamrpt.ksh` | MODIFIED | XAMR102 sub-script - report. prod3nt -> NFS, AIX -> RHEL |
| `setup_test_env.sh` | helper | Creates the test folder structure, verifies write access |
| `README_deploy.md` | this file | Deploy + run instructions |

The wrappers (xamr100.ksh, xamr101.ksh, xamr102.ksh) are NOT modified - they
only call the sub-scripts and never touched prod3nt.

---

## What changed in the scripts

1. **prod3nt removal** - every `fileget.exp` / `fileput.exp` call against
   `${NOVELL}altp` was replaced with local file operations (`cp`, `sed`, `tr`)
   against the NFS-mounted path. The `fileget.exp` / `fileput.exp` procedures
   themselves were NOT touched - other non-ALTP scripts still use them.

2. **Configurable path** - all scripts now `. altp_ftp_data.ksh` near the top.
   That file defines `ALTP_FTP_DATA` and the derived sub-paths
   (`ALTP_DIR`, `ALTP_NAPA_DIR`, `ALTP_INTRPT_DIR`, `ALTP_CUSTRPT_DIR`).
   To move to the final NAS folder later, edit ONLY one line in
   `altp_ftp_data.ksh`.

3. **AIX -> RHEL fixes**
   - `[ var -eq var ]` (bare names, AIX-tolerant) -> `[[ "$var" -eq "$var" ]]`
   - byte-count check no longer parses `fileget.exp` log output; uses `wc -c`
     directly on local files
   - `echo` -> `print` in the modified blocks for reliable behavior on ksh93
   - line-ending handling: GET steps that used FTP `ascii` mode now run
     `tr -d '\r'` (CRLF -> LF); PUT steps that used FTP `ascii` mode now run
     `sed 's/\r*$/\r/'` (LF -> CRLF) to preserve behavior for Windows analysts

---

## STEP 1 - Deploy the files

Copy all 5 files into the RACE scripts directory on RADD. To find it:

```
which setgdg.ksh        # the scripts dir is wherever this lives
echo $RACE
```

Copy the files there, then set permissions and confirm Unix line endings:

```
chmod +x altp_ftp_data.ksh xamref.ksh xamupd.ksh xamrpt.ksh setup_test_env.sh
file *.ksh *.sh          # every line must say "ASCII text" - NOT "CRLF"
```

If any file shows "with CRLF line terminators":
```
dos2unix altp_ftp_data.ksh xamref.ksh xamupd.ksh xamrpt.ksh setup_test_env.sh
```

> RCS note: before overwriting the originals, check them out / back up via RCS
> so you can roll back. The originals are at RCS revisions:
> xamref.ksh v1.4, xamupd.ksh v1.5, xamrpt.ksh v1.17

---

## STEP 2 - Confirm the config

Open `altp_ftp_data.ksh` and confirm the path line reads:

```
export ALTP_FTP_DATA=/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev
```

This is the TEMPORARY test location. When the final NAS share is ready,
this is the ONLY line to change.

---

## STEP 3 - Create the test folder structure

```
./setup_test_env.sh
```

Expected: it creates `altp/`, `altp/NAPA/`, `altp/Internal_Rpts/`,
`altp/Customer_Rpts/` under the test location and confirms write access.

---

## STEP 4 - Place the test input file

Get a recent `keystone_combined.txt` from Chuck (he is on Windows; he sends
it to you, you copy it in from the Linux side):

```
cp keystone_combined.txt /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/
ls -la /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/keystone_combined.txt
```

---

## STEP 5 - Redirect test emails

Edit these parm files in `$RACE/prm/` to point to YOUR email instead of the
real distribution lists (back them up first, restore them after the test):

```
zxamrefa.prm   - XAMR100 reformat notice
zxamupda.prm   - XAMR101 update notice
zxamrpta.prm   - XAMR102 DATA_ANALYST recipient
```

---

## STEP 6 - Run the chain

Run the three jobs in order, checking the result of each before moving on:

```
xamr100.ksh        # reformat  - reads keystone_combined.txt, writes keystone_refproc.txt
xamr101.ksh        # update    - reads keystone_refproc.txt, writes keystone_rpt_prov.txt
xamr102.ksh        # report    - reads keystone_rpt_prov.txt, sends reports
```

See `e2e_test_plan_keystone.md` for the detailed per-step validation checklist.

Quick sanity checks after each run:

```
# after xamr100
ls -la /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/keystone_refproc.txt
ls -la /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/Internal_Rpts/

# after xamr101
ls -la /nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev/altp/keystone_rpt_prov.txt

# after xamr102
# check the test email inbox for the report bundle
```

---

## STEP 7 - Capture evidence and roll back parm files

- Save the job logs from `$RACE/log/`
- Screenshot the shell output
- Restore the email parm files (zxamrefa.prm, zxamupda.prm, zxamrpta.prm)

---

## Open items still to confirm (do not block the test)

1. **AES story number** - replace `AES-XXXX` in all files once assigned.
2. **Line endings for analysts** - the PUT steps now write CRLF via `sed`.
   Confirm during the test that the analyst can open `keystone_refproc.txt`
   and `keystone_rpt_prov.txt` correctly on Windows.
3. **Final NAS folder** - when provisioned, change the one line in
   `altp_ftp_data.ksh` and re-test.
4. **Other ALTP scripts** - xam200.ksh, xam010.ksh, xam001.ksh, xam030.ksh,
   xam069.ksh still pending (not needed for the Keystone E2E test).
