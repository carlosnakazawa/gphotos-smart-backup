# Google Photos Smart Backup

[![CI](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml)
[![Licencia: MIT](https://img.shields.io/badge/licencia-MIT-blue.svg)](../LICENSE)
![PowerShell 5.1 | 7](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)
![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4)
[![Contribuciones bienvenidas](https://img.shields.io/badge/contribuciones-bienvenidas-brightgreen.svg)](../CONTRIBUTING.md)

[English](../README.md) | [Português (Brasil)](README.pt-BR.md) | **Español** | [Français](README.fr.md) | [Deutsch](README.de.md) | [Italiano](README.it.md) | [Русский](README.ru.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md)

> Esta traducción puede estar desactualizada respecto a la [versión en inglés](../README.md), que es la referencia.

Haz copia de seguridad de las fotos y vídeos de tu PC con Windows en **Google Fotos**, de forma automática y sin dejar una pestaña del navegador abierta. Los vídeos se **comprimen a H.265 antes de subirlos** para ahorrar espacio, y cada subida queda **registrada al instante**, así que una ejecución interrumpida continúa donde se quedó.

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

## Por qué existe este proyecto

Durante años, los usuarios de Windows podían hacer copia de seguridad de una carpeta en Google Fotos con la aplicación de escritorio de Google ("Copia de seguridad y sincronización" y luego **Google Drive para ordenadores**). **Eso se acabó**:

- desde el **15 de junio de 2026**, Drive para ordenadores ya no permite añadir carpetas para hacer copia de seguridad en Google Fotos;
- el **10 de agosto de 2026** dejó por completo de subir fotos y vídeos nuevos a Google Fotos.

La alternativa de Google es "Hacer copia de seguridad de carpetas" en [photos.google.com](https://photos.google.com), que **solo funciona mientras la página de Google Fotos sigue abierta en el navegador**. Ya no hay copia de seguridad en segundo plano para Windows.

Este proyecto cubre ese hueco con un script de PowerShell pequeño y transparente, basado en dos herramientas de código abierto muy conocidas, [rclone](https://rclone.org/googlephotos/) y [ffmpeg](https://ffmpeg.org/):

- funciona **sin supervisión** (por ejemplo, desde el Programador de tareas), sin navegador ni aplicación de Google;
- sube **solo lo nuevo o modificado**, con un historial local de cada archivo enviado;
- **reduce el tamaño de los vídeos** antes de subirlos. Los archivos subidos mediante la API de Google Fotos se guardan siempre en **calidad original y cuentan en tu almacenamiento de Google**, así que un vídeo 4K recodificado en H.265 puede ahorrar mucho espacio;
- **nunca borra ni mueve nada**, ni en tu PC ni en Google Fotos.

**Es un proyecto de la comunidad y toda ayuda es bienvenida.** Si te afectó el fin de las copias de seguridad de Drive para ordenadores, pruébalo, [cuéntanos lo que no funciona](https://github.com/carlosnakazawa/gphotos-smart-backup/issues/new?template=bug_report.yml), propón ideas, mejora las traducciones o envía un pull request. Consulta [CONTRIBUTING.md](../CONTRIBUTING.md). Puedes escribir en cualquier idioma.

## Funciones

| | |
| --- | --- |
| **Incremental** | Un historial JSON (`ruta relativa -> tamaño + fecha de modificación`) indica qué archivos ya están en Google Fotos. Se suben los nuevos y los editados; el resto se omite en segundos. |
| **Reanudable** | Cada archivo se registra justo después de subirlo. Si el PC entra en suspensión, se cae la red o pulsas Ctrl+C, la siguiente ejecución sigue desde el mismo archivo. |
| **Compresión de vídeo inteligente** | H.265/HEVC con ffmpeg (`-crf 24 -preset veryfast` por defecto, ajustable). Se conservan la fecha de creación y la ubicación, incluidas las etiquetas `com.apple.quicktime.*` del iPhone. Si la versión H.265 no es más pequeña, se sube el original. |
| **Álbumes (opcional)** | `-AlbumPerFolder` pone los archivos de cada subcarpeta en un álbum con su nombre. |
| **Seguro** | Solo sube (`rclone copyto`). No sigue enlaces simbólicos ni uniones. `-WhatIf` lo muestra todo sin subir nada. Un historial dañado detiene la ejecución en lugar de volver a subir toda la biblioteca. |
| **Listo para automatizar** | Códigos de salida: `0` éxito, `1` error (detenido), `2` terminado, pero algunos vídeos no se pudieron convertir. |

Formatos admitidos por defecto: `.jpg .jpeg .png .heic .heif .webp .gif` (fotos) y `.mp4 .mov .m4v` (vídeos). Los archivos RAW (`.dng`, `.arw`, `.cr2`, ...) y los archivos auxiliares (`.lrf`, `.xmp`, ...) se excluyen a propósito. Añádelos con `-PhotoExtensions` si quieres.

## Cómo funciona

```text
 Tu carpeta ──escaneo──> ¿nuevo o modificado? ──no──> omitir
                              │ sí
                              v
                     ¿vídeo? ──sí──> ffmpeg H.265 (carpeta temporal) ──> ¿más pequeño? ──no──> usar el original
                              │ no                                          │ sí
                              v                                             v
                     rclone copyto ──> Google Fotos ──> registrar en .sync_history.json ──> siguiente archivo
```

## Requisitos

- Windows 10 u 11, con Windows PowerShell 5.1 (incluido) o PowerShell 7+
- [rclone](https://rclone.org/) (una versión reciente; se recomienda v1.70 o posterior)
- [ffmpeg](https://ffmpeg.org/) con `libx265` (solo para comprimir vídeos; no hace falta con `-NoTranscode`)
- Una cuenta de Google y un proyecto gratuito de Google Cloud (para tu propio cliente OAuth, ver abajo)

No hacen falta permisos de administrador.

## Instalación

### 1. Instala rclone y ffmpeg

```powershell
winget install Rclone.Rclone
winget install Gyan.FFmpeg
```

Después abre un terminal nuevo para que ambos estén en el `PATH`.

### 2. Crea tu propio cliente OAuth de Google

El client ID compartido de rclone para Google Fotos se retira a lo largo de 2026. Necesitas el tuyo, que es gratuito y lleva unos 5 minutos:

1. Abre la [Google Cloud Console](https://console.cloud.google.com/) y crea un proyecto (por ejemplo, `gphotos-backup`).
2. **APIs y servicios > Biblioteca**: habilita la **Photos Library API**.
3. **Google Auth Platform > Branding / Público**: elige **Externo**, rellena el nombre de la app y tu correo, y añade tu cuenta de Google como **usuario de prueba**.
4. **Acceso a datos > Añadir o quitar permisos**: añade estos tres permisos (scopes):
   `https://www.googleapis.com/auth/photoslibrary.appendonly`,
   `https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata`,
   `https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata`.
5. **Clientes > Crear cliente**: tipo **Aplicación de escritorio**. Copia el **ID de cliente** y el **secreto del cliente**.
6. Recomendado: en **Público**, pulsa **Publicar app**. Mientras la app está en "Prueba", Google caduca el inicio de sesión cada 7 días. Al iniciar sesión verás el aviso "Google no ha verificado esta aplicación". Es normal, porque la app es tuya.

La documentación de rclone tiene más detalles: [Google Photos: making your own client ID](https://rclone.org/googlephotos/).

### 3. Configura el remote de rclone

```powershell
rclone config
```

Responde: `n` (nuevo remote), nombre **`gphotos`**, almacenamiento **Google Photos**, pega tu `client_id` y tu `client_secret`, `read_only` = **false**, y deja que rclone abra el navegador para iniciar sesión. Compruébalo con:

```powershell
rclone lsd gphotos:
```

Si actualizaste rclone desde una versión antigua y aparecen errores de permisos, ejecuta `rclone config reconnect gphotos:`.

### 4. Descarga el script y haz una vista previa

```powershell
git clone https://github.com/carlosnakazawa/gphotos-smart-backup.git
cd gphotos-smart-backup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1 -WhatIf
```

`-ExecutionPolicy Bypass` solo se aplica a este proceso. Si descargaste el ZIP, puedes ejecutar antes `Get-ChildItem -Recurse | Unblock-File`. `-WhatIf` muestra lo que se subiría y no cambia nada.

### 5. Ejecútalo

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1
```

## Uso

```powershell
# Tu carpeta Imágenes a gphotos:upload (valores por defecto)
.\gphotos-backup.ps1

# Otra carpeta, un álbum por subcarpeta
.\gphotos-backup.ps1 -SourcePath 'D:\Camera' -AlbumPerFolder

# Vídeos más pequeños (codificación más lenta)
.\gphotos-backup.ps1 -Crf 26 -Preset medium

# Subir los vídeos tal cual
.\gphotos-backup.ps1 -NoTranscode

# Omitir algunas carpetas e incluir archivos DNG
.\gphotos-backup.ps1 -ExcludeFolder 'Screenshots', '_Upload_Staging' -PhotoExtensions '.jpg', '.jpeg', '.png', '.heic', '.dng'

# Ayuda completa
Get-Help .\gphotos-backup.ps1 -Detailed
```

| Parámetro | Por defecto | Descripción |
| --- | --- | --- |
| `-SourcePath` | tu carpeta Imágenes | Carpeta con los originales (incluidas las subcarpetas). |
| `-RcloneRemote` | `gphotos:upload` | Destino de rclone. `upload` pone los archivos en la biblioteca, sin álbum. |
| `-AlbumPerFolder` | desactivado | Los archivos de `2024\Viaje\` van al álbum `2024/Viaje`. Los de la raíz van a `-RcloneRemote`. |
| `-HistoryFile` | `Imágenes\.sync_history.json` | Historial de subidas. Un mismo archivo puede servir para varias carpetas de origen. |
| `-StagingPath` | `%TEMP%\gphotos-smart-backup` | Carpeta temporal de los vídeos convertidos (se vacía tras cada archivo). |
| `-Crf` | `24` | Calidad H.265, de 0 a 51. Cuanto más bajo, más calidad y archivos más grandes. Entre 22 y 28 es un rango razonable. |
| `-Preset` | `veryfast` | Velocidad de x265. `medium` y `slow` dan archivos más pequeños, pero tardan más. |
| `-NoTranscode` | desactivado | No usa ffmpeg. |
| `-PhotoExtensions` / `-VideoExtensions` | ver arriba | Tipos de archivo que se suben. |
| `-ExcludeFolder` | `_Upload_Staging` | Nombres de carpeta que se omiten, a cualquier nivel. |
| `-RclonePath` / `-FfmpegPath` | `rclone` / `ffmpeg` | Ejecutables, si no están en el `PATH`. |
| `-WhatIf` / `-Confirm` | | Vista previa, o confirmación de cada archivo. |

Cualquier opción de rclone se puede definir con variables de entorno, por ejemplo `$env:RCLONE_BWLIMIT = '4M'` para limitar el ancho de banda de subida.

## Programación (copia automática)

Ejecútalo cada noche con el Programador de tareas. La tarea se ejecuta con tu usuario, mientras tienes la sesión iniciada, así que rclone encuentra tu configuración y no se guarda ninguna contraseña:

```powershell
$script = 'C:\Tools\gphotos-smart-backup\gphotos-backup.ps1'   # ajusta la ruta
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 21:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 12)
Register-ScheduledTask -TaskName 'gphotos-smart-backup' -Action $action -Trigger $trigger -Settings $settings

# Eliminarla
Unregister-ScheduledTask -TaskName 'gphotos-smart-backup' -Confirm:$false
```

Si una ejecución se interrumpe, la siguiente simplemente continúa.

## El archivo de historial

`.sync_history.json` asocia la ruta de cada archivo, relativa a `-SourcePath`, con `<tamaño>_<ticks-de-la-última-modificación>`:

```json
{
    "2026\\Viaje\\IMG_0412.HEIC": "2735969_639012345670000000"
}
```

- Borra una entrada para volver a subir ese archivo. Renombrar el archivo de historial vuelve a subirlo todo desde cero.
- Si editas una foto, cambian su tamaño o su fecha y se vuelve a subir. Google Fotos conserva las dos versiones.
- El archivo contiene los nombres de tus archivos. Mantenlo privado (está en `.gitignore`).
- Usa el mismo formato y la misma ubicación por defecto que la primera versión del script, así que los historiales existentes siguen funcionando.

## Conviene saber (limitaciones)

- **Almacenamiento:** las subidas por la API son siempre en "Calidad original" y cuentan en tu almacenamiento de Google. La API no ofrece "Ahorro de espacio". Por eso se comprimen los vídeos.
- **Fechas:** Google Fotos usa la fecha EXIF o de los metadatos. Los archivos sin ella (algunas capturas de pantalla, imágenes de apps de mensajería) muestran la fecha de subida.
- **Duplicados:** Google Fotos reconoce archivos idénticos, así que subir dos veces el mismo archivo no crea una copia. En cambio, un vídeo recodificado es un archivo distinto.
- **¿Lo borraste en Google Fotos?** El script no consulta Google Fotos. Un archivo que está en el historial no se vuelve a subir, aunque lo hayas borrado en línea.
- Los vídeos **HDR / Dolby Vision** pueden perder el aspecto HDR al recodificarse. Usa `-NoTranscode` (o excluye esas carpetas) si te importa.
- **Lo que ve rclone:** desde el 31 de marzo de 2025, Google solo permite a las apps leer el contenido que ellas mismas subieron. Esta herramienta solo sube, así que no es un problema.
- **Cuotas:** la API de Google Fotos tiene límites diarios de solicitudes. Una primera subida muy grande puede necesitar varias ejecuciones. El historial lo hace sencillo.

## Lo que no hace

- Nunca borra, mueve ni modifica tus archivos locales.
- Nunca borra nada en Google Fotos (solo se usa `rclone copyto`, y una prueba de seguridad lo garantiza).
- No envía datos a ningún sitio salvo a Google Fotos, a través de tu propio remote de rclone.

## Desarrollo

```powershell
# Comprobaciones estáticas rápidas (sintaxis, solo ASCII, salvaguardas)
.\scripts\Invoke-HarnessCheck.ps1 -SkipAnalyzer -SkipPester

# Todo (requiere PSScriptAnalyzer 1.25.0 y Pester 5.5+)
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck
.\scripts\Invoke-HarnessCheck.ps1
```

La CI ejecuta el analizador, las pruebas de Pester (rclone y ffmpeg se simulan) y una prueba de humo con `-WhatIf` en **Windows Server 2022 y 2025**, tanto con **Windows PowerShell 5.1 como con PowerShell 7**.

Los archivos `.ps1` se mantienen **solo en ASCII** a propósito: Windows PowerShell 5.1 lee los archivos sin BOM con la página de códigos ANSI, y los caracteres acentuados romperían el script. Una prueba lo garantiza.

Agentes de IA de programación: leed primero [AGENTS.md](../AGENTS.md).

## Contribuir

Los informes de errores, las ideas, las traducciones y los pull requests son bienvenidos, en cualquier idioma. Consulta [CONTRIBUTING.md](../CONTRIBUTING.md). Buenas primeras contribuciones:

- pruébalo con los archivos de tu cámara o tu móvil y cuéntanos el resultado;
- mejora una traducción o añade tu idioma;
- elige un punto de la hoja de ruta.

## Hoja de ruta

- Script auxiliar `Register-BackupTask.ps1` para crear la tarea programada con un solo comando.
- Codificación por hardware opcional (NVENC, Quick Sync, AMF) para convertir más rápido.
- No recodificar vídeos que ya son HEVC o pequeños, según su bitrate.
- Conservar los metadatos HDR al recodificar.
- Archivo de registro e informe JSON de cada ejecución.
- Publicar en la PowerShell Gallery y en `winget`.

## Licencia

[MIT](../LICENSE) © Carlos Alberto Nakazawa

*Este proyecto no está afiliado, respaldado ni patrocinado por Google. Google Fotos y Google Drive son marcas comerciales de Google LLC.*
