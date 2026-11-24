# Google Photos Smart Backup

[![CI](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![PowerShell 5.1 | 7](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)
![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4)
[![Contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](CONTRIBUTING.md)

**English** | [Português (Brasil)](docs/README.pt-BR.md) | [Español](docs/README.es.md) | [Français](docs/README.fr.md) | [Deutsch](docs/README.de.md) | [Italiano](docs/README.it.md) | [Русский](docs/README.ru.md) | [日本語](docs/README.ja.md) | [한국어](docs/README.ko.md) | [简体中文](docs/README.zh-CN.md)

Back up the photos and videos on your Windows PC to **Google Photos**, automatically, without keeping a browser tab open. Videos are **compressed to H.265 first** to save storage, and every upload is **checkpointed** so an interrupted run picks up where it stopped.

```text
=== gphotos-smart-backup v1.0.0 ===
Scanning: C:\Users\me\Pictures
Found 1250 media file(s): 1243 already uploaded, 7 new, 0 changed since their upload.
[1/7] 2026\Trip\IMG_0412.HEIC
  -> Uploading to gphotos:upload/IMG_0412.HEIC
  -> Done.
[2/7] 2026\Trip\VID_0413.MOV
  -> Transcoding video (H.265 CRF 24, veryfast)...
  -> 412.7 MB -> 96.3 MB (77% smaller)
  -> Uploading to gphotos:upload/VID_0413.MOV
  -> Done.
...
Uploaded 7 file(s). All done.
```

## Why this project exists

For years, Windows users could back up a folder to Google Photos with Google's desktop app ("Backup and Sync", then **Google Drive for desktop**). **That is over**:

- since **June 15, 2026**, Drive for desktop no longer lets you add folders to back up to Google Photos;
- on **August 10, 2026**, it stopped uploading new photos and videos to Google Photos altogether.

Google's replacement is "Back up folders" on [photos.google.com](https://photos.google.com), which **only runs while the Google Photos web page stays open in your browser**. There is no background backup for Windows anymore.

This project fills that gap with a small, transparent PowerShell script built on two well-known open-source tools, [rclone](https://rclone.org/googlephotos/) and [ffmpeg](https://ffmpeg.org/):

- it runs **unattended** (for example from Task Scheduler), with no browser and no Google app;
- it uploads **only what is new or changed**, keeping a local history of every file sent;
- it **shrinks videos** before upload. Files uploaded through the Google Photos API are always stored in **original quality and count towards your Google storage**, so a 4K video re-encoded to H.265 can save a lot of space;
- it **never deletes or moves anything**, neither on your PC nor in Google Photos.

**It is a community project, and help is very welcome.** If you were affected by the end of Drive for desktop backups, try it, [report what does not work](https://github.com/carlosnakazawa/gphotos-smart-backup/issues/new?template=bug_report.yml), suggest ideas, improve the translations or send a pull request. See [CONTRIBUTING.md](CONTRIBUTING.md). Any language is fine.

## Features

| | |
| --- | --- |
| **Incremental** | A JSON history (`relative path -> size + last modified time`) tells which files are already in Google Photos. New and edited files are uploaded; everything else is skipped in seconds. |
| **Resumable** | Each file is recorded right after its upload. If the PC sleeps, the network drops or you press Ctrl+C, the next run continues from the same file. |
| **Smart video compression** | H.265/HEVC with ffmpeg (`-crf 24 -preset veryfast` by default, tunable). The creation date and the location are kept, including the Apple `com.apple.quicktime.*` tags from iPhones. If the H.265 version is not smaller, the original is uploaded. Videos that are already compact (for example HEVC from recent iPhones) are detected with ffprobe and uploaded as they are, without wasting time on a re-encode. |
| **Albums (optional)** | `-AlbumPerFolder` puts the files of each subfolder into an album named after it. |
| **Safe** | Upload-only (`rclone copyto`). It does not follow symbolic links or junctions. `-WhatIf` previews everything without uploading. A corrupted history stops the run instead of uploading your whole library again. |
| **Friendly to automation** | Exit codes: `0` success, `1` error (stopped), `2` done but some videos could not be transcoded. |

Supported by default: `.jpg .jpeg .png .heic .heif .webp .gif` (photos) and `.mp4 .mov .m4v` (videos). RAW files (`.dng`, `.arw`, `.cr2`, ...) and sidecar files (`.lrf`, `.xmp`, ...) are left out on purpose. Add them with `-PhotoExtensions` if you want.

## How it works

```text
 Your folder ──scan──> new or changed? ──no──> skip
                              │ yes
                              v
                     video? ──yes──> ffmpeg H.265 (staging folder) ──> smaller? ──no──> use the original
                              │ no                                          │ yes
                              v                                             v
                     rclone copyto ──> Google Photos ──> record in .sync_history.json ──> next file
```

## Requirements

- Windows 10 or 11, with Windows PowerShell 5.1 (built in) or PowerShell 7+
- [rclone](https://rclone.org/) (a recent version; v1.70 or newer recommended)
- [ffmpeg](https://ffmpeg.org/) with `libx265` (only for video compression; not needed with `-NoTranscode`)
- A Google account and a free Google Cloud project (for your own OAuth client, see below)

No administrator rights are needed.

## Setup

### 1. Install rclone and ffmpeg

```powershell
winget install Rclone.Rclone
winget install Gyan.FFmpeg
```

Open a new terminal afterwards so that both are on `PATH`.

### 2. Create your own Google OAuth client

rclone's shared Google Photos client ID is being retired during 2026. You need your own, which is free and takes about 5 minutes:

1. Open the [Google Cloud Console](https://console.cloud.google.com/) and create a project (for example `gphotos-backup`).
2. **APIs & Services > Library**: enable the **Photos Library API**.
3. **Google Auth Platform > Branding / Audience**: choose **External**, fill in the app name and your email, and add your Google account as a **test user**.
4. **Data Access > Add or remove scopes**: add these three scopes:
   `https://www.googleapis.com/auth/photoslibrary.appendonly`,
   `https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata`,
   `https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata`.
5. **Clients > Create client**: type **Desktop app**. Copy the **client ID** and the **client secret**.
6. Recommended: in **Audience**, click **Publish app**. While the app is in "Testing", Google expires the login every 7 days. You will see a "Google hasn't verified this app" warning when you sign in. That is expected, because this is your own app.

The rclone documentation has more details: [Google Photos: making your own client ID](https://rclone.org/googlephotos/).

### 3. Configure the rclone remote

```powershell
rclone config
```

Answer: `n` (new remote), name **`gphotos`**, storage **Google Photos**, paste your `client_id` and `client_secret`, `read_only` = **false**, then let rclone open the browser and sign in. Check it with:

```powershell
rclone lsd gphotos:
```

If you upgraded rclone from an older version and get permission errors, run `rclone config reconnect gphotos:`.

### 4. Download the script and preview

```powershell
git clone https://github.com/carlosnakazawa/gphotos-smart-backup.git
cd gphotos-smart-backup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1 -WhatIf
```

`-ExecutionPolicy Bypass` applies only to this process. If you downloaded the ZIP, you can run `Get-ChildItem -Recurse | Unblock-File` first. `-WhatIf` lists what would be uploaded and changes nothing.

### 5. Run it

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1
```

## Usage

```powershell
# Your Pictures folder to gphotos:upload (defaults)
.\gphotos-backup.ps1

# Another folder, one album per subfolder
.\gphotos-backup.ps1 -SourcePath 'D:\Camera' -AlbumPerFolder

# Smaller videos (slower encoding)
.\gphotos-backup.ps1 -Crf 26 -Preset medium

# Upload videos as they are
.\gphotos-backup.ps1 -NoTranscode

# Skip some folders and include DNG files
.\gphotos-backup.ps1 -ExcludeFolder 'Screenshots', '_Upload_Staging' -PhotoExtensions '.jpg', '.jpeg', '.png', '.heic', '.dng'

# Full help
Get-Help .\gphotos-backup.ps1 -Detailed
```

| Parameter | Default | Description |
| --- | --- | --- |
| `-SourcePath` | your Pictures folder | Folder with the originals (subfolders included). |
| `-RcloneRemote` | `gphotos:upload` | rclone destination. `upload` puts files in the library without an album. |
| `-AlbumPerFolder` | off | Files in `2024\Trip\` go to the album `2024/Trip`. Files at the top level go to `-RcloneRemote`. |
| `-HistoryFile` | `Pictures\.sync_history.json` | Upload history. One file can be shared by several source folders. |
| `-StagingPath` | `%TEMP%\gphotos-smart-backup` | Temporary folder for transcoded videos (emptied after each file). |
| `-Crf` | `24` | H.265 quality, from 0 to 51. Lower values give better quality and bigger files. 22 to 28 is a sensible range. |
| `-Preset` | `veryfast` | x265 speed. `medium` and `slow` give smaller files but take longer. |
| `-NoTranscode` | off | Do not use ffmpeg. |
| `-SkipTranscodeBelowMbps` | `4` | Upload a video as it is when its bit rate, normalized to 1080p at 30 fps, is at or below this value (twice the value for HEVC, AV1 and VP9). `0` transcodes every video. |
| `-PhotoExtensions` / `-VideoExtensions` | see above | File types to upload. |
| `-ExcludeFolder` | `_Upload_Staging` | Folder names to skip at any depth. |
| `-RclonePath` / `-FfmpegPath` / `-FfprobePath` | `rclone` / `ffmpeg` / next to ffmpeg | Executables, if they are not on `PATH`. |
| `-WhatIf` / `-Confirm` | | Preview, or confirm each file. |

Any rclone option can be set through environment variables, for example `$env:RCLONE_BWLIMIT = '4M'` to limit the upload bandwidth.

## Scheduling (automatic backup)

Run it every evening with Task Scheduler. The task runs as you, while you are signed in, so rclone finds your configuration and no password is stored:

```powershell
$script = 'C:\Tools\gphotos-smart-backup\gphotos-backup.ps1'   # adjust
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 21:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 12)
Register-ScheduledTask -TaskName 'gphotos-smart-backup' -Action $action -Trigger $trigger -Settings $settings

# Remove it
Unregister-ScheduledTask -TaskName 'gphotos-smart-backup' -Confirm:$false
```

If a run is interrupted, the next one simply continues.

## The history file

`.sync_history.json` maps each file's path relative to `-SourcePath` to `<size>_<last-write-time-ticks>`:

```json
{
    "2026\\Trip\\IMG_0412.HEIC": "2735969_639012345670000000"
}
```

- Delete an entry to upload that file again. Renaming the history file starts a full upload from scratch.
- If you edit a photo, its size or date changes and it is uploaded again. Google Photos keeps both versions.
- The file contains your file names. Keep it private (it is in `.gitignore`).
- It uses the same format and default location as the first version of the script, so existing histories keep working.

## Good to know (limitations)

- **Storage:** uploads through the API are always "Original quality" and count towards your Google storage. There is no "Storage saver" option in the API. This is why videos are compressed.
- **Dates:** Google Photos uses the EXIF/metadata date. Files without one (some screenshots, messaging app images) show the upload date.
- **Duplicates:** Google Photos recognizes identical files, so uploading the same file twice does not create a copy. A re-encoded video is a different file, though.
- **Deleted in Google Photos?** The script does not check Google Photos. A file listed in the history is not uploaded again, even if you deleted it online.
- **HDR / Dolby Vision** videos may lose their HDR look after re-encoding. Use `-NoTranscode` (or exclude those folders) if this matters to you.
- **What rclone can see:** since March 31, 2025, Google only lets apps read the media they uploaded themselves. This tool only uploads, so that is not a problem.
- **Quotas:** the Google Photos API has daily request limits. A very large first upload may need several runs. The history makes this painless.

## What it does not do

- It never deletes, moves or modifies your local files.
- It never deletes anything in Google Photos (only `rclone copyto` is used, and a guardrail test enforces it).
- It sends no data anywhere other than Google Photos, through your own rclone remote.

## Development

```powershell
# Fast static checks (syntax, ASCII-only, guardrails)
.\scripts\Invoke-HarnessCheck.ps1 -SkipAnalyzer -SkipPester

# Everything (needs PSScriptAnalyzer 1.25.0 and Pester 5.5+)
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck
.\scripts\Invoke-HarnessCheck.ps1
```

The CI runs the analyzer, the Pester tests (rclone and ffmpeg are mocked) and a `-WhatIf` smoke test on **Windows Server 2022 and 2025**, with both **Windows PowerShell 5.1 and PowerShell 7**.

The `.ps1` files are **ASCII-only** on purpose: Windows PowerShell 5.1 reads BOM-less files with the ANSI code page, so accented characters would break the script. A test enforces this.

AI coding agents: read [AGENTS.md](AGENTS.md) first.

## Contributing

Bug reports, ideas, translations and pull requests are welcome, in any language. See [CONTRIBUTING.md](CONTRIBUTING.md). Good first contributions:

- test it with your camera or phone files and report the results;
- improve a translation, or add your language;
- pick an item from the roadmap.

## Roadmap

- `Register-BackupTask.ps1` helper to create the scheduled task in one command.
- Optional hardware encoding (NVENC, Quick Sync, AMF) for faster transcoding.
- Keep HDR metadata when re-encoding.
- Log file and JSON run report.
- Publish to the PowerShell Gallery and `winget`.

## License

[MIT](LICENSE) © Carlos Alberto Nakazawa

*This project is not affiliated with, endorsed or sponsored by Google. Google Photos and Google Drive are trademarks of Google LLC.*
