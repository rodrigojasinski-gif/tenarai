# Project rules — RACE OEM / MAPP (AIX → RHEL/AWS migration)

## Code comments
- Write all code comments in **English**.
- **Do not put any person's name in comments** (no Julian, Patty, Lorena, etc.).
- Keep the RCS-style change marker **`rj132422`** on lines that were changed. Example:
  `# rj132422 - shared OEM incoming folder (was: per-OEM path)`
- One-line, technical, and describe the change plus the old value when useful.

## Editing scripts
- Always create a **`.bak`** of the current file before changing it.
- Prefer **minimal, reversible** changes (WinMerge-friendly diffs).
- Files must stay **LF** (Unix) line endings — never CRLF (breaks on RHEL/AIX). A `.gitattributes` enforces this.
- Validate shell syntax (`ksh -n` / `bash -n`) after edits.

## Migration context (prod3nt sunset)
- prod3nt / Novell / `${NOVELL}` / `fileget.exp` / `fileput.exp` are decommissioned — replace with `scp` / `ssh` to the Mitchell SFTP (`ftp-ssh.mitchell.com`).
- Mitchell base path var: `${FTP_MITCHELL_BUSINESS_PATH}` = `/prod/data/ftp/Business_Partners/mitchell`.
- Folders: `oem/incoming` (arrivals), `oem/outgoing` (RACE-produced / pre-processor output), `oem_research` (Editorial), `oem/incoming/backup` (archive).
- SFTP user var `${FTP_SFTP_USER}` = `race_b1@` in prod, empty in dev.
