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

## Email recipient separator (always review this)
- **`mailx` on RHEL does NOT accept `;` between recipients** — it needs **space** (or comma).
  The old AIX/Novell scripts used `;` (e.g. `MAIL_RECIP="a@x.com; b@x.com"`), which breaks on RHEL.
- Whenever touching a script that sends mail, **check every `MAIL_RECIP` / recipient list** and
  convert `;` separators to a single space. Since the call is usually `mailx -s "..." ${MAIL_RECIP}`
  (unquoted), space-separated values word-split into correct args.
- Mark the change with `rj132422` and note the old separator, e.g.
  `# rj132422 - space-separated for RHEL mailx (was: ';' separator)`.
