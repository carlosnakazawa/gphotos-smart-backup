# Google Photos Smart Backup

[![CI](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](../LICENSE)
![PowerShell 5.1 | 7](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)
![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4)
[![Contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](../CONTRIBUTING.md)

[English](../README.md) | [Português (Brasil)](README.pt-BR.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Italiano](README.it.md) | [Русский](README.ru.md) | [日本語](README.ja.md) | **한국어** | [简体中文](README.zh-CN.md)

> 이 번역은 기준 문서인 [영어 버전](../README.md)보다 오래되었을 수 있습니다.

Windows PC의 사진과 동영상을 브라우저 탭을 열어 두지 않고도 **Google 포토**에 자동으로 백업합니다. 동영상은 저장 공간을 아끼기 위해 **업로드 전에 H.265로 압축**되고, 업로드할 때마다 **즉시 기록**되므로 중단되더라도 멈춘 곳에서 이어서 진행합니다.

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

## 이 프로젝트가 존재하는 이유

오랫동안 Windows 사용자는 Google의 데스크톱 앱("백업 및 동기화", 이후 **데스크톱용 Google Drive**)으로 폴더를 Google 포토에 백업할 수 있었습니다. **이제는 불가능합니다**.

- **2026년 6월 15일**부터 데스크톱용 Google Drive에서 Google 포토 백업용 폴더를 더 이상 추가할 수 없습니다.
- **2026년 8월 10일**에는 새 사진과 동영상을 Google 포토에 업로드하는 기능이 완전히 중단되었습니다.

Google의 대안은 [photos.google.com](https://photos.google.com)의 "폴더 백업"인데, 이 기능은 **브라우저에서 Google 포토 웹페이지가 열려 있는 동안에만 작동합니다**. 이제 Windows에서 백그라운드로 백업할 방법이 없습니다.

이 프로젝트는 잘 알려진 오픈소스 도구인 [rclone](https://rclone.org/googlephotos/)과 [ffmpeg](https://ffmpeg.org/)를 기반으로 한 작고 투명한 PowerShell 스크립트로 그 공백을 채웁니다.

- 브라우저나 Google 앱 없이 **무인으로** 실행됩니다(예: 작업 스케줄러).
- **새로 생기거나 변경된 파일만** 업로드하며, 보낸 파일의 기록을 로컬에 남깁니다.
- 업로드 전에 **동영상 크기를 줄입니다**. Google 포토 API로 업로드한 파일은 항상 **원본 화질로 저장되어 Google 저장용량을 차지**하므로, 4K 동영상을 H.265로 다시 인코딩하면 공간을 크게 아낄 수 있습니다.
- PC에서도 Google 포토에서도 **아무것도 삭제하거나 이동하지 않습니다**.

**커뮤니티 프로젝트이며, 어떤 도움이든 환영합니다.** 데스크톱용 Google Drive 백업 종료로 불편을 겪고 있다면 직접 사용해 보고, [작동하지 않는 부분을 알려 주거나](https://github.com/carlosnakazawa/gphotos-smart-backup/issues/new?template=bug_report.yml), 아이디어를 제안하거나, 번역을 개선하거나, 풀 리퀘스트를 보내 주세요. [CONTRIBUTING.md](../CONTRIBUTING.md)를 참고하세요. 어떤 언어로 작성해도 괜찮습니다.

## 기능

| | |
| --- | --- |
| **증분 업로드** | JSON 기록(`상대 경로 -> 크기 + 수정 시각`)으로 어떤 파일이 이미 Google 포토에 있는지 판단합니다. 새 파일과 편집된 파일만 업로드하고 나머지는 몇 초 만에 건너뜁니다. |
| **이어서 진행** | 각 파일은 업로드 직후 기록됩니다. PC가 절전 모드에 들어가거나, 네트워크가 끊기거나, Ctrl+C를 눌러도 다음 실행에서 같은 파일부터 계속합니다. |
| **스마트 동영상 압축** | ffmpeg로 H.265/HEVC 변환(기본값 `-crf 24 -preset veryfast`, 조정 가능). 촬영 날짜와 위치 정보는 유지되며, iPhone의 Apple `com.apple.quicktime.*` 태그도 보존됩니다. H.265 버전이 더 작지 않으면 원본을 업로드합니다. 이미 충분히 작은 동영상(예: 최신 iPhone의 HEVC)은 ffprobe로 판별해 다시 인코딩하지 않고 그대로 업로드합니다. |
| **앨범(선택 사항)** | `-AlbumPerFolder`를 사용하면 각 하위 폴더의 파일을 그 이름의 앨범에 넣습니다. |
| **안전함** | 업로드만 합니다(`rclone copyto`). 심볼릭 링크나 정션은 따라가지 않습니다. `-WhatIf`로 아무것도 업로드하지 않고 미리 볼 수 있습니다. 기록 파일이 손상되면 라이브러리 전체를 다시 올리는 대신 실행을 멈춥니다. |
| **자동화 친화적** | 종료 코드: `0` 성공, `1` 오류(중단), `2` 완료했지만 일부 동영상을 변환하지 못함. |

기본 지원 형식: `.jpg .jpeg .png .heic .heif .webp .gif`(사진), `.mp4 .mov .m4v`(동영상). RAW 파일(`.dng`, `.arw`, `.cr2` 등)과 보조 파일(`.lrf`, `.xmp` 등)은 의도적으로 제외했습니다. 필요하면 `-PhotoExtensions`로 추가하세요.

## 작동 방식

```text
 내 폴더 ──스캔──> 새 파일 또는 변경됨? ──아니요──> 건너뜀
                              │ 예
                              v
                     동영상? ──예──> ffmpeg H.265 (임시 폴더) ──> 더 작음? ──아니요──> 원본 사용
                              │ 아니요                               │ 예
                              v                                      v
                     rclone copyto ──> Google 포토 ──> .sync_history.json에 기록 ──> 다음 파일
```

## 요구 사항

- Windows 10 또는 11, Windows PowerShell 5.1(기본 포함) 또는 PowerShell 7 이상
- [rclone](https://rclone.org/)(최신 버전, v1.70 이상 권장)
- `libx265`가 포함된 [ffmpeg](https://ffmpeg.org/)(동영상 압축에만 필요, `-NoTranscode` 사용 시 불필요)
- Google 계정과 무료 Google Cloud 프로젝트(자신의 OAuth 클라이언트용, 아래 참고)

관리자 권한은 필요 없습니다.

## 설정

### 1. rclone과 ffmpeg 설치

```powershell
winget install Rclone.Rclone
winget install Gyan.FFmpeg
```

설치 후 두 프로그램이 `PATH`에 잡히도록 새 터미널을 여세요.

### 2. 나만의 Google OAuth 클라이언트 만들기

rclone의 Google 포토용 공유 클라이언트 ID는 2026년 중에 폐지됩니다. 자신의 클라이언트 ID가 필요하며, 무료이고 5분 정도 걸립니다.

1. [Google Cloud Console](https://console.cloud.google.com/)을 열고 프로젝트를 만듭니다(예: `gphotos-backup`).
2. **API 및 서비스 > 라이브러리**: **Photos Library API**를 사용 설정합니다.
3. **Google Auth Platform > 브랜딩 / 대상**: **외부**를 선택하고 앱 이름과 이메일을 입력한 뒤, 내 Google 계정을 **테스트 사용자**로 추가합니다.
4. **데이터 액세스 > 범위 추가 또는 삭제**: 다음 세 가지 범위를 추가합니다.
   `https://www.googleapis.com/auth/photoslibrary.appendonly`,
   `https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata`,
   `https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata`
5. **클라이언트 > 클라이언트 만들기**: 유형은 **데스크톱 앱**. **클라이언트 ID**와 **클라이언트 보안 비밀번호**를 복사합니다.
6. 권장: **대상**에서 **앱 게시**를 클릭합니다. 앱이 "테스트" 상태이면 Google이 7일마다 로그인을 만료시킵니다. 로그인할 때 "Google에서 확인하지 않은 앱" 경고가 나타나지만, 내 앱이므로 정상입니다.

자세한 내용은 rclone 문서를 참고하세요: [Google Photos: making your own client ID](https://rclone.org/googlephotos/)

### 3. rclone 리모트 설정

```powershell
rclone config
```

`n`(새 리모트), 이름 **`gphotos`**, 스토리지 **Google Photos**, `client_id`와 `client_secret` 붙여넣기, `read_only` = **false**로 답한 뒤, rclone이 브라우저를 열면 로그인합니다. 다음 명령으로 확인합니다.

```powershell
rclone lsd gphotos:
```

이전 버전의 rclone에서 업그레이드한 뒤 권한 오류가 나면 `rclone config reconnect gphotos:`를 실행하세요.

### 4. 스크립트 다운로드 및 미리 보기

```powershell
git clone https://github.com/carlosnakazawa/gphotos-smart-backup.git
cd gphotos-smart-backup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1 -WhatIf
```

`-ExecutionPolicy Bypass`는 이 프로세스에만 적용됩니다. ZIP으로 받았다면 먼저 `Get-ChildItem -Recurse | Unblock-File`을 실행할 수 있습니다. `-WhatIf`는 업로드될 항목을 보여 줄 뿐 아무것도 바꾸지 않습니다.

### 5. 실행

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1
```

## 사용법

```powershell
# 사진 폴더를 gphotos:upload로(기본값)
.\gphotos-backup.ps1

# 다른 폴더, 하위 폴더마다 앨범 하나
.\gphotos-backup.ps1 -SourcePath 'D:\Camera' -AlbumPerFolder

# 더 작은 동영상(인코딩은 더 느림)
.\gphotos-backup.ps1 -Crf 26 -Preset medium

# 동영상을 그대로 업로드
.\gphotos-backup.ps1 -NoTranscode

# 일부 폴더를 건너뛰고 DNG 파일 포함
.\gphotos-backup.ps1 -ExcludeFolder 'Screenshots', '_Upload_Staging' -PhotoExtensions '.jpg', '.jpeg', '.png', '.heic', '.dng'

# 전체 도움말
Get-Help .\gphotos-backup.ps1 -Detailed
```

| 매개변수 | 기본값 | 설명 |
| --- | --- | --- |
| `-SourcePath` | 사진 폴더 | 원본이 있는 폴더(하위 폴더 포함). |
| `-RcloneRemote` | `gphotos:upload` | rclone 대상. `upload`는 앨범 없이 라이브러리에 넣습니다. |
| `-AlbumPerFolder` | 끔 | `2024\Trip\`의 파일은 `2024/Trip` 앨범으로 갑니다. 최상위 파일은 `-RcloneRemote`로 갑니다. |
| `-HistoryFile` | `사진\.sync_history.json` | 업로드 기록. 하나의 파일을 여러 원본 폴더가 함께 쓸 수 있습니다. |
| `-StagingPath` | `%TEMP%\gphotos-smart-backup` | 변환된 동영상의 임시 폴더(파일마다 비워짐). |
| `-Crf` | `24` | H.265 화질(0~51). 낮을수록 화질이 좋고 파일이 커집니다. 22~28이 적당합니다. |
| `-Preset` | `veryfast` | x265 속도. `medium`, `slow`는 파일이 작아지지만 시간이 더 걸립니다. |
| `-NoTranscode` | 끔 | ffmpeg를 사용하지 않습니다. |
| `-SkipTranscodeBelowMbps` | `4` | 1080p 30fps 기준으로 환산한 비트레이트가 이 값 이하이면 동영상을 그대로 업로드합니다(HEVC, AV1, VP9는 두 배). `0`이면 모든 동영상을 변환합니다. |
| `-PhotoExtensions` / `-VideoExtensions` | 위 참고 | 업로드할 파일 형식. |
| `-ExcludeFolder` | `_Upload_Staging` | 어느 깊이에서든 건너뛸 폴더 이름. |
| `-RclonePath` / `-FfmpegPath` / `-FfprobePath` | `rclone` / `ffmpeg` / ffmpeg와 같은 폴더 | `PATH`에 없을 때의 실행 파일. |
| `-WhatIf` / `-Confirm` | | 미리 보기, 또는 파일마다 확인. |

rclone 옵션은 환경 변수로도 지정할 수 있습니다. 예를 들어 `$env:RCLONE_BWLIMIT = '4M'`로 업로드 대역폭을 제한할 수 있습니다.

## 예약 실행(자동 백업)

작업 스케줄러로 매일 저녁 실행하세요. 작업은 로그인한 내 계정으로 실행되므로 rclone이 설정을 찾을 수 있고, 비밀번호는 저장되지 않습니다.

```powershell
$script = 'C:\Tools\gphotos-smart-backup\gphotos-backup.ps1'   # 경로에 맞게 수정
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 21:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 12)
Register-ScheduledTask -TaskName 'gphotos-smart-backup' -Action $action -Trigger $trigger -Settings $settings

# 삭제
Unregister-ScheduledTask -TaskName 'gphotos-smart-backup' -Confirm:$false
```

실행이 중단되더라도 다음 실행에서 그대로 이어서 진행합니다.

## 기록 파일

`.sync_history.json`은 `-SourcePath` 기준 상대 경로를 `<크기>_<마지막-수정-시각-틱>`에 대응시킵니다.

```json
{
    "2026\\Trip\\IMG_0412.HEIC": "2735969_639012345670000000"
}
```

- 항목을 삭제하면 해당 파일을 다시 업로드합니다. 기록 파일 이름을 바꾸면 처음부터 전체를 다시 업로드합니다.
- 사진을 편집하면 크기나 날짜가 바뀌어 다시 업로드됩니다. Google 포토에는 두 버전이 모두 남습니다.
- 이 파일에는 파일 이름이 들어 있습니다. 공개하지 마세요(`.gitignore`에 포함되어 있습니다).
- 스크립트 첫 버전과 같은 형식과 기본 위치를 사용하므로, 기존 기록을 그대로 사용할 수 있습니다.

## 알아 두면 좋은 점(제한 사항)

- **저장용량:** API를 통한 업로드는 항상 "원본 화질"이며 Google 저장용량을 차지합니다. API에는 "저장용량 절약 화질" 옵션이 없습니다. 그래서 동영상을 압축합니다.
- **날짜:** Google 포토는 EXIF나 메타데이터의 날짜를 사용합니다. 날짜 정보가 없는 파일(일부 스크린샷, 메신저 앱 이미지)은 업로드 날짜로 표시됩니다.
- **중복:** Google 포토는 동일한 파일을 인식하므로 같은 파일을 두 번 올려도 사본이 생기지 않습니다. 단, 다시 인코딩한 동영상은 다른 파일입니다.
- **Google 포토에서 삭제했다면?** 스크립트는 Google 포토를 확인하지 않습니다. 기록에 있는 파일은 온라인에서 삭제했더라도 다시 업로드되지 않습니다.
- **HDR / Dolby Vision** 동영상은 다시 인코딩하면 HDR 느낌이 사라질 수 있습니다. 중요하다면 `-NoTranscode`를 사용하거나 해당 폴더를 제외하세요.
- **rclone이 볼 수 있는 것:** 2025년 3월 31일부터 Google은 앱이 직접 업로드한 미디어만 읽을 수 있게 했습니다. 이 도구는 업로드만 하므로 문제가 없습니다.
- **할당량:** Google 포토 API에는 일일 요청 한도가 있습니다. 아주 큰 첫 업로드는 여러 번 실행해야 할 수 있지만, 기록 덕분에 문제없이 이어집니다.

## 하지 않는 일

- 로컬 파일을 삭제, 이동, 수정하지 않습니다.
- Google 포토에서 아무것도 삭제하지 않습니다(`rclone copyto`만 사용하며, 안전 장치 테스트로 확인합니다).
- 내 rclone 리모트를 통해 Google 포토로 보내는 것 외에는 어디에도 데이터를 보내지 않습니다.

## 개발

```powershell
# 빠른 정적 검사(구문, ASCII 전용, 안전 장치)
.\scripts\Invoke-HarnessCheck.ps1 -SkipAnalyzer -SkipPester

# 전체(PSScriptAnalyzer 1.25.0과 Pester 5.5 이상 필요)
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck
.\scripts\Invoke-HarnessCheck.ps1
```

CI는 분석기, Pester 테스트(rclone과 ffmpeg는 모의 처리), `-WhatIf` 스모크 테스트를 **Windows Server 2022와 2025**에서 **Windows PowerShell 5.1과 PowerShell 7** 모두로 실행합니다.

`.ps1` 파일은 의도적으로 **ASCII 전용**입니다. Windows PowerShell 5.1은 BOM이 없는 파일을 ANSI 코드 페이지로 읽기 때문에, ASCII가 아닌 문자가 있으면 스크립트가 깨집니다. 테스트로 이를 확인합니다.

AI 코딩 에이전트는 먼저 [AGENTS.md](../AGENTS.md)를 읽으세요.

## 기여하기

버그 신고, 아이디어, 번역, 풀 리퀘스트를 어떤 언어로든 환영합니다. [CONTRIBUTING.md](../CONTRIBUTING.md)를 참고하세요. 처음 기여하기 좋은 일:

- 내 카메라나 휴대폰 파일로 테스트하고 결과 알려 주기
- 번역을 개선하거나 내 언어 추가하기
- 로드맵 항목 하나 맡기

## 로드맵

- 예약 작업을 명령 하나로 만드는 보조 스크립트 `Register-BackupTask.ps1`
- 더 빠른 변환을 위한 하드웨어 인코딩(NVENC, Quick Sync, AMF) 옵션
- 다시 인코딩할 때 HDR 메타데이터 유지
- 로그 파일과 실행별 JSON 보고서
- PowerShell Gallery와 `winget` 배포

## 라이선스

[MIT](../LICENSE) © Carlos Alberto Nakazawa

*이 프로젝트는 Google과 제휴하거나 Google의 승인 또는 후원을 받지 않았습니다. Google 포토와 Google Drive는 Google LLC의 상표입니다.*
