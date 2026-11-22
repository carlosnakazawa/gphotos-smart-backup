# Security Policy

## Supported Versions

Security fixes are provided for the latest `1.x` release on the `main` branch.

## Reporting a Vulnerability

Please do **not** report security vulnerabilities through public GitHub issues.

Report them privately using [GitHub Security Advisories](https://github.com/carlosnakazawa/gphotos-smart-backup/security/advisories/new).

Please include:

- a description of the vulnerability and its potential impact;
- steps to reproduce (Windows version, PowerShell version, rclone version and the command used);
- any suggested mitigation or fix, if you have one.

Examples of what we consider security issues: the script deleting or overwriting local files, uploading files outside `-SourcePath`, leaking tokens or file names, or executing unexpected programs.

## Security Considerations for Users

- **Your rclone configuration holds your Google OAuth token.** It is stored in `%APPDATA%\rclone\rclone.conf`. Anyone who can read that file can upload to your Google Photos. Do not share it, and consider protecting it with `rclone config` encryption (`s) Set configuration password`). If you encrypt it, set `RCLONE_CONFIG_PASS` for the scheduled task, or the task will not be able to run unattended.
- **Least privilege.** Your own OAuth client only needs the three `photoslibrary` scopes listed in the README (`appendonly`, `readonly.appcreateddata`, `edit.appcreateddata`). They do not give access to photos uploaded by other apps.
- **The history file lists your file names.** `.sync_history.json` is private data; do not publish it.
- **Run as a normal user.** The script does not need administrator rights. Do not run the scheduled task as SYSTEM or as an administrator.
- **Review before you run.** The script is a single readable file. Use `-WhatIf` first, and download it only from this repository.
