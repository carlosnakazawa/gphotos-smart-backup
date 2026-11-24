#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester shares variables from BeforeDiscovery/BeforeAll with It blocks.')]
param()

BeforeAll {
    $backupScriptPath = Join-Path -Path $PSScriptRoot -ChildPath '..\gphotos-backup.ps1'
    # Dot-sourcing loads the functions only; the entry point returns early.
    . $backupScriptPath

    function Write-TestFile {
        param([string] $Path, [int] $Size = 100, [datetime] $LastWrite = '2024-01-02T03:04:05Z')
        $directory = Split-Path -Path $Path -Parent
        if (-not (Test-Path -LiteralPath $directory)) { $null = New-Item -ItemType Directory -Path $directory -Force }
        [System.IO.File]::WriteAllBytes($Path, (New-Object -TypeName byte[] -ArgumentList $Size))
        (Get-Item -LiteralPath $Path).LastWriteTimeUtc = $LastWrite.ToUniversalTime()
        Get-Item -LiteralPath $Path
    }
}

Describe 'Script files' {
    BeforeDiscovery {
        $repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).ProviderPath
        $scriptCases = @(Get-ChildItem -LiteralPath $repoRoot -Filter '*.ps1' -File -Recurse |
                ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } })
    }

    It '<Name> has no syntax errors' -ForEach $scriptCases {
        $tokens = $null
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    It '<Name> is ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI)' -ForEach $scriptCases {
        $nonAscii = [System.IO.File]::ReadAllBytes($Path) | Where-Object { $_ -gt 127 }
        $nonAscii | Should -BeNullOrEmpty
    }
}

Describe 'Documentation' {
    BeforeDiscovery {
        $repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).ProviderPath
        $readmeFiles = @(Get-Item -LiteralPath (Join-Path $repoRoot 'README.md')) +
            @(Get-ChildItem -Path (Join-Path $repoRoot 'docs') -Filter 'README.*.md')
        $markdownFiles = $readmeFiles + @(
            'CONTRIBUTING.md', 'SECURITY.md', 'AGENTS.md', 'CLAUDE.md', 'CHANGELOG.md' |
                ForEach-Object { Get-Item -LiteralPath (Join-Path $repoRoot $_) }
        )
        $readmeCases = $readmeFiles | ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } }
        $markdownCases = $markdownFiles | ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } }
    }

    BeforeAll {
        $repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).ProviderPath
        $allReadmes = @(Join-Path $repoRoot 'README.md') +
            @(Get-ChildItem -Path (Join-Path $repoRoot 'docs') -Filter 'README.*.md' | ForEach-Object { $_.FullName })

        function Get-RelativeLinkTarget {
            param([string] $Path)
            $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
            $directory = Split-Path -Path $Path -Parent
            foreach ($match in [regex]::Matches($text, '\]\(([^)\s#]+)(#[^)]*)?\)')) {
                $link = $match.Groups[1].Value
                if ($link -match '^(https?|mailto):') { continue }
                [System.IO.Path]::GetFullPath((Join-Path -Path $directory -ChildPath $link))
            }
        }
    }

    It '<Name> has no broken relative links' -ForEach $markdownCases {
        $missing = Get-RelativeLinkTarget -Path $Path | Where-Object { -not (Test-Path -LiteralPath $_) }
        $missing | Should -BeNullOrEmpty
    }

    It '<Name> links to every other language' -ForEach $readmeCases {
        $targets = @(Get-RelativeLinkTarget -Path $Path) + $Path
        $notLinked = $allReadmes | Where-Object { $targets -notcontains $_ }
        $notLinked | Should -BeNullOrEmpty
    }
}

