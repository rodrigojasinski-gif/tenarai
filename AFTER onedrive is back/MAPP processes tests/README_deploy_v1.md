# Deploy — MAPP/ALTP prod3nt removal + AIX→RHEL  (package: `deliverablev1/`)

Target: **RADP** (`pawapp7017l`, prod). Also runs on RADD (`dawapp7017l`, dev) —
the config auto-selects the path by server via `THISHOST`, so the same package
works in both.

---

## Package contents — 10 files (all in `deliverablev1/`)

| File | Deploy to | Notes |
|---|---|---|
| `race_altp.ksh` | `share/bin` | Subsystem profile. **Now defines** `ALTP_FTP_DATA` + derived paths. **SHARED** — sourced by every ALTP wrapper. |
| `xamref.ksh` `xamupd.ksh` `xamrpt.ksh` | `altp/bin` | XAMR100/900, 101/901, 102/902 sub-scripts (reformat / update / report). |
| `xam200.ksh` `xam010.ksh` `xam001.ksh` `xam030.ksh` `xam069.ksh` | `altp/bin` | NAPA chain + auxiliaries. |
| `xamr200.ksh` | `altp/bin` | The only wrapper that changed (1 `echo`→`print` fix). |

**Not included** (unchanged, already on the server — do NOT redeploy):
`xamr100/101/102/201/202/900/901/902/001/010/030/069`.

The old `altp_ftp_data.ksh` is **gone** — its config lives in `race_altp.ksh` now.

---

## What changed

- prod3nt / `${NOVELL}` FTP → **local NFS ops** (`cp` / `sed` / `tr`).
  `fileget.exp` / `fileput.exp` were **not** touched (other scripts still use them).
- Path config moved into `race_altp.ksh` (prod/dev branch):
  - prod: `/nas/prod/OEM_Repair_Doc_Repository/ftpdata/prod`
  - dev:  `/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev`
  - derived: `ALTP_DIR` / `ALTP_NAPA_DIR` / `ALTP_INTRPT_DIR` / `ALTP_CUSTRPT_DIR`
- **To move the folder later:** edit ONLY the `ALTP_FTP_DATA` line(s) in `race_altp.ksh`.

---

## Deploy steps

1. **Back up the originals via RCS** before overwriting (so you can roll back):
   `race_altp.ksh` (v1.8), `xamref.ksh` (v1.4), `xamupd.ksh` (v1.5),
   `xamrpt.ksh` (v1.17), plus `xam200/010/001/030/069` and `xamr200`.
   Find the dirs with: `which race_altp.ksh` (share/bin) and `which xamref.ksh` (altp/bin).

2. **Copy the files** to their dirs (see table). Deploy `race_altp.ksh` **with or before**
   the sub-scripts — they depend on it for `ALTP_DIR` etc.

3. **Permissions / line endings:**
   ```
   chmod +x <files>
   file *.ksh          # must say "ASCII text", NOT "CRLF"
   ```
   If any shows CRLF: `dos2unix <file>`.

4. **Confirm the NAS is mounted and writable** (prod):
   ```
   df -hT /nas/prod/OEM_Repair_Doc_Repository     # type must be nfs / nfs4
   ```

5. **Create the altp subtree** under the NAS path:
   ```
   mkdir -p /nas/prod/OEM_Repair_Doc_Repository/ftpdata/prod/altp/NAPA
   mkdir -p /nas/prod/OEM_Repair_Doc_Repository/ftpdata/prod/altp/Internal_Rpts
   mkdir -p /nas/prod/OEM_Repair_Doc_Repository/ftpdata/prod/altp/Customer_Rpts
   ```
   (On RADD the base is `/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev`.)

6. **Redirect test emails** — point `zxamrefa.prm`, `zxamupda.prm`, `zxamrpta.prm`
   in `$RACE/prm/` to your address (back up first, restore after the test).

---

## Run — XAMR900 chain (Multiple)

Using the `multiple_*` files you already have as a gabarito:

1. Place `multiple_combined.txt` in `${ALTP_DIR}` (`.../ftpdata/<lvl>/altp/`).
2. Run in order, checking each: `xamr900.ksh` → `xamr901.ksh` → `xamr902.ksh`.
3. **Compare** the generated `multiple_refproc.txt` with your reference copy —
   if they match, the migrated `xamref` is correct.

Sanity checks:
```
ls -la ${ALTP_DIR}/multiple_refproc.txt          # after xamr900
ls -la ${ALTP_DIR}/Internal_Rpts/                # referrs / refsum
ls -la ${ALTP_DIR}/multiple_rpt_prov.txt         # after xamr901
# after xamr902: check the test inbox for the report bundle
```

---

## Rollback

- Restore the originals from RCS (`co -l <file>`), redeploy.
- The `race_altp.ksh` change is **additive** (only adds `ALTP_FTP_DATA` + derived
  vars; `RACE` / `PATH` / `OBJ_*` untouched) — reverting it simply removes those vars.

---

## Evidence to capture (for the story)

- Job logs for xamr900 / 901 / 902 from `$RACE/log/`
- `ls -la` of `${ALTP_DIR}` before/after each run
- Shell output (Start/End, "counts are good")
- SQL validation for `part_altpart_xref`
- Test-email screenshot

> Note: the final supplier deliverable `mitch_exc_rpts.zip` still goes out over the
> **Mitchell FTP** (`$FTP_BUSINESS_PATH/.../outgoing/`) — that path is unchanged by
> this task.
