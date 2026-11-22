# Google Photos Smart Backup

[![CI](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](../LICENSE)
![PowerShell 5.1 | 7](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)
![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4)
[![Contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](../CONTRIBUTING.md)

[English](../README.md) | [Português (Brasil)](README.pt-BR.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Italiano](README.it.md) | [Русский](README.ru.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | **简体中文**

> 本译文可能落后于作为基准的[英文版本](../README.md)。

把 Windows 电脑上的照片和视频自动备份到 **Google 相册**，无需一直开着浏览器标签页。为节省空间，视频会在 **上传前压缩为 H.265**；每次上传都会 **立即记录**，因此中断后会从停下的地方继续。

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

## 为什么会有这个项目

多年来，Windows 用户可以使用 Google 的桌面应用（“备份与同步”，后来是 **Google 云端硬盘桌面版**）把文件夹备份到 Google 相册。**现在这条路已经关闭**：

- 自 **2026 年 6 月 15 日** 起，Google 云端硬盘桌面版不再允许添加要备份到 Google 相册的文件夹；
- **2026 年 8 月 10 日**，它彻底停止向 Google 相册上传新的照片和视频。

Google 给出的替代方案是 [photos.google.com](https://photos.google.com) 上的“备份文件夹”，但它 **只有在浏览器中保持打开 Google 相册网页时才会运行**。Windows 上已经没有后台备份的方式了。

本项目用一个小巧、透明的 PowerShell 脚本填补这一空白，它基于两个知名的开源工具：[rclone](https://rclone.org/googlephotos/) 和 [ffmpeg](https://ffmpeg.org/)。

- 可以 **无人值守** 运行（例如通过任务计划程序），不需要浏览器，也不需要 Google 应用；
- **只上传新增或修改过的文件**，并在本地记录每个已上传的文件；
- 上传前 **压缩视频**。通过 Google 相册 API 上传的文件始终以 **原始画质保存，并占用你的 Google 存储空间**，因此把 4K 视频重新编码为 H.265 可以节省大量空间；
- **从不删除或移动任何内容**，无论是在电脑上还是在 Google 相册中。

**这是一个社区项目，非常欢迎大家参与。** 如果你也受到 Google 云端硬盘桌面版停止备份的影响，欢迎试用、[报告问题](https://github.com/carlosnakazawa/gphotos-smart-backup/issues/new?template=bug_report.yml)、提出建议、改进翻译或提交 Pull Request。详见 [CONTRIBUTING.md](../CONTRIBUTING.md)。使用任何语言都可以。

## 功能

| | |
| --- | --- |
| **增量上传** | 用 JSON 历史记录（`相对路径 -> 大小 + 修改时间`）判断哪些文件已在 Google 相册中。只上传新增和编辑过的文件，其余文件几秒内即可跳过。 |
| **断点续传** | 每个文件上传后立即记录。即使电脑休眠、网络中断或按下 Ctrl+C，下次运行也会从同一个文件继续。 |
| **智能视频压缩** | 使用 ffmpeg 转为 H.265/HEVC（默认 `-crf 24 -preset veryfast`，可调）。保留拍摄日期和位置信息，包括 iPhone 的 Apple `com.apple.quicktime.*` 标签。如果 H.265 版本没有变小，就上传原文件。 |
| **相册（可选）** | 使用 `-AlbumPerFolder` 时，每个子文件夹中的文件会放入以该文件夹命名的相册。 |
| **安全** | 只上传（`rclone copyto`）。不跟随符号链接或目录联接。`-WhatIf` 可在不上传的情况下预览全部操作。历史文件损坏时会停止运行，而不是重新上传整个图库。 |
| **便于自动化** | 退出码：`0` 成功，`1` 出错（已停止），`2` 已完成但部分视频无法转码。 |

默认支持的格式：`.jpg .jpeg .png .heic .heif .webp .gif`（照片）和 `.mp4 .mov .m4v`（视频）。RAW 文件（`.dng`、`.arw`、`.cr2` 等）和附属文件（`.lrf`、`.xmp` 等）被有意排除。如有需要，可用 `-PhotoExtensions` 添加。

## 工作原理

```text
 你的文件夹 ──扫描──> 新增或已修改? ──否──> 跳过
                              │ 是
                              v
                     视频? ──是──> ffmpeg H.265 (临时文件夹) ──> 更小? ──否──> 使用原文件
                              │ 否                                   │ 是
                              v                                      v
                     rclone copyto ──> Google 相册 ──> 记录到 .sync_history.json ──> 下一个文件
```

## 环境要求

- Windows 10 或 11，带有 Windows PowerShell 5.1（系统自带）或 PowerShell 7+
- [rclone](https://rclone.org/)（较新的版本，推荐 v1.70 或更高）
- 带 `libx265` 的 [ffmpeg](https://ffmpeg.org/)（仅用于压缩视频；使用 `-NoTranscode` 时不需要）
- 一个 Google 账号和一个免费的 Google Cloud 项目（用于你自己的 OAuth 客户端，见下文）

不需要管理员权限。

## 安装配置

### 1. 安装 rclone 和 ffmpeg

```powershell
winget install Rclone.Rclone
winget install Gyan.FFmpeg
```

安装后请打开一个新的终端，确保两者都在 `PATH` 中。

### 2. 创建你自己的 Google OAuth 客户端

rclone 用于 Google 相册的共享客户端 ID 将在 2026 年内停用。你需要自己的客户端 ID，免费，大约 5 分钟即可完成：

1. 打开 [Google Cloud Console](https://console.cloud.google.com/)，创建一个项目（例如 `gphotos-backup`）。
2. **API 和服务 > 库**：启用 **Photos Library API**。
3. **Google Auth Platform > 品牌塑造 / 目标对象**：选择 **外部**，填写应用名称和你的邮箱，并把你的 Google 账号添加为 **测试用户**。
4. **数据访问 > 添加或移除范围**：添加以下三个范围：
   `https://www.googleapis.com/auth/photoslibrary.appendonly`,
   `https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata`,
   `https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata`
5. **客户端 > 创建客户端**：类型选择 **桌面应用**。复制 **客户端 ID** 和 **客户端密钥**。
6. 建议：在 **目标对象** 中点击 **发布应用**。应用处于“测试”状态时，Google 每 7 天会让登录失效。登录时会看到“Google 未验证此应用”的警告，这是正常的，因为这是你自己的应用。

更多细节请参阅 rclone 文档：[Google Photos: making your own client ID](https://rclone.org/googlephotos/)

### 3. 配置 rclone 远程

```powershell
rclone config
```

依次回答：`n`（新建远程），名称 **`gphotos`**，存储类型 **Google Photos**，粘贴 `client_id` 和 `client_secret`，`read_only` = **false**，然后让 rclone 打开浏览器登录。用以下命令检查：

```powershell
rclone lsd gphotos:
```

如果你从旧版本升级了 rclone 并遇到权限错误，请运行 `rclone config reconnect gphotos:`。

### 4. 下载脚本并预览

```powershell
git clone https://github.com/carlosnakazawa/gphotos-smart-backup.git
cd gphotos-smart-backup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1 -WhatIf
```

`-ExecutionPolicy Bypass` 只对当前进程生效。如果下载的是 ZIP，可以先运行 `Get-ChildItem -Recurse | Unblock-File`。`-WhatIf` 只列出将要上传的内容，不做任何更改。

### 5. 运行

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1
```

## 用法

```powershell
# 把“图片”文件夹上传到 gphotos:upload（默认值）
.\gphotos-backup.ps1

# 其他文件夹，每个子文件夹一个相册
.\gphotos-backup.ps1 -SourcePath 'D:\Camera' -AlbumPerFolder

# 更小的视频（编码更慢）
.\gphotos-backup.ps1 -Crf 26 -Preset medium

# 视频按原样上传
.\gphotos-backup.ps1 -NoTranscode

# 跳过部分文件夹，并包含 DNG 文件
.\gphotos-backup.ps1 -ExcludeFolder 'Screenshots', '_Upload_Staging' -PhotoExtensions '.jpg', '.jpeg', '.png', '.heic', '.dng'

# 完整帮助
Get-Help .\gphotos-backup.ps1 -Detailed
```

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `-SourcePath` | “图片”文件夹 | 存放原始文件的文件夹（包括子文件夹）。 |
| `-RcloneRemote` | `gphotos:upload` | rclone 目标。`upload` 会把文件放入图库，不归入相册。 |
| `-AlbumPerFolder` | 关闭 | `2024\Trip\` 中的文件进入相册 `2024/Trip`。顶层文件进入 `-RcloneRemote`。 |
| `-HistoryFile` | `图片\.sync_history.json` | 上传历史记录。多个源文件夹可以共用一个文件。 |
| `-StagingPath` | `%TEMP%\gphotos-smart-backup` | 转码视频的临时文件夹（每个文件处理完后清空）。 |
| `-Crf` | `24` | H.265 画质，取值 0 到 51。数值越小画质越好、文件越大。22 到 28 比较合适。 |
| `-Preset` | `veryfast` | x265 速度。`medium` 和 `slow` 文件更小，但耗时更长。 |
| `-NoTranscode` | 关闭 | 不使用 ffmpeg。 |
| `-PhotoExtensions` / `-VideoExtensions` | 见上文 | 要上传的文件类型。 |
| `-ExcludeFolder` | `_Upload_Staging` | 在任意层级跳过的文件夹名称。 |
| `-RclonePath` / `-FfmpegPath` | `rclone` / `ffmpeg` | 不在 `PATH` 中时的可执行文件路径。 |
| `-WhatIf` / `-Confirm` | | 预览，或逐个文件确认。 |

任何 rclone 选项都可以通过环境变量设置，例如用 `$env:RCLONE_BWLIMIT = '4M'` 限制上传带宽。

## 计划任务（自动备份）

用任务计划程序每天晚上运行。任务以你的账号、在你登录期间运行，因此 rclone 能找到你的配置，也不会保存任何密码：

```powershell
$script = 'C:\Tools\gphotos-smart-backup\gphotos-backup.ps1'   # 按实际路径修改
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 21:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 12)
Register-ScheduledTask -TaskName 'gphotos-smart-backup' -Action $action -Trigger $trigger -Settings $settings

# 删除任务
Unregister-ScheduledTask -TaskName 'gphotos-smart-backup' -Confirm:$false
```

如果某次运行被中断，下一次会直接继续。

## 历史记录文件

`.sync_history.json` 把每个文件相对于 `-SourcePath` 的路径映射为 `<大小>_<最后修改时间的刻度值>`：

```json
{
    "2026\\Trip\\IMG_0412.HEIC": "2735969_639012345670000000"
}
```

- 删除某一条记录即可重新上传该文件。重命名历史文件会从头开始完整上传。
- 编辑照片后，其大小或日期会改变，因此会再次上传。Google 相册会保留两个版本。
- 该文件包含你的文件名，请勿公开（它已列入 `.gitignore`）。
- 它沿用脚本第一个版本的格式和默认位置，因此现有的历史记录可以继续使用。

## 须知（限制）

- **存储空间：** 通过 API 上传的文件始终是“原始画质”，并占用你的 Google 存储空间。API 不提供“节省存储空间”选项。这就是要压缩视频的原因。
- **日期：** Google 相册使用 EXIF 或元数据中的日期。没有日期信息的文件（部分截图、聊天应用中的图片）会显示上传日期。
- **重复文件：** Google 相册能识别完全相同的文件，所以同一文件上传两次不会产生副本。但重新编码后的视频是另一个文件。
- **在 Google 相册中删除了？** 脚本不会查询 Google 相册。已在历史记录中的文件不会再次上传，即使你已在网上删除。
- **HDR / Dolby Vision** 视频在重新编码后可能失去 HDR 效果。如果在意，请使用 `-NoTranscode`（或排除这些文件夹）。
- **rclone 能看到什么：** 自 2025 年 3 月 31 日起，Google 只允许应用读取它们自己上传的媒体。本工具只负责上传，所以没有影响。
- **配额：** Google 相册 API 有每日请求上限。非常大的首次上传可能需要运行多次，历史记录会让这一过程很轻松。

## 它不会做什么

- 从不删除、移动或修改你的本地文件。
- 从不删除 Google 相册中的任何内容（只使用 `rclone copyto`，并有防护测试确保这一点）。
- 除了通过你自己的 rclone 远程上传到 Google 相册之外，不向任何地方发送数据。

## 开发

```powershell
# 快速静态检查（语法、仅 ASCII、防护规则）
.\scripts\Invoke-HarnessCheck.ps1 -SkipAnalyzer -SkipPester

# 全部检查（需要 PSScriptAnalyzer 1.25.0 和 Pester 5.5+）
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck
.\scripts\Invoke-HarnessCheck.ps1
```

CI 会在 **Windows Server 2022 和 2025** 上，分别使用 **Windows PowerShell 5.1 和 PowerShell 7** 运行分析器、Pester 测试（rclone 和 ffmpeg 均为模拟）以及 `-WhatIf` 冒烟测试。

`.ps1` 文件有意保持 **仅含 ASCII**：Windows PowerShell 5.1 会用 ANSI 代码页读取不带 BOM 的文件，非 ASCII 字符会导致脚本出错。有测试会检查这一点。

AI 编程代理：请先阅读 [AGENTS.md](../AGENTS.md)。

## 参与贡献

欢迎用任何语言提交问题报告、想法、翻译和 Pull Request。详见 [CONTRIBUTING.md](../CONTRIBUTING.md)。适合作为第一次贡献的事情：

- 用你的相机或手机文件测试，并分享结果；
- 改进翻译，或添加你的语言；
- 认领路线图中的一项。

## 路线图

- 辅助脚本 `Register-BackupTask.ps1`，一条命令创建计划任务。
- 可选的硬件编码（NVENC、Quick Sync、AMF），加快转码。
- 根据码率，跳过已是 HEVC 或体积较小的视频。
- 重新编码时保留 HDR 元数据。
- 日志文件和每次运行的 JSON 报告。
- 发布到 PowerShell Gallery 和 `winget`。

## 许可证

[MIT](../LICENSE) © Carlos Alberto Nakazawa

*本项目与 Google 无关，未获得 Google 的认可或赞助。Google 相册和 Google 云端硬盘是 Google LLC 的商标。*
