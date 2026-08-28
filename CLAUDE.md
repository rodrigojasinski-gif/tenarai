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

## Email recipient separator (always review this)
- **`mailx` on RHEL does NOT accept `;` between recipients** — it needs **space** (or comma).
  The old AIX/Novell scripts used `;` (e.g. `MAIL_RECIP="a@x.com; b@x.com"`), which breaks on RHEL.
- Whenever touching a script that sends mail, **check every `MAIL_RECIP` / recipient list** and
  convert `;` separators to a single space. Since the call is usually `mailx -s "..." ${MAIL_RECIP}`
  (unquoted), space-separated values word-split into correct args.
- Mark the change with `rj132422` and note the old separator, e.g.
  `# rj132422 - space-separated for RHEL mailx (was: ';' separator)`.