Describe 'Path and naming helpers' {
    It 'builds the relative path used as the history key' {
        Get-RelativeMediaPath -Root 'C:\Users\me\Pictures' -FullName 'C:\Users\me\Pictures\2024\Trip\a.jpg' | Should -Be '2024\Trip\a.jpg'
        Get-RelativeMediaPath -Root 'C:\Users\me\Pictures\' -FullName 'C:\Users\me\Pictures\a.jpg' | Should -Be 'a.jpg'
        Get-RelativeMediaPath -Root 'D:\' -FullName 'D:\DCIM\a.jpg' | Should -Be 'DCIM\a.jpg'
    }

    It 'rejects files outside the source folder' {
        { Get-RelativeMediaPath -Root 'C:\Pictures' -FullName 'C:\PicturesOld\a.jpg' } | Should -Throw
    }

    It 'keeps the stamp format of earlier versions (<size>_<ticks>)' {
        $file = Write-TestFile -Path (Join-Path $TestDrive 'stamp.jpg') -Size 1234
        Get-MediaFileStamp -File $file | Should -Be ('1234_{0}' -f $file.LastWriteTimeUtc.Ticks)
    }

    It 'normalizes extensions' {
        ConvertTo-ExtensionList -Extension @('JPG', '.Png', ' heic ', '') | Should -Be @('.jpg', '.png', '.heic')
    }

    It 'uploads to the flat upload folder by file name' {
        ConvertTo-RemoteTarget -Remote 'gphotos:upload' -RelativePath '2024\Trip\a.jpg' | Should -Be 'gphotos:upload/a.jpg'
        ConvertTo-RemoteTarget -Remote 'gphotos:upload/' -RelativePath 'a.jpg' | Should -Be 'gphotos:upload/a.jpg'
        ConvertTo-RemoteTarget -Remote 'gphotos:' -RelativePath 'a.jpg' | Should -Be 'gphotos:a.jpg'
    }

    It 'maps subfolders to albums with -AlbumPerFolder' {
        ConvertTo-RemoteTarget -Remote 'gphotos:upload' -RelativePath '2024\Trip\a.jpg' -AlbumPerFolder | Should -Be 'gphotos:album/2024/Trip/a.jpg'
        ConvertTo-RemoteTarget -Remote 'gphotos:upload' -RelativePath 'root.jpg' -AlbumPerFolder | Should -Be 'gphotos:upload/root.jpg'
    }

    It 'keeps date and location metadata when transcoding' {
        $arguments = Get-VideoTranscodeArgument -InputPath 'C:\in file.mov' -OutputPath 'C:\out file.mov' -Crf 26 -Preset 'medium'
        ($arguments -join ' ') | Should -Match '-map_metadata 0 -movflags \+use_metadata_tags'
        ($arguments -join ' ') | Should -Match '-c:v libx265 -crf 26 -preset medium -tag:v hvc1'
        $arguments[$arguments.IndexOf('-i') + 1] | Should -Be 'C:\in file.mov'
        $arguments[-1] | Should -Be 'C:\out file.mov'
    }
}

