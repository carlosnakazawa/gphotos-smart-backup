# Google Photos Smart Backup

[![CI](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml)
[![Licence : MIT](https://img.shields.io/badge/licence-MIT-blue.svg)](../LICENSE)
![PowerShell 5.1 | 7](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)
![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4)
[![Contributions bienvenues](https://img.shields.io/badge/contributions-bienvenues-brightgreen.svg)](../CONTRIBUTING.md)

[English](../README.md) | [Português (Brasil)](README.pt-BR.md) | [Español](README.es.md) | **Français** | [Deutsch](README.de.md) | [Italiano](README.it.md) | [Русский](README.ru.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md)

> Cette traduction peut être en retard sur la [version anglaise](../README.md), qui fait référence.

Sauvegardez les photos et vidéos de votre PC Windows dans **Google Photos**, automatiquement, sans garder un onglet du navigateur ouvert. Les vidéos sont **compressées en H.265 avant l'envoi** pour économiser de l'espace, et chaque envoi est **enregistré aussitôt** : une exécution interrompue reprend là où elle s'était arrêtée.

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

## Pourquoi ce projet existe

Pendant des années, les utilisateurs de Windows pouvaient sauvegarder un dossier dans Google Photos avec l'application de bureau de Google (« Sauvegarde et synchronisation », puis **Google Drive pour ordinateur**). **C'est terminé** :

- depuis le **15 juin 2026**, Drive pour ordinateur ne permet plus d'ajouter des dossiers à sauvegarder dans Google Photos ;
- le **10 août 2026**, il a complètement cessé d'envoyer les nouvelles photos et vidéos vers Google Photos.

La solution de remplacement de Google est « Sauvegarder des dossiers » sur [photos.google.com](https://photos.google.com), qui **ne fonctionne que tant que la page Google Photos reste ouverte dans le navigateur**. Il n'existe plus de sauvegarde en arrière-plan pour Windows.

Ce projet comble ce manque avec un petit script PowerShell transparent, basé sur deux outils open source bien connus, [rclone](https://rclone.org/googlephotos/) et [ffmpeg](https://ffmpeg.org/) :

- il s'exécute **sans surveillance** (par exemple depuis le Planificateur de tâches), sans navigateur ni application Google ;
- il envoie **uniquement ce qui est nouveau ou modifié**, avec un historique local de chaque fichier envoyé ;
- il **réduit la taille des vidéos** avant l'envoi. Les fichiers envoyés via l'API Google Photos sont toujours stockés en **qualité d'origine et comptent dans votre espace de stockage Google** : une vidéo 4K réencodée en H.265 peut donc faire gagner beaucoup de place ;
- il **ne supprime ni ne déplace jamais rien**, ni sur votre PC ni dans Google Photos.

**C'est un projet communautaire, et toute aide est la bienvenue.** Si la fin des sauvegardes de Drive pour ordinateur vous a touché, essayez-le, [signalez ce qui ne marche pas](https://github.com/carlosnakazawa/gphotos-smart-backup/issues/new?template=bug_report.yml), proposez des idées, améliorez les traductions ou envoyez une pull request. Voir [CONTRIBUTING.md](../CONTRIBUTING.md). Toutes les langues sont acceptées.

## Fonctionnalités

| | |
| --- | --- |
| **Incrémental** | Un historique JSON (`chemin relatif -> taille + date de modification`) indique quels fichiers sont déjà dans Google Photos. Les fichiers nouveaux et modifiés sont envoyés ; le reste est ignoré en quelques secondes. |
| **Reprise automatique** | Chaque fichier est enregistré juste après son envoi. Si le PC se met en veille, si le réseau tombe ou si vous appuyez sur Ctrl+C, l'exécution suivante reprend au même fichier. |
| **Compression vidéo intelligente** | H.265/HEVC avec ffmpeg (`-crf 24 -preset veryfast` par défaut, réglable). La date de création et la localisation sont conservées, y compris les balises `com.apple.quicktime.*` des iPhone. Si la version H.265 n'est pas plus petite, l'original est envoyé. Les vidéos déjà compactes (par exemple en HEVC sur les iPhone récents) sont détectées avec ffprobe et envoyées telles quelles, sans perdre de temps à les réencoder. |
| **Albums (facultatif)** | `-AlbumPerFolder` place les fichiers de chaque sous-dossier dans un album portant son nom. |
| **Sûr** | Envoi uniquement (`rclone copyto`). Ne suit ni les liens symboliques ni les jonctions. `-WhatIf` montre tout sans rien envoyer. Un historique corrompu arrête l'exécution au lieu de renvoyer toute votre bibliothèque. |
| **Adapté à l'automatisation** | Codes de sortie : `0` succès, `1` erreur (arrêt), `2` terminé, mais certaines vidéos n'ont pas pu être converties. |

Formats pris en charge par défaut : `.jpg .jpeg .png .heic .heif .webp .gif` (photos) et `.mp4 .mov .m4v` (vidéos). Les fichiers RAW (`.dng`, `.arw`, `.cr2`, ...) et les fichiers annexes (`.lrf`, `.xmp`, ...) sont volontairement exclus. Ajoutez-les avec `-PhotoExtensions` si vous le souhaitez.

## Fonctionnement

```text
 Votre dossier ──analyse──> nouveau ou modifié ? ──non──> ignorer
                              │ oui
                              v
                     vidéo ? ──oui──> ffmpeg H.265 (dossier temporaire) ──> plus petit ? ──non──> utiliser l'original
                              │ non                                          │ oui
                              v                                              v
                     rclone copyto ──> Google Photos ──> enregistrer dans .sync_history.json ──> fichier suivant
```

## Prérequis

- Windows 10 ou 11, avec Windows PowerShell 5.1 (intégré) ou PowerShell 7+
- [rclone](https://rclone.org/) (une version récente ; v1.70 ou plus recommandée)
- [ffmpeg](https://ffmpeg.org/) avec `libx265` (uniquement pour compresser les vidéos ; inutile avec `-NoTranscode`)
- Un compte Google et un projet Google Cloud gratuit (pour votre propre client OAuth, voir ci-dessous)

Aucun droit administrateur n'est nécessaire.

## Installation

### 1. Installer rclone et ffmpeg

```powershell
winget install Rclone.Rclone
winget install Gyan.FFmpeg
```

Ouvrez ensuite un nouveau terminal pour que les deux soient dans le `PATH`.

### 2. Créer votre propre client OAuth Google

Le client ID partagé de rclone pour Google Photos est retiré au cours de 2026. Il vous faut le vôtre ; c'est gratuit et cela prend environ 5 minutes :

1. Ouvrez la [Google Cloud Console](https://console.cloud.google.com/) et créez un projet (par exemple `gphotos-backup`).
2. **API et services > Bibliothèque** : activez la **Photos Library API**.
3. **Google Auth Platform > Branding / Audience** : choisissez **Externe**, indiquez le nom de l'application et votre e-mail, et ajoutez votre compte Google comme **utilisateur test**.
4. **Accès aux données > Ajouter ou supprimer des champs d'application** : ajoutez ces trois scopes :
   `https://www.googleapis.com/auth/photoslibrary.appendonly`,
   `https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata`,
   `https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata`.
5. **Clients > Créer un client** : type **Application de bureau**. Copiez l'**ID client** et le **code secret du client**.
6. Recommandé : dans **Audience**, cliquez sur **Publier l'application**. Tant que l'application est en « Test », Google fait expirer la connexion tous les 7 jours. Lors de la connexion, vous verrez l'avertissement « Google n'a pas validé cette application ». C'est normal, puisqu'il s'agit de votre propre application.

La documentation de rclone donne plus de détails : [Google Photos: making your own client ID](https://rclone.org/googlephotos/).

### 3. Configurer le remote rclone

```powershell
rclone config
```

Répondez : `n` (nouveau remote), nom **`gphotos`**, stockage **Google Photos**, collez votre `client_id` et votre `client_secret`, `read_only` = **false**, puis laissez rclone ouvrir le navigateur pour vous connecter. Vérifiez avec :

```powershell
rclone lsd gphotos:
```

Si vous avez mis à jour rclone depuis une ancienne version et obtenez des erreurs d'autorisation, lancez `rclone config reconnect gphotos:`.

### 4. Télécharger le script et prévisualiser

```powershell
git clone https://github.com/carlosnakazawa/gphotos-smart-backup.git
cd gphotos-smart-backup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1 -WhatIf
```

`-ExecutionPolicy Bypass` ne s'applique qu'à ce processus. Si vous avez téléchargé le ZIP, vous pouvez d'abord lancer `Get-ChildItem -Recurse | Unblock-File`. `-WhatIf` liste ce qui serait envoyé sans rien modifier.

### 5. Lancer la sauvegarde

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1
```

## Utilisation

```powershell
# Votre dossier Images vers gphotos:upload (valeurs par défaut)
.\gphotos-backup.ps1

# Un autre dossier, un album par sous-dossier
.\gphotos-backup.ps1 -SourcePath 'D:\Camera' -AlbumPerFolder

# Vidéos plus petites (encodage plus lent)
.\gphotos-backup.ps1 -Crf 26 -Preset medium

# Envoyer les vidéos telles quelles
.\gphotos-backup.ps1 -NoTranscode

# Ignorer certains dossiers et inclure les fichiers DNG
.\gphotos-backup.ps1 -ExcludeFolder 'Screenshots', '_Upload_Staging' -PhotoExtensions '.jpg', '.jpeg', '.png', '.heic', '.dng'

# Aide complète
Get-Help .\gphotos-backup.ps1 -Detailed
```

| Paramètre | Défaut | Description |
| --- | --- | --- |
| `-SourcePath` | votre dossier Images | Dossier contenant les originaux (sous-dossiers compris). |
| `-RcloneRemote` | `gphotos:upload` | Destination rclone. `upload` place les fichiers dans la bibliothèque, sans album. |
| `-AlbumPerFolder` | désactivé | Les fichiers de `2024\Voyage\` vont dans l'album `2024/Voyage`. Ceux à la racine vont vers `-RcloneRemote`. |
| `-HistoryFile` | `Images\.sync_history.json` | Historique des envois. Un même fichier peut servir pour plusieurs dossiers sources. |
| `-StagingPath` | `%TEMP%\gphotos-smart-backup` | Dossier temporaire des vidéos converties (vidé après chaque fichier). |
| `-Crf` | `24` | Qualité H.265, de 0 à 51. Plus la valeur est basse, meilleure est la qualité et plus les fichiers sont gros. Entre 22 et 28 est une plage raisonnable. |
| `-Preset` | `veryfast` | Vitesse de x265. `medium` et `slow` donnent des fichiers plus petits, mais prennent plus de temps. |
| `-NoTranscode` | désactivé | N'utilise pas ffmpeg. |
| `-SkipTranscodeBelowMbps` | `4` | Envoie la vidéo telle quelle si son débit, ramené à du 1080p à 30 i/s, est inférieur ou égal à cette valeur (le double pour HEVC, AV1 et VP9). `0` convertit toutes les vidéos. |
| `-PhotoExtensions` / `-VideoExtensions` | voir plus haut | Types de fichiers à envoyer. |
| `-ExcludeFolder` | `_Upload_Staging` | Noms de dossiers à ignorer, à toute profondeur. |
| `-RclonePath` / `-FfmpegPath` / `-FfprobePath` | `rclone` / `ffmpeg` / à côté de ffmpeg | Exécutables, s'ils ne sont pas dans le `PATH`. |
| `-WhatIf` / `-Confirm` | | Aperçu, ou confirmation pour chaque fichier. |

Toute option de rclone peut être définie par variable d'environnement, par exemple `$env:RCLONE_BWLIMIT = '4M'` pour limiter la bande passante d'envoi.

## Planification (sauvegarde automatique)

Lancez-le chaque soir avec le Planificateur de tâches. La tâche s'exécute sous votre compte, tant que vous êtes connecté : rclone trouve ainsi votre configuration et aucun mot de passe n'est enregistré :

```powershell
$script = 'C:\Tools\gphotos-smart-backup\gphotos-backup.ps1'   # à adapter
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 21:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 12)
Register-ScheduledTask -TaskName 'gphotos-smart-backup' -Action $action -Trigger $trigger -Settings $settings

# La supprimer
Unregister-ScheduledTask -TaskName 'gphotos-smart-backup' -Confirm:$false
```

Si une exécution est interrompue, la suivante reprend simplement.

## Le fichier d'historique

`.sync_history.json` associe le chemin de chaque fichier, relatif à `-SourcePath`, à `<taille>_<ticks-de-dernière-modification>` :

```json
{
    "2026\\Voyage\\IMG_0412.HEIC": "2735969_639012345670000000"
}
```

- Supprimez une entrée pour renvoyer ce fichier. Renommer le fichier d'historique relance un envoi complet depuis zéro.
- Si vous modifiez une photo, sa taille ou sa date change et elle est renvoyée. Google Photos conserve les deux versions.
- Le fichier contient les noms de vos fichiers. Gardez-le privé (il figure dans `.gitignore`).
- Il utilise le même format et le même emplacement par défaut que la première version du script : les historiques existants continuent de fonctionner.

## Bon à savoir (limites)

- **Stockage :** les envois via l'API sont toujours en « Qualité d'origine » et comptent dans votre espace Google. L'API ne propose pas l'option « Économiseur d'espace ». C'est pourquoi les vidéos sont compressées.
- **Dates :** Google Photos utilise la date EXIF ou celle des métadonnées. Les fichiers qui n'en ont pas (certaines captures d'écran, images de messageries) affichent la date d'envoi.
- **Doublons :** Google Photos reconnaît les fichiers identiques ; envoyer deux fois le même fichier ne crée pas de copie. Une vidéo réencodée est en revanche un fichier différent.
- **Supprimé dans Google Photos ?** Le script ne consulte pas Google Photos. Un fichier présent dans l'historique n'est pas renvoyé, même si vous l'avez supprimé en ligne.
- Les vidéos **HDR / Dolby Vision** peuvent perdre leur rendu HDR une fois réencodées. Utilisez `-NoTranscode` (ou excluez ces dossiers) si cela compte pour vous.
- **Ce que voit rclone :** depuis le 31 mars 2025, Google ne permet aux applications de lire que les médias qu'elles ont elles-mêmes envoyés. Cet outil ne fait qu'envoyer, ce n'est donc pas un problème.
- **Quotas :** l'API Google Photos impose des limites quotidiennes de requêtes. Un premier envoi très volumineux peut nécessiter plusieurs exécutions. L'historique rend cela sans douleur.

## Ce qu'il ne fait pas

- Il ne supprime, ne déplace ni ne modifie jamais vos fichiers locaux.
- Il ne supprime jamais rien dans Google Photos (seul `rclone copyto` est utilisé, et un test de garde-fou le vérifie).
- Il n'envoie aucune donnée ailleurs que vers Google Photos, via votre propre remote rclone.

## Développement

```powershell
# Vérifications statiques rapides (syntaxe, ASCII uniquement, garde-fous)
.\scripts\Invoke-HarnessCheck.ps1 -SkipAnalyzer -SkipPester

# Tout (nécessite PSScriptAnalyzer 1.25.0 et Pester 5.5+)
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck
.\scripts\Invoke-HarnessCheck.ps1
```

La CI exécute l'analyseur, les tests Pester (rclone et ffmpeg sont simulés) et un test de fumée `-WhatIf` sur **Windows Server 2022 et 2025**, avec **Windows PowerShell 5.1 et PowerShell 7**.

Les fichiers `.ps1` sont volontairement **en ASCII uniquement** : Windows PowerShell 5.1 lit les fichiers sans BOM avec la page de codes ANSI, et les caractères accentués casseraient le script. Un test le vérifie.

Agents de code IA : lisez d'abord [AGENTS.md](../AGENTS.md).

## Contribuer

Les rapports de bugs, idées, traductions et pull requests sont les bienvenus, dans n'importe quelle langue. Voir [CONTRIBUTING.md](../CONTRIBUTING.md). Bonnes premières contributions :

- testez-le avec les fichiers de votre appareil photo ou de votre téléphone et partagez le résultat ;
- améliorez une traduction ou ajoutez votre langue ;
- choisissez un point de la feuille de route.

## Feuille de route

- Script d'aide `Register-BackupTask.ps1` pour créer la tâche planifiée en une commande.
- Encodage matériel facultatif (NVENC, Quick Sync, AMF) pour convertir plus vite.
- Conserver les métadonnées HDR lors du réencodage.
- Fichier journal et rapport JSON de chaque exécution.
- Publication sur la PowerShell Gallery et dans `winget`.

## Licence

[MIT](../LICENSE) © Carlos Alberto Nakazawa

*Ce projet n'est ni affilié à Google, ni approuvé ou sponsorisé par Google. Google Photos et Google Drive sont des marques de Google LLC.*
