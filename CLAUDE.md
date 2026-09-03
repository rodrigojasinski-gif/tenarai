# Project rules — RACE OEM / MAPP (AIX → RHEL/AWS migration)

## No personal names — ANYWHERE (read this every time)
- **NEVER use any person's name** (Julian, Patty, Lorena, Rodrigo, etc.) in: file names,
  comments, commit messages, variable names, log/echo strings, email bodies, test files,
  documentation, or any artifact produced for this project.
- This applies to test/scratch files too — use neutral names (e.g. `__linktest.txt`,
  `__nas_write_test.txt`), never `__patty_test.txt` or `__test_rodrigo.txt`.
- The only allowed identifier tied to a person is the RCS change marker **`rj132422`**
  (an ID, not a name).

## Code comments
- Write all code comments in **English**.
- **Do not put any person's name in comments** (see the no-names rule above).
- Keep the RCS-style change marker **`rj132422`** on lines that were changed. Example:
  `# rj132422 - shared OEM incoming folder (was: per-OEM path)`
- One-line, technical, and describe the change plus the old value when useful.

## Editing scripts
- Always create a **`.bak`** of the current file before changing it.
- Prefer **minimal, reversible** changes (WinMerge-friendly diffs).
- Files must stay **LF** (Unix) line endings — never CRLF (breaks on RHEL/AIX). A `.gitattributes` enforces this.
- Validate shell syntax (`ksh -n` / `bash -n`) after edits.

## Deploy commands — always this format (RCS + prod_move)
- When handing over a deploy, give **three lines in ONE ```sh block** — all check-outs chained with
  `&&`, then all check-ins chained, then all prod_moves chained. Never one block per file.
- Shared/profile scripts (`race_<sub>.ksh`, `raceftp.ksh`, `oem_job_*.ksh`) live in `share/bin`;
  subsystem scripts live in `<sub>/bin` (`oem/bin`, `altp/bin`, `ext/bin`). Order matters: deploy the
  shared/profile script **first** — the others depend on the variables it exports.
- Template:
```sh
rcheck_out -l <file1> <dir1> && rcheck_out -l <file2> <dir2>

rcheck_in -d "AIX to RHEL migration" <file1> <dir1> && rcheck_in -d "AIX to RHEL migration" <file2> <dir2>

