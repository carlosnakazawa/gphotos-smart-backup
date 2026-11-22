<#
.SYNOPSIS
    Backs up new photos and videos from a Windows folder to Google Photos with rclone.
    Videos are shrunk to H.265 first, and every uploaded file is recorded so it is never sent twice.

.DESCRIPTION
    gphotos-smart-backup replaces the "Back up to Google Photos" feature that Google Drive for
    desktop dropped in August 2026. It scans a folder, finds photos and videos that were not
    uploaded yet (or that changed), and uploads them one at a time:

      1. Videos are transcoded to H.265/HEVC (CRF 24 by default) with ffmpeg, keeping the
         creation date and location metadata. If the result is not smaller, the original is sent.
      2. The file is uploaded with "rclone copyto" to a Google Photos remote.
      3. The upload is written to a JSON history file immediately (checkpoint), so an interrupted
         run resumes where it stopped.

    Uploads through the Google Photos API are stored in original quality and count towards your
    Google storage quota, which is why videos are compressed before upload.

    Exit codes: 0 = success, 1 = fatal error (nothing more was uploaded), 2 = finished but some
    videos could not be transcoded and were skipped.

.PARAMETER SourcePath
    Folder that contains the original photos and videos. Default: your Pictures folder.

.PARAMETER RcloneRemote
    rclone destination for uploads, in the form "<remote>:upload" (default "gphotos:upload").
    Files land in the library without an album.

.PARAMETER AlbumPerFolder
    Upload files that are inside a subfolder to an album named after that subfolder
    (for example "2024\Trip\a.jpg" goes to the album "2024/Trip"). Files directly in SourcePath
    still go to RcloneRemote.

.PARAMETER HistoryFile
    JSON history of uploaded files. Default: ".sync_history.json" in your Pictures folder (the same
    file earlier versions used, whatever SourcePath is).

.PARAMETER StagingPath
    Temporary folder for transcoded videos. Default: "%TEMP%\gphotos-smart-backup".

.PARAMETER Crf
    H.265 constant rate factor (0-51). Lower is better quality and bigger files. Default 24.

.PARAMETER Preset
    x265 speed preset. Slower presets give smaller files for the same quality. Default "veryfast".

.PARAMETER NoTranscode
    Upload videos as they are, without ffmpeg.

.PARAMETER PhotoExtensions
    Photo file extensions to upload. RAW files are not included by default.

.PARAMETER VideoExtensions
    Video file extensions to upload (and transcode).

.PARAMETER ExcludeFolder
    Folder names to skip anywhere in the tree. "_Upload_Staging" (the staging folder of older
    versions) is skipped by default.

.PARAMETER RclonePath
    rclone executable. Default: "rclone" from PATH.

.PARAMETER FfmpegPath
    ffmpeg executable. Default: "ffmpeg" from PATH.

.EXAMPLE
    .\gphotos-backup.ps1 -WhatIf

    Lists what would be uploaded, without transcoding, uploading or changing the history.

.EXAMPLE
    .\gphotos-backup.ps1 -SourcePath 'D:\Camera' -AlbumPerFolder

.EXAMPLE
    .\gphotos-backup.ps1 -Crf 26 -Preset medium -ExcludeFolder 'Screenshots', '_Upload_Staging'

.LINK
    https://github.com/carlosnakazawa/gphotos-smart-backup
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $SourcePath = [Environment]::GetFolderPath('MyPictures'),
    [string] $RcloneRemote = 'gphotos:upload',
    [switch] $AlbumPerFolder,
    [string] $HistoryFile,
    [string] $StagingPath = (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'gphotos-smart-backup'),
    [ValidateRange(0, 51)]
    [int] $Crf = 24,
    [ValidateSet('ultrafast', 'superfast', 'veryfast', 'faster', 'fast', 'medium', 'slow', 'slower', 'veryslow')]
    [string] $Preset = 'veryfast',
    [switch] $NoTranscode,
    [string[]] $PhotoExtensions = @('.jpg', '.jpeg', '.png', '.heic', '.heif', '.webp', '.gif'),
    [string[]] $VideoExtensions = @('.mp4', '.mov', '.m4v'),
    [string[]] $ExcludeFolder = @('_Upload_Staging'),
    [string] $RclonePath = 'rclone',
    [string] $FfmpegPath = 'ffmpeg'
)

$script:AppVersion = '1.0.0'

