# CLAUDE.md

@AGENTS.md

## Claude Code Harness Notes

- [AGENTS.md](AGENTS.md) is the single source of truth for architecture, guardrails and verification. Do not duplicate or contradict it here.
- Before committing, run `.\scripts\Invoke-HarnessCheck.ps1`. If PSScriptAnalyzer or Pester 5 is not installed, run it with `-SkipAnalyzer -SkipPester`, say so, and rely on the GitHub Actions run.
- Never run `gphotos-backup.ps1` without `-WhatIf`, and always point `-SourcePath`, `-HistoryFile` and `-StagingPath` at a temporary folder, unless the user explicitly asks for a live upload in this session.
- [.claude/settings.json](.claude/settings.json) denies destructive `rclone` commands and reading `rclone.conf` / `.sync_history.json`. Do not work around these rules. Ask the user instead.
- This machine may only have Windows PowerShell 5.1. Test there first. PS 5.1 is the strictest target (encoding, syntax, array unrolling).
- When a fact about Google Photos, Google Drive or rclone matters (dates, API limits, scopes), check the current official docs instead of relying on memory, and cite the link in the PR.