/prod/race/share/bin/prod_move <file1> <dir1> && /prod/race/share/bin/prod_move <file2> <dir2>
```

## prod3nt share is NFS-mounted — `${NOVELL}` has a local equivalent
- The prod3nt server is gone, but its share (`\\pawsvm7001a\cdprod02\ftp_data`) is **NFS-mounted**
  at `/<lvl>/ftp_data`, with the original folder tree intact:
  `altp  iaest  misc  oem  oem_research  race  usrdat`.
- So every legacy `${NOVELL}<folder>` maps to a plain local path — no scp, no key, no remote
  byte-count: `${NOVELL}oem` -> `/${ACT_LVL}/ftp_data/${ACT_LVL}/oem`.
- ALTP already uses this (`race_altp.ksh` exports `ALTP_FTP_DATA=/prod/ftp_data/prod`, deriving
  `ALTP_DIR`, `ALTP_NAPA_DIR`, `ALTP_INTRPT_DIR`, `ALTP_CUSTRPT_DIR`).
- For an `ascii` fileput, keep the CRLF conversion: `sed 's/\r*$/\r/' ${SRC} > ${DEST}`.
- **Before migrating a `${NOVELL}` transfer, decide the destination deliberately:** the NFS share
  (internal consumers who open it from Windows) or the Mitchell SFTP (external partners). They are
  different places; delivering to the wrong one "works" but nobody picks the file up.

## Environment quirks (get these right in commands)
- **`rm` wrapper differs by host:** on **RADD (dev, `dawapp7017l`)** the delete command is **`rmi`**;
  on **RADP (prod, `pawapp7017l`)** it is plain **`rm`**. Use the right one per host.
- Login shell is **ksh with `noclobber`** — `>` fails if the file exists. Use **`>|`** to overwrite.
- `oem_doc_repository` is a **symlink** to the NFS-mounted OEM doc repository, created per env
  (dev: `/mdev/oem_doc_repository` -> `/nas/mdev/OEM_Repair_Doc_Repository/oem_doc_repository`;
  prod: `/prod/oem_doc_repository` -> `/nas/prod/OEM_Repair_Doc_Repository/oem_doc_repository`).
  The scripts reference `${RACE}/../../oem_doc_repository`, so the symlink is mandatory — do not
  hardcode `/nas/...` paths in scripts.

## Migration context (prod3nt sunset)
- prod3nt / Novell / `${NOVELL}` / `fileget.exp` / `fileput.exp` are decommissioned — replace with `scp` / `ssh` to the Mitchell SFTP (`ftp-ssh.mitchell.com`).
- Mitchell base path var: `${FTP_MITCHELL_BUSINESS_PATH}` = `/prod/data/ftp/Business_Partners/mitchell`.
- Folders: `oem/incoming` (arrivals), `oem/outgoing` (RACE-produced / pre-processor output), `oem_research` (Editorial), `oem/incoming/backup` (archive).
- SFTP user var `${FTP_SFTP_USER}` = `race_b1@` in prod, empty in dev.

## Mitchell SFTP destination folders — group + permissions
- The `race_b1` SFTP account belongs to group **`OEMD`** (among others). Working delivery folders
  (e.g. `oem_research`) are `root:OEMD` mode `775`, so `race_b1` can write via the group.
- When a **new** destination folder is created on the Mitchell SFTP (e.g. `usrdat`), it may come
  as `root:root` → `race_b1` falls into "other" (`r-x`) → **scp fails with `Permission denied`**.
  Fix: ask Mitchell to `chgrp OEMD` (make it match `oem_research`). Create the same folder in both
  `mdev/` and `prod/` for the cutover.
- `usrdat` is a **manual/report** drop (consumed by people), mirrored under the Mitchell path:
  `${FTP_MITCHELL_BUSINESS_PATH}/${ACT_LVL}/usrdat`.

## ASCII (text) transfers — CRLF for Windows consumers
- The old `fileput.exp ... ascii` did LF->CRLF conversion. `scp` is binary, so when migrating an
  `ascii` transfer of a text report bound for Windows/Notepad, convert first:
  `sed 's/$/\r/' ${SRC} > ${SRC}.crlf` then `scp ${SRC}.crlf ...`, and compare byte counts on the
  `.crlf` file. Binary transfers (zip/dat) need no conversion.

## Network direction — always pull from RADP
- The flow is **RADP-initiated**: RADP/RADD → `ftp-ssh.mitchell.com` (scp/ssh) works.
- The **reverse (Mitchell SFTP host -> RADP) is firewalled/blocked.** To bring a file back, run the
  `scp` **on RADP pulling from Mitchell**, never push from the Mitchell server.

## Shared env: `raceftp.ksh` must carry `FTP_MITCHELL_BUSINESS_PATH`
- Subsystem env is loaded by `raceprofile.ksh` -> `race_<sub>.ksh` (e.g. `race_ext.ksh`) -> `. raceftp.ksh`.
  Jobs do **not** set FTP vars themselves; running a `.ksh` raw (outside the harness/subsystem menu)
  leaves them empty.
- The **deployed** `/<lvl>/race/share/bin/raceftp.ksh` must contain
  `export FTP_MITCHELL_BUSINESS_PATH=/prod/data/ftp/Business_Partners/mitchell`. A deployed copy
  missing this line makes every job build a wrong/empty Mitchell path. Also beware stale personal
  copies (e.g. `~/raceftp.ksh`) shadowing the share-bin one in `PATH`.

## ftp-ssh host key keeps changing (load-balanced)
- `ftp-ssh.mitchell.com` (10.0.23.119) presents different host keys over time (likely load-balanced
  nodes). `StrictHostKeyChecking accept-new` does NOT fix a *changed* (mismatched) key — remove the
  stale entry first: `ssh-keygen -R ftp-ssh.mitchell.com; ssh-keygen -R 10.0.23.119`, then reconnect.
  For the service accounts, `StrictHostKeyChecking no` + `UserKnownHostsFile /dev/null` on that Host
  block avoids recurring breakage.

## External SFTP password auth (Net::SFTP::Foreign) — force password-only
- `get_sftp_file.pl` uses `Net::SFTP::Foreign` with a password from the parm file (needs `IO::Pty`).
- If the job account's key is *also* authorized on the target (e.g. `bestfit` on `sftp-corp.mitchell.com`),
  ssh does a pubkey partial-auth that derails the module's password expect -> hangs at the prompt.
  Fix per host in `~/.ssh/config`: `PubkeyAuthentication no` + `PreferredAuthentications password`.

## CHAR -> VARCHAR2 regression breaks space-padded DELETE (+100 abend)
- Symptom: a COBOL update program (e.g. `mptz026`) abends with `SQLCODE +100 / NO ROWS FOUND`
  in a DELETE paragraph (`R2300-DELETE-PART` -> `PKG_PART.P_PART_DEL_01`), even though the row exists.
- Cause: a char column (e.g. `PART.PART_NUMBER`) was **CHAR** on AIX (blank-padded compares) and is
  **VARCHAR2** on the new DB (`DUMP` shows `Typ=1 Len=11`, no trailing spaces). The COBOL passes the
  part number from a **fixed-width field** (space-padded) into the delete; VARCHAR2 uses non-blank-padded
  comparison, so `'K1D5-V3-540'` != `'K1D5-V3-540      '` -> 0 rows -> +100.
- Why only DELETE fails: UPDATE path uses the value read **from the DB** (`RS-DB-PART-NUM`, already
  trimmed) so it matches; only the DELETE/discontinue/supersession path uses the **transaction** value
  (padded, `TR-OLD-PART-NUM`). So updates work and only discontinue deletes blow up.
- Proof (no LogMiner needed): `SELECT COUNT(*) ... WHERE part_number='K1D5-V3-540'` = 1, but
  `... WHERE part_number=RPAD('K1D5-V3-540',25)` = 0. Records are correctly aligned (price column lines
  up for short and long part numbers) -> not a merge/CRLF/alignment problem.
- Fix is DB-side (not `.ksh`): make `P_PART_DEL_01` `RTRIM` the part number in its WHERE (restores
  pre-migration behavior, fixes all OEMs), or revert the column to CHAR. Do NOT just tolerate +100 —
  that would skip the discontinue. Likely latent in other procs comparing char columns to COBOL fixed
  fields if the cutover changed CHAR->VARCHAR2 broadly.

## Email recipient separator — ONLY spaces (always review this)
- On RHEL `mailx` is **s-nail**, which rejects **both `;` and `,`** between recipients.
  Proven in prod (mptr911): `MAIL_TO="a@x.com,b@x.com"` ->
  `s-nail: ... contains invalid byte ','` / `No recipients specified` / `message not sent` -> job abends rc=4.
- **The only valid separator is a single space.** The old AIX scripts used `;` and `,` freely.
- Whenever touching a script that sends mail, **check every recipient list** (`MAIL_RECIP`,
  `MAIL_TO`, `PROD_MAIL_*`, `TEST_MAIL_*`) and convert `;` and `,` to a single space. The call is
  usually `mailx -s "..." ${MAIL_TO}` (unquoted), so space-separated values word-split correctly.
- Mark the change with `rj132422` and note the old separator, e.g.
  `# rj132422 - space-separated for RHEL s-nail (was: ',' separator)`.