function Show-BackupMessage {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive tool: colored console output.')]
    param(
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [string] $Message,
        [ValidateSet('Info', 'Step', 'Detail', 'Success', 'Warning', 'Error')] [string] $Level = 'Info'
    )
    $colors = @{ Info = 'Cyan'; Step = 'White'; Detail = 'Gray'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red' }
    Write-Host $Message -ForegroundColor $colors[$Level]
}

function Resolve-FullPath {
    # Resolves relative paths against the PowerShell location (not the process directory)
    # and works for paths that do not exist yet.
    param([Parameter(Mandatory = $true)] [string] $Path)
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $full = [System.IO.Path]::GetFullPath($resolved)
    if ($full.Length -gt 3) { $full = $full.TrimEnd('\', '/') }
    return $full
}

function Test-PathUnder {
    param([string] $Path, [string] $Parent)
    if ([string]::IsNullOrEmpty($Parent)) { return $false }
    $p = $Path.TrimEnd('\') + '\'
    $root = $Parent.TrimEnd('\') + '\'
    return $p.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-ExtensionList {
    param([string[]] $Extension)
    @($Extension | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
            '.' + $_.Trim().TrimStart('.').ToLowerInvariant()
        })
}

function Get-RelativeMediaPath {
    param([Parameter(Mandatory = $true)] [string] $Root, [Parameter(Mandatory = $true)] [string] $FullName)
    $rootPrefix = $Root.TrimEnd('\') + '\'
    if (-not $FullName.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "File '$FullName' is not inside '$Root'."
    }
    return $FullName.Substring($rootPrefix.Length)
}

function Get-MediaFileStamp {
    # Same format as the history written by earlier versions: "<size>_<last write UTC ticks>".
    param([Parameter(Mandatory = $true)] [System.IO.FileInfo] $File)
    return ('{0}_{1}' -f $File.Length, $File.LastWriteTimeUtc.Ticks)
}

function Get-MediaFile {
    # Walks the tree without following symbolic links or junctions (no loops, no surprises).
    param(
        [Parameter(Mandatory = $true)] [string] $Root,
        [Parameter(Mandatory = $true)] [string[]] $Extension,
        [string[]] $ExcludeFolder = @(),
        [string[]] $ExcludePath = @()
    )
    $pending = New-Object -TypeName 'System.Collections.Generic.Queue[System.IO.DirectoryInfo]'
    $pending.Enqueue((New-Object -TypeName System.IO.DirectoryInfo -ArgumentList $Root))
    while ($pending.Count -gt 0) {
        $directory = $pending.Dequeue()
        try {
            $entries = $directory.GetFileSystemInfos()
        }
        catch {
            Write-Warning "Cannot read folder '$($directory.FullName)': $($_.Exception.Message)"
            continue
        }
        foreach ($entry in ($entries | Sort-Object -Property Name)) {
            if ($entry -is [System.IO.DirectoryInfo]) {
                if ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
                if ($ExcludeFolder -contains $entry.Name) { continue }
                $excluded = $false
                foreach ($path in $ExcludePath) {
                    if (Test-PathUnder -Path $entry.FullName -Parent $path) { $excluded = $true; break }
                }
                if (-not $excluded) { $pending.Enqueue($entry) }
            }
            elseif ($Extension -contains $entry.Extension.ToLowerInvariant()) {
                # "._name.jpg" files are macOS metadata, not photos.
                if ($entry.Name.StartsWith('._')) { continue }
                $entry
            }
        }
    }
}

function Read-BackupHistory {
    # Returns a case-insensitive hashtable: relative path -> stamp. Throws when the file is corrupted,
    # so the caller can stop instead of uploading the whole library again.
    param([Parameter(Mandatory = $true)] [string] $Path)
    $history = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $history }
    $raw = [System.IO.File]::ReadAllText($Path)
    if ([string]::IsNullOrWhiteSpace($raw)) { return $history }
    $data = ConvertFrom-Json -InputObject $raw
    if ($data -isnot [System.Management.Automation.PSCustomObject]) {
        throw 'The history file does not contain a JSON object.'
    }
    foreach ($property in $data.PSObject.Properties) {
        $history[$property.Name] = [string] $property.Value
    }
    return $history
}

function Save-BackupHistory {
    # Writes to a temporary file first and then swaps it in, so a crash never leaves half a file.
    param(
        [Parameter(Mandatory = $true)] [hashtable] $History,
        [Parameter(Mandatory = $true)] [string] $Path
    )
    $directory = Split-Path -Path $Path -Parent
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        $null = New-Item -ItemType Directory -Path $directory -Force -WhatIf:$false -Confirm:$false
    }
    $json = ConvertTo-Json -InputObject $History -Depth 2
    $temp = "$Path.tmp"
    [System.IO.File]::WriteAllText($temp, $json, (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false))
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        [System.IO.File]::Replace($temp, $Path, [NullString]::Value)
    }
    else {
        [System.IO.File]::Move($temp, $Path)
    }
}

function ConvertTo-RemoteTarget {
    param(
        [Parameter(Mandatory = $true)] [string] $Remote,
        [Parameter(Mandatory = $true)] [string] $RelativePath,
        [switch] $AlbumPerFolder
    )
    $parts = $RelativePath -split '[\\/]'
    $leaf = $parts[-1]
    if ($AlbumPerFolder -and $parts.Count -gt 1) {
        $remoteName = $Remote.Substring(0, $Remote.IndexOf(':') + 1)
        $album = ($parts[0..($parts.Count - 2)]) -join '/'
        return "${remoteName}album/$album/$leaf"
    }
    # The Google Photos "upload" folder is flat: only the file name is used.
    if ($Remote.EndsWith(':') -or $Remote.EndsWith('/')) { return "$Remote$leaf" }
    return "$Remote/$leaf"
}

function Get-VideoTranscodeArgument {
    param(
        [Parameter(Mandatory = $true)] [string] $InputPath,
        [Parameter(Mandatory = $true)] [string] $OutputPath,
        [int] $Crf = 24,
        [string] $Preset = 'veryfast'
    )
    # -map_metadata 0 plus +use_metadata_tags keeps creation_time and the location tags
    # (including Apple "com.apple.quicktime.*" keys) that Google Photos uses for date and place.
    @(
        '-hide_banner', '-loglevel', 'error', '-stats', '-y',
        '-i', $InputPath,
        '-c:v', 'libx265', '-crf', [string] $Crf, '-preset', $Preset, '-tag:v', 'hvc1',
        '-c:a', 'aac', '-b:a', '192k',
        '-map_metadata', '0', '-movflags', '+use_metadata_tags',
        $OutputPath
    )
}

function Invoke-ExternalTool {
    # Single place for native calls (easy to mock in tests). Output goes to the console.
    param(
        [Parameter(Mandatory = $true)] [string] $FilePath,
        [Parameter(Mandatory = $true)] [string[]] $ArgumentList
    )
    & $FilePath @ArgumentList | Out-Host
    return $LASTEXITCODE
}

function Get-RcloneRemoteList {
    param([Parameter(Mandatory = $true)] [string] $RclonePath)
    @(& $RclonePath listremotes | ForEach-Object { ([string] $_).Trim() } | Where-Object { $_ })
}

function Test-CommandAvailable {
    param([Parameter(Mandatory = $true)] [string] $Name)
    return [bool] (Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue)
}

function Invoke-GPhotosBackup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)] [string] $SourcePath,
        [Parameter(Mandatory = $true)] [string] $RcloneRemote,
        [switch] $AlbumPerFolder,
        [string] $HistoryFile,
        [Parameter(Mandatory = $true)] [string] $StagingPath,
        [int] $Crf = 24,
        [string] $Preset = 'veryfast',
        [switch] $NoTranscode,
        [string[]] $PhotoExtensions = @('.jpg', '.jpeg', '.png'),
        [string[]] $VideoExtensions = @('.mp4', '.mov'),
        [string[]] $ExcludeFolder = @(),
        [string] $RclonePath = 'rclone',
        [string] $FfmpegPath = 'ffmpeg'
    )

    $result = [PSCustomObject]@{ Found = 0; Pending = 0; Changed = 0; Uploaded = 0; Skipped = 0; ExitCode = 0 }
    $isPreview = [bool] $WhatIfPreference

    Show-BackupMessage "=== gphotos-smart-backup v$script:AppVersion ===" -Level Info

    if ($RcloneRemote -notmatch '^[^:\\/]+:') {
        Show-BackupMessage "RcloneRemote '$RcloneRemote' must look like 'gphotos:upload'." -Level Error
        $result.ExitCode = 1
        return $result
    }

    $source = Resolve-FullPath -Path $SourcePath
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        Show-BackupMessage "Source folder not found: $source" -Level Error
        $result.ExitCode = 1
        return $result
    }
    if ([string]::IsNullOrWhiteSpace($HistoryFile)) {
        # Same default as earlier versions, whatever SourcePath is. Sharing one history between
        # sources is safe: an entry only matches the same relative path, size and timestamp.
        $HistoryFile = Join-Path -Path ([Environment]::GetFolderPath('MyPictures')) -ChildPath '.sync_history.json'
    }
    $historyPath = Resolve-FullPath -Path $HistoryFile
    $staging = Resolve-FullPath -Path $StagingPath

    # @() keeps one-element lists as arrays (otherwise '.jpg' + '.mp4' would concatenate strings).
    $photoList = @(ConvertTo-ExtensionList -Extension $PhotoExtensions)
    $videoList = @(ConvertTo-ExtensionList -Extension $VideoExtensions)

    # 1. History of files already uploaded
    try {
        $history = Read-BackupHistory -Path $historyPath
    }
    catch {
        Show-BackupMessage "The history file '$historyPath' cannot be read: $($_.Exception.Message)" -Level Error
        Show-BackupMessage 'Stopping so the whole library is not uploaded again. Fix the file, or rename it to start over.' -Level Error
        $result.ExitCode = 1
        return $result
    }

    # 2. Scan
    Show-BackupMessage "Scanning: $source" -Level Info
    $files = @(Get-MediaFile -Root $source -Extension ($photoList + $videoList) -ExcludeFolder $ExcludeFolder -ExcludePath @($staging))
    $result.Found = $files.Count

    $queue = New-Object -TypeName 'System.Collections.Generic.List[PSCustomObject]'
    $changed = 0
    foreach ($file in $files) {
        $relative = Get-RelativeMediaPath -Root $source -FullName $file.FullName
        $stamp = Get-MediaFileStamp -File $file
        if ($history.ContainsKey($relative)) {
            if ($history[$relative] -eq $stamp) { continue }
            $changed++
        }
        $queue.Add([PSCustomObject]@{
                File         = $file
                RelativePath = $relative
                Stamp        = $stamp
                IsVideo      = ($videoList -contains $file.Extension.ToLowerInvariant())
                Target       = ConvertTo-RemoteTarget -Remote $RcloneRemote -RelativePath $relative -AlbumPerFolder:$AlbumPerFolder
            })
    }
    $result.Pending = $queue.Count
    $result.Changed = $changed
    Show-BackupMessage "History: $historyPath ($($history.Count) entries)" -Level Detail
    Show-BackupMessage ("Found {0} media file(s): {1} already uploaded, {2} new, {3} changed since their upload." -f $files.Count, ($files.Count - $queue.Count), ($queue.Count - $changed), $changed) -Level Warning

    if ($queue.Count -eq 0) {
        Show-BackupMessage 'Everything is up to date.' -Level Success
        return $result
    }

    # 3. Required tools
    $needFfmpeg = (-not $NoTranscode) -and (@($queue | Where-Object { $_.IsVideo }).Count -gt 0)
    $problems = New-Object -TypeName 'System.Collections.Generic.List[string]'
    if (-not (Test-CommandAvailable -Name $RclonePath)) {
        $problems.Add("rclone was not found ('$RclonePath'). Install it with: winget install Rclone.Rclone")
    }
    else {
        $remoteName = $RcloneRemote.Substring(0, $RcloneRemote.IndexOf(':') + 1)
        $remotes = @(Get-RcloneRemoteList -RclonePath $RclonePath)
        if ($remotes -notcontains $remoteName) {
            $problems.Add("rclone has no remote named '$remoteName'. Create it with: rclone config (see README).")
        }
    }
    if ($needFfmpeg -and -not (Test-CommandAvailable -Name $FfmpegPath)) {
        $problems.Add("ffmpeg was not found ('$FfmpegPath'). Install it with: winget install Gyan.FFmpeg, or use -NoTranscode.")
    }
    foreach ($problem in $problems) {
        if ($isPreview) { Write-Warning $problem } else { Show-BackupMessage $problem -Level Error }
    }
    if ($problems.Count -gt 0 -and -not $isPreview) {
        $result.ExitCode = 1
        return $result
    }

    # 4. One file at a time: (transcode) -> upload -> checkpoint
    $index = 0
    foreach ($item in $queue) {
        $index++
        $label = "[$index/$($queue.Count)] $($item.RelativePath)"
        if (-not $PSCmdlet.ShouldProcess($item.RelativePath, "Upload to $($item.Target)")) { continue }

        Show-BackupMessage $label -Level Step
        $uploadPath = $item.File.FullName
        $stagedFile = $null
        try {
            if ($item.IsVideo -and -not $NoTranscode) {
                if (-not (Test-Path -LiteralPath $staging)) {
                    $null = New-Item -ItemType Directory -Path $staging -Force
                }
                $stagedFile = Join-Path -Path $staging -ChildPath $item.File.Name
                Show-BackupMessage "  -> Transcoding video (H.265 CRF $Crf, $Preset)..." -Level Detail
                $ffmpegArgs = Get-VideoTranscodeArgument -InputPath $item.File.FullName -OutputPath $stagedFile -Crf $Crf -Preset $Preset
                $code = Invoke-ExternalTool -FilePath $FfmpegPath -ArgumentList $ffmpegArgs
                if ($code -ne 0 -or -not (Test-Path -LiteralPath $stagedFile -PathType Leaf)) {
                    Write-Warning "  -> ffmpeg failed (exit code $code). Skipping $($item.RelativePath); it will be retried on the next run."
                    $result.Skipped++
                    continue
                }
                $stagedSize = (Get-Item -LiteralPath $stagedFile).Length
                if ($stagedSize -ge $item.File.Length) {
                    Show-BackupMessage '  -> The H.265 version is not smaller; uploading the original.' -Level Detail
                }
                else {
                    $saved = 100 - [math]::Round(100 * $stagedSize / [math]::Max(1, $item.File.Length))
                    Show-BackupMessage ("  -> {0:N1} MB -> {1:N1} MB ({2}% smaller)" -f ($item.File.Length / 1MB), ($stagedSize / 1MB), $saved) -Level Detail
                    $uploadPath = $stagedFile
                }
            }

            Show-BackupMessage "  -> Uploading to $($item.Target)" -Level Detail
            $code = Invoke-ExternalTool -FilePath $RclonePath -ArgumentList @('copyto', $uploadPath, $item.Target, '--log-level', 'NOTICE')
            if ($code -ne 0) {
                Show-BackupMessage "  -> rclone failed (exit code $code). Stopping; run the script again to resume from this file." -Level Error
                $result.ExitCode = 1
                return $result
            }

            $history[$item.RelativePath] = $item.Stamp
            Save-BackupHistory -History $history -Path $historyPath
            $result.Uploaded++
            Show-BackupMessage '  -> Done.' -Level Success
        }
        finally {
            if ($stagedFile -and (Test-Path -LiteralPath $stagedFile)) {
                Remove-Item -LiteralPath $stagedFile -Force -ErrorAction SilentlyContinue -WhatIf:$false -Confirm:$false
            }
        }
    }

    Show-BackupMessage '' -Level Info
    if ($isPreview) {
        Show-BackupMessage ("Preview only: {0} file(s) would be uploaded. Nothing was changed." -f $queue.Count) -Level Success
    }
    elseif ($result.Skipped -gt 0) {
        Show-BackupMessage ("Uploaded {0} file(s); {1} skipped (see warnings above)." -f $result.Uploaded, $result.Skipped) -Level Warning
        $result.ExitCode = 2
    }
    else {
        Show-BackupMessage ("Uploaded {0} file(s). All done." -f $result.Uploaded) -Level Success
    }
    return $result
}

# Dot-sourcing (tests) loads the functions only.
if ($MyInvocation.InvocationName -eq '.') { return }

$backupArgs = @{
    SourcePath      = $SourcePath
    RcloneRemote    = $RcloneRemote
    AlbumPerFolder  = $AlbumPerFolder
    HistoryFile     = $HistoryFile
    StagingPath     = $StagingPath
    Crf             = $Crf
    Preset          = $Preset
    NoTranscode     = $NoTranscode
    PhotoExtensions = $PhotoExtensions
    VideoExtensions = $VideoExtensions
    ExcludeFolder   = $ExcludeFolder
    RclonePath      = $RclonePath
    FfmpegPath      = $FfmpegPath
}
$summary = @(Invoke-GPhotosBackup @backupArgs)[-1]
exit $summary.ExitCode
