# AGENTS.md

Canonical instructions and guardrails for AI coding agents (Claude Code, Codex, Copilot, Cursor, Gemini and others) working in `gphotos-smart-backup`. Humans are welcome to read it too.

## Project Overview

`gphotos-smart-backup` is a single PowerShell script that backs up new photos and videos from a Windows folder to Google Photos through `rclone`, optionally re-encoding videos to H.265 with `ffmpeg` first, and recording every upload in a JSON history (checkpoint) so runs are incremental and resumable. It exists because Google Drive for desktop stopped uploading to Google Photos on 2026-08-10.

| File | Responsibility |
| --- | --- |
| [gphotos-backup.ps1](gphotos-backup.ps1) | Entry point and all logic: scan, history, transcode, upload, checkpoint. Functions first, then a dot-source guard, then the entry point. |
| [tests/gphotos-backup.Tests.ps1](tests/gphotos-backup.Tests.ps1) | Pester 5.5+ tests: helpers, scan, history, end-to-end with mocked `rclone`/`ffmpeg`, ASCII and documentation links. |
| [scripts/Invoke-HarnessCheck.ps1](scripts/Invoke-HarnessCheck.ps1) | Deterministic verification harness (AST parse, ASCII, guardrails, PSScriptAnalyzer, Pester). |
| [PSScriptAnalyzerSettings.psd1](PSScriptAnalyzerSettings.psd1) | Static analysis rules (PowerShell 5.1 and 7.4 syntax compatibility). |
| [.github/workflows/ci.yml](.github/workflows/ci.yml) | CI: harness + analyzer + Pester + `-WhatIf` smoke test on Windows Server 2022/2025 x PS 5.1/7. |
| [README.md](README.md) and `docs/README.*.md` | Documentation in 10 languages. `README.md` (English) is the reference. |
| [.claude/settings.json](.claude/settings.json) | Deny list for destructive `rclone` commands and for reading private files. |

### Data flow

```text
Get-MediaFile (no reparse points, excluded folders)
  -> Get-RelativeMediaPath + Get-MediaFileStamp   (history key + value)
  -> compare with Read-BackupHistory
  -> per file: [Get-VideoTranscodeArgument -> Invoke-ExternalTool ffmpeg] -> Invoke-ExternalTool rclone copyto
  -> Save-BackupHistory (atomic write) after EACH successful upload
```

All native calls go through `Invoke-ExternalTool`, which is the single point to mock in tests.

## Non-Negotiable Guardrails

### 1. Never lose or leak the user's photos

- **Upload-only.** The script may only use `rclone copyto` (and `rclone listremotes`). Never add `sync`, `move`, `moveto`, `delete`, `deletefile`, `purge`, `rmdir`, `rmdirs`, `cleanup` or `dedupe`. The harness fails if one of these appears as a string literal.
- **Never touch source files.** No `Remove-Item`, `Move-Item`, `Rename-Item` or `Set-ItemProperty` on anything under `-SourcePath`. The only files the script deletes are its own staged copies in `-StagingPath`.
- **No symlink/junction traversal.** Keep skipping `ReparsePoint` directories in `Get-MediaFile`.
- **Fail closed on a bad history.** A corrupted history file must stop the run (exit `1`), never reset to empty, because that would re-upload the whole library.

### 2. History file compatibility (users already have one)

- Keep the key = path relative to `-SourcePath` with backslashes, and the value = `"<Length>_<LastWriteTimeUtc.Ticks>"` (`Get-MediaFileStamp`).
- Keep the default location `[Environment]::GetFolderPath('MyPictures')\.sync_history.json`, independent of `-SourcePath`.
- Write it atomically (`Save-BackupHistory`: temp file + `File.Replace`), right after each successful upload, and only then.
- If you must change the format, add a reader for the old one and a Pester test with a legacy fixture.

### 3. Safe agent execution

