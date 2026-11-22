# Contributing

Thanks for helping! This project exists because many people lost their automatic Windows-to-Google-Photos backup when Google Drive for desktop dropped it in 2026, and the more people test it on real photo libraries, the better it gets.

You can write issues and pull requests **in any language**. English is the easiest for everyone to read, but it is not required.

## Ways to help

- **Test it** with files from your phone or camera (iPhone, Android, GoPro, DJI, mirrorless cameras...) and tell us how it went, especially dates and locations in Google Photos after a video was re-encoded.
- **Report a problem** or **suggest an idea** (see below).
- **Translate** or proofread the documentation.
- **Write code**: pick something from the roadmap in the [README](README.md#roadmap) or from the issues labeled `good first issue`.

## Reporting a problem

Open a [bug report](https://github.com/carlosnakazawa/gphotos-smart-backup/issues/new?template=bug_report.yml). The most useful information is:

- the Windows version and the PowerShell version (`$PSVersionTable.PSVersion`);
- `rclone version` and `ffmpeg -version` (first line);
- the command you ran and the console output around the error.

**Privacy:** never post your `rclone.conf` (it contains your Google tokens) or your `.sync_history.json` (it lists your file names). Replace personal file and folder names in logs if you prefer.

## Suggesting an idea

Open a [feature request](https://github.com/carlosnakazawa/gphotos-smart-backup/issues/new?template=feature_request.yml). Describe the problem first, then the solution you imagine.

## Code changes

1. Fork the repository and create a branch.
2. Read [AGENTS.md](AGENTS.md). Its guardrails apply to humans too: upload-only, never touch source files, keep the history format, ASCII-only `.ps1` files, Windows PowerShell 5.1 compatible.
3. Add or update tests in `tests/` when you change logic. Mock `rclone` and `ffmpeg` (`Invoke-ExternalTool`); tests must never upload anything.
4. Run the checks locally:

   ```powershell
   Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
   Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck
   .\scripts\Invoke-HarnessCheck.ps1
   ```

5. Try your change with `-WhatIf` on a test folder, and, if you can, a real run on a few files with your own Google account.
6. Open a pull request describing what changed, why, and how you tested it. Add an entry to [CHANGELOG.md](CHANGELOG.md) under `[Unreleased]`.

Using an AI coding agent? Great. Point it to [AGENTS.md](AGENTS.md), and review what it produces before you open the pull request.

## Translations

The documentation is available in English (the reference), Português (Brasil), Español, Français, Deutsch, Italiano, Русский, 日本語, 한국어 and 简体中文.

- **Fix a translation:** edit the file in `docs/` and open a pull request. Reviews by native speakers are very welcome.
- **Add a language:** copy `README.md` to `docs/README.<language-code>.md` (for example `README.hi.md`), translate it, keep commands and code unchanged (only comments are translated), fix relative links (`../`), and add the new language to the language bar at the top of **every** README. A test checks that all language links resolve.
- **Update translations:** when `README.md` changes, it is fine if a translation lags behind for a while. Each translation says that the English version is the reference.

## Code of conduct

Be kind and patient. Many users are not developers; they just want their photos safe. Harassment or disrespect is not tolerated.
