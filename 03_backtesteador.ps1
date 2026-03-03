# Lanza el Strategy Tester con la configuración indicada en plantilla_funcional.ini,
# actualizando login/password/servidor y el EA a testear según la instancia activa.

$root        = Join-Path $env:USERPROFILE 'Desktop\.eastudio'
$credPath    = Join-Path $root '00_setup/Instancias/credencial_en_uso.json'
$configPath  = Join-Path $root 'plantilla_funcional.ini'

function Update-IniValue {
    param(
        [string[]]$Lines,
        [string]$Section,
        [string]$Key,
        [string]$Value
    )
    $result = @()
    $inSection = $false
    $replaced  = $false
    foreach($line in $Lines){
        if($line -match '^\s*\[.+\]\s*$'){
            if($inSection -and -not $replaced){
                $result += "$Key=$Value"
                $replaced = $true
            }
            $inSection = ($line -match "^\s*\[$Section\]\s*$")
            $result += $line
            continue
        }
        if($inSection -and $line -match "^\s*$Key\s*="){
            $result += "$Key=$Value"
            $replaced = $true
        } else {
            $result += $line
        }
    }
    if(-not $replaced){
        $result += "[$Section]"
        $result += "$Key=$Value"
    }
    return $result
}

if (-not (Test-Path $credPath)) {
    Write-Host "No se encontró credencial_en_uso.json. Ejecutá 01_init_0.ps1 opción 3 para marcar una instancia activa." -ForegroundColor Yellow
    exit 1
}

try { $cred = Get-Content $credPath -Raw | ConvertFrom-Json } catch {
    Write-Host "No se pudo leer ${credPath}: $($_)" -ForegroundColor Red
    exit 1
}

$terminalExe = $cred.terminal_exe
if (-not $terminalExe -or -not (Test-Path $terminalExe)) {
    Write-Host "terminal_exe no está definido o no existe. Reejecutá 01_init_0.ps1 opción 3." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $configPath)) {
    Write-Host "No se encontró $configPath. Asegurate de tener plantilla_funcional.ini en la raíz del proyecto." -ForegroundColor Red
    exit 1
}

$eaDir = Join-Path $cred.ruta_instancia 'instalacion/MQL5/Experts/Ea_Studio'
if (-not (Test-Path $eaDir)) {
    Write-Host "No se encontró la carpeta de EAs en $eaDir. Revisa la instancia o compila primero." -ForegroundColor Red
    exit 1
}

$eas = Get-ChildItem -Path $eaDir -Filter *.ex5 -File | Sort-Object Name
if (-not $eas) {
    Write-Host "No hay .ex5 en $eaDir. Compilá un EA con 02_compilador.ps1 antes de backtestear." -ForegroundColor Yellow
    exit 1
}

Write-Host "`nEAs disponibles:" -ForegroundColor Cyan
$i=1; foreach($ea in $eas){ Write-Host ("[{0}] {1}" -f $i, $ea.Name) ; $i++ }

$sel = Read-Host "Elegí número de EA para probar"
if(-not ($sel -match '^\d+$') -or [int]$sel -lt 1 -or [int]$sel -gt $eas.Count){
    Write-Host "Selección inválida." -ForegroundColor Red
    exit 1
}
$chosen = $eas[[int]$sel - 1]
$relativeExpert = "Ea_Studio\$($chosen.Name)"

$lines = Get-Content $configPath
$lines = Update-IniValue -Lines $lines -Section "Common" -Key "Login"    -Value ($cred.credencial.cuenta)
$lines = Update-IniValue -Lines $lines -Section "Common" -Key "Password" -Value ($cred.credencial.password)
$lines = Update-IniValue -Lines $lines -Section "Common" -Key "Server"   -Value ($cred.credencial.servidor)
$lines = Update-IniValue -Lines $lines -Section "Tester" -Key "Expert"   -Value $relativeExpert

$lines | Set-Content -Path $configPath -Encoding UTF8

$args = @("/portable", "/config:$configPath")
Write-Host "`nLanzando tester con:" -ForegroundColor Cyan
Write-Host "  Terminal: $terminalExe" -ForegroundColor Gray
Write-Host "  Config:   $configPath" -ForegroundColor Gray
Write-Host "  Expert:   $relativeExpert" -ForegroundColor Gray

Start-Process -FilePath $terminalExe -ArgumentList $args -Wait
