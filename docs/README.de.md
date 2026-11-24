# Google Photos Smart Backup

[![CI](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml)
[![Lizenz: MIT](https://img.shields.io/badge/Lizenz-MIT-blue.svg)](../LICENSE)
![PowerShell 5.1 | 7](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)
![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4)
[![Beiträge willkommen](https://img.shields.io/badge/Beitr%C3%A4ge-willkommen-brightgreen.svg)](../CONTRIBUTING.md)

[English](../README.md) | [Português (Brasil)](README.pt-BR.md) | [Español](README.es.md) | [Français](README.fr.md) | **Deutsch** | [Italiano](README.it.md) | [Русский](README.ru.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md)

> Diese Übersetzung ist möglicherweise nicht auf dem Stand der [englischen Version](../README.md), die maßgeblich ist.

Sichern Sie die Fotos und Videos Ihres Windows-PCs automatisch in **Google Fotos**, ohne einen Browser-Tab offen zu lassen. Videos werden **vor dem Hochladen nach H.265 komprimiert**, um Speicherplatz zu sparen, und jeder Upload wird **sofort festgehalten**, sodass ein unterbrochener Lauf dort weitermacht, wo er aufgehört hat.

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

## Warum es dieses Projekt gibt

Jahrelang konnten Windows-Nutzer einen Ordner mit Googles Desktop-App („Sichern und synchronisieren", später **Google Drive für den Computer**) in Google Fotos sichern. **Damit ist Schluss**:

- seit dem **15. Juni 2026** lassen sich in Drive für den Computer keine Ordner mehr für die Sicherung in Google Fotos hinzufügen;
- am **10. August 2026** wurde das Hochladen neuer Fotos und Videos zu Google Fotos ganz eingestellt.

Googles Ersatz ist „Ordner sichern" auf [photos.google.com](https://photos.google.com), das **nur läuft, solange die Google-Fotos-Webseite im Browser geöffnet bleibt**. Eine Sicherung im Hintergrund gibt es für Windows nicht mehr.

Dieses Projekt schließt die Lücke mit einem kleinen, transparenten PowerShell-Skript, das auf zwei bekannten Open-Source-Werkzeugen aufbaut: [rclone](https://rclone.org/googlephotos/) und [ffmpeg](https://ffmpeg.org/):

- es läuft **unbeaufsichtigt** (zum Beispiel über die Aufgabenplanung), ohne Browser und ohne Google-App;
- es lädt **nur Neues oder Geändertes** hoch und führt einen lokalen Verlauf aller hochgeladenen Dateien;
- es **verkleinert Videos** vor dem Hochladen. Über die Google-Fotos-API hochgeladene Dateien werden immer in **Originalqualität gespeichert und auf Ihren Google-Speicher angerechnet**. Ein nach H.265 neu kodiertes 4K-Video kann daher viel Platz sparen;
- es **löscht oder verschiebt nie etwas**, weder auf Ihrem PC noch in Google Fotos.

**Es ist ein Community-Projekt, und jede Hilfe ist willkommen.** Wenn Sie vom Ende der Sicherung in Drive für den Computer betroffen sind: Probieren Sie es aus, [melden Sie, was nicht funktioniert](https://github.com/carlosnakazawa/gphotos-smart-backup/issues/new?template=bug_report.yml), schlagen Sie Ideen vor, verbessern Sie die Übersetzungen oder schicken Sie einen Pull Request. Siehe [CONTRIBUTING.md](../CONTRIBUTING.md). Jede Sprache ist in Ordnung.

## Funktionen

| | |
| --- | --- |
| **Inkrementell** | Ein JSON-Verlauf (`relativer Pfad -> Größe + Änderungszeit`) zeigt, welche Dateien schon in Google Fotos sind. Neue und bearbeitete Dateien werden hochgeladen, alles andere ist in Sekunden übersprungen. |
| **Fortsetzbar** | Jede Datei wird direkt nach dem Upload festgehalten. Geht der PC in den Ruhezustand, fällt das Netz aus oder drücken Sie Strg+C, setzt der nächste Lauf bei derselben Datei fort. |
| **Intelligente Videokompression** | H.265/HEVC mit ffmpeg (standardmäßig `-crf 24 -preset veryfast`, einstellbar). Aufnahmedatum und Ort bleiben erhalten, auch die Apple-Tags `com.apple.quicktime.*` von iPhones. Ist die H.265-Version nicht kleiner, wird das Original hochgeladen. Bereits kompakte Videos (zum Beispiel HEVC von aktuellen iPhones) erkennt ffprobe; sie werden unverändert hochgeladen, ohne Zeit mit einer Neukodierung zu verlieren. |
| **Alben (optional)** | `-AlbumPerFolder` legt die Dateien jedes Unterordners in ein Album mit dessen Namen. |
| **Sicher** | Nur Hochladen (`rclone copyto`). Symbolische Links und Junctions werden nicht verfolgt. `-WhatIf` zeigt alles an, ohne hochzuladen. Ein beschädigter Verlauf stoppt den Lauf, statt die ganze Bibliothek erneut hochzuladen. |
| **Automatisierungsfreundlich** | Exit-Codes: `0` Erfolg, `1` Fehler (abgebrochen), `2` fertig, aber einige Videos konnten nicht konvertiert werden. |

Standardmäßig unterstützt: `.jpg .jpeg .png .heic .heif .webp .gif` (Fotos) und `.mp4 .mov .m4v` (Videos). RAW-Dateien (`.dng`, `.arw`, `.cr2`, ...) und Begleitdateien (`.lrf`, `.xmp`, ...) sind bewusst ausgenommen. Mit `-PhotoExtensions` können Sie sie hinzufügen.

## So funktioniert es

```text
 Ihr Ordner ──Scan──> neu oder geändert? ──nein──> überspringen
                              │ ja
                              v
                     Video? ──ja──> ffmpeg H.265 (temporärer Ordner) ──> kleiner? ──nein──> Original verwenden
                              │ nein                                       │ ja
                              v                                            v
                     rclone copyto ──> Google Fotos ──> in .sync_history.json eintragen ──> nächste Datei
```

## Voraussetzungen

- Windows 10 oder 11 mit Windows PowerShell 5.1 (integriert) oder PowerShell 7+
- [rclone](https://rclone.org/) (eine aktuelle Version; v1.70 oder neuer empfohlen)
- [ffmpeg](https://ffmpeg.org/) mit `libx265` (nur für die Videokompression; mit `-NoTranscode` nicht nötig)
- Ein Google-Konto und ein kostenloses Google-Cloud-Projekt (für Ihren eigenen OAuth-Client, siehe unten)

Administratorrechte sind nicht erforderlich.

## Einrichtung

### 1. rclone und ffmpeg installieren

```powershell
winget install Rclone.Rclone
winget install Gyan.FFmpeg
```

Öffnen Sie danach ein neues Terminal, damit beide im `PATH` sind.

### 2. Einen eigenen Google-OAuth-Client anlegen

Die gemeinsame Client-ID von rclone für Google Fotos wird im Laufe des Jahres 2026 abgeschaltet. Sie brauchen eine eigene. Das ist kostenlos und dauert etwa 5 Minuten:

1. Öffnen Sie die [Google Cloud Console](https://console.cloud.google.com/) und legen Sie ein Projekt an (zum Beispiel `gphotos-backup`).
2. **APIs & Dienste > Bibliothek**: Aktivieren Sie die **Photos Library API**.
3. **Google Auth Platform > Branding / Zielgruppe**: Wählen Sie **Extern**, geben Sie App-Namen und Ihre E-Mail-Adresse an und fügen Sie Ihr Google-Konto als **Testnutzer** hinzu.
4. **Datenzugriff > Bereiche hinzufügen oder entfernen**: Fügen Sie diese drei Scopes hinzu:
   `https://www.googleapis.com/auth/photoslibrary.appendonly`,
   `https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata`,
   `https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata`.
5. **Clients > Client erstellen**: Typ **Desktop-App**. Kopieren Sie **Client-ID** und **Clientschlüssel**.
6. Empfohlen: Klicken Sie unter **Zielgruppe** auf **App veröffentlichen**. Solange die App im Status „Test" ist, lässt Google die Anmeldung alle 7 Tage ablaufen. Beim Anmelden erscheint die Warnung „Google hat diese App nicht überprüft". Das ist zu erwarten, denn es ist Ihre eigene App.

Weitere Details stehen in der rclone-Dokumentation: [Google Photos: making your own client ID](https://rclone.org/googlephotos/).

### 3. Das rclone-Remote einrichten

```powershell
rclone config
```

Antworten Sie: `n` (neues Remote), Name **`gphotos`**, Speicher **Google Photos**, `client_id` und `client_secret` einfügen, `read_only` = **false**, und lassen Sie rclone den Browser für die Anmeldung öffnen. Prüfen Sie es mit:

```powershell
rclone lsd gphotos:
```

Wenn Sie rclone von einer älteren Version aktualisiert haben und Berechtigungsfehler erhalten, führen Sie `rclone config reconnect gphotos:` aus.

### 4. Skript herunterladen und Vorschau anzeigen

```powershell
git clone https://github.com/carlosnakazawa/gphotos-smart-backup.git
cd gphotos-smart-backup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1 -WhatIf
```

`-ExecutionPolicy Bypass` gilt nur für diesen Prozess. Wenn Sie das ZIP heruntergeladen haben, können Sie vorher `Get-ChildItem -Recurse | Unblock-File` ausführen. `-WhatIf` listet auf, was hochgeladen würde, und ändert nichts.

### 5. Ausführen

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1
```

## Verwendung

```powershell
# Ihr Bilder-Ordner nach gphotos:upload (Standardwerte)
.\gphotos-backup.ps1

# Ein anderer Ordner, ein Album pro Unterordner
.\gphotos-backup.ps1 -SourcePath 'D:\Camera' -AlbumPerFolder

# Kleinere Videos (langsamere Kodierung)
.\gphotos-backup.ps1 -Crf 26 -Preset medium

# Videos unverändert hochladen
.\gphotos-backup.ps1 -NoTranscode

# Einige Ordner überspringen und DNG-Dateien einbeziehen
.\gphotos-backup.ps1 -ExcludeFolder 'Screenshots', '_Upload_Staging' -PhotoExtensions '.jpg', '.jpeg', '.png', '.heic', '.dng'

# Vollständige Hilfe
Get-Help .\gphotos-backup.ps1 -Detailed
```

| Parameter | Standard | Beschreibung |
| --- | --- | --- |
| `-SourcePath` | Ihr Bilder-Ordner | Ordner mit den Originalen (inklusive Unterordner). |
| `-RcloneRemote` | `gphotos:upload` | rclone-Ziel. `upload` legt die Dateien ohne Album in der Bibliothek ab. |
| `-AlbumPerFolder` | aus | Dateien in `2024\Reise\` landen im Album `2024/Reise`. Dateien auf oberster Ebene gehen an `-RcloneRemote`. |
| `-HistoryFile` | `Bilder\.sync_history.json` | Upload-Verlauf. Eine Datei kann für mehrere Quellordner genutzt werden. |
| `-StagingPath` | `%TEMP%\gphotos-smart-backup` | Temporärer Ordner für konvertierte Videos (wird nach jeder Datei geleert). |
| `-Crf` | `24` | H.265-Qualität von 0 bis 51. Niedrigere Werte bedeuten bessere Qualität und größere Dateien. 22 bis 28 ist ein sinnvoller Bereich. |
| `-Preset` | `veryfast` | x265-Geschwindigkeit. `medium` und `slow` ergeben kleinere Dateien, dauern aber länger. |
| `-NoTranscode` | aus | ffmpeg nicht verwenden. |
| `-SkipTranscodeBelowMbps` | `4` | Lädt ein Video unverändert hoch, wenn seine Bitrate, umgerechnet auf 1080p mit 30 fps, höchstens diesem Wert entspricht (doppelter Wert für HEVC, AV1 und VP9). `0` konvertiert jedes Video. |
| `-PhotoExtensions` / `-VideoExtensions` | siehe oben | Hochzuladende Dateitypen. |
| `-ExcludeFolder` | `_Upload_Staging` | Ordnernamen, die auf jeder Ebene übersprungen werden. |
| `-RclonePath` / `-FfmpegPath` / `-FfprobePath` | `rclone` / `ffmpeg` / neben ffmpeg | Programmdateien, falls sie nicht im `PATH` sind. |
| `-WhatIf` / `-Confirm` | | Vorschau oder Bestätigung für jede Datei. |

Jede rclone-Option lässt sich über Umgebungsvariablen setzen, zum Beispiel `$env:RCLONE_BWLIMIT = '4M'`, um die Upload-Bandbreite zu begrenzen.

## Zeitplan (automatische Sicherung)

Lassen Sie es jeden Abend über die Aufgabenplanung laufen. Die Aufgabe läuft unter Ihrem Konto, solange Sie angemeldet sind. So findet rclone Ihre Konfiguration, und es wird kein Passwort gespeichert:

```powershell
$script = 'C:\Tools\gphotos-smart-backup\gphotos-backup.ps1'   # anpassen
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 21:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 12)
Register-ScheduledTask -TaskName 'gphotos-smart-backup' -Action $action -Trigger $trigger -Settings $settings

# Entfernen
Unregister-ScheduledTask -TaskName 'gphotos-smart-backup' -Confirm:$false
```

Wird ein Lauf unterbrochen, macht der nächste einfach weiter.

## Die Verlaufsdatei

`.sync_history.json` ordnet den Pfad jeder Datei, relativ zu `-SourcePath`, dem Wert `<Größe>_<Ticks-der-letzten-Änderung>` zu:

```json
{
    "2026\\Reise\\IMG_0412.HEIC": "2735969_639012345670000000"
}
```

- Löschen Sie einen Eintrag, um die Datei erneut hochzuladen. Wenn Sie die Verlaufsdatei umbenennen, beginnt ein vollständiger Upload von vorn.
- Bearbeiten Sie ein Foto, ändern sich Größe oder Datum, und es wird erneut hochgeladen. Google Fotos behält beide Versionen.
- Die Datei enthält Ihre Dateinamen. Behandeln Sie sie vertraulich (sie steht in `.gitignore`).
- Sie verwendet dasselbe Format und denselben Standardort wie die erste Version des Skripts. Vorhandene Verläufe funktionieren also weiter.

## Gut zu wissen (Einschränkungen)

- **Speicher:** Uploads über die API sind immer „Originalqualität" und werden auf Ihren Google-Speicher angerechnet. Die API bietet kein „Speicherplatz sparen". Deshalb werden Videos komprimiert.
- **Datum:** Google Fotos verwendet das EXIF- bzw. Metadaten-Datum. Dateien ohne diese Angabe (manche Screenshots, Bilder aus Messengern) zeigen das Upload-Datum.
- **Duplikate:** Google Fotos erkennt identische Dateien. Dieselbe Datei zweimal hochzuladen, erzeugt also keine Kopie. Ein neu kodiertes Video ist allerdings eine andere Datei.
- **In Google Fotos gelöscht?** Das Skript fragt Google Fotos nicht ab. Eine Datei im Verlauf wird nicht erneut hochgeladen, auch wenn Sie sie online gelöscht haben.
- **HDR-/Dolby-Vision**-Videos können durch die Neukodierung ihren HDR-Look verlieren. Verwenden Sie `-NoTranscode` (oder schließen Sie diese Ordner aus), wenn Ihnen das wichtig ist.
- **Was rclone sieht:** Seit dem 31. März 2025 dürfen Apps nur noch Medien lesen, die sie selbst hochgeladen haben. Dieses Werkzeug lädt nur hoch, das ist also kein Problem.
- **Kontingente:** Die Google-Fotos-API hat tägliche Anfragelimits. Ein sehr großer erster Upload kann mehrere Läufe brauchen. Dank des Verlaufs ist das unproblematisch.

## Was es nicht tut

- Es löscht, verschiebt oder verändert niemals Ihre lokalen Dateien.
- Es löscht niemals etwas in Google Fotos (es wird nur `rclone copyto` verwendet, und ein Schutztest stellt das sicher).
- Es sendet keine Daten an andere Ziele als Google Fotos, und zwar über Ihr eigenes rclone-Remote.

## Entwicklung

```powershell
# Schnelle statische Prüfungen (Syntax, nur ASCII, Schutzregeln)
.\scripts\Invoke-HarnessCheck.ps1 -SkipAnalyzer -SkipPester

# Alles (erfordert PSScriptAnalyzer 1.25.0 und Pester 5.5+)
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck
.\scripts\Invoke-HarnessCheck.ps1
```

Die CI führt den Analyzer, die Pester-Tests (rclone und ffmpeg werden simuliert) und einen `-WhatIf`-Smoke-Test auf **Windows Server 2022 und 2025** aus, jeweils mit **Windows PowerShell 5.1 und PowerShell 7**.

Die `.ps1`-Dateien sind bewusst **reines ASCII**: Windows PowerShell 5.1 liest Dateien ohne BOM mit der ANSI-Codepage, Umlaute und Akzente würden das Skript also beschädigen. Ein Test stellt das sicher.

KI-Coding-Agenten: Lest zuerst [AGENTS.md](../AGENTS.md).

## Mitwirken

Fehlerberichte, Ideen, Übersetzungen und Pull Requests sind willkommen, in jeder Sprache. Siehe [CONTRIBUTING.md](../CONTRIBUTING.md). Gute erste Beiträge:

- testen Sie es mit Dateien Ihrer Kamera oder Ihres Handys und berichten Sie vom Ergebnis;
- verbessern Sie eine Übersetzung oder fügen Sie Ihre Sprache hinzu;
- übernehmen Sie einen Punkt aus der Roadmap.

## Roadmap

- Hilfsskript `Register-BackupTask.ps1`, um die geplante Aufgabe mit einem Befehl anzulegen.
- Optionale Hardware-Kodierung (NVENC, Quick Sync, AMF) für schnellere Konvertierung.
- HDR-Metadaten bei der Neukodierung erhalten.
- Logdatei und JSON-Bericht für jeden Lauf.
- Veröffentlichung in der PowerShell Gallery und in `winget`.

## Lizenz

[MIT](../LICENSE) © Carlos Alberto Nakazawa

*Dieses Projekt steht in keiner Verbindung zu Google und wird von Google weder unterstützt noch gesponsert. Google Fotos und Google Drive sind Marken der Google LLC.*
