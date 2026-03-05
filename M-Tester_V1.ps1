# Lanza el Strategy Tester con la configuración indicada en plantilla_funcional.ini,
# actualizando login/password/servidor y el EA a testear según la instancia activa.

$root        = Join-Path $env:USERPROFILE 'Desktop\.eastudio'
$credPath    = Join-Path $root '00_setup/Instancias/credencial_en_uso.json'
$configPath  = Join-Path $root 'Tools/EXEC-INI/plantilla_funcional.ini'
$tplDir      = Join-Path $root 'Tools'
$tplSingleTest  = Join-Path $tplDir 'plantilla_single_test.ini'
$tplGenetic     = Join-Path $tplDir 'plantilla_genetica.ini'
$tplForward     = Join-Path $tplDir 'plantilla_forward.ini'
$tplSingleFull  = Join-Path $tplDir 'plantilla_single_full.ini'
$tplGeneticFW   = Join-Path $tplDir 'plantilla_genetica_fw50.ini'
$tplBrute       = Join-Path $tplDir 'plantilla_brute.ini'
$tplAllSym      = Join-Path $tplDir 'plantilla_all_symbols.ini'
$tplVisual      = Join-Path $tplDir 'plantilla_visual_debug.ini'

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
    Write-Host "No se encontró credencial_en_uso.json. Ejecutá .\\00_setup\\Instalador.ps1 opción 3 para marcar una instancia activa." -ForegroundColor Yellow
    exit 1
}

try { $cred = Get-Content $credPath -Raw | ConvertFrom-Json } catch {
    Write-Host "No se pudo leer ${credPath}: $($_)" -ForegroundColor Red
    exit 1
}

$terminalExe = $cred.terminal_exe
if (-not $terminalExe -or -not (Test-Path $terminalExe)) {
    Write-Host "terminal_exe no está definido o no existe. Reejecutá .\\00_setup\\Instalador.ps1 opción 3." -ForegroundColor Red
    exit 1
}

$presetsDir = Join-Path $cred.ruta_instancia 'instalacion/MQL5/Presets'
$testerDir  = Join-Path $cred.ruta_instancia 'instalacion/MQL5/Profiles/Tester'

if (-not (Test-Path $configPath)) {
    Write-Host "No se encontró $configPath. Asegurate de tener plantilla_funcional.ini en Tools/EXEC-INI." -ForegroundColor Red
    exit 1
}

$eaDir = Join-Path $cred.ruta_instancia 'instalacion/MQL5/Experts/Ea_Studio'
if (-not (Test-Path $eaDir)) {
    Write-Host "No se encontró la carpeta de EAs en $eaDir. Revisa la instancia o compila primero." -ForegroundColor Red
    exit 1
}

