# Compila todos los EAs (.mq5/.mql5) en BUILD/01_ea_construccion usando el MetaEditor de la instancia activa.
# Usa la ruta almacenada en 00_setup/Instancias/credencial_en_uso.json (metaeditor_exe).

$ErrorActionPreference = 'Stop'

$repoRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$credPath  = Join-Path $repoRoot '00_setup/Instancias/credencial_en_uso.json'
$sourceDir = Join-Path $repoRoot 'BUILD/01_ea_construccion'
$archiveDir= Join-Path $sourceDir 'archivados'
$logRoot  = Join-Path $repoRoot 'Compilacion'
$logDir    = Join-Path $logRoot 'logs'

if (-not (Test-Path $credPath)) { throw "No existe $credPath. Ejecutá .\\00_setup\\Instalador.ps1 (opción 3) para generar credencial_en_uso.json." }
$cred = Get-Content $credPath -Raw | ConvertFrom-Json
if (-not $cred.metaeditor_exe) { throw "El JSON activo no tiene metaeditor_exe. Reejecutá .\\00_setup\\Instalador.ps1 opción 3." }
if (-not (Test-Path $cred.metaeditor_exe)) { throw "No se encontró MetaEditor en: $($cred.metaeditor_exe)" }
if (-not $cred.ruta_instancia) { throw "El JSON activo no tiene ruta_instancia. Reejecutá .\\00_setup\\Instalador.ps1 opción 3." }
$eaStudioDir = Join-Path $cred.ruta_instancia 'instalacion/MQL5/Experts/Ea_Studio'
if (-not (Test-Path $eaStudioDir)) { New-Item -ItemType Directory -Path $eaStudioDir -Force | Out-Null }
$metaLogSrc  = Join-Path $cred.ruta_instancia 'instalacion/logs/metaeditor.log'

if (-not (Test-Path $sourceDir)) { throw "No existe el directorio fuente: $sourceDir" }
# Crear carpeta de compilación/logs si no existe
if (-not (Test-Path $logRoot)) { New-Item -ItemType Directory -Path $logRoot -Force | Out-Null }
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
# -Include requiere -Recurse o comodín en Path; usamos Filter dos veces para evitar falso negativo.
$files = @()
$files += Get-ChildItem -Path $sourceDir -File -Filter '*.mq5'  -ErrorAction SilentlyContinue
$files += Get-ChildItem -Path $sourceDir -File -Filter '*.mql5' -ErrorAction SilentlyContinue
if (-not $files) { Write-Host "No hay archivos .mq5/.mql5 en $sourceDir" -ForegroundColor Yellow; exit 0 }

# Si hay más de un EA, conservar solo el más reciente y archivar los demás para evitar duplicados entre instancias.
if ($files.Count -gt 1) {
    if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null }
    $latest      = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $latestBase  = $latest.BaseName
    $keep        = $files | Where-Object { $_.BaseName -eq $latestBase }
    $archive     = $files | Where-Object { $_.BaseName -ne $latestBase }

    foreach ($f in $archive) {
        $dest = Join-Path $archiveDir $f.Name
        Move-Item -Path $f.FullName -Destination $dest -Force
        # Mover también el ex5 con el mismo nombre si está en la carpeta de construcción
        $ex5 = Join-Path $sourceDir ($f.BaseName + '.ex5')
        if (Test-Path $ex5) { Move-Item -Path $ex5 -Destination (Join-Path $archiveDir ([IO.Path]::GetFileName($ex5))) -Force }
        # Mover también teoría asociada si existe (BaseName_teoria.md)
        $theory = Join-Path $sourceDir ($f.BaseName + '_teoria.md')
        if (Test-Path $theory) {
            $theoryDest = Join-Path $archiveDir ([IO.Path]::GetFileName($theory))
            Move-Item -Path $theory -Destination $theoryDest -Force
        }
    }
    $files = $keep
    $keepList = ($keep | Select-Object -ExpandProperty Name -Unique) -join ', '
    Write-Host ("Se archivaron {0} EA(s) antiguos en {1}. Se compila solo: {2}" -f $archive.Count, $archiveDir, $keepList) -ForegroundColor DarkYellow
}

if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
# Limpiar logs antiguos para que queden solo los de la compilación actual
Get-ChildItem -Path $logDir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
# Borrar metaeditor.log de la instancia para capturar solo esta corrida
if (Test-Path $metaLogSrc) { Remove-Item $metaLogSrc -Force -ErrorAction SilentlyContinue }

foreach ($f in $files) {
    $logFile = Join-Path $logDir ("{0}.log" -f $f.BaseName)
    if (Test-Path $logFile) { Remove-Item $logFile -Force }

    Write-Host ("Compilando {0} ..." -f $f.Name) -ForegroundColor Cyan
    $args = @(
        '/portable'
        ("/compile:`"{0}`"" -f $f.FullName)
        ("/log:`"{0}`"" -f $logFile)
    )
    $proc = Start-Process -FilePath $cred.metaeditor_exe -ArgumentList $args -NoNewWindow -Wait -PassThru

    $status = 'sin log'
    $fg     = 'Yellow'
    if (Test-Path $logFile) {
        $status = 'OK'
        $fg     = 'Green'
        $resultLine = Select-String -Path $logFile -Pattern '^Result:\s+(\d+)\s+errors?,\s+(\d+)\s+warnings?' | Select-Object -First 1
        if ($resultLine) {
            $errCount  = [int]$resultLine.Matches[0].Groups[1].Value
            $warnCount = [int]$resultLine.Matches[0].Groups[2].Value
            if ($errCount -gt 0) { $status = "con errores ($errCount)"; $fg = 'Red' }
            elseif ($warnCount -gt 0) { $status = "con warnings ($warnCount)"; $fg = 'Yellow' }
        } else {
            $status = 'log sin línea Result'
            $fg     = 'Yellow'
        }
    }
    Write-Host ("Resultado {0}: {1}" -f $status, $logFile) -ForegroundColor $fg

    # Copiar el binario compilado al Experts/Ea_Studio de la instancia activa
    $ex5Source = [IO.Path]::ChangeExtension($f.FullName, '.ex5')
    if (Test-Path $ex5Source) {
        $dest = Join-Path $eaStudioDir ([IO.Path]::GetFileName($ex5Source))
        Copy-Item -Path $ex5Source -Destination $dest -Force
        Write-Host ("Binario copiado a {0}" -f $dest) -ForegroundColor DarkCyan
    } else {
        Write-Host "No se encontró binario .ex5 para copiar (¿falló la compilación?)." -ForegroundColor Yellow
    }
}

# Copiar metaeditor.log de la instancia activa para referencia
if (Test-Path $metaLogSrc) {
    $metaLogDest = Join-Path $logDir 'metaeditor.log'
    Copy-Item -Path $metaLogSrc -Destination $metaLogDest -Force
    Write-Host ("metaeditor.log guardado en {0}" -f $metaLogDest) -ForegroundColor DarkGray
}

Write-Host "Terminó la compilación. Revisá los logs en $logDir" -ForegroundColor Green