- **Never run the script live.** Use `-WhatIf` and always pass `-SourcePath`, `-HistoryFile` and `-StagingPath` pointing to a temporary folder (`$env:TEMP`, Pester `TestDrive:`). A live run uploads private photos to someone's Google account and consumes their storage, and it cannot be undone through the API.
- **Never read or print** the user's `.sync_history.json`, `rclone.conf`, or `rclone config show` output. They contain private file names and OAuth tokens.
- **Tests must not reach the real Pictures folder.** Every end-to-end test passes `-HistoryFile` explicitly (the default points to the real one) and mocks `Invoke-ExternalTool`, `Test-CommandAvailable` and `Get-RcloneRemoteList`.

### 4. PowerShell 5.1 and encoding compatibility

- **ASCII-only `.ps1` files** (every byte `<= 127`). Windows PowerShell 5.1 reads BOM-less UTF-8 as ANSI.
- **PS 5.1 + PS 7 syntax only.** No `??`, `??=`, `?.`, `?[]`, ternary `?:`, `&&`, `||`, `ForEach-Object -Parallel`, `ConvertFrom-Json -AsHashtable`, or `Join-Path` with more than one child path.
- **Dot-source safety.** Keep `if ($MyInvocation.InvocationName -eq '.') { return }` before the entry point, and do not use `$PSScriptRoot` in `param()` defaults.
- **Arrays from functions.** Wrap calls in `@()` when you need an array. PowerShell unrolls one-element arrays, and `'.jpg' + '.mp4'` would become a string (this bug already happened once).
- **`.NET` paths.** Resolve paths with `Resolve-FullPath` before calling `[System.IO.File]` methods, because .NET uses the process directory, not the PowerShell location.
- **No built-in cmdlet shadowing.** Use approved verbs and singular nouns. Console output goes through `Show-BackupMessage`.

### 5. Media correctness

- Keep `-map_metadata 0 -movflags +use_metadata_tags` in `Get-VideoTranscodeArgument`. Without `use_metadata_tags`, iPhone videos lose their creation date and location (verified with ffprobe).
- Keep the "upload the original if the H.265 file is not smaller" rule.
- The Google Photos `upload` folder is flat. Only the file name goes after `remote:upload/`. Albums are `remote:album/<name>/<file>`.

### 6. Documentation

- `README.md` is the reference. When you change behavior or parameters, update it, and add the same change to the translations when you can (an outdated translation is acceptable; a wrong one is not).
- Every language README must link to all others, and every relative link must resolve. Pester enforces both.
- Update [CHANGELOG.md](CHANGELOG.md) under `[Unreleased]` for user-visible changes.
- Facts about Google or rclone behavior (dates, quotas, API limits) need a source link in the PR.

## Verification Harness (Run Before Finishing)

```powershell
# Fast static checks (AST parse, ASCII-only, guardrails)
.\scripts\Invoke-HarnessCheck.ps1 -SkipAnalyzer -SkipPester

# Full local verification (requires PSScriptAnalyzer 1.25.0 and Pester 5.5+)
.\scripts\Invoke-HarnessCheck.ps1

# Safe end-to-end preview on throwaway data
$tmp = Join-Path $env:TEMP 'gphotos-smoke'
New-Item -ItemType Directory -Force "$tmp\src\2024" | Out-Null
Set-Content "$tmp\src\2024\a.jpg" 'x'
.\gphotos-backup.ps1 -SourcePath "$tmp\src" -HistoryFile "$tmp\history.json" -StagingPath "$tmp\staging" -WhatIf
```

Definition of done:

1. The harness passes: 0 PSScriptAnalyzer issues, all Pester tests green, on Windows PowerShell 5.1 (and PowerShell 7 if available).
2. Every new behavior or bug fix has a Pester test that fails without the change. Mock native tools; never call real `rclone`/`ffmpeg` in tests.
3. Docs and changelog are updated when behavior changes.
4. Commits are small, focused and written in English, in the imperative mood (`Add ...`, `Fix ...`).
