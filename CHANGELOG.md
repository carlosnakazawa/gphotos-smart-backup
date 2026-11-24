# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0] - 2026-11-24

### Added

- Videos that are already compact are uploaded as they are, without spending time on a re-encode that would not save space. ffprobe reads the codec, resolution, frame rate and bit rate; the bit rate is normalized to 1080p at 30 fps and compared with `-SkipTranscodeBelowMbps` (default `4`, doubled for HEVC, AV1 and VP9 sources). For example, a typical iPhone 4K HEVC video is uploaded directly, while a 100 Mbps HEVC video from an action cam is still compressed.
- `-FfprobePath`. By default ffprobe is looked up next to ffmpeg. Without ffprobe, every video is transcoded as before. Cover art or thumbnails embedded in MP4/M4V files are ignored when probing.
- The summary shows how many videos were uploaded without re-encoding.

### Changed

- `-SkipTranscodeBelowMbps 0` restores the 1.0.0 behavior (every video is transcoded). The "upload the original if the H.265 file is not smaller" rule still applies in all cases.

## [1.0.0] - 2026-11-22

First public release.

### Added

- `-WhatIf` and `-Confirm`: preview what would be uploaded without transcoding, uploading or changing the history.
- `-AlbumPerFolder`: upload the files of each subfolder to an album named after it.
- `-Crf`, `-Preset` and `-NoTranscode` to control video compression.
- `-PhotoExtensions`, `-VideoExtensions` and `-ExcludeFolder`. HEIC/HEIF, WebP, GIF and M4V are supported by default.
- `-RclonePath` and `-FfmpegPath`.
- Checks before uploading: rclone and ffmpeg are installed, and the rclone remote exists.
- The H.265 version is uploaded only when it is smaller than the original. The summary shows how much space it saved.
- The summary separates new files from files that changed since their upload.
- Exit codes: `0` success, `1` error, `2` finished with skipped videos.
- Pester tests, PSScriptAnalyzer rules, a verification harness and a GitHub Actions workflow on Windows Server 2022 and 2025 with Windows PowerShell 5.1 and PowerShell 7.
- Documentation in 10 languages, `AGENTS.md` / `CLAUDE.md` for AI coding agents, contribution guide and security policy.

### Changed

- Video metadata: `-movflags +use_metadata_tags` keeps the creation date and the location of iPhone videos (Apple `com.apple.quicktime.*` tags), which were lost before.
- Uploads to `remote:upload` use the file name only. The Google Photos `upload` folder is flat; the relative path was sent before.
- Photos are uploaded directly from the source folder instead of being copied to the staging folder first.
- The default staging folder moved from `Pictures\_Upload_Staging` to `%TEMP%\gphotos-smart-backup`, so it is not synced by OneDrive. `_Upload_Staging` folders are skipped by default.
- The history file is written atomically (temporary file, then replace), so a crash cannot leave it half-written.
- A corrupted history file now stops the run instead of silently starting a new one, which would re-upload everything.
- Symbolic links and junctions are no longer followed while scanning. macOS `._*` metadata files are ignored.
- Native tools are called directly instead of through `Start-Process`, so paths with spaces and special characters are passed correctly.

### Compatibility

- The history file keeps the same format (`relative path -> <size>_<LastWriteTimeUtc ticks>`) and the same default location (`Pictures\.sync_history.json`), so existing histories keep working.

## [0.1.0]

### Added

- First version: scan a folder, transcode videos to H.265 with ffmpeg, upload with `rclone copyto` and record each upload in `.sync_history.json`.