Describe 'Video probing' {
    It 'finds ffprobe next to ffmpeg' {
        Get-FfprobePath -FfmpegPath 'ffmpeg' | Should -Be 'ffprobe'
        Get-FfprobePath -FfmpegPath 'C:\Tools\ffmpeg\bin\ffmpeg.exe' | Should -Be 'C:\Tools\ffmpeg\bin\ffprobe.exe'
    }

    It 'parses numbers and fractions the same way on a pt-BR system' {
        $previous = [System.Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('pt-BR')
            ConvertTo-InvariantNumber -Value '29.97' | Should -Be 29.97
            [math]::Round((ConvertTo-InvariantNumber -Value '30000/1001'), 3) | Should -Be 29.97
            ConvertTo-InvariantNumber -Value 1920 | Should -Be 1920
            ConvertTo-InvariantNumber -Value '0/0' | Should -Be 0
            ConvertTo-InvariantNumber -Value 'N/A' | Should -Be 0
            ConvertTo-InvariantNumber -Value $null | Should -Be 0
        }
        finally {
            [System.Threading.Thread]::CurrentThread.CurrentCulture = $previous
        }
    }

    It 'reads codec, size, frame rate and stream bit rate from ffprobe JSON' {
        $json = '{ "streams": [ { "codec_name": "HEVC", "width": 3840, "height": 2160, "avg_frame_rate": "30000/1001", "bit_rate": "22000000" } ], "format": { "bit_rate": "22300000" } }'
        $info = ConvertFrom-FfprobeJson -Json $json
        $info.Codec | Should -Be 'hevc'
        $info.Width | Should -Be 3840
        $info.Height | Should -Be 2160
        [math]::Round($info.Fps, 2) | Should -Be 29.97
        $info.BitRate | Should -Be 22000000
    }

    It 'falls back to the file bit rate, then to size and duration' {
        $formatRate = ConvertFrom-FfprobeJson -Json '{ "streams": [ { "codec_name": "h264", "width": 1920, "height": 1080, "avg_frame_rate": "30/1" } ], "format": { "bit_rate": "8000000" } }'
        $formatRate.BitRate | Should -Be 8000000
        $sizeRate = ConvertFrom-FfprobeJson -Json '{ "streams": [ { "codec_name": "h264", "width": 1920, "height": 1080, "avg_frame_rate": "30/1" } ], "format": { "size": "10000000", "duration": "10.0" } }'
        $sizeRate.BitRate | Should -Be 8000000
    }

    It 'returns nothing for empty or invalid output' {
        ConvertFrom-FfprobeJson -Json '' | Should -BeNullOrEmpty
        ConvertFrom-FfprobeJson -Json 'not json' | Should -BeNullOrEmpty
        ConvertFrom-FfprobeJson -Json '{ "streams": [] }' | Should -BeNullOrEmpty
    }

    It '<Case>: transcode = <Expected>' -ForEach @(
        @{ Case = 'iPhone 4K30 HEVC (~22 Mbps)'; Codec = 'hevc'; Width = 3840; Height = 2160; Fps = 30; Mbps = 22; Expected = $false }
        @{ Case = 'iPhone 4K60 HEVC (~50 Mbps)'; Codec = 'hevc'; Width = 3840; Height = 2160; Fps = 60; Mbps = 50; Expected = $false }
        @{ Case = 'portrait 1080p30 HEVC (~8 Mbps)'; Codec = 'hevc'; Width = 1080; Height = 1920; Fps = 30; Mbps = 8; Expected = $false }
        @{ Case = 'action cam 4K60 HEVC (~100 Mbps)'; Codec = 'hevc'; Width = 3840; Height = 2160; Fps = 60; Mbps = 100; Expected = $true }
        @{ Case = 'camera 4K30 HEVC (~100 Mbps)'; Codec = 'hevc'; Width = 3840; Height = 2160; Fps = 30; Mbps = 100; Expected = $true }
        @{ Case = 'Android 1080p30 H.264 (~17 Mbps)'; Codec = 'h264'; Width = 1920; Height = 1080; Fps = 30; Mbps = 17; Expected = $true }
        @{ Case = 'messaging app 720p H.264 (~1.5 Mbps)'; Codec = 'h264'; Width = 1280; Height = 720; Fps = 30; Mbps = 1.5; Expected = $false }
        @{ Case = 'small H.264 at 4 Mbps 1080p30 (limit)'; Codec = 'h264'; Width = 1920; Height = 1080; Fps = 30; Mbps = 4; Expected = $false }
    ) {
        $info = [PSCustomObject]@{ Codec = $Codec; Width = $Width; Height = $Height; Fps = $Fps; BitRate = $Mbps * 1000000 }
        (Get-TranscodeDecision -VideoInfo $info -SkipBelowMbps 4).Transcode | Should -Be $Expected
    }

    It 'transcodes when the bit rate is unknown or the check is disabled' {
        (Get-TranscodeDecision -VideoInfo $null -SkipBelowMbps 4).Transcode | Should -BeTrue
        $noRate = [PSCustomObject]@{ Codec = 'h264'; Width = 1920; Height = 1080; Fps = 30; BitRate = 0 }
        (Get-TranscodeDecision -VideoInfo $noRate -SkipBelowMbps 4).Transcode | Should -BeTrue
        $tiny = [PSCustomObject]@{ Codec = 'h264'; Width = 1920; Height = 1080; Fps = 30; BitRate = 100000 }
        (Get-TranscodeDecision -VideoInfo $tiny -SkipBelowMbps 0).Transcode | Should -BeTrue
    }

    It 'assumes 30 fps when the frame rate is missing or is a timebase (<Fps>)' -ForEach @(
        @{ Fps = 0 }
        @{ Fps = 90000 }
    ) {
        $info = [PSCustomObject]@{ Codec = 'h264'; Width = 1920; Height = 1080; Fps = $Fps; BitRate = 6000000 }
        [math]::Round((Get-TranscodeDecision -VideoInfo $info -SkipBelowMbps 4).EquivalentMbps, 1) | Should -Be 6
    }

    It 'doubles the limit for every efficient codec (<Codec>)' -ForEach @(
        @{ Codec = 'hevc' }
        @{ Codec = 'av1' }
        @{ Codec = 'vp9' }
    ) {
        $info = [PSCustomObject]@{ Codec = $Codec; Width = 1920; Height = 1080; Fps = 30; BitRate = 6000000 }
        (Get-TranscodeDecision -VideoInfo $info -SkipBelowMbps 4).Transcode | Should -BeFalse
        $h264 = [PSCustomObject]@{ Codec = 'h264'; Width = 1920; Height = 1080; Fps = 30; BitRate = 6000000 }
        (Get-TranscodeDecision -VideoInfo $h264 -SkipBelowMbps 4).Transcode | Should -BeTrue
    }

    It 'transcodes when the width or height is unknown' {
        $noWidth = [PSCustomObject]@{ Codec = 'h264'; Width = 0; Height = 1080; Fps = 30; BitRate = 1000000 }
        (Get-TranscodeDecision -VideoInfo $noWidth -SkipBelowMbps 4).Transcode | Should -BeTrue
        $noHeight = [PSCustomObject]@{ Codec = 'h264'; Width = 1920; Height = 0; Fps = 30; BitRate = 1000000 }
        (Get-TranscodeDecision -VideoInfo $noHeight -SkipBelowMbps 4).Transcode | Should -BeTrue
    }

    It 'names a missing codec "unknown"' {
        $info = ConvertFrom-FfprobeJson -Json '{ "streams": [ { "width": 1920, "height": 1080, "avg_frame_rate": "30/1", "bit_rate": "2000000" } ] }'
        $info.Codec | Should -Be 'unknown'
        (Get-TranscodeDecision -VideoInfo $info -SkipBelowMbps 4).Reason | Should -Match '^unknown at '
    }

    It 'asks ffprobe for the first real video stream, not the cover art (V:0)' {
        # A fake ffprobe (a function), so the test does not need ffprobe installed on the CI runner.
        function Invoke-FakeFfprobe {
            $script:probeArgs = $args
            $global:LASTEXITCODE = 0
            '{ "streams": [ { "codec_name": "h264", "width": 1920, "height": 1080, "avg_frame_rate": "30/1", "bit_rate": "17000000" } ] }'
        }
        $info = Get-VideoInfo -FfprobePath 'Invoke-FakeFfprobe' -Path 'C:\clip with cover.mp4'
        $info.Codec | Should -Be 'h264'
        $selected = $script:probeArgs[[array]::IndexOf($script:probeArgs, '-select_streams') + 1]
        $selected | Should -BeExactly 'V:0'
        $script:probeArgs[-1] | Should -Be 'C:\clip with cover.mp4'
    }
}

