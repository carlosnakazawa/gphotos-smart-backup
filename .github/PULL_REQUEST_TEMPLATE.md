## Summary

<!-- What changed and why. You can write in any language. -->

## Checklist

- [ ] `.\scripts\Invoke-HarnessCheck.ps1` passes (syntax, ASCII, guardrails, PSScriptAnalyzer, Pester)
- [ ] `.ps1` files are **ASCII-only** and work on **Windows PowerShell 5.1** and **PowerShell 7+**
- [ ] Added or updated Pester tests for logic changes (`rclone`/`ffmpeg` mocked, `-HistoryFile` passed explicitly)
- [ ] Guardrails respected: upload-only, source files never modified, history format and default location unchanged, corrupted history fails closed
- [ ] Updated [README.md](README.md) (and translations when possible) and [CHANGELOG.md](CHANGELOG.md) if user-facing behavior changed
- [ ] Linked an official source for any claim about Google Photos / Google Drive / rclone behavior

## Testing

- Windows / PowerShell version:
- rclone / ffmpeg version:
- Commands run (`-WhatIf` and/or real upload of a few files):
