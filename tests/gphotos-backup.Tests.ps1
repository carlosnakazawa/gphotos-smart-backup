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