$eas = Get-ChildItem -Path $eaDir -Filter *.ex5 -File | Sort-Object Name
if (-not $eas) {
    Write-Host "No hay .ex5 en $eaDir. Compilá un EA con Compilador.ps1 antes de backtestear." -ForegroundColor Yellow
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
$eaNameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($chosen.Name)

Write-Host "" -ForegroundColor Cyan
$modesOrdered = @(
    @{ Key="single_test";    Label="single_test";            Desc="Backtest sin optimización (6M o 1A)" },
    @{ Key="genetica";       Label="genetica";               Desc="Optimización genética (Optimization=2)" },
    @{ Key="single_full";    Label="single_full";            Desc="Backtest largo (6M/1/2/3/5 años), sin optimización" },
    @{ Key="genetica_fw50";  Label="genetica_fw50";          Desc="Genética + forward 50/50 (Optimization=2, ForwardMode=1)" },
    @{ Key="brute";          Label="brute (.set acotado)";   Desc="Opt=1 completa; pocos rangos Y" },
    @{ Key="all_symbols";    Label="all_symbols";            Desc="Optimización multi-símbolo (Optimization=3)" },
    @{ Key="visual_debug";   Label="visual_debug";           Desc="10d, TICK, Visual=1 para depurar" }
)

Write-Host "Elegí modo:" -ForegroundColor Cyan
$idx=1
foreach($m in $modesOrdered){
    Write-Host ("  [{0}] {1} - {2}" -f $idx, $m.Label, $m.Desc)
    $idx++
}
$modeInput = Read-Host "Ingresá número o nombre de modo"
$modeNorm = $modeInput.Trim().ToLower()
if($modeNorm -match '^\d+$'){
    $num = [int]$modeNorm
    if($num -lt 1 -or $num -gt $modesOrdered.Count){
        Write-Host "Número de modo inválido." -ForegroundColor Red
        exit 1
    }
    $modeNorm = $modesOrdered[$num-1].Key
} else {
    $match = $modesOrdered | Where-Object { $_.Key -eq $modeNorm }
    if(-not $match){
        Write-Host "Modo inválido." -ForegroundColor Red
        exit 1
    }
}
Write-Host ("MODO SELECCIONADO: {0}" -f $modeNorm.ToUpper()) -ForegroundColor Cyan

# Defaults
$tplToUse        = $tplSingleTest
$setName         = ""
$reportBase      = "report\report_single_test__$eaNameNoExt"
$optimizationVal = ""
$forwardModeVal  = ""
$visualVal       = "0"
$rangeOverride   = $null
$modelOverride   = $null

switch ($modeNorm) {
    "single_test" {
        $tplToUse       = $tplSingleTest
        $reportBase     = "report\report_single_test__$eaNameNoExt"
    }

    "genetica" {
        $tplToUse        = $tplGenetic
        $setName         = "$eaNameNoExt.set"
        $optimizationVal = "2"   # genética (según mapping solicitado)
        $reportBase      = "report\report_genetic__$eaNameNoExt"
    }

    "single_full" {
        $tplToUse       = $tplSingleFull
        $reportBase     = "report\report_single_full__$eaNameNoExt"
    }

    "genetica_fw50" {
        $tplToUse        = $tplGeneticFW
        $setName         = "$eaNameNoExt.set"
        $optimizationVal = "2"   # genética + forward
        $forwardModeVal  = "1"   # 50/50 split
        $reportBase      = "report\report_geneticfw__$eaNameNoExt"
    }

    "brute" {
        $tplToUse        = $tplBrute
        $setName         = "$eaNameNoExt.set"
        $optimizationVal = "1"   # slow completa (mapping solicitado)
        $reportBase      = "report\report_brute__$eaNameNoExt"
    }

    "all_symbols" {
        $tplToUse        = $tplAllSym
        $setName         = "$eaNameNoExt.set"
        $optimizationVal = "3"   # all symbols in market watch
        $reportBase      = "report\report_all_symbols__$eaNameNoExt"
    }

    "visual_debug" {
        $tplToUse        = $tplVisual
        $visualVal       = "1"
        $modelOverride   = 0     # Every tick
        $rangeOverride   = "TEST"
        $reportBase      = "report\report_visual__$eaNameNoExt"
    }

    default {
        Write-Host "Modo inválido. Usa: single_test | genetica | single_full | genetica_fw50 | brute | all_symbols | visual_debug" -ForegroundColor Red
        exit 1
    }
}

if (-not (Test-Path $tplToUse)) {
    Write-Host "No encontré la plantilla para modo $modeNorm en $tplToUse. Revisá B_Plantillas." -ForegroundColor Red
    exit 1
}

# Preparar preset para modos con optimización
$modesNeedPreset = @("genetica","genetica_fw50","brute","all_symbols")
if($modesNeedPreset -contains $modeNorm){
    if(-not (Test-Path $presetsDir)){
        try {
            New-Item -ItemType Directory -Path $presetsDir -Force | Out-Null
            Write-Host "Creada carpeta de presets: $presetsDir" -ForegroundColor DarkGray
        } catch {
            Write-Host ("No se pudo crear carpeta de presets en {0}: {1}" -f $presetsDir, $_) -ForegroundColor Red
            exit 1
        }
    }
    $presetPath = Join-Path $presetsDir "$eaNameNoExt.set"
    if(-not (Test-Path $testerDir)){
        try { New-Item -ItemType Directory -Path $testerDir -Force | Out-Null } catch {}
    }
    $testerSetPath = Join-Path $testerDir "$eaNameNoExt.set"
    $skipCopy = $false

    if(-not (Test-Path $presetPath)){
        if(Test-Path $testerSetPath){
            $firstLine = Get-Content -Path $testerSetPath -First 1 -ErrorAction SilentlyContinue
            if($firstLine -like ";preset creado por agentes, alojado por M-Tester*"){
                Write-Host "Preset ya está en Tester con comentario; usando el existente." -ForegroundColor DarkGray
                $skipCopy = $true
            }
        }
        if(-not $skipCopy){
            Write-Host "Falta preset requerido en $presetPath. Crealo en MQL5/Presets y reintenta." -ForegroundColor Red
            exit 1
        }
    }
    if(-not $skipCopy){
        try {
            $presetContent = Get-Content -Raw $presetPath -ErrorAction Stop
            $commentLine   = ";preset creado por agentes, alojado por M-Tester"
            $outContent    = $commentLine + "`r`n" + $presetContent
            Set-Content -Path $testerSetPath -Value $outContent -Encoding UTF8
            Remove-Item -Path $presetPath -Force
            Write-Host "Preset movido a Tester: $presetPath -> $testerSetPath (comentado)" -ForegroundColor DarkGray
        } catch {
            Write-Host "No se pudo mover el preset a Tester: $($_)" -ForegroundColor Red
            exit 1
        }
    }
}

# Reemplaza placeholders en todas las plantillas (credenciales + EA) para mantenerlas al día
$templates = @($tplSingleTest, $tplGenetic, $tplForward, $tplSingleFull, $tplGeneticFW, $tplBrute, $tplAllSym, $tplVisual)
foreach($tpl in $templates){
    if(-not (Test-Path $tpl)) { continue }
    $contentTpl = Get-Content $tpl -Raw
    $contentTpl = $contentTpl -replace '__LOGIN__',    [regex]::Escape($cred.credencial.cuenta)
    $contentTpl = $contentTpl -replace '__PASSWORD__', [regex]::Escape($cred.credencial.password)
    $contentTpl = $contentTpl -replace '__SERVER__',   [regex]::Escape($cred.credencial.servidor)
    $contentTpl = $contentTpl -replace '__EA_NAME__',  [regex]::Escape($eaNameNoExt)

    if($tpl -eq $tplSingleTest){
        $contentTpl = $contentTpl -replace '(?m)^ExpertParameters=.*$', 'ExpertParameters='
        $contentTpl = $contentTpl -replace '(?m)^Optimization=.*$', 'Optimization='
        $contentTpl = $contentTpl -replace '(?m)^Report=.*$', "Report=report\report_single_test__$eaNameNoExt"
    } elseif($tpl -eq $tplGenetic){
        $contentTpl = $contentTpl -replace '(?m)^ExpertParameters=.*$', "ExpertParameters=$eaNameNoExt.set"
        $contentTpl = $contentTpl -replace '(?m)^Report=.*$', "Report=report\report_genetic__$eaNameNoExt"
    } elseif($tpl -eq $tplForward){
        $contentTpl = $contentTpl -replace '(?m)^ExpertParameters=.*$', "ExpertParameters=$eaNameNoExt.set"
        $contentTpl = $contentTpl -replace '(?m)^Report=.*$', "Report=report\report_forward__$eaNameNoExt"
    } elseif($tpl -eq $tplSingleFull){
        $contentTpl = $contentTpl -replace '(?m)^ExpertParameters=.*$', 'ExpertParameters='
        $contentTpl = $contentTpl -replace '(?m)^Optimization=.*$', 'Optimization='
        $contentTpl = $contentTpl -replace '(?m)^Report=.*$', "Report=report\report_single_full__$eaNameNoExt"
    } else {
        $contentTpl = $contentTpl -replace '(?m)^ExpertParameters=.*$', "ExpertParameters=$eaNameNoExt.set"
    }

    $contentTpl = $contentTpl -replace '(?m)^Report=(.+?)(?:\.htm|\.html|\.xml)?\s*$', 'Report=$1'
    $contentTpl = $contentTpl -replace '(?m)^Expert=.*$', "Expert=Ea_Studio\$eaNameNoExt.ex5"
    Set-Content -Path $tpl -Value $contentTpl -Encoding UTF8
}

# --- Preguntas de rango temporal, timeframe, símbolo y puerto ---
$endDateFixed = [datetime]"2026-01-01"
$rangeChoice = $null
if($rangeOverride){
    $rangeChoice = $rangeOverride.ToString().ToUpper()
} else {
    if($modeNorm -eq "single_test"){
        $pattern = '^(6M|1)$'
        $prompt  = "Rango desde $($endDateFixed.ToString('yyyy.MM.dd')) hacia atrás (6M/1, Enter=1)"
    } elseif($modeNorm -eq "single_full"){
        $pattern = '^(6M|1|2|3|5)$'
        $prompt  = "Rango desde $($endDateFixed.ToString('yyyy.MM.dd')) hacia atrás (6M/1/2/3/5, Enter=1)"
    } else {
        $pattern = '^(TEST|1|2|3|5)$'
        $prompt  = "Rango desde $($endDateFixed.ToString('yyyy.MM.dd')) hacia atrás (TEST=10d/1/2/3/5, Enter=1)"
    }
    do {
        $rangeChoice = Read-Host $prompt
        if([string]::IsNullOrWhiteSpace($rangeChoice)){ $rangeChoice = '1' }
        $rangeChoice = $rangeChoice.ToUpper().Trim()
    } until ($rangeChoice -match $pattern)
}

switch ($rangeChoice) {
    "TEST" { $fromDateVal = $endDateFixed.AddDays(-10).ToString('yyyy.MM.dd') }
    "6M"   { $fromDateVal = $endDateFixed.AddMonths(-6).ToString('yyyy.MM.dd') }
    default { $fromDateVal = $endDateFixed.AddYears(-[int]$rangeChoice).ToString('yyyy.MM.dd') }
}
$toDateVal    = $endDateFixed.ToString('yyyy.MM.dd')

$rangeInfo = switch ($rangeChoice) {
    "TEST" { "TEST = últimos 10 días" }
    "6M"   { "6M = últimos 6 meses" }
    default { "$rangeChoice año(s) hacia atrás" }
}
Write-Host ("Rango aplicado: {0} -> {1} ({2})" -f $fromDateVal, $toDateVal, $rangeInfo) -ForegroundColor DarkGray

$tfPrompt = Read-Host "Timeframe (M1/M5/M15/M30/H1/H4/D1, default H1)"
if([string]::IsNullOrWhiteSpace($tfPrompt)){ $tfPrompt = "H1" }
$tfPrompt = $tfPrompt.Trim().ToUpper()
$validTF = @("M1","M5","M15","M30","H1","H4","D1")
if(-not ($validTF -contains $tfPrompt)){ $tfPrompt = "H1" }

if($modelOverride -ne $null){
    $modelVal = $modelOverride
    $modelLabel = if($modelVal -eq 0){ "TICK (Every tick)" } else { "OHLC M1" }
    Write-Host "Modelo fijado por el modo ($modeNorm): $modelLabel" -ForegroundColor DarkGray
} else {
    do {
        $modelPrompt = Read-Host "Modelo de ticks (Enter=OHLC M1 / TICK=Every tick)"
        if([string]::IsNullOrWhiteSpace($modelPrompt)){ $modelPrompt = '1M' }
        $modelPrompt = $modelPrompt.Trim().ToUpper()
    } until ($modelPrompt -match '^(TICK|OHLC|1M)$')
    $modelVal = if($modelPrompt -eq 'TICK'){ 0 } else { 1 }
}

$symbolPrompt = Read-Host "Símbolo (Enter para EURUSD)"
if([string]::IsNullOrWhiteSpace($symbolPrompt)){ $symbolPrompt = "EURUSD" }
$symbolPrompt = $symbolPrompt.Trim().ToUpper()

$portPrompt = Read-Host "Puerto para esta sesión (default 3000)"
if(-not ($portPrompt -match '^\d+$')){ $portPrompt = 3000 }

# Tomamos la plantilla específica elegida y la volcamos a plantilla_funcional.ini
$finalContent = Get-Content $tplToUse -Raw
$finalContent | Set-Content -Path $configPath -Encoding UTF8

$lines = Get-Content $configPath
$lines = Update-IniValue -Lines $lines -Section "Common" -Key "Login"    -Value ($cred.credencial.cuenta)
$lines = Update-IniValue -Lines $lines -Section "Common" -Key "Password" -Value ($cred.credencial.password)
$lines = Update-IniValue -Lines $lines -Section "Common" -Key "Server"   -Value ($cred.credencial.servidor)
$lines = Update-IniValue -Lines $lines -Section "Tester" -Key "Expert"   -Value $relativeExpert
$lines = Update-IniValue -Lines $lines -Section "Tester" -Key "ExpertParameters" -Value $setName
$lines = Update-IniValue -Lines $lines -Section "Tester" -Key "Report"   -Value $reportBase
$lines = Update-IniValue -Lines $lines -Section "Tester" -Key "Optimization" -Value $optimizationVal
$lines = Update-IniValue -Lines $lines -Section "Tester" -Key "ForwardMode"   -Value $forwardModeVal
$lines = Update-IniValue -Lines $lines -Section "Tester" -Key "Visual"   -Value $visualVal
$lines = Update-IniValue -Lines $lines -Section "Tester" -Key "Model"    -Value $modelVal
$lines = Update-IniValue -Lines $lines -Section "Tester" -Key "FromDate" -Value $fromDateVal
$lines = Update-IniValue -Lines $lines -Section "Tester" -Key "ToDate"   -Value $toDateVal
$lines = Update-IniValue -Lines $lines -Section "Tester" -Key "Period"   -Value $tfPrompt
$lines = Update-IniValue -Lines $lines -Section "Tester" -Key "Symbol"   -Value $symbolPrompt
$lines = Update-IniValue -Lines $lines -Section "Tester" -Key "Port"     -Value $portPrompt
$lines = Update-IniValue -Lines $lines -Section "StartUp" -Key "Period"  -Value $tfPrompt
$lines = Update-IniValue -Lines $lines -Section "StartUp" -Key "Symbol"  -Value $symbolPrompt
$lines = Update-IniValue -Lines $lines -Section "StartUp" -Key "ExpertParameters" -Value $setName

$lines | Set-Content -Path $configPath -Encoding UTF8

$reportDir = Join-Path ([IO.Path]::GetDirectoryName($terminalExe)) (Split-Path $reportBase -Parent)
if(-not (Test-Path $reportDir)){
    try {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
        Write-Host "Creada carpeta de reportes: $reportDir" -ForegroundColor DarkGray
    } catch {
        Write-Host ("No se pudo crear carpeta de reportes en {0}: {1}" -f $reportDir, $_) -ForegroundColor Yellow
    }
}

$summary = @(
    "Modo: $modeNorm",
    "Símbolo: $symbolPrompt",
    "Timeframe: $tfPrompt",
    "Modelo: $(if($modelVal -eq 0){'TICK'}else{'OHLC 1M'})",
    "Rango: $fromDateVal -> $toDateVal",
    "Optimization: $optimizationVal ForwardMode: $forwardModeVal Visual: $visualVal",
    "Report: $reportBase",
    "Port: $portPrompt"
) -join " | "
Write-Host $summary -ForegroundColor DarkGray

$args = @("/portable", "/config:$configPath")
Write-Host "`nLanzando tester con:" -ForegroundColor Cyan
Write-Host "  Terminal: $terminalExe" -ForegroundColor Gray
Write-Host "  Config:   $configPath" -ForegroundColor Gray
Write-Host "  Expert:   $relativeExpert" -ForegroundColor Gray

Start-Process -FilePath $terminalExe -ArgumentList $args -Wait
