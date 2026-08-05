# Changelog — MAPP/ALTP scripts: prod3nt removal + AIX to RHEL

Story: AES-XXXX
Author: rj132422 (Rodrigo Jasinski)
Date: 2026-04-24
Target server: RADD (dawapp7017l) - dev

---

## Scope

Convert the MAPP/ALTP batch scripts to run on AWS RHEL and remove the
dependency on the prod3nt server (being decommissioned). File access moves
from FTP (fileget.exp / fileput.exp) to local operations on an NFS-mounted
path, configured in a single place.

---

## New file

| File | Purpose |
|---|---|
| `altp_ftp_data.ksh` | Config. Defines `ALTP_FTP_DATA` and the derived sub-paths `ALTP_DIR`, `ALTP_NAPA_DIR`, `ALTP_INTRPT_DIR`, `ALTP_CUSTRPT_DIR`. The ONE place to change the folder location. Currently points to the TEMPORARY test location `/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev`. |

---

## Modified files

### Sub-scripts (the file I/O engine) - 6 files

| Script | prod3nt points changed | AIX->RHEL fixes |
|---|---|---|
| `xamref.ksh` | 1 GET + 3 PUT | `[ -eq ]` -> `[[ ]]`; byte-count via wc -c; echo -> print |
| `xamupd.ksh` | 1 GET + 3 PUT | same + removed brittle CRLF-offset arithmetic |
| `xamrpt.ksh` | 1 GET | same. Note: the scp/sftp calls in Step700R go to the Mitchell FTP, NOT prod3nt - left unchanged |
| `xam200.ksh` | 2 GET + 4 PUT | `[ -eq ]` x5 -> `[[ ]]`; echo -> print. Note: Step010R scp + Step098R ssh go to Mitchell FTP - left unchanged |
| `xam010.ksh` | 3 PUT (live) | non-ASCII chars in comments cleaned to ASCII |
| `xam001.ksh` / `xam030.ksh` / `xam069.ksh` | 1 GET each | `[ -eq ]` -> `[[ ]]`; echo -> print |

### Wrapper - 1 file

| Script | Change |
|---|---|
| `xamr200.ksh` | 1 line: `echo "...\n\n"` -> `print "...\n\n"` (only AIX-ism found in any wrapper) |

### Wrappers NOT modified (already RHEL-clean)

xamr100, xamr101, xamr102, xamr201, xamr202, xamr900, xamr901, xamr902,
xamr001, xamr010, xamr030, xamr069 - verified: no prod3nt refs, no AIX-isms.

---

## Conversion patterns applied

| Original (AIX + prod3nt) | New (RHEL + NFS) |
|---|---|
| `export NTDIR=${NOVELL}altp` | `export NTDIR=${ALTP_DIR}` (from altp_ftp_data.ksh) |
| `fileget.exp f u d` (binary) | `cp ${d}/${f} ${u}` + wc -c byte-count check |
| `fileget.exp f u d ascii` | `cp` + `tr -d '\r'` (CRLF->LF, replicates ascii mode) |
| `fileput.exp f name d ascii` | `sed 's/\r*$/\r/' f > ${d}/name` (LF->CRLF, replicates ascii mode) |
| `grep 'Information ret' log` | `wc -c` directly on local files |
| `[ var -eq var ]` (bare names) | `[[ "$var" -eq "$var" ]]` |
| `echo "...\n..."` | `print "...\n..."` (reliable on ksh93) |
| `\| tee $LOG` (masked exit code) | `> $LOG 2>&1` (preserves exit code for trap err) |

---

## Known items left as-is (intentional - documented for review)

### xam010.ksh - 4 dead-code fileput.exp lines

Lines 158, 215, 259, 969 still contain `fileput.exp` / `${NOVELL}`. ALL FOUR
are inside `: <<'END_COMMENT'` ... `END_COMMENT` blocks - they are
commented-out dead code (disabled under AES-3148). They never execute.
Left untouched to avoid editing inside comment blocks. If any block is ever
re-enabled, those lines must be migrated too.

### xam010.ksh - ${NOVELL}race references

Lines 215 and 259 (both dead code, see above) use `${NOVELL}race`, not
`${NOVELL}altp`. The `race` shared area is OUT OF SCOPE for this task per
the agreement with Julian. NOTE: if prod3nt is fully decommissioned, any
LIVE `${NOVELL}race` usage anywhere in the RACE codebase will also break -
that should be tracked separately.

---

## Open items

1. `AES-XXXX` - replace with the real story number in all files (global
   find/replace on the `# Change rj132422 - 20260424 - AES-XXXX` comments).
2. Line endings for analysts - PUT steps now write CRLF via `sed`. Validate
   during testing that analysts can open the files correctly on Windows.
3. Final NAS folder - when provisioned, change ONLY the `ALTP_FTP_DATA` line
   in `altp_ftp_data.ksh`.
4. `${NOVELL}` is no longer referenced by any LIVE ALTP code. It can stay
   defined for other non-ALTP scripts; this task does not touch it.

---

## Validation done in this package

- `bash -n` syntax check: PASS on all 10 files
- Encoding: all ASCII text (xam010.ksh non-ASCII comment chars cleaned)
- No CRLF line terminators
- No LIVE prod3nt references remain in any ALTP script
