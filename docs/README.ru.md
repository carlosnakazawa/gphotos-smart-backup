# Google Photos Smart Backup

[![CI](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml)
[![Лицензия: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](../LICENSE)
![PowerShell 5.1 | 7](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)
![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4)
[![Contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](../CONTRIBUTING.md)

[English](../README.md) | [Português (Brasil)](README.pt-BR.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Italiano](README.it.md) | **Русский** | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md)

> Этот перевод может отставать от [английской версии](../README.md), которая является основной.

Автоматическое резервное копирование фото и видео с ПК на Windows в **Google Фото**, без открытой вкладки браузера. Видео **сжимаются в H.265 перед загрузкой**, чтобы экономить место, а каждая загрузка **сразу записывается**, поэтому прерванный запуск продолжается с того же места.

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

## Зачем нужен этот проект

Много лет пользователи Windows могли копировать папку в Google Фото с помощью настольного приложения Google («Автозагрузка и синхронизация», затем **Google Диск для компьютеров**). **Этого больше нет**:

- с **15 июня 2026 года** в Google Диске для компьютеров нельзя добавлять папки для резервного копирования в Google Фото;
- **10 августа 2026 года** он полностью перестал загружать новые фото и видео в Google Фото.

Google предлагает взамен функцию «Резервное копирование папок» на [photos.google.com](https://photos.google.com), которая **работает, только пока страница Google Фото открыта в браузере**. Фонового резервного копирования для Windows больше нет.

Этот проект закрывает пробел небольшим прозрачным скриптом PowerShell на основе двух известных open-source инструментов, [rclone](https://rclone.org/googlephotos/) и [ffmpeg](https://ffmpeg.org/):

- работает **без участия пользователя** (например, из Планировщика заданий), без браузера и приложений Google;
- загружает **только новое или изменённое** и ведёт локальную историю всех отправленных файлов;
- **уменьшает видео** перед загрузкой. Файлы, загруженные через API Google Фото, всегда хранятся в **исходном качестве и занимают место в хранилище Google**, поэтому 4K-видео, перекодированное в H.265, может сэкономить много места;
- **никогда ничего не удаляет и не перемещает** ни на ПК, ни в Google Фото.

**Это проект сообщества, и любая помощь очень приветствуется.** Если вас затронуло прекращение резервного копирования в Google Диске для компьютеров, попробуйте скрипт, [сообщите, что не работает](https://github.com/carlosnakazawa/gphotos-smart-backup/issues/new?template=bug_report.yml), предложите идеи, улучшите переводы или отправьте pull request. См. [CONTRIBUTING.md](../CONTRIBUTING.md). Писать можно на любом языке.

## Возможности

| | |
| --- | --- |
| **Инкрементальность** | История в JSON (`относительный путь -> размер + время изменения`) показывает, какие файлы уже есть в Google Фото. Новые и изменённые файлы загружаются, остальные пропускаются за секунды. |
| **Возобновление** | Каждый файл записывается сразу после загрузки. Если ПК уснул, пропала сеть или вы нажали Ctrl+C, следующий запуск продолжит с того же файла. |
| **Умное сжатие видео** | H.265/HEVC через ffmpeg (по умолчанию `-crf 24 -preset veryfast`, настраивается). Сохраняются дата съёмки и геопозиция, включая теги Apple `com.apple.quicktime.*` с iPhone. Если версия H.265 не меньше оригинала, загружается оригинал. Уже компактные видео (например, HEVC с современных iPhone) определяются через ffprobe и загружаются как есть, без лишнего перекодирования. |
| **Альбомы (по желанию)** | `-AlbumPerFolder` помещает файлы каждой подпапки в альбом с её именем. |
| **Безопасность** | Только загрузка (`rclone copyto`). Символические ссылки и junction-точки не обходятся. `-WhatIf` показывает всё без загрузки. Повреждённая история останавливает запуск, а не загружает всю медиатеку заново. |
| **Удобно для автоматизации** | Коды выхода: `0` успех, `1` ошибка (остановлено), `2` завершено, но некоторые видео не удалось перекодировать. |

Форматы по умолчанию: `.jpg .jpeg .png .heic .heif .webp .gif` (фото) и `.mp4 .mov .m4v` (видео). RAW-файлы (`.dng`, `.arw`, `.cr2`, ...) и вспомогательные файлы (`.lrf`, `.xmp`, ...) намеренно исключены. Их можно добавить через `-PhotoExtensions`.

## Как это работает

```text
 Ваша папка ──сканирование──> новый или изменён? ──нет──> пропустить
                              │ да
                              v
                     видео? ──да──> ffmpeg H.265 (временная папка) ──> меньше? ──нет──> взять оригинал
                              │ нет                                       │ да
                              v                                           v
                     rclone copyto ──> Google Фото ──> запись в .sync_history.json ──> следующий файл
```

## Требования

- Windows 10 или 11 с Windows PowerShell 5.1 (встроен) или PowerShell 7+
- [rclone](https://rclone.org/) (свежая версия; рекомендуется v1.70 или новее)
- [ffmpeg](https://ffmpeg.org/) с `libx265` (только для сжатия видео; не нужен с `-NoTranscode`)
- Аккаунт Google и бесплатный проект Google Cloud (для собственного OAuth-клиента, см. ниже)

Права администратора не нужны.

## Настройка

### 1. Установите rclone и ffmpeg

```powershell
winget install Rclone.Rclone
winget install Gyan.FFmpeg
```

Затем откройте новый терминал, чтобы обе программы оказались в `PATH`.

### 2. Создайте собственный OAuth-клиент Google

Общий client ID rclone для Google Фото выводится из эксплуатации в течение 2026 года. Нужен собственный: это бесплатно и занимает около 5 минут.

1. Откройте [Google Cloud Console](https://console.cloud.google.com/) и создайте проект (например, `gphotos-backup`).
2. **APIs & Services > Library**: включите **Photos Library API**.
3. **Google Auth Platform > Branding / Audience**: выберите **External**, укажите название приложения и свою почту и добавьте свой аккаунт Google как **тестового пользователя**.
4. **Data Access > Add or remove scopes**: добавьте эти три scope:
   `https://www.googleapis.com/auth/photoslibrary.appendonly`,
   `https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata`,
   `https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata`.
5. **Clients > Create client**: тип **Desktop app**. Скопируйте **client ID** и **client secret**.
6. Рекомендуется: в разделе **Audience** нажмите **Publish app**. Пока приложение в статусе «Testing», Google сбрасывает вход каждые 7 дней. При входе появится предупреждение «Google не проверил это приложение». Это нормально, ведь приложение ваше.

Подробнее в документации rclone: [Google Photos: making your own client ID](https://rclone.org/googlephotos/).

### 3. Настройте remote в rclone

```powershell
rclone config
```

Ответы: `n` (новый remote), имя **`gphotos`**, хранилище **Google Photos**, вставьте `client_id` и `client_secret`, `read_only` = **false**, затем позвольте rclone открыть браузер для входа. Проверка:

```powershell
rclone lsd gphotos:
```

Если вы обновили rclone со старой версии и видите ошибки доступа, выполните `rclone config reconnect gphotos:`.

### 4. Скачайте скрипт и посмотрите предпросмотр

```powershell
git clone https://github.com/carlosnakazawa/gphotos-smart-backup.git
cd gphotos-smart-backup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1 -WhatIf
```

`-ExecutionPolicy Bypass` действует только для этого процесса. Если вы скачали ZIP, сначала можно выполнить `Get-ChildItem -Recurse | Unblock-File`. `-WhatIf` показывает, что было бы загружено, и ничего не меняет.

### 5. Запустите

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1
```

## Использование

```powershell
# Папка «Изображения» в gphotos:upload (по умолчанию)
.\gphotos-backup.ps1

# Другая папка, по альбому на каждую подпапку
.\gphotos-backup.ps1 -SourcePath 'D:\Camera' -AlbumPerFolder

# Видео меньшего размера (кодирование медленнее)
.\gphotos-backup.ps1 -Crf 26 -Preset medium

# Загружать видео без перекодирования
.\gphotos-backup.ps1 -NoTranscode

# Пропустить некоторые папки и добавить DNG
.\gphotos-backup.ps1 -ExcludeFolder 'Screenshots', '_Upload_Staging' -PhotoExtensions '.jpg', '.jpeg', '.png', '.heic', '.dng'

# Полная справка
Get-Help .\gphotos-backup.ps1 -Detailed
```

| Параметр | По умолчанию | Описание |
| --- | --- | --- |
| `-SourcePath` | ваша папка «Изображения» | Папка с оригиналами (включая подпапки). |
| `-RcloneRemote` | `gphotos:upload` | Назначение rclone. `upload` кладёт файлы в медиатеку без альбома. |
| `-AlbumPerFolder` | выкл. | Файлы из `2024\Trip\` попадают в альбом `2024/Trip`. Файлы верхнего уровня идут в `-RcloneRemote`. |
| `-HistoryFile` | `Изображения\.sync_history.json` | История загрузок. Один файл можно использовать для нескольких исходных папок. |
| `-StagingPath` | `%TEMP%\gphotos-smart-backup` | Временная папка для перекодированных видео (очищается после каждого файла). |
| `-Crf` | `24` | Качество H.265 от 0 до 51. Меньше значение означает выше качество и больше файл. Разумный диапазон: 22–28. |
| `-Preset` | `veryfast` | Скорость x265. `medium` и `slow` дают файлы меньше, но работают дольше. |
| `-NoTranscode` | выкл. | Не использовать ffmpeg. |
| `-SkipTranscodeBelowMbps` | `4` | Загружать видео как есть, если его битрейт в пересчёте на 1080p 30 fps не выше этого значения (для HEVC, AV1 и VP9 — вдвое больше). `0` — перекодировать все видео. |
| `-PhotoExtensions` / `-VideoExtensions` | см. выше | Типы загружаемых файлов. |
| `-ExcludeFolder` | `_Upload_Staging` | Имена папок, пропускаемых на любом уровне. |
| `-RclonePath` / `-FfmpegPath` / `-FfprobePath` | `rclone` / `ffmpeg` / рядом с ffmpeg | Исполняемые файлы, если их нет в `PATH`. |
| `-WhatIf` / `-Confirm` | | Предпросмотр или подтверждение для каждого файла. |

Любой параметр rclone можно задать переменной окружения, например `$env:RCLONE_BWLIMIT = '4M'`, чтобы ограничить скорость загрузки.

## Расписание (автоматическое копирование)

Запускайте каждый вечер через Планировщик заданий. Задание выполняется от вашего имени, пока вы вошли в систему, поэтому rclone находит вашу конфигурацию, а пароль нигде не хранится:

```powershell
$script = 'C:\Tools\gphotos-smart-backup\gphotos-backup.ps1'   # укажите свой путь
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 21:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 12)
Register-ScheduledTask -TaskName 'gphotos-smart-backup' -Action $action -Trigger $trigger -Settings $settings

# Удалить
Unregister-ScheduledTask -TaskName 'gphotos-smart-backup' -Confirm:$false
```

Если запуск прервался, следующий просто продолжит работу.

## Файл истории

`.sync_history.json` связывает путь каждого файла относительно `-SourcePath` со значением `<размер>_<тики-времени-изменения>`:

```json
{
    "2026\\Trip\\IMG_0412.HEIC": "2735969_639012345670000000"
}
```

- Удалите запись, чтобы загрузить файл заново. Если переименовать файл истории, загрузка начнётся с нуля.
- Если вы отредактируете фото, изменятся размер или дата, и оно будет загружено снова. Google Фото сохранит обе версии.
- Файл содержит имена ваших файлов. Не публикуйте его (он есть в `.gitignore`).
- Формат и расположение по умолчанию те же, что в первой версии скрипта, поэтому существующие истории продолжают работать.

## Полезно знать (ограничения)

- **Хранилище:** загрузки через API всегда идут в «Исходном качестве» и занимают место в хранилище Google. Варианта «Экономия места» в API нет. Поэтому видео и сжимаются.
- **Даты:** Google Фото берёт дату из EXIF или метаданных. У файлов без неё (некоторые скриншоты, картинки из мессенджеров) будет показана дата загрузки.
- **Дубликаты:** Google Фото распознаёт одинаковые файлы, поэтому повторная загрузка того же файла не создаёт копию. Но перекодированное видео — это уже другой файл.
- **Удалили в Google Фото?** Скрипт не обращается к Google Фото. Файл из истории не будет загружен снова, даже если вы удалили его онлайн.
- Видео **HDR / Dolby Vision** после перекодирования могут потерять HDR. Используйте `-NoTranscode` (или исключите такие папки), если это важно.
- **Что видит rclone:** с 31 марта 2025 года Google разрешает приложениям читать только те медиафайлы, которые они загрузили сами. Этот инструмент только загружает, так что проблем нет.
- **Квоты:** у API Google Фото есть суточные лимиты запросов. Очень большая первая загрузка может потребовать нескольких запусков. Благодаря истории это не страшно.

## Чего скрипт не делает

- Никогда не удаляет, не перемещает и не изменяет ваши локальные файлы.
- Никогда ничего не удаляет в Google Фото (используется только `rclone copyto`, и это проверяет защитный тест).
- Не отправляет данные никуда, кроме Google Фото, через ваш собственный remote rclone.

## Разработка

```powershell
# Быстрые статические проверки (синтаксис, только ASCII, защитные правила)
.\scripts\Invoke-HarnessCheck.ps1 -SkipAnalyzer -SkipPester

# Всё (нужны PSScriptAnalyzer 1.25.0 и Pester 5.5+)
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck
.\scripts\Invoke-HarnessCheck.ps1
```

CI запускает анализатор, тесты Pester (rclone и ffmpeg подменяются заглушками) и smoke-тест с `-WhatIf` на **Windows Server 2022 и 2025**, как в **Windows PowerShell 5.1, так и в PowerShell 7**.

Файлы `.ps1` намеренно содержат **только ASCII**: Windows PowerShell 5.1 читает файлы без BOM в кодировке ANSI, и символы вне ASCII сломали бы скрипт. Это проверяет тест.

ИИ-агентам для программирования: сначала прочитайте [AGENTS.md](../AGENTS.md).

## Участие

Сообщения об ошибках, идеи, переводы и pull request приветствуются на любом языке. См. [CONTRIBUTING.md](../CONTRIBUTING.md). Хорошие первые шаги:

- проверьте скрипт на файлах со своей камеры или телефона и расскажите о результате;
- улучшите перевод или добавьте свой язык;
- возьмите пункт из плана развития.

## План развития

- Вспомогательный скрипт `Register-BackupTask.ps1` для создания задания одной командой.
- Необязательное аппаратное кодирование (NVENC, Quick Sync, AMF) для ускорения.
- Сохранять HDR-метаданные при перекодировании.
- Файл журнала и JSON-отчёт о каждом запуске.
- Публикация в PowerShell Gallery и `winget`.

## Лицензия

[MIT](../LICENSE) © Carlos Alberto Nakazawa

*Проект не связан с Google и не одобрен и не спонсируется Google. Google Фото и Google Диск — товарные знаки Google LLC.*
