# Helper to list MT instances inside 00_setup/Instancias and bootstrap a portable one if none exists.
# Usage: run from Desktop\.eastudio inside VS Code/Cursor terminal. Optional: -InstallerPath "C:\path\mt5setup.exe"

param(
    [string]$InstallerPath
)

$expectedRoot     = Join-Path $env:USERPROFILE 'Desktop\.eastudio'
$instanciasRoot   = Join-Path $expectedRoot '00_setup/Instancias'
$defaultInstaller = Join-Path $expectedRoot '00_setup/bin/mt5setup.exe'
$dataRoot         = Join-Path $expectedRoot 'DATA'
$resultadosRoot   = Join-Path $expectedRoot 'RESULTADOS'

function Get-CredentialKeys {
    param($creds)
    if (-not $creds) { return @() }
    if ($creds -is [hashtable]) { return $creds.Keys }
    if ($creds.PSObject -and $creds.PSObject.Properties){ return $creds.PSObject.Properties.Name }
    return @()
}

function New-LinkForce {
    param($Path, $Target)
    if (Test-Path $Path) { Remove-Item -Path $Path -Force -Recurse -ErrorAction SilentlyContinue }
    try { New-Item -ItemType SymbolicLink -Path $Path -Target $Target -ErrorAction Stop | Out-Null }
    catch { New-Item -ItemType Junction -Path $Path -Target $Target -ErrorAction SilentlyContinue | Out-Null }
}

function Get-NextInstanceName {
    $dirs = Get-ChildItem -Path $instanciasRoot -Directory -ErrorAction SilentlyContinue
    $nums = @()
    foreach($d in $dirs){
        if($d.Name -match '^instancia_(\d+)$'){ $nums += [int]$matches[1] }
    }
    if(-not $nums){ return 'instancia_01' }
    $next = ([int]($nums | Measure-Object -Maximum).Maximum) + 1
    return ('instancia_{0:D2}' -f $next)
}

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

function Get-Instances {
    param($creds)
    $dirs = Get-ChildItem -Path $instanciasRoot -Directory -ErrorAction SilentlyContinue
    foreach ($d in $dirs) {
        $instalacion   = Join-Path $d.FullName 'instalacion'
        $portableExe   = Get-ChildItem -Path $instalacion -Filter 'terminal*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        $credPath      = Join-Path $instalacion 'credenciales.json'
        $legacyCred    = Join-Path $d.FullName 'credenciales.json'
        if(-not (Test-Path $credPath) -and (Test-Path $legacyCred)){
            try {
                if (-not (Test-Path $instalacion)) { New-Item -ItemType Directory -Path $instalacion -Force | Out-Null }
                Move-Item -Path $legacyCred -Destination $credPath -Force
            } catch {}
        }
        $hasCred       = Test-Path $credPath
        $valStr        = '-'
        if($hasCred){
            try {
                $cjson = Get-Content $credPath -Raw | ConvertFrom-Json
                if($cjson.validada -eq $true){ $valStr = 'Sí' }
                elseif($cjson.validada -eq $false){ $valStr = 'No' }
                else { $valStr = 'Pendiente' }
            } catch { $valStr = 'Pendiente' }
        }
        [pscustomobject]@{
            Instancia     = $d.Name
            Instalacion   = if (Test-Path $instalacion) {'OK'} else {'-'}
            PortableExe   = if ($portableExe) {$portableExe.Name} else {'(no exe)'}
            Credenciales  = if ($hasCred) { 'Sí' } else { 'No' }
            Validada      = $valStr
            CredPath      = $credPath
            Ruta          = $d.FullName
        }
    }
}

function Load-InstanceCred {
    param($instancePath)
    $instCred = Join-Path $instancePath 'instalacion/credenciales.json'
    $legacy   = Join-Path $instancePath 'credenciales.json'

    if (-not (Test-Path $instCred) -and (Test-Path $legacy)) {
        try {
            if (-not (Test-Path (Split-Path $instCred -Parent))) { New-Item -ItemType Directory -Path (Split-Path $instCred -Parent) -Force | Out-Null }
            Move-Item -Path $legacy -Destination $instCred -Force
        } catch {}
    }
    if (-not (Test-Path $instCred)) { return $null }
    try { return Get-Content $instCred -Raw | ConvertFrom-Json } catch { return $null }
}

