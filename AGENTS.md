# AGENTS

Contexto: usar siempre la terminal integrada de VS Code / Cursor / Antigravity. El agente avanza despacio, explica y confirma cada paso; no asume permisos ni lanza instaladores por su cuenta.

Regla clave:
- **01_init_0.ps1 no lo ejecuta el agente.** Solo guía al usuario sobre cómo correrlo y qué responder. Otros scripts pueden evaluarse caso a caso.

Flujo recomendado en cada sesión:
1) Verificar credencial activa (sin ejecutar nada):
   - Revisar si existe `00_setup/Instancias/credencial_en_uso.json`.
   - Si existe, mostrar cuenta y servidor al usuario y preguntar: “¿Querés trabajar con esta credencial?”  
     - Si la credencial no es la correcta: indicar que reejecute `01_init_0.ps1` opción 3 (o 2+3 si necesita cargar otra) y detenerse hasta que confirme.
     - Si no existe el archivo: pedir que ejecute `01_init_0.ps1` y siga opciones 2 y 3. El agente no lo ejecuta.

2) Preparar EA (el agente es quien genera/edita código MQL5):
   - Explicar que los .mq5/.mql5 van en `A_MQL5/01_ea_construccion`.
   - Ofrecer crear un EA nuevo según reglas del usuario o editar uno existente.
   - Cada EA debe acompañarse con un archivo de teoría `A_MQL5/01_ea_construccion/<nombre>_teoria.md` describiendo lógica, entradas/salidas, gestión de riesgo y parámetros clave.

3) Compilar:
   - Preguntar si el usuario quiere que el agente ejecute `02_compilador.ps1`; solo ejecutarlo si el usuario lo autoriza explícitamente.
   - Si lo prefiere hacer manual: indicar `powershell -ExecutionPolicy Bypass -File .\02_compilador.ps1`.
   - Tras compilar, revisar `02_compilador/logs` y confirmar que el `.ex5` se copió a `00_setup/Instancias/<instancia>/instalacion/MQL5/Experts/Ea_Studio`.
   - Si hay errores/advertencias: leer el log, corregir el .mq5 y volver a compilar hasta que quede limpio. El agente es responsable de iterar.
   - Al archivar EAs antiguos, archivar también el respectivo `<nombre>_teoria.md` para mantener contexto histórico.

4) Referencias y calidad de código:
   - Antes o durante la elaboración del EA, puede consultar `01_documentacion_de_referencia` y `docs` para buscar includes, convenciones y ejemplos que mejoren la calidad.
   - Si aparece un error que no reconoce, revisar primero los logs y luego la documentación de referencia antes de pedir más datos al usuario.

5) Métricas y OnTester (siempre incluir):
   - Implementar `OnTester()` en todos los EAs generados, salvo que el usuario pida explícitamente no hacerlo.
   - Calcular y mostrar al menos: profit factor, max drawdown, recovery factor, winrate, payoff ratio, avg RR, número de trades, profit medio por trade, Sharpe/Sortino si es posible, tiempo medio en posición.
   - Devolver un fitness combinando métricas (ejemplo sugerido: `(profit factor * winrate) / (1 + maxDD)`), ajustable según el caso.
   - Registrar métricas en log/Comment para que el usuario las vea en pruebas y optimizaciones.

6) Backtesting (03_backtesteador.ps1):
   - Antes de ejecutarlo, preguntar al usuario qué modo quiere: single, con preset (.set), optimización, forward, visual, fechas, símbolo, periodo, modelado, spread, etc. El usuario controla los parámetros.
   - Con permiso del usuario, el agente puede editar `plantilla_funcional.ini` y luego correr `03_backtesteador.ps1`. Si el usuario prefiere hacerlo manual, solo darle el comando.
   - Usar los ejemplos de `01_documentacion_de_referencia/backtesting-modos/*.ini` y el README de esa carpeta como guía; ofrecer presets listos si el usuario lo pide.
   - Tras lanzar el tester, esperar el resultado y, si hay errores, ayudar a ajustar parámetros o EA y reintentar.

7) Archivos .set (parámetros de tester/optimización):
   - Ubicación: siempre en la instancia activa según `credencial_en_uso.json`.
     - Carpeta operativa para el probador: `00_setup/Instancias/<instancia>/instalacion/MQL5/Presets/` (es donde MT5 busca por defecto). **El agente debe guardar/copiar allí los .set que cree.**
     - Carpeta de perfiles del tester: `00_setup/Instancias/<instancia>/instalacion/MQL5/Profiles/Tester/` (puede usarse como staging, pero si el .set se deja ahí hay que duplicarlo en `Presets` antes de correr pruebas).
   - Nombre típico: mismo nombre del EA, ej. `EA_Spectacular.set`.
   - Formato por línea (para numéricos/bools/enums): `Parametro=valor_defecto||inicio||paso||fin||Y|N` donde:
     - `valor_defecto` es lo que usa un backtest single si no optimiza.
     - `inicio`, `paso`, `fin` definen rango de optimización; `Y` activa optimización, `N` la deja fija.
   - Para strings no se usan rangos: escribir solo `Parametro=valor` (o vacío `Parametro=` para usar el símbolo/valor definido en el .ini).
   - Timeframes van como enteros (ej. H1=16385); símbolos deben coincidir exactamente con el Market Watch de la cuenta (incluir sufijos si existen).
   - Cada vez que se cambie de instancia/credencial, asegurarse de usar/crear el .set dentro de esa instancia, no en otra carpeta.
   - Mapas de Optimization en .ini: 0 = slow complete (búsqueda exhaustiva), 1 = fast genetic, 2 = all symbols in Market Watch. Para single run dejar la línea `Optimization` vacía o comentada y asegurarse de que el .set no tenga flags `Y`.

Tono y ritmo:
- Ir despacio, ser muy claro para usuarios nuevos.
- Confirmar credencial antes de avanzar al código.
- No ejecutar `01_init_0.ps1`; sí puedes generar EAs y, con permiso, correr `02_compilador.ps1`.
