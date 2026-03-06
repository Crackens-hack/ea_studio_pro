# Desinstala una instancia de MT (carpeta en 00_setup/Instancias)
# Flujo: lista instancias, pide elección, confirma nombre, ejecuta uninstall.exe si existe y luego borra la carpeta completa.

$expectedRoot   = Join-Path $env:USERPROFILE 'Desktop\.eastudio'
$instanciasRoot = Join-Path $expectedRoot '00_setup/Instancias'
$credFile       = Join-Path $instanciasRoot 'credencial_en_uso.json'
$dataRoot       = Join-Path $expectedRoot 'DATA'

function Assert-Location {
    $here = (Get-Location).ProviderPath
    if ($here -ne $expectedRoot) {
        Write-Host "Ejecutá desde $expectedRoot. Actual: $here" -ForegroundColor Yellow
        exit 1
    }
    $isVSCode = $env:TERM_PROGRAM -eq 'vscode' -or $env:VSCODE_GIT_IPC_HANDLE -or $env:VSCODE_INJECTION
    if (-not $isVSCode) {
        Write-Host "Usá la terminal integrada de VS Code/Cursor/Antigravity." -ForegroundColor Yellow
        exit 1
    }
}

Assert-Location

if (-not (Test-Path $instanciasRoot)) {
    Write-Host "No existe 00_setup/Instancias. Nada que desinstalar." -ForegroundColor Yellow
    # limpiar credenciales/DATA huérfanos si existieran
    if(Test-Path $credFile){ try{ Remove-Item $credFile -Force -ErrorAction Stop; Write-Host "credencial_en_uso.json eliminado (sin instancias)." -ForegroundColor Green } catch{ Write-Host "No se pudo eliminar credencial_en_uso.json: $($_)" -ForegroundColor Yellow } }
    if(Test-Path $dataRoot){ try{ Remove-Item $dataRoot -Recurse -Force -ErrorAction Stop; Write-Host "DATA eliminada (sin instancias)." -ForegroundColor Green } catch{ Write-Host "No se pudo eliminar DATA: $($_)" -ForegroundColor Yellow } }
    exit 0
}

$instDirs = Get-ChildItem -Path $instanciasRoot -Directory -ErrorAction SilentlyContinue
if (-not $instDirs) {
    Write-Host "No hay carpetas de instancia en $instanciasRoot." -ForegroundColor Yellow
    # limpiar credenciales/DATA huérfanos si existieran
    if(Test-Path $credFile){ try{ Remove-Item $credFile -Force -ErrorAction Stop; Write-Host "credencial_en_uso.json eliminado (sin instancias)." -ForegroundColor Green } catch{ Write-Host "No se pudo eliminar credencial_en_uso.json: $($_)" -ForegroundColor Yellow } }
    if(Test-Path $dataRoot){ try{ Remove-Item $dataRoot -Recurse -Force -ErrorAction Stop; Write-Host "DATA eliminada (sin instancias)." -ForegroundColor Green } catch{ Write-Host "No se pudo eliminar DATA: $($_)" -ForegroundColor Yellow } }
    exit 0
}

Write-Host ("Instancias encontradas en {0}:`n" -f $instanciasRoot) -ForegroundColor Cyan
$i=1; foreach($d in $instDirs){ Write-Host ("[{0}] {1}" -f $i, $d.Name) ; $i++ }
$sel = Read-Host "Elegí número de instancia a desinstalar"
if(-not ($sel -match '^\d+$') -or [int]$sel -lt 1 -or [int]$sel -gt $instDirs.Count){
    Write-Host "Selección inválida." -ForegroundColor Red
    exit 1
}

$chosen = $instDirs[[int]$sel - 1]
Write-Host "Vas a desinstalar: $($chosen.FullName)" -ForegroundColor Yellow
$confirm = Read-Host "Escribe el nombre exacto de la carpeta para confirmar (o ENTER para cancelar)"
if($confirm -ne $chosen.Name){
    Write-Host "Confirmación incorrecta. Abortando." -ForegroundColor Red
    exit 1
}

# Determinar si es la última instancia o la activa
$isLastInstance = ($instDirs.Count -eq 1)
$isActiveInstance = $false
if(Test-Path $credFile){
    try{
        $credJson = Get-Content $credFile -Raw | ConvertFrom-Json
        $activePath = $credJson.ruta_instancia
        if($activePath -and [string]::Equals($activePath.TrimEnd('\'), $chosen.FullName.TrimEnd('\'), [System.StringComparison]::InvariantCultureIgnoreCase)){
            $isActiveInstance = $true
        }
    } catch {
        Write-Host "Advertencia: no se pudo leer credencial_en_uso.json ($_)"
    }
}
$shouldPurgeData = $isLastInstance -or $isActiveInstance

# Intentar ejecutar uninstall si existe
$uninstaller = Get-ChildItem -Path $chosen.FullName -Recurse -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match 'unins.*\.exe$' -or $_.Name -match 'uninstall.*\.exe$' } |
               Select-Object -First 1

if($uninstaller){
    Write-Host "Ejecutando desinstalador: $($uninstaller.FullName)" -ForegroundColor Cyan
    try {
        Start-Process -FilePath $uninstaller.FullName -Wait -ErrorAction Stop
    } catch {
        Write-Host "No se pudo ejecutar el desinstalador: $($_)" -ForegroundColor Yellow
    }
} else {
    Write-Host "No se encontró uninstall.exe / unins*.exe dentro de la instancia. Se procederá a borrar la carpeta." -ForegroundColor Yellow
}

# Intentar eliminar la carpeta completa
try {
    Remove-Item -Path $chosen.FullName -Recurse -Force -ErrorAction Stop
    Write-Host "Instancia eliminada: $($chosen.FullName)" -ForegroundColor Green
} catch {
    Write-Host "No se pudo eliminar la carpeta: $($_)" -ForegroundColor Red
    Write-Host "Revisa si el terminal sigue abierto o permisos de archivos." -ForegroundColor Yellow
    $shouldPurgeData = $false  # si no eliminó la instancia, no seguir con purga
}

# Purga de DATA y credencial activa si corresponde
if($shouldPurgeData){
    if(Test-Path $dataRoot){
        try{
            Remove-Item -Path $dataRoot -Recurse -Force -ErrorAction Stop
            Write-Host "DATA eliminada (última/instancia activa)." -ForegroundColor Green
        } catch {
            Write-Host "No se pudo eliminar DATA: $($_)" -ForegroundColor Yellow
        }
    }
    if(Test-Path $credFile){
        try{
            Remove-Item -Path $credFile -Force -ErrorAction Stop
            Write-Host "credencial_en_uso.json eliminada." -ForegroundColor Green
        } catch {
            Write-Host "No se pudo eliminar credencial_en_uso.json: $($_)" -ForegroundColor Yellow
        }
    }
}