function Ensure-PortableInstall {
    param($instName, $installerPath)
    $success         = $false
    $targetRoot      = Join-Path $instanciasRoot $instName
    $instalacionDir  = Join-Path $targetRoot 'instalacion'

    foreach ($d in @($targetRoot, $instalacionDir)) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }

    if (-not $installerPath -and (Test-Path $defaultInstaller)) { $installerPath = $defaultInstaller }
    if (-not $installerPath) {
        $installerPath = Read-Host "Ruta al instalador MT5/MT4 (mt5setup.exe). Enter para omitir"
    }
    if (-not $installerPath) {
        Write-Host "Instancia creada sin instalar MT. Ejecutá manualmente con /portable apuntando a $instalacionDir" -ForegroundColor Yellow
        return $false
    }
    if (-not (Test-Path $installerPath)) {
        Write-Host "No se encontró el instalador en: $installerPath" -ForegroundColor Red
        return $false
    }
    $terminalExe = Get-ChildItem -Path $instalacionDir -Filter 'terminal*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($terminalExe) {
        Write-Host "Ya existe un terminal en $instalacionDir. Se creará launcher portable." -ForegroundColor Cyan
    } else {
        Write-Host "El instalador MT5 estándar no expone portable en modo silencioso. Se abrirá la UI para que elijas la carpeta (sugerido: $instalacionDir)." -ForegroundColor Yellow
        $args = @("/dir=""$instalacionDir""")
        try {
            Start-Process -FilePath $installerPath -ArgumentList $args -Wait -ErrorAction Stop
        } catch {
            Write-Host "No se pudo lanzar el instalador. Ejecutalo manualmente y apunta a: $instalacionDir" -ForegroundColor Red
            try { Remove-Item -Path $targetRoot -Recurse -Force -ErrorAction Stop; Write-Host "Instancia eliminada: $targetRoot" -ForegroundColor Yellow } catch {}
            return $false
        }
        $terminalExe = Get-ChildItem -Path $instalacionDir -Filter 'terminal*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $terminalExe) {
            # Intentar detectar si el usuario instaló en la ruta por defecto.
            $roamingTerm = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
            $latestExe = $null
            if (Test-Path $roamingTerm) {
                $latestExe = Get-ChildItem -Path $roamingTerm -Filter 'terminal*.exe' -Recurse -ErrorAction SilentlyContinue |
                             Sort-Object LastWriteTime -Descending | Select-Object -First 1
            }
            if ($latestExe) {
                Write-Host "Parece que el instalador se ejecutó en '$($latestExe.DirectoryName)' y no en $instalacionDir." -ForegroundColor Yellow
                Write-Host "Se eliminará la instancia incompleta en $targetRoot. Reinstalá eligiendo la carpeta sugerida." -ForegroundColor Yellow
            } else {
                Write-Host "No se encontró terminal después de la instalación. Verificá la ruta." -ForegroundColor Red
                Write-Host "Se eliminará la instancia incompleta en $targetRoot." -ForegroundColor Yellow
            }
            try { Remove-Item -Path $targetRoot -Recurse -Force -ErrorAction Stop; Write-Host "Eliminado $targetRoot" -ForegroundColor Green }
            catch { Write-Host ("No se pudo eliminar {0}: {1}" -f $targetRoot, $_) -ForegroundColor Red }
            return $false
        }
    }

    # Crear acceso directo con /portable para uso desde Explorer y compatibilidad.
    $lnkPath = Join-Path $instalacionDir 'terminal_portable.lnk'
    $ws = New-Object -ComObject WScript.Shell
    $shortcut = $ws.CreateShortcut($lnkPath)
    $shortcut.TargetPath = $terminalExe.FullName
    $shortcut.Arguments  = '/portable'
    $shortcut.WorkingDirectory = $instalacionDir
    $shortcut.Save()

    # Launcher .cmd que llama directo al exe con /portable (mejor para terminal).
    $launcherCmd = Join-Path $instalacionDir 'launch_portable.cmd'
    $exeName = Split-Path $terminalExe.FullName -Leaf
    @(
        '@echo off'
        'setlocal'
        'set MT_DIR=%~dp0'
        ('start "" "%MT_DIR%{0}" /portable' -f $exeName)
    ) | Set-Content -Path $launcherCmd -Encoding ASCII

    # Lanzar una vez en portable para que genere data folder (solo si el usuario quiere).
    # Auto-launch MT en modo portable sin preguntar (antes se pedía s/n).
    $launch = 's'
    if($launch -match '^[sS]'){
        Write-Host "Abriendo MT en modo portable..." -ForegroundColor Cyan
        try {
            Start-Process -FilePath $terminalExe.FullName -WorkingDirectory $instalacionDir -ArgumentList '/portable' -ErrorAction Stop
            Start-Sleep -Seconds 4
            # Asegurar estructura MQL5/Experts/Ea_Studio y carpeta de reportes
            $mqlDir           = Join-Path $instalacionDir 'MQL5'
            $expertsDir       = Join-Path $mqlDir 'Experts'
            $eaStudioDir      = Join-Path $expertsDir 'Ea_Studio'
            $reportDir        = Join-Path $instalacionDir 'report'
            $testerProfileDir = Join-Path $instalacionDir 'MQL5/Profiles/Tester'
            $presetsDir       = Join-Path $mqlDir 'Presets'
            foreach($d in @($mqlDir, $expertsDir, $eaStudioDir, $reportDir, $testerProfileDir, $presetsDir)){
                if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
            }
            Write-Host "Estructura MQL5/Experts/Ea_Studio creada." -ForegroundColor Green
            Write-Host "Carpetas report, Profiles/Tester y Presets creadas." -ForegroundColor Green
            Write-Host "Si se abrió la ventana de MT, cerrala cuando termine de generar las carpetas." -ForegroundColor Yellow
        } catch {
            Write-Host "No se pudo lanzar el terminal en modo portable: $_" -ForegroundColor Red
        }
    }

    Write-Host "Listo. Usá launch_portable.cmd o el acceso directo terminal_portable.lnk para arrancar en modo portable." -ForegroundColor Green
    $success = $true
    return $success
}