Describe 'Get-MediaFile' {
    BeforeAll {
        $root = Join-Path $TestDrive 'scan'
        $null = Write-TestFile -Path (Join-Path $root 'a.JPG')
        $null = Write-TestFile -Path (Join-Path $root 'sub\b.mp4')
        $null = Write-TestFile -Path (Join-Path $root 'sub\notes.txt')
        $null = Write-TestFile -Path (Join-Path $root 'sub\raw.ARW')
        $null = Write-TestFile -Path (Join-Path $root 'sub\._b.mp4')
        $null = Write-TestFile -Path (Join-Path $root '_Upload_Staging\old.mp4')
        $null = Write-TestFile -Path (Join-Path $root 'staging\c.jpg')
        $null = Write-TestFile -Path (Join-Path $TestDrive 'outside\linked.jpg')
        $null = New-Item -ItemType Junction -Path (Join-Path $root 'junction') -Target (Join-Path $TestDrive 'outside')

        $found = @(Get-MediaFile -Root $root -Extension @('.jpg', '.mp4') -ExcludeFolder @('_Upload_Staging') -ExcludePath @(Join-Path $root 'staging'))
        $names = $found | ForEach-Object { $_.Name }
    }

    It 'finds photos and videos, ignoring extension case' {
        $names | Should -Contain 'a.JPG'
        $names | Should -Contain 'b.mp4'
    }

    It 'skips other files, RAW files and macOS "._" files' {
        $names | Should -Not -Contain 'notes.txt'
        $names | Should -Not -Contain 'raw.ARW'
        $names | Should -Not -Contain '._b.mp4'
    }

    It 'skips excluded folder names, the staging folder and junctions' {
        $names | Should -Not -Contain 'old.mp4'
        $names | Should -Not -Contain 'c.jpg'
        $names | Should -Not -Contain 'linked.jpg'
        $found.Count | Should -Be 2
    }
}