## `TESTHOST` is unset in prod — it holds the literal `TESTHOSTgoesHERE`
- Scripts branch TEST vs PROD with `if [ ${THISHOST} = ${TESTHOST} ]`. In RADP the log shows
  `[ pawapp7017l = TESTHOSTgoesHERE ]` — the variable was never given a real value.
- In prod this "works" by accident (no match -> PROD branch, which is correct there). **In dev it is
  dangerous**: `dawapp7017l` also fails to match, so a dev run takes the **PROD branch** and mails
  the production distribution lists. Verify `TESTHOST` before running anything mail-related in RADD.

## scp with a wildcard filename creates a literal `*` target (mptr045)
- When `input_file_name` contains a wildcard (e.g. `AP01186O_Level3_*.zip`), the GETIT path skips
  name resolution and passes the pattern through. The remote side expands it, but the **local
  destination keeps the literal `*`**, so scp ends up creating a *directory* named
  `mptr045_AP01186O_Level3_*.zip`. Then `[ ! -s ... ]` passes (a directory has size) and the job
  reports "Input file pulled ... is good" before `gunzip` fails with
  `is a directory -- ignored` -> abend rc=2.
- Fix: resolve the wildcard remotely first (`ssh -nq ${FTP_SITE} "ls -1 <dir>/<pattern>"`), take the
  concrete file name, and use **that** name for both the scp source and the local target.
  The old `fileget` resolved the real name before transferring; scp does not.