function Build-Hub {
    param(
        [string]$instName,
        [string]$instPath
    )
    if(-not $instName -or -not $instPath){ return }

    $hubPath = Join-Path $dataRoot ("{0}_hub" -f $instName)
    if(Test-Path $hubPath){ Remove-Item -Path $hubPath -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $hubPath -Force | Out-Null

    $instalacion = Join-Path $instPath 'instalacion'
    $credPath    = Join-Path $instalacion 'credenciales.json'
    $mqlDir      = Join-Path $instalacion 'MQL5'

    $links = @(
        @{ name='credencial.json';               target=$credPath },
        # Carpeta con los .ex5 ya compilados dentro del terminal
        @{ name='Asesores_Expertos(En Terminal)'; target=Join-Path $mqlDir 'Experts/Ea_Studio' },
        @{ name='presets';                       target=Join-Path $mqlDir 'Presets' },
        @{ name='profiles_tester';               target=Join-Path $mqlDir 'Profiles/Tester' },
        @{ name='LOGS_Terminal';                 target=Join-Path $mqlDir 'Logs' },
        @{ name='LOGS_Editor';                   target=Join-Path $instalacion 'Logs' },
        @{ name='LOGS_Tester';                   target=Join-Path $instalacion 'Tester/Logs' }
    )

    foreach($l in $links){
        $p = Join-Path $hubPath $l.name
        if(Test-Path $p){ Remove-Item -Path $p -Force -Recurse -ErrorAction SilentlyContinue }
        New-LinkForce -Path $p -Target $l.target
    }

    # trace_agents: crear contenedor y symlinks a cada Agent-*/logs
    $agentsRoot = Join-Path $instalacion 'Tester'
    $hubAgents  = Join-Path $hubPath 'LOGS_Agents'
    if(Test-Path $hubAgents){ Remove-Item -Path $hubAgents -Force -Recurse -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $hubAgents -Force | Out-Null
    if(Test-Path $agentsRoot){
        Get-ChildItem -Path $agentsRoot -Directory -Filter 'Agent-*' -ErrorAction SilentlyContinue | ForEach-Object {
            $logsDir = Join-Path $_.FullName 'logs'
            if(Test-Path $logsDir){
                $linkPath = Join-Path $hubAgents $_.Name
                if(Test-Path $linkPath){ Remove-Item -Path $linkPath -Force -Recurse -ErrorAction SilentlyContinue }
                New-LinkForce -Path $linkPath -Target $logsDir
            }
        }
    }

    # En RESULTADOS, crear link a report original de la instancia activa
    try {
        if (-not (Test-Path $resultadosRoot)) { New-Item -ItemType Directory -Path $resultadosRoot -Force | Out-Null }
        # Carpetas listas para pipeline (no son symlink)
        foreach($d in @('Reportes-Analizados','Reportes-Normalizados')){
            $full = Join-Path $resultadosRoot $d
            if(-not (Test-Path $full)){ New-Item -ItemType Directory -Path $full -Force | Out-Null }
        }
        # Enlace a reportes crudos
        $linkReportes = Join-Path $resultadosRoot 'Reportes-SinProcesar'
        if (Test-Path $linkReportes) { Remove-Item -Path $linkReportes -Force -Recurse -ErrorAction SilentlyContinue }
        New-LinkForce -Path $linkReportes -Target (Join-Path $instalacion 'report')
    } catch {}
}

Assert-Location

# Asegurar carpeta DATA en raíz
if (-not (Test-Path $dataRoot)) {
    try { New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null } catch {}
}
if (-not (Test-Path $resultadosRoot)) {
    try { New-Item -ItemType Directory -Path $resultadosRoot -Force | Out-Null } catch {}
}
# Asegurar .vscode/tasks.json con atajos básicos si no existe
$vscodeDir   = Join-Path $expectedRoot '.vscode'
$tasksPath   = Join-Path $vscodeDir 'tasks.json'
$keysPath    = Join-Path $vscodeDir 'keybindings.json'
if (-not (Test-Path $vscodeDir)) {
    try { New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null } catch {}
}
if (-not (Test-Path $tasksPath)) {
    $tasksContent = @'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Normalizador (reports → Reportes-Normalizados)",
      "type": "shell",
      "command": "python",
      "args": ["script/A_Normalizador_Master.py"],
      "group": "build",
      "presentation": { "reveal": "always", "panel": "dedicated" },
      "problemMatcher": []
    },
    {
      "label": "Analista (Reportes-Analizados)",
      "type": "shell",
      "command": "python",
      "args": ["script/B_Analista_Profesional.py"],
      "group": "build",
      "presentation": { "reveal": "always", "panel": "dedicated" },
      "problemMatcher": []
    },
    {
      "label": "Limpiar RESULTADOS",
      "type": "shell",
      "command": "python",
      "args": ["script/Clear.py"],
      "group": "none",
      "presentation": { "reveal": "always", "panel": "dedicated" },
      "problemMatcher": []
    }
  ]
}
'@
    try { Set-Content -Path $tasksPath -Value $tasksContent -Encoding UTF8 }
    catch { Write-Host "No se pudo crear .vscode/tasks.json: $_" -ForegroundColor Yellow }
}
# Crear keybindings solo si no existe para no pisar ajustes del usuario
if (-not (Test-Path $keysPath)) {
    $keysContent = @'
[
  {
    "key": "alt+t",
    "command": "workbench.action.tasks.runTask",
    "when": "editorTextFocus || terminalFocus || explorerViewletVisible"
  },
  {
    "key": "ctrl+alt+shift+n",
    "command": "workbench.action.tasks.runTask",
    "args": "Normalizador (reports → Reportes-Normalizados)"
  },
  {
    "key": "ctrl+alt+shift+a",
    "command": "workbench.action.tasks.runTask",
    "args": "Analista (Reportes-Analizados)"
  },
  {
    "key": "ctrl+alt+shift+c",
    "command": "workbench.action.tasks.runTask",
    "args": "Limpiar RESULTADOS"
  }
]
'@
    try {
        Set-Content -Path $keysPath -Value $keysContent -Encoding UTF8
        Write-Host "Atajos Ctrl+Alt+Shift+N/A/C creados en .vscode/keybindings.json." -ForegroundColor Green
    } catch {
        Write-Host "No se pudo crear .vscode/keybindings.json: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host ".vscode/keybindings.json ya existe; no se modificó. Si querés otras teclas, edita manualmente ese archivo." -ForegroundColor DarkGray
}
$instances = Get-Instances -creds $null

if (-not $instances) {
    Write-Host "No hay instancias. Podés crear la primera instalación portable ahora." -ForegroundColor Yellow
    $nextName = 'instancia_{0:D2}' -f 1
    $nameInput = Read-Host "Nombre para la nueva instancia (ENTER usa $nextName)"
    if (-not $nameInput) { $nameInput = $nextName }
    if(Ensure-PortableInstall -instName $nameInput -installerPath $InstallerPath){
        Write-Host "Listo. Nueva carpeta: $(Join-Path $instanciasRoot $nameInput)" -ForegroundColor Green
    } else {
        Write-Host "Instalación cancelada o fuera de la ruta esperada. Vuelve a ejecutar y elige la carpeta sugerida." -ForegroundColor Yellow
    }
    exit 0
}

Write-Host "Instancias detectadas en 00_setup/Instancias:`n" -ForegroundColor Cyan
$instances | Format-Table -AutoSize

$actionPrompt = @"
Elige acción:
  [1] Crear nueva instancia portable
  [2] Asignar credenciales a instancia
  [3] Elegir credencial activa
  [4] Reasignar credenciales no validadas
  [ENTER] Salir
"@
$action = Read-Host $actionPrompt
if ($action -eq '1') {
    $newName = Read-Host "Nombre para la nueva instancia (ENTER usa siguiente correlativo)"
    if(-not $newName){ $newName = Get-NextInstanceName }
    if(Ensure-PortableInstall -instName $newName -installerPath $InstallerPath){
        Write-Host "Listo. Nueva carpeta: $(Join-Path $instanciasRoot $newName)" -ForegroundColor Green
    } else {
        Write-Host "Instalación cancelada o fuera de la ruta esperada. Vuelve a ejecutar y elige la carpeta sugerida." -ForegroundColor Yellow
    }
    exit 0
}
elseif ($action -eq '2') {
    # instancias sin credenciales.json
    $sinCred = @($instances | Where-Object { $_.Credenciales -eq 'No' })
    if (-not $sinCred) {
        Write-Host "Todas las instancias ya tienen credenciales.json (en instalacion/). Nada que hacer." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "`nInstancias sin credenciales:" -ForegroundColor Cyan
    $i=1; foreach($inst in $sinCred){ Write-Host ("[{0}] {1} -> {2}" -f $i,$inst.Instancia,$inst.Ruta); $i++ }
    $sel = Read-Host "Elegí número de instancia"
    if(-not ($sel -match '^\d+$') -or [int]$sel -lt 1 -or [int]$sel -gt $sinCred.Count){
        Write-Host "Selección inválida." -ForegroundColor Red
        exit 1
    }
    $chosen = $sinCred[[int]$sel - 1]
    $cuenta = Read-Host "Número de cuenta"
    $pass   = Read-Host "Contraseña"
    $server = Read-Host "Servidor"
    $credObj = [pscustomobject]@{
        cuenta      = $cuenta
        password    = $pass
        servidor    = $server
        fecha_guardado = (Get-Date).ToString('s')
        validada    = $false
        fecha_validacion = $null
        detalle_validacion = $null
    }
    $instalacionDir = Join-Path $chosen.Ruta 'instalacion'
    if (-not (Test-Path $instalacionDir)) { New-Item -ItemType Directory -Path $instalacionDir -Force | Out-Null }
    $credPathNew = Join-Path $instalacionDir 'credenciales.json'
    $credObj | ConvertTo-Json | Set-Content -Path $credPathNew -Encoding UTF8
    # limpiar legacy si existiera
    $credLegacy = Join-Path $chosen.Ruta 'credenciales.json'
    if(Test-Path $credLegacy){ Remove-Item -Path $credLegacy -Force -ErrorAction SilentlyContinue }
    Write-Host "Credenciales guardadas en $credPathNew" -ForegroundColor Green
    $terminalExe    = Get-ChildItem -Path $instalacionDir -Filter 'terminal*.exe'   -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($terminalExe) {
        $openTerm = Read-Host "¿Abrir MT en modo portable para ingresar y validar la credencial ahora? (s/n)"
        if ($openTerm -match '^[sS]') {
            Write-Host "Abriendo MT en modo portable para validación..." -ForegroundColor Cyan
            try {
                $mtProc = Start-Process -FilePath $terminalExe.FullName -ArgumentList '/portable' -WorkingDirectory $instalacionDir -PassThru -ErrorAction Stop
            } catch {
                Write-Host "No se pudo abrir el terminal en modo portable: $_" -ForegroundColor Red
            }

            # Espera y lee logs para detectar autorización
            $logsDir = Join-Path $instalacionDir 'logs'
            $validated = $false
            $failed = $false
            $detalle = $null
            if(Test-Path $logsDir){
                $deadline = (Get-Date).AddMinutes(5)
                while((Get-Date) -lt $deadline -and -not ($validated -or $failed)){
                    $logFile = Get-ChildItem -Path $logsDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
                               Where-Object { $_.Name -ne 'metaeditor.log' } |
                               Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    if($logFile){
                        try{
                            $lines = Get-Content -Path $logFile.FullName -Tail 400 -ErrorAction SilentlyContinue
                        } catch { $lines = @() }
                        foreach($ln in $lines){
                            if($ln -match "authorized on"){
                                $validated = $true
                                $detalle = $ln.Trim()
                                break
                            }
                            if($ln -match "authorization on .*failed"){
                                $failed = $true
                                $detalle = $ln.Trim()
                                break
                            }
                        }
                    }
                    if(-not ($validated -or $failed)){ Start-Sleep -Seconds 5 }
                }
            }

            if($validated){
                Write-Host "Credencial validada: $detalle" -ForegroundColor Green
                $credObj.validada = $true
                $credObj.fecha_validacion = (Get-Date).ToString('s')
                $credObj.detalle_validacion = $detalle
            } elseif($failed){
                Write-Host "Credencial inválida: $detalle" -ForegroundColor Red
                $credObj.validada = $false
                $credObj.fecha_validacion = (Get-Date).ToString('s')
                $credObj.detalle_validacion = $detalle
            } else {
                Write-Host "No se pudo confirmar la validación en el log dentro del tiempo de espera." -ForegroundColor Yellow
                $credObj.detalle_validacion = "pendiente"
            }

            # Actualizar credenciales con estado de validación
            $credObj | ConvertTo-Json | Set-Content -Path $credPathNew -Encoding UTF8
            Write-Host "Estado de validación guardado en $credPathNew" -ForegroundColor DarkGray
        }
    }
    exit 0
}
elseif ($action -eq '3') {
    $conCred = @($instances | Where-Object { $_.Credenciales -eq 'Sí' -and $_.Validada -eq 'Sí' })
    if (-not $conCred) {
        Write-Host "No hay instancias con credenciales válidas en instalacion/. Valida primero (opción 4) o asigna (opción 2)." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "`nInstancias con credenciales disponibles:" -ForegroundColor Cyan
    $i=1; foreach($inst in $conCred){
        $c = Load-InstanceCred $inst.Ruta
        $cuenta = if($c){$c.cuenta}else{'(sin dato)'}
        $srv    = if($c){$c.servidor}else{'(sin dato)'}
        Write-Host ("[{0}] {1} -> cuenta {2}, servidor {3}" -f $i, $inst.Instancia, $cuenta, $srv)
        $i++
    }
    $sel = Read-Host "Elegí número de instancia para credencial activa"
    if(-not ($sel -match '^\d+$') -or [int]$sel -lt 1 -or [int]$sel -gt $conCred.Count){
        Write-Host "Selección inválida." -ForegroundColor Red
        exit 1
    }
    $chosen = $conCred[[int]$sel - 1]
    $c = Load-InstanceCred $chosen.Ruta
    if (-not $c) {
        Write-Host "No se pudo leer credenciales de la instancia elegida." -ForegroundColor Red
        exit 1
    }
    $instalacionDir = Join-Path $chosen.Ruta 'instalacion'
    $terminalExe    = Get-ChildItem -Path $instalacionDir -Filter 'terminal*.exe'   -ErrorAction SilentlyContinue | Select-Object -First 1
    $metaeditorExe  = Get-ChildItem -Path $instalacionDir -Filter 'metaeditor*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    $mqlDir         = Join-Path $instalacionDir 'MQL5'
    $expertsDir     = Join-Path $mqlDir 'Experts'
    $eaStudioDir    = Join-Path $expertsDir 'Ea_Studio'
    $presetsDir     = Join-Path $mqlDir 'Presets'
    $profilesTester = Join-Path $mqlDir 'Profiles/Tester'
    $reportsDir     = Join-Path $instalacionDir 'report'
    $logsTerminal   = Join-Path $mqlDir 'Logs'
    $logsEditor     = Join-Path $instalacionDir 'Logs'
    $logsTester     = Join-Path $instalacionDir 'Tester/Logs'
    $agentsRoot     = Join-Path $instalacionDir 'Tester'
    $outPath = Join-Path $instanciasRoot 'credencial_en_uso.json'
    $outObj = [pscustomobject]@{
        instancia = $chosen.Instancia
        ruta_instancia = $chosen.Ruta
        credencial = $c
        terminal_exe = if($terminalExe){ $terminalExe.FullName } else { $null }
        metaeditor_exe = if($metaeditorExe){ $metaeditorExe.FullName } else { $null }
        rutas = [pscustomobject]@{
            instalacion     = $instalacionDir
            mql5            = $mqlDir
            experts         = $expertsDir
            ea_studio       = $eaStudioDir
            presets         = $presetsDir
            profiles_tester = $profilesTester
            reports         = $reportsDir
            logs_terminal   = $logsTerminal
            logs_editor     = $logsEditor
            logs_tester     = $logsTester
            tester_agents   = $agentsRoot
        }
        fecha_seleccion = (Get-Date).ToString('s')
    }
    $outObj | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding UTF8
    Write-Host "Credencial activa guardada en $outPath" -ForegroundColor Green
    Build-Hub -instName $chosen.Instancia -instPath $chosen.Ruta
    # Mantener solo el hub de la credencial activa para evitar confusión
    try {
        $expectedHub = ('{0}_hub' -f $chosen.Instancia)
        Get-ChildItem -Path $dataRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like '*_hub' -and $_.Name -ne $expectedHub } |
            ForEach-Object {
                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        # Limpiar Reportes-SinProcesar si apunta a otra instancia
        $linkReportes = Join-Path $resultadosRoot 'Reportes-SinProcesar'
        if (Test-Path $linkReportes) {
            Remove-Item -Path $linkReportes -Recurse -Force -ErrorAction SilentlyContinue
        }
        # Asegurar carpetas base en RESULTADOS (sin symlink)
        foreach($d in @('Reportes-Analizados','Reportes-Normalizados')){
            $full = Join-Path $resultadosRoot $d
            if(-not (Test-Path $full)){ New-Item -ItemType Directory -Path $full -Force | Out-Null }
        }
        # Recrear link a reports de la instancia activa
        New-LinkForce -Path $linkReportes -Target (Join-Path $instalacionDir 'report')
    } catch {}
    exit 0
}
elseif ($action -eq '4') {
    # instancias con credenciales no validadas
    $noVal = @($instances | Where-Object { $_.Credenciales -eq 'Sí' -and $_.Validada -ne 'Sí' })
    if (-not $noVal) {
        Write-Host "No hay instancias con credenciales pendientes o fallidas." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "`nInstancias con credenciales no validadas:" -ForegroundColor Cyan
    $i=1; foreach($inst in $noVal){
        $c = Load-InstanceCred $inst.Ruta
        $cuenta = if($c){$c.cuenta}else{'(sin dato)'}
        $srv    = if($c){$c.servidor}else{'(sin dato)'}
        $estado = if($c){ if($c.validada -eq $true){'Sí'} elseif($c.validada -eq $false){'No'} else {'Pendiente'} } else {'(N/A)'}
        Write-Host ("[{0}] {1} -> cuenta {2}, servidor {3}, validada={4}" -f $i, $inst.Instancia, $cuenta, $srv, $estado)
        $i++
    }
    $sel = Read-Host "Elegí número de instancia para reasignar credencial"
    if(-not ($sel -match '^\d+$') -or [int]$sel -lt 1 -or [int]$sel -gt $noVal.Count){
        Write-Host "Selección inválida." -ForegroundColor Red
        exit 1
    }
    $chosen = $noVal[[int]$sel - 1]
    $cuenta = Read-Host "Número de cuenta"
    $pass   = Read-Host "Contraseña"
    $server = Read-Host "Servidor"
    $credObj = [pscustomobject]@{
        cuenta      = $cuenta
        password    = $pass
        servidor    = $server
        fecha_guardado = (Get-Date).ToString('s')
        validada    = $false
        fecha_validacion = $null
        detalle_validacion = $null
    }
    $instalacionDir = Join-Path $chosen.Ruta 'instalacion'
    if (-not (Test-Path $instalacionDir)) { New-Item -ItemType Directory -Path $instalacionDir -Force | Out-Null }
    $credPathNew = Join-Path $instalacionDir 'credenciales.json'
    $credObj | ConvertTo-Json | Set-Content -Path $credPathNew -Encoding UTF8
    Write-Host "Credenciales guardadas en $credPathNew" -ForegroundColor Green
    $terminalExe    = Get-ChildItem -Path $instalacionDir -Filter 'terminal*.exe'   -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($terminalExe) {
        $openTerm = Read-Host "¿Abrir MT en modo portable para ingresar y validar la credencial ahora? (s/n)"
        if ($openTerm -match '^[sS]') {
            Write-Host "Abriendo MT en modo portable para validación..." -ForegroundColor Cyan
            try {
                $mtProc = Start-Process -FilePath $terminalExe.FullName -ArgumentList '/portable' -WorkingDirectory $instalacionDir -PassThru -ErrorAction Stop
            } catch {
                Write-Host "No se pudo abrir el terminal en modo portable: $_" -ForegroundColor Red
            }

            # Espera y lee logs para detectar autorización
            $logsDir = Join-Path $instalacionDir 'logs'
            $validated = $false
            $failed = $false
            $detalle = $null
            if(Test-Path $logsDir){
                $deadline = (Get-Date).AddMinutes(5)
                while((Get-Date) -lt $deadline -and -not ($validated -or $failed)){
                    $logFile = Get-ChildItem -Path $logsDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
                               Where-Object { $_.Name -ne 'metaeditor.log' } |
                               Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    if($logFile){
                        try{
                            $lines = Get-Content -Path $logFile.FullName -Tail 400 -ErrorAction SilentlyContinue
                        } catch { $lines = @() }
                        foreach($ln in $lines){
                            if($ln -match "authorized on"){
                                $validated = $true
                                $detalle = $ln.Trim()
                                break
                            }
                            if($ln -match "authorization on .*failed"){
                                $failed = $true
                                $detalle = $ln.Trim()
                                break
                            }
                        }
                    }
                    if(-not ($validated -or $failed)){ Start-Sleep -Seconds 5 }
                }
            }

            if($validated){
                Write-Host "Credencial validada: $detalle" -ForegroundColor Green
                $credObj.validada = $true
                $credObj.fecha_validacion = (Get-Date).ToString('s')
                $credObj.detalle_validacion = $detalle
            } elseif($failed){
                Write-Host "Credencial inválida: $detalle" -ForegroundColor Red
                $credObj.validada = $false
                $credObj.fecha_validacion = (Get-Date).ToString('s')
                $credObj.detalle_validacion = $detalle
            } else {
                Write-Host "No se pudo confirmar la validación en el log dentro del tiempo de espera." -ForegroundColor Yellow
                $credObj.detalle_validacion = "pendiente"
            }

            # Actualizar credenciales con estado de validación
            $credObj | ConvertTo-Json | Set-Content -Path $credPathNew -Encoding UTF8
            Write-Host "Estado de validación guardado en $credPathNew" -ForegroundColor DarkGray
        }
    }
    exit 0
}
else {
    Write-Host "Sin cambios." -ForegroundColor Yellow
    exit 0
}