Describe 'Backup history' {
    It 'returns an empty history when the file does not exist or is empty' {
        (Read-BackupHistory -Path (Join-Path $TestDrive 'missing.json')).Count | Should -Be 0
        $empty = Join-Path $TestDrive 'empty.json'
        Set-Content -LiteralPath $empty -Value '' -Encoding ASCII
        (Read-BackupHistory -Path $empty).Count | Should -Be 0
    }

    It 'reads the format written by earlier versions (UTF-8 with BOM)' {
        $legacy = Join-Path $TestDrive 'legacy.json'
        $content = "{`r`n    `"2024\\Trip\\a.jpg`":  `"10_20`",`r`n    `"b.mp4`":  `"30_40`"`r`n}"
        [System.IO.File]::WriteAllText($legacy, $content, (New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $true))
        $history = Read-BackupHistory -Path $legacy
        $history.Count | Should -Be 2
        $history['2024\Trip\a.jpg'] | Should -Be '10_20'
        $history['B.MP4'] | Should -Be '30_40'
    }

    It 'throws on a corrupted file instead of starting over' {
        $broken = Join-Path $TestDrive 'broken.json'
        Set-Content -LiteralPath $broken -Value '{ "a.jpg": ' -Encoding ASCII
        { Read-BackupHistory -Path $broken } | Should -Throw
    }

    It 'round-trips through Save-BackupHistory without leaving a temporary file' {
        $path = Join-Path $TestDrive 'history\round.json'
        $history = @{ 'x\y.jpg' = '1_2'; 'z.mov' = '3_4' }
        Save-BackupHistory -History $history -Path $path
        $history['new.jpg'] = '5_6'
        Save-BackupHistory -History $history -Path $path
        $read = Read-BackupHistory -Path $path
        $read.Count | Should -Be 3
        $read['x\y.jpg'] | Should -Be '1_2'
        Test-Path -LiteralPath "$path.tmp" | Should -BeFalse
    }
}

Describe 'Invoke-GPhotosBackup' {
    BeforeEach {
        $source = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $staging = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $historyPath = Join-Path $source '.sync_history.json'
        $photo = Write-TestFile -Path (Join-Path $source '2024\a.jpg') -Size 500
        $video = Write-TestFile -Path (Join-Path $source '2024\b.mp4') -Size 1000

        $script:uploads = New-Object -TypeName 'System.Collections.Generic.List[string]'
        $script:transcodedSize = 100

        # Always pass HistoryFile: the default points to the real Pictures folder.
        $backupArgs = @{
            SourcePath      = $source
            HistoryFile     = $historyPath
            RcloneRemote    = 'gphotos:upload'
            StagingPath     = $staging
            PhotoExtensions = @('.jpg')
            VideoExtensions = @('.mp4')
        }

        Mock Show-BackupMessage { }
        Mock Write-Warning { }
        Mock Test-CommandAvailable { $true }
        Mock Get-RcloneRemoteList { @('gphotos:') }
        # Default: bit rate unknown, so videos are transcoded (never call the real ffprobe).
        Mock Get-VideoInfo { $null }
        Mock Invoke-ExternalTool -ParameterFilter { $FilePath -eq 'ffmpeg' } {
            [System.IO.File]::WriteAllBytes($ArgumentList[-1], (New-Object -TypeName byte[] -ArgumentList $script:transcodedSize))
            0
        }
        Mock Invoke-ExternalTool -ParameterFilter { $FilePath -eq 'rclone' } {
            $script:uploads.Add(('{0} -> {1}' -f $ArgumentList[1], $ArgumentList[2]))
            0
        }
    }

    It 'uploads new files, records them and exits 0' {
        $result = Invoke-GPhotosBackup @backupArgs
        $result.ExitCode | Should -Be 0
        $result.Uploaded | Should -Be 2
        $history = Read-BackupHistory -Path $historyPath
        $history['2024\a.jpg'] | Should -Be (Get-MediaFileStamp -File $photo)
        $history['2024\b.mp4'] | Should -Be (Get-MediaFileStamp -File $video)
        $script:uploads | Should -Contain ('{0} -> gphotos:upload/a.jpg' -f $photo.FullName)
    }

    It 'uploads the smaller H.265 file and removes it from staging' {
        $null = Invoke-GPhotosBackup @backupArgs
        $script:uploads | Should -Contain ('{0} -> gphotos:upload/b.mp4' -f (Join-Path $staging 'b.mp4'))
        @(Get-ChildItem -LiteralPath $staging -File).Count | Should -Be 0
    }

    It 'uploads the original video when the H.265 file is not smaller' {
        $script:transcodedSize = 5000
        $null = Invoke-GPhotosBackup @backupArgs
        $script:uploads | Should -Contain ('{0} -> gphotos:upload/b.mp4' -f $video.FullName)
    }

    It 'does nothing on the second run' {
        $null = Invoke-GPhotosBackup @backupArgs
        $result = Invoke-GPhotosBackup @backupArgs
        $result.Pending | Should -Be 0
        Should -Invoke Invoke-ExternalTool -Times 3 -Exactly
    }

    It 'uploads a file again when it changed' {
        $null = Invoke-GPhotosBackup @backupArgs
        $null = Write-TestFile -Path $photo.FullName -Size 600
        $result = Invoke-GPhotosBackup @backupArgs
        $result.Pending | Should -Be 1
        $result.Changed | Should -Be 1
    }

    It 'uploads an already compact video without calling ffmpeg' {
        Mock Get-VideoInfo { [PSCustomObject]@{ Codec = 'hevc'; Width = 3840; Height = 2160; Fps = 30; BitRate = 22000000 } }
        $result = Invoke-GPhotosBackup @backupArgs
        $result.ExitCode | Should -Be 0
        $result.NotTranscoded | Should -Be 1
        Should -Invoke Invoke-ExternalTool -ParameterFilter { $FilePath -eq 'ffmpeg' } -Times 0 -Exactly
        $script:uploads | Should -Contain ('{0} -> gphotos:upload/b.mp4' -f $video.FullName)
        (Read-BackupHistory -Path $historyPath).ContainsKey('2024\b.mp4') | Should -BeTrue
    }

    It 'still transcodes a high bit rate video' {
        Mock Get-VideoInfo { [PSCustomObject]@{ Codec = 'h264'; Width = 1920; Height = 1080; Fps = 30; BitRate = 17000000 } }
        $result = Invoke-GPhotosBackup @backupArgs
        $result.NotTranscoded | Should -Be 0
        Should -Invoke Invoke-ExternalTool -ParameterFilter { $FilePath -eq 'ffmpeg' } -Times 1 -Exactly
    }

    It 'does not probe videos with -SkipTranscodeBelowMbps 0' {
        $null = Invoke-GPhotosBackup @backupArgs -SkipTranscodeBelowMbps 0
        Should -Invoke Get-VideoInfo -Times 0 -Exactly
        Should -Invoke Invoke-ExternalTool -ParameterFilter { $FilePath -eq 'ffmpeg' } -Times 1 -Exactly
    }

    It 'does not count a compact video when its upload fails' {
        Mock Get-VideoInfo { [PSCustomObject]@{ Codec = 'hevc'; Width = 3840; Height = 2160; Fps = 30; BitRate = 22000000 } }
        Mock Invoke-ExternalTool -ParameterFilter { $FilePath -eq 'rclone' -and $ArgumentList[1] -like '*b.mp4' } { 7 }
        $result = Invoke-GPhotosBackup @backupArgs
        $result.ExitCode | Should -Be 1
        $result.NotTranscoded | Should -Be 0
    }

    It 'uses an explicit -FfprobePath' {
        $null = Invoke-GPhotosBackup @backupArgs -FfprobePath 'D:\bin\ffprobe.exe'
        Should -Invoke Get-VideoInfo -ParameterFilter { $FfprobePath -eq 'D:\bin\ffprobe.exe' } -Times 1 -Exactly
    }

    It 'looks for ffprobe next to a full -FfmpegPath' {
        Mock Invoke-ExternalTool -ParameterFilter { $FilePath -eq 'C:\Tools\ffmpeg\bin\ffmpeg.exe' } {
            [System.IO.File]::WriteAllBytes($ArgumentList[-1], (New-Object -TypeName byte[] -ArgumentList 10))
            0
        }
        $null = Invoke-GPhotosBackup @backupArgs -FfmpegPath 'C:\Tools\ffmpeg\bin\ffmpeg.exe'
        Should -Invoke Get-VideoInfo -ParameterFilter { $FfprobePath -eq 'C:\Tools\ffmpeg\bin\ffprobe.exe' } -Times 1 -Exactly
    }

    It 'does not warn about ffprobe when ffmpeg itself is missing' {
        Mock Test-CommandAvailable -ParameterFilter { $Name -eq 'ffmpeg' } { $false }
        $result = Invoke-GPhotosBackup @backupArgs
        $result.ExitCode | Should -Be 1
        Should -Invoke Write-Warning -ParameterFilter { $Message -like '*ffprobe*' } -Times 0 -Exactly
        Should -Invoke Test-CommandAvailable -ParameterFilter { $Name -eq 'ffprobe' } -Times 0 -Exactly
    }

    It 'transcodes every video when ffprobe is missing' {
        Mock Test-CommandAvailable -ParameterFilter { $Name -eq 'ffprobe' } { $false }
        $result = Invoke-GPhotosBackup @backupArgs
        $result.ExitCode | Should -Be 0
        Should -Invoke Write-Warning -ParameterFilter { $Message -like '*ffprobe*' } -Times 1 -Exactly
        Should -Invoke Get-VideoInfo -Times 0 -Exactly
        Should -Invoke Invoke-ExternalTool -ParameterFilter { $FilePath -eq 'ffmpeg' } -Times 1 -Exactly
    }

    It 'never touches the real Pictures history when HistoryFile is given' {
        Mock Read-BackupHistory { @{} }
        $null = Invoke-GPhotosBackup @backupArgs -WhatIf
        Should -Invoke Read-BackupHistory -ParameterFilter { $Path -eq $historyPath } -Times 1 -Exactly
    }

    It 'stops at the first upload failure and keeps the checkpoint of earlier files' {
        $null = Write-TestFile -Path (Join-Path $source '2024\c.jpg')
        Mock Invoke-ExternalTool -ParameterFilter { $FilePath -eq 'rclone' -and $ArgumentList[1] -like '*b.mp4' } { 7 }
        $result = Invoke-GPhotosBackup @backupArgs
        $result.ExitCode | Should -Be 1
        $history = Read-BackupHistory -Path $historyPath
        $history.ContainsKey('2024\a.jpg') | Should -BeTrue
        $history.ContainsKey('2024\b.mp4') | Should -BeFalse
        $history.ContainsKey('2024\c.jpg') | Should -BeFalse
        @(Get-ChildItem -LiteralPath $staging -File).Count | Should -Be 0
    }

    It 'skips a video that cannot be transcoded and exits 2' {
        Mock Invoke-ExternalTool -ParameterFilter { $FilePath -eq 'ffmpeg' } { 1 }
        $result = Invoke-GPhotosBackup @backupArgs
        $result.ExitCode | Should -Be 2
        $result.Skipped | Should -Be 1
        $history = Read-BackupHistory -Path $historyPath
        $history.ContainsKey('2024\a.jpg') | Should -BeTrue
        $history.ContainsKey('2024\b.mp4') | Should -BeFalse
    }

    It 'does not call ffmpeg with -NoTranscode, even when ffmpeg is missing' {
        Mock Test-CommandAvailable -ParameterFilter { $Name -eq 'ffmpeg' } { $false }
        $result = Invoke-GPhotosBackup @backupArgs -NoTranscode
        $result.ExitCode | Should -Be 0
        Should -Invoke Invoke-ExternalTool -ParameterFilter { $FilePath -eq 'ffmpeg' } -Times 0 -Exactly
        $script:uploads | Should -Contain ('{0} -> gphotos:upload/b.mp4' -f $video.FullName)
    }

    It 'changes nothing with -WhatIf' {
        $result = Invoke-GPhotosBackup @backupArgs -WhatIf
        $result.ExitCode | Should -Be 0
        $result.Pending | Should -Be 2
        Should -Invoke Invoke-ExternalTool -Times 0 -Exactly
        Test-Path -LiteralPath $historyPath | Should -BeFalse
        Test-Path -LiteralPath $staging | Should -BeFalse
    }

    It 'stops before uploading when the history file is corrupted' {
        Set-Content -LiteralPath $historyPath -Value 'not json' -Encoding ASCII
        $result = Invoke-GPhotosBackup @backupArgs
        $result.ExitCode | Should -Be 1
        Should -Invoke Invoke-ExternalTool -Times 0 -Exactly
        Get-Content -LiteralPath $historyPath -Raw | Should -Match 'not json'
    }

    It 'stops when the rclone remote does not exist' {
        Mock Get-RcloneRemoteList { @('other:') }
        $result = Invoke-GPhotosBackup @backupArgs
        $result.ExitCode | Should -Be 1
        Should -Invoke Invoke-ExternalTool -Times 0 -Exactly
    }

    It 'stops when rclone is not installed' {
        Mock Test-CommandAvailable -ParameterFilter { $Name -eq 'rclone' } { $false }
        $result = Invoke-GPhotosBackup @backupArgs
        $result.ExitCode | Should -Be 1
        Should -Invoke Invoke-ExternalTool -Times 0 -Exactly
    }

    It 'rejects a remote without a colon' {
        $backupArgs.RcloneRemote = 'gphotos'
        (Invoke-GPhotosBackup @backupArgs).ExitCode | Should -Be 1
    }

    It 'fails when the source folder does not exist' {
        $backupArgs.SourcePath = Join-Path $TestDrive 'does-not-exist'
        (Invoke-GPhotosBackup @backupArgs).ExitCode | Should -Be 1
    }
}
