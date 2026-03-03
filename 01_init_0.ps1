# Helper to list MT instances inside 00_setup/Instancias and bootstrap a portable one if none exists.
# Usage: run from Desktop\.eastudio inside VS Code/Cursor terminal. Optional: -InstallerPath "C:\path\mt5setup.exe"

param(
    [string]$InstallerPath
)

$expectedRoot   = Join-Path $env:USERPROFILE 'Desktop\.eastudio'
$instanciasRoot = Join-Path $expectedRoot '00_setup/Instancias'
$defaultInstaller = Join-Path $expectedRoot '00_setup/bin/mt5setup.exe'

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
        $accesoRapido  = Join-Path $d.FullName 'acceso_rapido'
        $portableExe   = Get-ChildItem -Path $instalacion -Filter 'terminal*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        $credPath      = Join-Path $d.FullName 'credenciales.json'
        $hasCred       = Test-Path $credPath
        [pscustomobject]@{
            Instancia     = $d.Name
            Instalacion   = if (Test-Path $instalacion) {'OK'} else {'-'}
            AccesoRapido  = if (Test-Path $accesoRapido) {'OK'} else {'-'}
            PortableExe   = if ($portableExe) {$portableExe.Name} else {'(no exe)'}
            Credenciales  = if ($hasCred) { 'Sí' } else { 'No' }
            CredPath      = $credPath
            Ruta          = $d.FullName
        }
    }
}

function Load-InstanceCred {
    param($instancePath)
    $credPath = Join-Path $instancePath 'credenciales.json'
    if (-not (Test-Path $credPath)) { return $null }
    try { return Get-Content $credPath -Raw | ConvertFrom-Json } catch { return $null }
}

function Ensure-PortableInstall {
    param($instName, $installerPath)
    $success         = $false
    $targetRoot      = Join-Path $instanciasRoot $instName
    $instalacionDir  = Join-Path $targetRoot 'instalacion'
    $accesoRapidoDir = Join-Path $targetRoot 'acceso_rapido'

    foreach ($d in @($targetRoot, $instalacionDir, $accesoRapidoDir)) {
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
            $mqlDir      = Join-Path $instalacionDir 'MQL5'
            $expertsDir  = Join-Path $mqlDir 'Experts'
            $eaStudioDir = Join-Path $expertsDir 'Ea_Studio'
            $reportDir   = Join-Path $instalacionDir 'report'
            $testerProfileDir = Join-Path $instalacionDir 'MQL5/Profiles/Tester'
            foreach($d in @($mqlDir, $expertsDir, $eaStudioDir, $reportDir)){
                if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
            }
            # Enlazar a acceso_rapido/Ea_Studio
            $eaStudioLink = Join-Path $accesoRapidoDir 'Ea_Studio'
            New-LinkForce -Path $eaStudioLink -Target $eaStudioDir
            # Enlace rápido a reportes
            $reportLink = Join-Path $accesoRapidoDir 'report'
            New-LinkForce -Path $reportLink -Target $reportDir
            # Enlace rápido a perfiles de tester
            $testerLink = Join-Path $accesoRapidoDir 'Profiles_Tester'
            if(Test-Path $testerProfileDir){
                New-LinkForce -Path $testerLink -Target $testerProfileDir
            } else {
                Write-Host "Aviso: no se encontró $testerProfileDir; crea un backtest manual una vez para que MT genere la carpeta, luego reejecutá para enlazar." -ForegroundColor Yellow
            }
            Write-Host "Estructura MQL5/Experts/Ea_Studio creada y enlazada en acceso_rapido." -ForegroundColor Green
            Write-Host "Carpeta de reportes report creada y enlazada en acceso_rapido." -ForegroundColor Green
            Write-Host "Carpeta de perfiles de tester enlazada en acceso_rapido (Profiles_Tester)." -ForegroundColor Green
            Write-Host "Si se abrió la ventana de MT, cerrala cuando termine de generar las carpetas." -ForegroundColor Yellow
        } catch {
            Write-Host "No se pudo lanzar el terminal en modo portable: $_" -ForegroundColor Red
        }
    }

    Write-Host "Listo. Usá launch_portable.cmd o el acceso directo terminal_portable.lnk para arrancar en modo portable." -ForegroundColor Green
    $success = $true
    return $success
}

Assert-Location
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

$action = Read-Host "Elige acción: [1] Crear nueva instancia portable  [2] Asignar credenciales a instancia  [3] Elegir credencial activa  [ENTER] Salir"
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
        Write-Host "Todas las instancias ya tienen credenciales.json. Nada que hacer." -ForegroundColor Yellow
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
    }
    $credPath = Join-Path $chosen.Ruta 'credenciales.json'
    $credObj | ConvertTo-Json | Set-Content -Path $credPath -Encoding UTF8
    Write-Host "Credenciales guardadas en $credPath" -ForegroundColor Green
    exit 0
}
elseif ($action -eq '3') {
    $conCred = @($instances | Where-Object { $_.Credenciales -eq 'Sí' })
    if (-not $conCred) {
        Write-Host "No hay instancias con credenciales.json. Asigna primero (opción 2)." -ForegroundColor Yellow
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
    $outPath = Join-Path $instanciasRoot 'credencial_en_uso.json'
    $outObj = [pscustomobject]@{
        instancia = $chosen.Instancia
        ruta_instancia = $chosen.Ruta
        credencial = $c
        terminal_exe = if($terminalExe){ $terminalExe.FullName } else { $null }
        metaeditor_exe = if($metaeditorExe){ $metaeditorExe.FullName } else { $null }
        fecha_seleccion = (Get-Date).ToString('s')
    }
    $outObj | ConvertTo-Json -Depth 5 | Set-Content -Path $outPath -Encoding UTF8
    Write-Host "Credencial activa guardada en $outPath" -ForegroundColor Green

    if ($terminalExe) {
        $openTerm = Read-Host "¿Abrir MT en modo portable para iniciar sesión y verificar credencial ahora? (s/n)"
        if ($openTerm -match '^[sS]') {
            try {
                Start-Process -FilePath $terminalExe.FullName -ArgumentList '/portable' -WorkingDirectory $instalacionDir -ErrorAction Stop
                Write-Host "Se abrió MT en modo portable. Ingresá la cuenta y confirmá conexión." -ForegroundColor Cyan
            } catch {
                Write-Host "No se pudo abrir el terminal en modo portable: $_" -ForegroundColor Red
            }
        }
    }

    exit 0
}
else {
    Write-Host "Sin cambios." -ForegroundColor Yellow
    exit 0
}
