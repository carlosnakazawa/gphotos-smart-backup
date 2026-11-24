# Google Photos Smart Backup

[![CI](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](../LICENSE)
![PowerShell 5.1 | 7](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)
![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4)
[![Contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](../CONTRIBUTING.md)

[English](../README.md) | [Português (Brasil)](README.pt-BR.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Italiano](README.it.md) | [Русский](README.ru.md) | **日本語** | [한국어](README.ko.md) | [简体中文](README.zh-CN.md)

> この翻訳は、基準となる[英語版](../README.md)より古い場合があります。

Windows PC の写真と動画を、ブラウザのタブを開いたままにすることなく、自動で **Google フォト** にバックアップします。容量を節約するため、動画は **アップロード前に H.265 に圧縮** されます。また、アップロードのたびに **すぐ記録** されるので、中断しても続きから再開できます。

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

## このプロジェクトが生まれた理由

長年、Windows ユーザーは Google のデスクトップアプリ（「バックアップと同期」、その後の **パソコン版 Google ドライブ**）でフォルダを Google フォトにバックアップできました。**それは終わりました**。

- **2026 年 6 月 15 日** 以降、パソコン版 Google ドライブでは Google フォトへのバックアップ対象フォルダを追加できなくなりました。
- **2026 年 8 月 10 日** には、新しい写真と動画の Google フォトへのアップロードが完全に停止しました。

Google の代替手段は [photos.google.com](https://photos.google.com) の「フォルダをバックアップ」ですが、これは **Google フォトのウェブページをブラウザで開いている間しか動きません**。Windows でバックグラウンドのバックアップを行う手段はもうありません。

このプロジェクトは、よく知られた 2 つのオープンソースツール [rclone](https://rclone.org/googlephotos/) と [ffmpeg](https://ffmpeg.org/) を使った、小さく透明な PowerShell スクリプトでその穴を埋めます。

- ブラウザも Google のアプリも使わずに **無人で** 実行できます（タスク スケジューラなど）。
- **新規または変更されたファイルだけ** をアップロードし、送信済みファイルの履歴をローカルに保存します。
- アップロード前に **動画を小さく** します。Google フォト API 経由でアップロードしたファイルは常に **元の画質で保存され、Google の保存容量を消費します**。そのため、4K 動画を H.265 に再エンコードすると大きく容量を節約できます。
- PC 上でも Google フォト上でも、**何も削除・移動しません**。

**これはコミュニティのプロジェクトです。ご協力を心から歓迎します。** パソコン版 Google ドライブのバックアップ終了で困っている方は、ぜひ試して、[うまく動かない点を報告](https://github.com/carlosnakazawa/gphotos-smart-backup/issues/new?template=bug_report.yml)したり、アイデアを提案したり、翻訳を改善したり、プルリクエストを送ったりしてください。詳しくは [CONTRIBUTING.md](../CONTRIBUTING.md) をご覧ください。どの言語でも構いません。

## 機能

| | |
| --- | --- |
| **差分アップロード** | JSON 履歴（`相対パス -> サイズ + 更新日時`）で、どのファイルが Google フォトにあるかを判断します。新規・編集済みのファイルだけをアップロードし、それ以外は数秒でスキップします。 |
| **再開可能** | 各ファイルはアップロード直後に記録されます。PC がスリープしても、回線が切れても、Ctrl+C を押しても、次回は同じファイルから続けます。 |
| **スマートな動画圧縮** | ffmpeg で H.265/HEVC に変換します（既定は `-crf 24 -preset veryfast`、変更可能）。撮影日時と位置情報は保持され、iPhone の Apple `com.apple.quicktime.*` タグも残ります。H.265 版が小さくならない場合は元のファイルをアップロードします。すでに十分小さい動画（最近の iPhone の HEVC など）は ffprobe で判定し、再エンコードに時間をかけずにそのままアップロードします。 |
| **アルバム（任意）** | `-AlbumPerFolder` を付けると、サブフォルダごとにその名前のアルバムへ入れます。 |
| **安全** | アップロードのみ（`rclone copyto`）。シンボリックリンクやジャンクションはたどりません。`-WhatIf` で何もアップロードせずに確認できます。履歴ファイルが壊れている場合は、ライブラリ全体を再アップロードせずに停止します。 |
| **自動化しやすい** | 終了コード: `0` 成功、`1` エラー（停止）、`2` 完了したが一部の動画を変換できなかった。 |

既定で対象となる形式: `.jpg .jpeg .png .heic .heif .webp .gif`（写真）、`.mp4 .mov .m4v`（動画）。RAW ファイル（`.dng`、`.arw`、`.cr2` など）や付属ファイル（`.lrf`、`.xmp` など）は意図的に除外しています。必要なら `-PhotoExtensions` で追加できます。

## 仕組み

```text
 フォルダ ──スキャン──> 新規または変更? ──いいえ──> スキップ
                              │ はい
                              v
                     動画? ──はい──> ffmpeg H.265 (一時フォルダ) ──> 小さくなった? ──いいえ──> 元のファイルを使う
                              │ いいえ                                    │ はい
                              v                                           v
                     rclone copyto ──> Google フォト ──> .sync_history.json に記録 ──> 次のファイル
```

## 必要なもの

- Windows 10 または 11、Windows PowerShell 5.1（標準搭載）または PowerShell 7 以降
- [rclone](https://rclone.org/)（最近のバージョン。v1.70 以降を推奨）
- `libx265` 付きの [ffmpeg](https://ffmpeg.org/)（動画圧縮にのみ使用。`-NoTranscode` なら不要）
- Google アカウントと無料の Google Cloud プロジェクト（自分専用の OAuth クライアント用。下記参照）

管理者権限は不要です。

## セットアップ

### 1. rclone と ffmpeg をインストール

```powershell
winget install Rclone.Rclone
winget install Gyan.FFmpeg
```

その後、両方が `PATH` に入るよう新しいターミナルを開いてください。

### 2. 自分専用の Google OAuth クライアントを作成

rclone の Google フォト用共有クライアント ID は 2026 年中に廃止されます。自分のものが必要です。無料で、5 分ほどで作れます。

1. [Google Cloud Console](https://console.cloud.google.com/) を開き、プロジェクトを作成します（例: `gphotos-backup`）。
2. **API とサービス > ライブラリ**: **Photos Library API** を有効にします。
3. **Google Auth Platform > ブランディング / 対象**: **外部** を選び、アプリ名とメールアドレスを入力し、自分の Google アカウントを **テストユーザー** に追加します。
4. **データアクセス > スコープを追加または削除**: 次の 3 つのスコープを追加します。
   `https://www.googleapis.com/auth/photoslibrary.appendonly`,
   `https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata`,
   `https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata`
5. **クライアント > クライアントを作成**: 種類は **デスクトップ アプリ**。**クライアント ID** と **クライアント シークレット** をコピーします。
6. 推奨: **対象** で **アプリを公開** をクリックします。アプリが「テスト」状態のままだと、Google はログインを 7 日ごとに失効させます。ログイン時に「このアプリは Google で確認されていません」という警告が出ますが、自分のアプリなので問題ありません。

詳しくは rclone のドキュメントを参照してください: [Google Photos: making your own client ID](https://rclone.org/googlephotos/)

### 3. rclone のリモートを設定

```powershell
rclone config
```

`n`（新しいリモート）、名前は **`gphotos`**、ストレージは **Google Photos**、`client_id` と `client_secret` を貼り付け、`read_only` = **false** と答え、rclone にブラウザを開かせてサインインします。確認方法:

```powershell
rclone lsd gphotos:
```

古いバージョンの rclone から更新して権限エラーが出る場合は、`rclone config reconnect gphotos:` を実行してください。

### 4. スクリプトをダウンロードしてプレビュー

```powershell
git clone https://github.com/carlosnakazawa/gphotos-smart-backup.git
cd gphotos-smart-backup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1 -WhatIf
```

`-ExecutionPolicy Bypass` はこのプロセスにだけ適用されます。ZIP をダウンロードした場合は、先に `Get-ChildItem -Recurse | Unblock-File` を実行できます。`-WhatIf` はアップロード対象を一覧表示するだけで、何も変更しません。

### 5. 実行

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1
```

## 使い方

```powershell
# ピクチャ フォルダを gphotos:upload へ（既定値）
.\gphotos-backup.ps1

# 別のフォルダ、サブフォルダごとにアルバム
.\gphotos-backup.ps1 -SourcePath 'D:\Camera' -AlbumPerFolder

# 動画をさらに小さく（エンコードは遅くなる）
.\gphotos-backup.ps1 -Crf 26 -Preset medium

# 動画をそのままアップロード
.\gphotos-backup.ps1 -NoTranscode

# 一部のフォルダを除外し、DNG も含める
.\gphotos-backup.ps1 -ExcludeFolder 'Screenshots', '_Upload_Staging' -PhotoExtensions '.jpg', '.jpeg', '.png', '.heic', '.dng'

# 詳しいヘルプ
Get-Help .\gphotos-backup.ps1 -Detailed
```

| パラメーター | 既定値 | 説明 |
| --- | --- | --- |
| `-SourcePath` | ピクチャ フォルダ | 元ファイルのあるフォルダ（サブフォルダを含む）。 |
| `-RcloneRemote` | `gphotos:upload` | rclone の送信先。`upload` はアルバムなしでライブラリに入れます。 |
| `-AlbumPerFolder` | オフ | `2024\Trip\` のファイルはアルバム `2024/Trip` へ。最上位のファイルは `-RcloneRemote` へ。 |
| `-HistoryFile` | `ピクチャ\.sync_history.json` | アップロード履歴。1 つのファイルを複数の元フォルダで共有できます。 |
| `-StagingPath` | `%TEMP%\gphotos-smart-backup` | 変換した動画の一時フォルダ（ファイルごとに空になります）。 |
| `-Crf` | `24` | H.265 の画質（0〜51）。小さいほど高画質でファイルが大きくなります。22〜28 が目安です。 |
| `-Preset` | `veryfast` | x265 の速度。`medium` や `slow` はファイルが小さくなりますが時間がかかります。 |
| `-NoTranscode` | オフ | ffmpeg を使いません。 |
| `-SkipTranscodeBelowMbps` | `4` | 1080p・30 fps 換算のビットレートがこの値以下なら、動画をそのままアップロードします（HEVC、AV1、VP9 は 2 倍の値）。`0` ですべての動画を変換します。 |
| `-PhotoExtensions` / `-VideoExtensions` | 上記参照 | アップロードするファイルの種類。 |
| `-ExcludeFolder` | `_Upload_Staging` | どの階層でもスキップするフォルダ名。 |
| `-RclonePath` / `-FfmpegPath` / `-FfprobePath` | `rclone` / `ffmpeg` / ffmpeg と同じ場所 | `PATH` にない場合の実行ファイル。 |
| `-WhatIf` / `-Confirm` | | プレビュー、またはファイルごとに確認。 |

rclone のオプションは環境変数でも指定できます。たとえば `$env:RCLONE_BWLIMIT = '4M'` でアップロード帯域を制限できます。

## スケジュール実行（自動バックアップ）

タスク スケジューラで毎晩実行しましょう。タスクはサインイン中のあなたのアカウントで動くので、rclone が設定を見つけられ、パスワードも保存されません。

```powershell
$script = 'C:\Tools\gphotos-smart-backup\gphotos-backup.ps1'   # 環境に合わせて変更
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 21:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 12)
Register-ScheduledTask -TaskName 'gphotos-smart-backup' -Action $action -Trigger $trigger -Settings $settings

# 削除
Unregister-ScheduledTask -TaskName 'gphotos-smart-backup' -Confirm:$false
```

実行が中断しても、次回はそのまま続きから進みます。

## 履歴ファイル

`.sync_history.json` は、`-SourcePath` からの相対パスを `<サイズ>_<最終更新日時のティック>` に対応付けます。

```json
{
    "2026\\Trip\\IMG_0412.HEIC": "2735969_639012345670000000"
}
```

- エントリを削除すると、そのファイルを再アップロードします。履歴ファイルの名前を変えると、最初から全件アップロードし直します。
- 写真を編集するとサイズや日時が変わるため、再アップロードされます。Google フォトには両方のバージョンが残ります。
- このファイルにはファイル名が含まれます。公開しないでください（`.gitignore` に登録済みです）。
- 形式と既定の場所はスクリプトの最初のバージョンと同じなので、既存の履歴はそのまま使えます。

## 知っておきたいこと（制限事項）

- **保存容量:** API 経由のアップロードは常に「元の画質」で、Google の保存容量を消費します。API には「保存容量の節約画質」がありません。そのため動画を圧縮しています。
- **日付:** Google フォトは EXIF やメタデータの日時を使います。日時情報のないファイル（一部のスクリーンショットやメッセージアプリの画像）はアップロード日になります。
- **重複:** Google フォトは同一ファイルを認識するため、同じファイルを 2 回アップロードしてもコピーは作られません。ただし、再エンコードした動画は別のファイルになります。
- **Google フォトで削除した場合:** スクリプトは Google フォトを確認しません。履歴にあるファイルは、オンラインで削除していても再アップロードされません。
- **HDR / Dolby Vision** の動画は、再エンコードで HDR の見た目が失われることがあります。気になる場合は `-NoTranscode` を使うか、そのフォルダを除外してください。
- **rclone から見えるもの:** 2025 年 3 月 31 日以降、Google はアプリ自身がアップロードしたメディアしか読み取れないようにしました。このツールはアップロードだけを行うので問題ありません。
- **割り当て:** Google フォト API には 1 日あたりのリクエスト上限があります。非常に大きな初回アップロードは数回に分かれることがありますが、履歴のおかげで問題なく続けられます。

## しないこと

- ローカルのファイルを削除・移動・変更することはありません。
- Google フォト上のものを削除することはありません（`rclone copyto` のみを使用し、ガードレールのテストで保証しています）。
- あなた自身の rclone リモートを通じて Google フォトに送る以外、どこにもデータを送信しません。

## 開発

```powershell
# 高速な静的チェック（構文、ASCII のみ、ガードレール）
.\scripts\Invoke-HarnessCheck.ps1 -SkipAnalyzer -SkipPester

# すべて（PSScriptAnalyzer 1.25.0 と Pester 5.5 以降が必要）
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck
.\scripts\Invoke-HarnessCheck.ps1
```

CI では、アナライザー、Pester テスト（rclone と ffmpeg はモック）、`-WhatIf` のスモークテストを、**Windows Server 2022 と 2025** 上の **Windows PowerShell 5.1 と PowerShell 7** の両方で実行します。

`.ps1` ファイルは意図的に **ASCII のみ** にしています。Windows PowerShell 5.1 は BOM なしのファイルを ANSI コードページで読むため、ASCII 以外の文字があるとスクリプトが壊れます。テストでこれを確認しています。

AI コーディングエージェントは、まず [AGENTS.md](../AGENTS.md) を読んでください。

## コントリビュート

バグ報告、アイデア、翻訳、プルリクエストを歓迎します。言語は問いません。[CONTRIBUTING.md](../CONTRIBUTING.md) をご覧ください。最初の貢献におすすめ:

- 自分のカメラやスマートフォンのファイルで試して、結果を報告する
- 翻訳を改善する、または自分の言語を追加する
- ロードマップの項目に取り組む

## ロードマップ

- スケジュールタスクを 1 コマンドで作成する補助スクリプト `Register-BackupTask.ps1`
- 変換を速くするためのハードウェアエンコード（NVENC、Quick Sync、AMF）のオプション
- 再エンコード時に HDR メタデータを保持する
- ログファイルと実行ごとの JSON レポート
- PowerShell Gallery と `winget` での公開

## ライセンス

[MIT](../LICENSE) © Carlos Alberto Nakazawa

*このプロジェクトは Google とは無関係であり、Google による承認や後援を受けていません。Google フォトと Google ドライブは Google LLC の商標です。*
