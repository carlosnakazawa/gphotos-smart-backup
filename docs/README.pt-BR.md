# Google Photos Smart Backup

[![CI](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/carlosnakazawa/gphotos-smart-backup/actions/workflows/ci.yml)
[![Licença: MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-blue.svg)](../LICENSE)
![PowerShell 5.1 | 7](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)
![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4)
[![Contribuições bem-vindas](https://img.shields.io/badge/contribui%C3%A7%C3%B5es-bem--vindas-brightgreen.svg)](../CONTRIBUTING.md)

[English](../README.md) | **Português (Brasil)** | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Italiano](README.it.md) | [Русский](README.ru.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md)

> Esta tradução pode estar desatualizada em relação à [versão em inglês](../README.md), que é a referência.

Faça backup das fotos e vídeos do seu PC com Windows no **Google Fotos**, automaticamente, sem precisar deixar uma aba do navegador aberta. Os vídeos são **comprimidos em H.265 antes do envio** para economizar espaço, e cada upload é **registrado na hora**, então uma execução interrompida continua de onde parou.

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

## Por que este projeto existe

Durante anos, quem usava Windows conseguia fazer backup de uma pasta no Google Fotos com o aplicativo de desktop do Google ("Backup e sincronização" e depois o **Google Drive para computador**). **Isso acabou**:

- desde **15 de junho de 2026**, o Drive para computador não permite mais adicionar pastas para backup no Google Fotos;
- em **10 de agosto de 2026**, ele parou de vez de enviar novas fotos e vídeos ao Google Fotos.

A alternativa do Google é o "Fazer backup de pastas" em [photos.google.com](https://photos.google.com), que **só funciona enquanto a página do Google Fotos fica aberta no navegador**. Não existe mais backup em segundo plano no Windows.

Este projeto preenche essa lacuna com um script PowerShell pequeno e transparente, baseado em duas ferramentas open source conhecidas, o [rclone](https://rclone.org/googlephotos/) e o [ffmpeg](https://ffmpeg.org/):

- roda **sem supervisão** (por exemplo, pelo Agendador de Tarefas), sem navegador e sem aplicativo do Google;
- envia **só o que é novo ou foi alterado**, mantendo um histórico local de cada arquivo enviado;
- **reduz o tamanho dos vídeos** antes do envio. Arquivos enviados pela API do Google Fotos ficam sempre em **qualidade original e contam no seu armazenamento do Google**, então um vídeo 4K recodificado em H.265 pode economizar muito espaço;
- **nunca apaga nem move nada**, nem no seu PC nem no Google Fotos.

**É um projeto da comunidade, e toda ajuda é muito bem-vinda.** Se você foi afetado pelo fim do backup do Drive para computador, experimente, [conte o que não funcionou](https://github.com/carlosnakazawa/gphotos-smart-backup/issues/new?template=bug_report.yml), sugira ideias, melhore as traduções ou mande um pull request. Veja o [CONTRIBUTING.md](../CONTRIBUTING.md). Pode escrever em qualquer idioma.

## Funcionalidades

| | |
| --- | --- |
| **Incremental** | Um histórico em JSON (`caminho relativo -> tamanho + data de modificação`) indica quais arquivos já estão no Google Fotos. Arquivos novos e editados são enviados; o resto é ignorado em segundos. |
| **Retomável** | Cada arquivo é registrado logo após o upload. Se o PC suspender, a internet cair ou você apertar Ctrl+C, a próxima execução continua do mesmo arquivo. |
| **Compressão inteligente de vídeo** | H.265/HEVC com ffmpeg (`-crf 24 -preset veryfast` por padrão, ajustável). A data de criação e a localização são mantidas, inclusive as tags `com.apple.quicktime.*` do iPhone. Se a versão H.265 não ficar menor, o original é enviado. Vídeos que já são compactos (por exemplo, HEVC de iPhones recentes) são detectados com o ffprobe e enviados como estão, sem perder tempo com uma nova codificação. |
| **Álbuns (opcional)** | `-AlbumPerFolder` coloca os arquivos de cada subpasta num álbum com o nome dela. |
| **Seguro** | Só envia (`rclone copyto`). Não segue links simbólicos nem junções. `-WhatIf` mostra tudo sem enviar nada. Um histórico corrompido interrompe a execução em vez de reenviar a biblioteca inteira. |
| **Pronto para automação** | Códigos de saída: `0` sucesso, `1` erro (interrompido), `2` concluído, mas alguns vídeos não puderam ser convertidos. |

Formatos suportados por padrão: `.jpg .jpeg .png .heic .heif .webp .gif` (fotos) e `.mp4 .mov .m4v` (vídeos). Arquivos RAW (`.dng`, `.arw`, `.cr2`, ...) e arquivos auxiliares (`.lrf`, `.xmp`, ...) ficam de fora de propósito. Inclua-os com `-PhotoExtensions` se quiser.

## Como funciona

```text
 Sua pasta ──varre──> novo ou alterado? ──não──> ignora
                              │ sim
                              v
                     vídeo? ──sim──> ffmpeg H.265 (pasta temporária) ──> menor? ──não──> usa o original
                              │ não                                         │ sim
                              v                                             v
                     rclone copyto ──> Google Fotos ──> registra em .sync_history.json ──> próximo arquivo
```

## Requisitos

- Windows 10 ou 11, com Windows PowerShell 5.1 (já incluído) ou PowerShell 7+
- [rclone](https://rclone.org/) (versão recente; v1.70 ou mais nova recomendada)
- [ffmpeg](https://ffmpeg.org/) com `libx265` (só para comprimir vídeos; dispensável com `-NoTranscode`)
- Uma conta Google e um projeto gratuito no Google Cloud (para o seu próprio cliente OAuth, veja abaixo)

Não é preciso ser administrador.

## Configuração

### 1. Instale o rclone e o ffmpeg

```powershell
winget install Rclone.Rclone
winget install Gyan.FFmpeg
```

Depois, abra um novo terminal para que os dois estejam no `PATH`.

### 2. Crie o seu próprio cliente OAuth do Google

O client ID compartilhado do rclone para o Google Fotos está sendo desativado ao longo de 2026. Você precisa do seu, o que é gratuito e leva uns 5 minutos:

1. Abra o [Google Cloud Console](https://console.cloud.google.com/) e crie um projeto (por exemplo, `gphotos-backup`).
2. **APIs e serviços > Biblioteca**: ative a **Photos Library API**.
3. **Google Auth Platform > Branding / Público-alvo**: escolha **Externo**, preencha o nome do app e o seu e-mail e adicione a sua conta Google como **usuário de teste**.
4. **Acesso a dados > Adicionar ou remover escopos**: adicione estes três escopos:
   `https://www.googleapis.com/auth/photoslibrary.appendonly`,
   `https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata`,
   `https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata`.
5. **Clientes > Criar cliente**: tipo **App para computador**. Copie o **ID do cliente** e a **chave secreta do cliente**.
6. Recomendado: em **Público-alvo**, clique em **Publicar app**. Enquanto o app está em "Teste", o Google expira o login a cada 7 dias. Ao entrar, vai aparecer o aviso "O Google não verificou este app". Isso é esperado, porque o app é seu.

A documentação do rclone tem mais detalhes: [Google Photos: making your own client ID](https://rclone.org/googlephotos/).

### 3. Configure o remote do rclone

```powershell
rclone config
```

Responda: `n` (novo remote), nome **`gphotos`**, armazenamento **Google Photos**, cole o `client_id` e o `client_secret`, `read_only` = **false**, e deixe o rclone abrir o navegador para você entrar na conta. Confira com:

```powershell
rclone lsd gphotos:
```

Se você atualizou o rclone de uma versão antiga e aparecerem erros de permissão, rode `rclone config reconnect gphotos:`.

### 4. Baixe o script e veja a prévia

```powershell
git clone https://github.com/carlosnakazawa/gphotos-smart-backup.git
cd gphotos-smart-backup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1 -WhatIf
```

O `-ExecutionPolicy Bypass` vale só para este processo. Se você baixou o ZIP, pode rodar `Get-ChildItem -Recurse | Unblock-File` antes. O `-WhatIf` lista o que seria enviado e não altera nada.

### 5. Execute

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gphotos-backup.ps1
```

## Uso

```powershell
# Sua pasta Imagens para gphotos:upload (padrões)
.\gphotos-backup.ps1

# Outra pasta, um álbum por subpasta
.\gphotos-backup.ps1 -SourcePath 'D:\Camera' -AlbumPerFolder

# Vídeos menores (codificação mais lenta)
.\gphotos-backup.ps1 -Crf 26 -Preset medium

# Enviar os vídeos como estão
.\gphotos-backup.ps1 -NoTranscode

# Ignorar algumas pastas e incluir arquivos DNG
.\gphotos-backup.ps1 -ExcludeFolder 'Screenshots', '_Upload_Staging' -PhotoExtensions '.jpg', '.jpeg', '.png', '.heic', '.dng'

# Ajuda completa
Get-Help .\gphotos-backup.ps1 -Detailed
```

| Parâmetro | Padrão | Descrição |
| --- | --- | --- |
| `-SourcePath` | sua pasta Imagens | Pasta com os originais (subpastas incluídas). |
| `-RcloneRemote` | `gphotos:upload` | Destino no rclone. `upload` coloca os arquivos na biblioteca, sem álbum. |
| `-AlbumPerFolder` | desligado | Arquivos em `2024\Viagem\` vão para o álbum `2024/Viagem`. Arquivos na raiz vão para `-RcloneRemote`. |
| `-HistoryFile` | `Imagens\.sync_history.json` | Histórico de uploads. Um mesmo arquivo pode servir para várias pastas de origem. |
| `-StagingPath` | `%TEMP%\gphotos-smart-backup` | Pasta temporária dos vídeos convertidos (esvaziada após cada arquivo). |
| `-Crf` | `24` | Qualidade H.265, de 0 a 51. Valores menores dão mais qualidade e arquivos maiores. De 22 a 28 é uma faixa razoável. |
| `-Preset` | `veryfast` | Velocidade do x265. `medium` e `slow` geram arquivos menores, mas demoram mais. |
| `-NoTranscode` | desligado | Não usa o ffmpeg. |
| `-SkipTranscodeBelowMbps` | `4` | Envia o vídeo como está quando o bitrate, normalizado para 1080p a 30 fps, fica igual ou abaixo deste valor (o dobro para HEVC, AV1 e VP9). `0` converte todos os vídeos. |
| `-PhotoExtensions` / `-VideoExtensions` | veja acima | Tipos de arquivo a enviar. |
| `-ExcludeFolder` | `_Upload_Staging` | Nomes de pasta a ignorar, em qualquer nível. |
| `-RclonePath` / `-FfmpegPath` / `-FfprobePath` | `rclone` / `ffmpeg` / ao lado do ffmpeg | Executáveis, se não estiverem no `PATH`. |
| `-WhatIf` / `-Confirm` | | Prévia, ou confirmação a cada arquivo. |

Qualquer opção do rclone pode ser definida por variável de ambiente, por exemplo `$env:RCLONE_BWLIMIT = '4M'` para limitar a banda de upload.

## Agendamento (backup automático)

Rode todas as noites pelo Agendador de Tarefas. A tarefa roda com o seu usuário, enquanto você está conectado, então o rclone encontra a sua configuração e nenhuma senha é armazenada:

```powershell
$script = 'C:\Tools\gphotos-smart-backup\gphotos-backup.ps1'   # ajuste
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 21:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 12)
Register-ScheduledTask -TaskName 'gphotos-smart-backup' -Action $action -Trigger $trigger -Settings $settings

# Remover
Unregister-ScheduledTask -TaskName 'gphotos-smart-backup' -Confirm:$false
```

Se uma execução for interrompida, a próxima simplesmente continua.

## O arquivo de histórico

O `.sync_history.json` associa o caminho de cada arquivo, relativo ao `-SourcePath`, a `<tamanho>_<ticks-da-última-modificação>`:

```json
{
    "2026\\Viagem\\IMG_0412.HEIC": "2735969_639012345670000000"
}
```

- Apague uma entrada para enviar aquele arquivo de novo. Renomear o arquivo de histórico recomeça o envio do zero.
- Se você editar uma foto, o tamanho ou a data mudam e ela é enviada de novo. O Google Fotos guarda as duas versões.
- O arquivo contém os nomes dos seus arquivos. Mantenha-o privado (ele está no `.gitignore`).
- Ele usa o mesmo formato e o mesmo local padrão da primeira versão do script, então históricos existentes continuam funcionando.

## Bom saber (limitações)

- **Armazenamento:** uploads pela API ficam sempre em "Qualidade original" e contam no seu armazenamento do Google. A API não tem a opção "Economia de armazenamento". Por isso os vídeos são comprimidos.
- **Datas:** o Google Fotos usa a data do EXIF/metadados. Arquivos sem essa informação (algumas capturas de tela, imagens de apps de mensagens) aparecem com a data do upload.
- **Duplicados:** o Google Fotos reconhece arquivos idênticos, então enviar o mesmo arquivo duas vezes não cria cópia. Um vídeo recodificado, porém, é um arquivo diferente.
- **Apagou no Google Fotos?** O script não consulta o Google Fotos. Um arquivo que está no histórico não é reenviado, mesmo que você o tenha apagado online.
- Vídeos **HDR / Dolby Vision** podem perder o aspecto HDR ao serem recodificados. Use `-NoTranscode` (ou exclua essas pastas) se isso importar para você.
- **O que o rclone enxerga:** desde 31 de março de 2025, o Google só deixa os apps lerem as mídias que eles mesmos enviaram. Esta ferramenta só envia, então isso não é problema.
- **Cotas:** a API do Google Fotos tem limites diários de requisições. Um primeiro envio muito grande pode precisar de várias execuções. O histórico torna isso tranquilo.

## O que o script não faz

- Nunca apaga, move ou altera os seus arquivos locais.
- Nunca apaga nada no Google Fotos (só `rclone copyto` é usado, e um teste de proteção garante isso).
- Não envia dados para lugar nenhum além do Google Fotos, pelo seu próprio remote do rclone.

## Desenvolvimento

```powershell
# Verificações estáticas rápidas (sintaxe, só ASCII, proteções)
.\scripts\Invoke-HarnessCheck.ps1 -SkipAnalyzer -SkipPester

# Tudo (requer PSScriptAnalyzer 1.25.0 e Pester 5.5+)
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -SkipPublisherCheck
.\scripts\Invoke-HarnessCheck.ps1
```

O CI roda o analisador, os testes Pester (rclone e ffmpeg são simulados) e um teste de fumaça com `-WhatIf` no **Windows Server 2022 e 2025**, tanto no **Windows PowerShell 5.1 quanto no PowerShell 7**.

Os arquivos `.ps1` são mantidos **somente em ASCII** de propósito: o Windows PowerShell 5.1 lê arquivos sem BOM com a página de código ANSI, e caracteres acentuados quebrariam o script. Um teste garante isso.

Agentes de IA para código: leiam primeiro o [AGENTS.md](../AGENTS.md).

## Contribuindo

Relatos de bugs, ideias, traduções e pull requests são bem-vindos, em qualquer idioma. Veja o [CONTRIBUTING.md](../CONTRIBUTING.md). Boas primeiras contribuições:

- teste com os arquivos da sua câmera ou celular e conte o resultado;
- melhore uma tradução ou adicione o seu idioma;
- escolha um item dos próximos passos.

## Próximos passos

- Script auxiliar `Register-BackupTask.ps1` para criar a tarefa agendada com um comando.
- Codificação por hardware opcional (NVENC, Quick Sync, AMF) para converter mais rápido.
- Preservar os metadados HDR na recodificação.
- Arquivo de log e relatório JSON de cada execução.
- Publicar na PowerShell Gallery e no `winget`.

## Licença

[MIT](../LICENSE) © Carlos Alberto Nakazawa

*Este projeto não é afiliado, endossado nem patrocinado pelo Google. Google Fotos e Google Drive são marcas registradas da Google LLC.*
