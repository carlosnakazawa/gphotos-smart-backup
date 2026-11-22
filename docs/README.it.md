# Google Photos Smart Backup

[![CI](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml)
[![Licenza: MIT](https://img.shields.io/badge/licenza-MIT-blue.svg)](../LICENSE)
![PowerShell 5.1 | 7](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)
![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4)
[![Contributi benvenuti](https://img.shields.io/badge/contributi-benvenuti-brightgreen.svg)](../CONTRIBUTING.md)

[English](../README.md) | [Português (Brasil)](README.pt-BR.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | **Italiano** | [Русский](README.ru.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md)

> Questa traduzione potrebbe non essere aggiornata rispetto alla [versione inglese](../README.md), che fa da riferimento.

Esegui il backup di foto e video del tuo PC Windows su **Google Foto**, in automatico, senza tenere aperta una scheda del browser. I video vengono **compressi in H.265 prima del caricamento** per risparmiare spazio, e ogni caricamento viene **registrato subito**, così un'esecuzione interrotta riprende da dove si era fermata.

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

## Perché esiste questo progetto

Per anni chi usava Windows poteva fare il backup di una cartella su Google Foto con l'app desktop di Google ("Backup e sincronizzazione", poi **Google Drive per desktop**). **Non è più possibile**:

- dal **15 giugno 2026** Drive per desktop non permette più di aggiungere cartelle da salvare su Google Foto;
- il **10 agosto 2026** ha smesso del tutto di caricare nuove foto e nuovi video su Google Foto.

L'alternativa di Google è "Esegui il backup delle cartelle" su [photos.google.com](https://photos.google.com), che **funziona solo finché la pagina di Google Foto resta aperta nel browser**. Per Windows non esiste più un backup in background.

Questo progetto colma la lacuna con uno script PowerShell piccolo e trasparente, basato su due noti strumenti open source, [rclone](https://rclone.org/googlephotos/) e [ffmpeg](https://ffmpeg.org/):

- funziona **senza supervisione** (per esempio dall'Utilità di pianificazione), senza browser e senza app di Google;
- carica **solo ciò che è nuovo o modificato**, tenendo uno storico locale di ogni file inviato;
- **riduce le dimensioni dei video** prima del caricamento. I file caricati tramite l'API di Google Foto sono sempre salvati in **qualità originale e occupano il tuo spazio di archiviazione Google**, quindi un video 4K ricodificato in H.265 può far risparmiare molto spazio;
- **non elimina né sposta mai nulla**, né sul PC né su Google Foto.

**È un progetto della comunità e ogni aiuto è benvenuto.** Se la fine del backup di Drive per desktop ti ha colpito, provalo, [segnala cosa non funziona](https://github.com/carlosnakazawa/gphotos-smart-backup/issues/new?template=bug_report.yml), proponi idee, migliora le traduzioni o invia una pull request. Vedi [CONTRIBUTING.md](../CONTRIBUTING.md). Va bene qualsiasi lingua.

## Funzionalità

| | |
| --- | --- |
| **Incrementale** | Uno storico JSON (`percorso relativo -> dimensione + data di modifica`) indica quali file sono già su Google Foto. I file nuovi e modificati vengono caricati, il resto viene saltato in pochi secondi. |
| **Ripristinabile** | Ogni file viene registrato subito dopo il caricamento. Se il PC va in sospensione, la rete cade o premi Ctrl+C, l'esecuzione successiva riparte dallo stesso file. |
| **Compressione video intelligente** | H.265/HEVC con ffmpeg (`-crf 24 -preset veryfast` di default, regolabile). La data di creazione e la posizione vengono mantenute, compresi i tag Apple `com.apple.quicktime.*` degli iPhone. Se la versione H.265 non è più piccola, viene caricato l'originale. |
| **Album (facoltativi)** | `-AlbumPerFolder` mette i file di ogni sottocartella in un album con il suo nome. |
| **Sicuro** | Solo caricamento (`rclone copyto`). Non segue collegamenti simbolici né giunzioni. `-WhatIf` mostra tutto senza caricare nulla. Uno storico danneggiato interrompe l'esecuzione invece di ricaricare l'intera libreria. |
| **Adatto all'automazione** | Codici di uscita: `0` successo, `1` errore (interrotto), `2` terminato, ma alcuni video non sono stati convertiti. |

Formati supportati di default: `.jpg .jpeg .png .heic .heif .webp .gif` (foto) e `.mp4 .mov .m4v` (video). I file RAW (`.dng`, `.arw`, `.cr2`, ...) e i file accessori (`.lrf`, `.xmp`, ...) sono esclusi di proposito. Se vuoi, aggiungili con `-PhotoExtensions`.

## Come funziona

```text
 La tua cartella ──scansione──> nuovo o modificato? ──no──> salta
                              │ sì
                              v
                     video? ──sì──> ffmpeg H.265 (cartella temporanea) ──> più piccolo? ──no──> usa l'originale
                              │ no                                          │ sì
                              v                                             v
                     rclone copyto ──> Google Foto ──> registra in .sync_history.json ──> file successivo
```

## Requisiti

- Windows 10 o 11, con Windows PowerShell 5.1 (incluso) o PowerShell 7+
- [rclone](https://rclone.org/) (una versione recente; consigliata la v1.70 o successiva)
- [ffmpeg](https://ffmpeg.org/) con `libx265` (solo per comprimere i video; non serve con `-NoTranscode`)
- Un account Google e un progetto Google Cloud gratuito (per il tuo client OAuth, vedi sotto)

Non servono diritti di amministratore.

## Configurazione

### 1. Installa rclone e ffmpeg

```powershell
winget install Rclone.Rclone
winget install Gyan.FFmpeg
```

Poi apri un nuovo terminale, così entrambi saranno nel `PATH`.

### 2. Crea il tuo client OAuth di Google

Il client ID condiviso di rclone per Google Foto viene dismesso nel corso del 2026. Te ne serve uno tuo: è gratuito e richiede circa 5 minuti.

1. Apri la [Google Cloud Console](https://console.cloud.google.com/) e crea un progetto (per esempio `gphotos-backup`).
2. **API e servizi > Libreria**: abilita la **Photos Library API**.
3. **Google Auth Platform > Branding / Pubblico**: scegli **Esterno**, inserisci il nome dell'app e la tua email e aggiungi il tuo account Google come **utente di test**.
4. **Accesso ai dati > Aggiungi o rimuovi ambiti**: aggiungi questi tre scope:
   `https://www.googleapis.com/auth/photoslibrary.appendonly`,
   `https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata`,
   `https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata`.
5. **Client > Crea client**: tipo **App desktop**. Copia l'**ID client** e il **client secret**.
6. Consigliato: in **Pubblico**, fai clic su **Pubblica app**. Finché l'app è in "Test", Google fa scadere l'accesso ogni 7 giorni. Durante l'accesso vedrai l'avviso "Google non ha verificato questa app". È normale, perché l'app è tua.

La documentazione di rclone ha altri dettagli: [Google Photos: making your own client ID](https://rclone.org/googlephotos/).

### 3. Configura il remote di rclone

```powershell
rclone config
```

Rispondi: `n` (nuovo remote), nome **`gphotos`**, archiviazione **Google Photos**, incolla `client_id` e `client_secret`, `read_only` = **false**, poi lascia che rclone apra il browser per l'accesso. Verifica con:

```powershell
rclone lsd gphotos:
```

Se hai aggiornato rclone da una versione vecchia e ricevi errori di autorizzazione, esegui `rclone config reconnect gphotos:`.

### 4. Scarica lo script e guarda l'anteprima

```powershell
git clone https://github.com/carlosnakazawa/gphotos-smart-backup.git
cd gphotos-smart-backup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1 -WhatIf
```

`-ExecutionPolicy Bypass` vale solo per questo processo. Se hai scaricato lo ZIP, puoi eseguire prima `Get-ChildItem -Recurse | Unblock-File`. `-WhatIf` elenca ciò che verrebbe caricato senza modificare nulla.

### 5. Avvialo

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1
```

## Utilizzo

```powershell
# La cartella Immagini verso gphotos:upload (valori predefiniti)
.\gphotos-backup.ps1

# Un'altra cartella, un album per sottocartella
.\gphotos-backup.ps1 -SourcePath 'D:\Camera' -AlbumPerFolder

# Video più piccoli (codifica più lenta)
.\gphotos-backup.ps1 -Crf 26 -Preset medium

# Caricare i video così come sono
.\gphotos-backup.ps1 -NoTranscode

# Saltare alcune cartelle e includere i file DNG
.\gphotos-backup.ps1 -ExcludeFolder 'Screenshots', '_Upload_Staging' -PhotoExtensions '.jpg', '.jpeg', '.png', '.heic', '.dng'

# Guida completa
Get-Help .\gphotos-backup.ps1 -Detailed
```

| Parametro | Predefinito | Descrizione |
| --- | --- | --- |
| `-SourcePath` | la tua cartella Immagini | Cartella con gli originali (sottocartelle incluse). |
| `-RcloneRemote` | `gphotos:upload` | Destinazione rclone. `upload` mette i file nella libreria, senza album. |
| `-AlbumPerFolder` | disattivato | I file in `2024\Viaggio\` vanno nell'album `2024/Viaggio`. Quelli al primo livello vanno a `-RcloneRemote`. |
| `-HistoryFile` | `Immagini\.sync_history.json` | Storico dei caricamenti. Lo stesso file può servire più cartelle di origine. |
| `-StagingPath` | `%TEMP%\gphotos-smart-backup` | Cartella temporanea per i video convertiti (svuotata dopo ogni file). |
| `-Crf` | `24` | Qualità H.265, da 0 a 51. Valori più bassi danno qualità migliore e file più grandi. Tra 22 e 28 è un intervallo ragionevole. |
| `-Preset` | `veryfast` | Velocità di x265. `medium` e `slow` producono file più piccoli, ma richiedono più tempo. |
| `-NoTranscode` | disattivato | Non usa ffmpeg. |
| `-PhotoExtensions` / `-VideoExtensions` | vedi sopra | Tipi di file da caricare. |
| `-ExcludeFolder` | `_Upload_Staging` | Nomi di cartelle da saltare, a qualsiasi livello. |
| `-RclonePath` / `-FfmpegPath` | `rclone` / `ffmpeg` | Eseguibili, se non sono nel `PATH`. |
| `-WhatIf` / `-Confirm` | | Anteprima, o conferma per ogni file. |

Qualsiasi opzione di rclone si può impostare con variabili d'ambiente, per esempio `$env:RCLONE_BWLIMIT = '4M'` per limitare la banda in caricamento.

## Pianificazione (backup automatico)

Eseguilo ogni sera con l'Utilità di pianificazione. L'attività gira con il tuo utente, mentre hai effettuato l'accesso, quindi rclone trova la tua configurazione e non viene salvata alcuna password:

```powershell
$script = 'C:\Tools\gphotos-smart-backup\gphotos-backup.ps1'   # da adattare
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 21:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 12)
Register-ScheduledTask -TaskName 'gphotos-smart-backup' -Action $action -Trigger $trigger -Settings $settings

# Rimuoverla
Unregister-ScheduledTask -TaskName 'gphotos-smart-backup' -Confirm:$false
```

Se un'esecuzione viene interrotta, la successiva semplicemente continua.

## Il file di storico

`.sync_history.json` associa il percorso di ogni file, relativo a `-SourcePath`, a `<dimensione>_<tick-dell'ultima-modifica>`:

```json
{
    "2026\\Viaggio\\IMG_0412.HEIC": "2735969_639012345670000000"
}
```

- Elimina una voce per ricaricare quel file. Rinominare il file di storico fa ripartire da zero il caricamento completo.
- Se modifichi una foto, cambiano dimensione o data e viene ricaricata. Google Foto conserva entrambe le versioni.
- Il file contiene i nomi dei tuoi file. Tienilo privato (è in `.gitignore`).
- Usa lo stesso formato e la stessa posizione predefinita della prima versione dello script, quindi gli storici esistenti continuano a funzionare.

## Buono a sapersi (limitazioni)

- **Spazio:** i caricamenti tramite API sono sempre in "Qualità originale" e occupano il tuo spazio Google. L'API non offre l'opzione "Risparmio spazio". Per questo i video vengono compressi.
- **Date:** Google Foto usa la data EXIF o dei metadati. I file che ne sono privi (alcuni screenshot, immagini delle app di messaggistica) mostrano la data di caricamento.
- **Duplicati:** Google Foto riconosce i file identici, quindi caricare due volte lo stesso file non crea una copia. Un video ricodificato, però, è un file diverso.
- **Eliminato su Google Foto?** Lo script non interroga Google Foto. Un file presente nello storico non viene ricaricato, anche se lo hai eliminato online.
- I video **HDR / Dolby Vision** possono perdere l'aspetto HDR dopo la ricodifica. Usa `-NoTranscode` (o escludi quelle cartelle) se per te è importante.
- **Cosa vede rclone:** dal 31 marzo 2025 Google permette alle app di leggere solo i contenuti che hanno caricato loro stesse. Questo strumento si limita a caricare, quindi non è un problema.
- **Quote:** l'API di Google Foto ha limiti giornalieri di richieste. Un primo caricamento molto grande può richiedere più esecuzioni. Lo storico lo rende semplice.

## Cosa non fa

- Non elimina, non sposta e non modifica mai i tuoi file locali.
- Non elimina mai nulla su Google Foto (usa solo `rclone copyto`, e un test di sicurezza lo garantisce).
- Non invia dati da nessuna parte se non a Google Foto, tramite il tuo remote rclone.

## Sviluppo

```powershell
# Controlli statici veloci (sintassi, solo ASCII, regole di sicurezza)
.\scripts\Invoke-HarnessCheck.ps1 -SkipAnalyzer -SkipPester

# Tutto (richiede PSScriptAnalyzer 1.25.0 e Pester 5.5+)
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck
.\scripts\Invoke-HarnessCheck.ps1
```

La CI esegue l'analizzatore, i test Pester (rclone e ffmpeg sono simulati) e uno smoke test con `-WhatIf` su **Windows Server 2022 e 2025**, sia con **Windows PowerShell 5.1 sia con PowerShell 7**.

I file `.ps1` sono volutamente **solo ASCII**: Windows PowerShell 5.1 legge i file senza BOM con la code page ANSI, e i caratteri accentati romperebbero lo script. Un test lo garantisce.

Agenti di programmazione IA: leggete prima [AGENTS.md](../AGENTS.md).

## Contribuire

Segnalazioni di bug, idee, traduzioni e pull request sono benvenute, in qualsiasi lingua. Vedi [CONTRIBUTING.md](../CONTRIBUTING.md). Buoni primi contributi:

- provalo con i file della tua fotocamera o del tuo telefono e racconta com'è andata;
- migliora una traduzione o aggiungi la tua lingua;
- scegli una voce della roadmap.

## Roadmap

- Script di supporto `Register-BackupTask.ps1` per creare l'attività pianificata con un solo comando.
- Codifica hardware facoltativa (NVENC, Quick Sync, AMF) per convertire più in fretta.
- Non ricodificare i video già in HEVC o piccoli, in base al bitrate.
- Mantenere i metadati HDR durante la ricodifica.
- File di log e report JSON di ogni esecuzione.
- Pubblicazione nella PowerShell Gallery e in `winget`.

## Licenza

[MIT](../LICENSE) © Carlos Alberto Nakazawa

*Questo progetto non è affiliato, approvato né sponsorizzato da Google. Google Foto e Google Drive sono marchi di Google LLC.*
