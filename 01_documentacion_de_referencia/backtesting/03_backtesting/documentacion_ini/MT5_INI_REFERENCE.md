# MetaTrader 5 CLI `.ini` referencia rápida

Plantilla base: `documentacion_ini/plantilla_funcional.ini`. Úsala tal cual y completa solo los valores.

## Carpetas clave
- Carpeta de instalación (ejecutable): donde está `terminal64.exe`. En `/portable`, la carpeta de datos es esta misma.
- Data folder (modo normal): `%APPDATA%\MetaQuotes\Terminal\<instance_id>\`
  - `MQL5\Experts\` → EAs. El valor de `Expert` es relativo a esta carpeta (no incluyas `MQL5`).
  - `MQL5\Profiles\Tester\` → presets `.set` para `ExpertParameters`.
  - `profiles\templates\` → plantillas de gráficos (`StartUp.Template`).
  - `logs\`, `Tester\logs\` → registros.
- Reportes:
  - Modo normal: la ruta relativa se resuelve dentro del data folder (`%APPDATA%\MetaQuotes\Terminal\<instance_id>`). No se usan rutas fuera de ese árbol; escribe con una sola `\` (ej. `\reports\MyExpert.htm`).
  - Modo portátil: la ruta relativa se resuelve junto al `terminal64.exe`.

## Secciones y parámetros

### [Common]
Login, Password, Server, CertPassword, EnableNews, proxy (`ProxyEnable/Type/Address/Login/Password`), KeepPrivate.

### [Charts]
ProfileLast, MaxBars, PrintColor, SaveDeleted.

### [Experts]
AllowLiveTrading, AllowDllImport, Enabled, Account (desactiva EAs al cambiar de cuenta), Profile (al cambiar de perfil).

### [Objects]
ShowPropertiesOnCreate, SelectOneClick, MagnetSens.

### [Email]
Enable, Server, Auth, Login, Password, FromName, FromAddress, To.

### [StartUp]
Expert (ruta relativa a `MQL5\Experts`), ExpertParameters (preset en `MQL5\Profiles\Tester`), Symbol, Period, Template (`profiles\templates\`), Script, ScriptParameters, ShutdownTerminal.

### [Tester]
Expert (ruta relativa a `MQL5\Experts`, sin anteponer `Experts\`; extensión opcional), ExpertParameters (`MQL5\Profiles\Tester`, no admite ruta externa), Symbol, Period, Login (solo visible para el EA), Model (0 ticks, 1 OHLC M1, 2 open, 3 math, 4 ticks reales), Spread, FromDate/ToDate, ForwardMode (0 off, 1–3 fracciones, 4 custom), ForwardDate/ForwardPoints, ExecutionMode (0 normal, -1 delay random, >0 delay ms), Deposit, Currency, Leverage (número, ej. 100), ProfitInPips (1 pips netos sin swaps/comisiones), Optimization (0 off, 1 slow, 2 genetic, 3 todos símbolos), OptimizationCriterion (0–6), GeneticIterations, Visual, Report (ruta relativa al data folder en modo normal; relativa al exe en portátil), ReplaceReport (0 añade sufijo, 1 sobrescribe), ShutdownTerminal, Port (cambiar si ejecutas instancias paralelas), UseLocal/UseRemote/UseCloud, MaxProcessors, Migrate (1 fuerza migrar a VPS en próxima sincronización).

## Ejecución por CLI
- Modo normal (usa data en `%APPDATA%`):
  - `& 'C:\Program Files\MetaTrader 5\terminal64.exe' '/config:C:\Users\ezequiel\.eastudio\documentacion_ini\plantilla_funcional.ini'`
- Modo portátil (data junto al exe):
  - `& 'D:\MT5_Portable\terminal64.exe' '/portable' '/config:C:\Users\ezequiel\.eastudio\documentacion_ini\plantilla_funcional.ini'`
- Versión mini de referencia:
  - `terminal64.exe /config:C:\Users\ezequiel\.eastudio\documentacion_ini\example__mini.ini`

Notas:
- Cambia la ruta del `terminal64.exe` si lo tienes en otra carpeta.
- Con rutas relativas: en modo normal se guardan en `%APPDATA%...`; en portátil junto al exe. Usa `\reports\MiArchivo.htm` (una sola barra invertida).

## Notas rápidas
- No antepongas `Experts\` en `Expert`; se interpreta relativo a `MQL5\Experts`.
- El `.set` de `ExpertParameters` vive en `MQL5\Profiles\Tester` y es texto `param=valor`.
- Reporte: relativo al data folder en modo normal, relativo al exe en portátil; con ruta absoluta lo envías donde quieras.

## Valores de la plantilla incluida
- Placeholders: `Login`, `Password`, `Server`, `ExpertParameters`, `Symbol`, `Period`.
- EA de ejemplo: `Expert=EaStudio\example.ex5` (ubícalo en `MQL5\Experts\EaStudio\`).
- Rango: `2025.01.01` a `2025.12.31`, modelo ticks (`Model=0`), spread 0, sin optimización.
- Reporte: `\reports\MyExpert.htm` relativo al data folder/instancia. Crea la carpeta `reports` si no existe.
