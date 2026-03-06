# AGENTS

Contexto: usar siempre la terminal integrada de VS Code / Cursor / Antigravity. El agente avanza despacio, explica y confirma cada paso; no asume permisos ni lanza instaladores por su cuenta.

Regla clave:
- **00_setup/Instalador.ps1 (antes 01_init_0.ps1) no lo ejecuta el agente.** Solo guía al usuario sobre cómo correrlo y qué responder. Otros scripts pueden evaluarse caso a caso.

Flujo recomendado en cada sesión:
1) Verificar credencial activa (sin ejecutar nada):
   - Revisar si existe `00_setup/Instancias/credencial_en_uso.json`.
   - Si existe, mostrar cuenta y servidor al usuario y preguntar: “¿Querés trabajar con esta credencial?”  
     - Si la credencial no es la correcta: indicar que reejecute `00_setup/Instalador.ps1` opción 3 (o 2+3 si necesita cargar otra) y detenerse hasta que confirme.
     - Si no existe el archivo: pedir que ejecute `00_setup/Instalador.ps1` y siga opciones 2 y 3. El agente no lo ejecuta.

2) Preparar EA (el agente es quien genera/edita código MQL5):
   - Explicar que los .mq5/.mql5 van en `BUILD/01_ea_construccion`.
   - Ofrecer crear un EA nuevo según reglas del usuario o editar uno existente.
   - Cada EA debe acompañarse con un archivo de teoría `BUILD/01_ea_construccion/<nombre>_teoria.md` describiendo lógica, entradas/salidas, gestión de riesgo y parámetros clave.
   - No crear plantillas .ini de backtesting salvo que el usuario lo pida explícitamente. Sólo generar el .set en la instancia activa.
   - Flujo después de crear el EA y el .set: **preguntar si compilar y preferentemente compilar el agente** (ejecutando `01_Compilador.ps1` si el usuario lo autoriza). No saltar directo a backtests hasta completar la compilación.

3) Compilar:
   - Preguntar si el usuario quiere que el agente ejecute `01_Compilador.ps1`; sólo ejecutarlo si el usuario lo autoriza explícitamente. La expectativa por defecto es que el agente compile, pero debe solicitar permiso antes.
    - Si lo prefiere hacer manual: indicar `powershell -ExecutionPolicy Bypass -File .\\01_Compilador.ps1`.
    - Tras compilar, revisar `Compilacion/logs` y confirmar que el `.ex5` se copió a `00_setup/Instancias/<instancia>/instalacion/MQL5/Experts/Ea_Studio`.
   - Si hay errores/advertencias: leer el log, corregir el .mq5 y volver a compilar hasta que quede limpio. El agente es responsable de iterar.
   - Al archivar EAs antiguos, archivar también el respectivo `<nombre>_teoria.md` para mantener contexto histórico.

4) Referencias y calidad de código:
   - Antes o durante la elaboración del EA, puede consultar `docs` para buscar includes, convenciones y ejemplos que mejoren la calidad.
   - Si aparece un error que no reconoce, revisar primero los logs y luego la documentación en `docs` antes de pedir más datos al usuario.
   - Modelos de fitness listos para copiar están en `Tools/fitness/modelos.md`. Usar el modelo “Robusto balanceado” como plantilla por defecto salvo instrucción contraria.

5) Métricas y OnTester (siempre incluir):
   - Implementar `OnTester()` en todos los EAs generados, salvo que el usuario pida explícitamente no hacerlo.
   - Calcular y mostrar al menos: profit factor, max drawdown, recovery factor, winrate, payoff ratio, avg RR, número de trades, profit medio por trade, Sharpe/Sortino si es posible, tiempo medio en posición.
   - Devolver un fitness combinando métricas (ejemplo sugerido: `(profit factor * winrate) / (1 + maxDD)`), ajustable según el caso.
   - Registrar métricas en log/Comment para que el usuario las vea en pruebas y optimizaciones.

6) Backtesting (02_M-Tester.ps1):
   - Sugerir al usuario el modo de prueba (single, preset/.set, optimización, forward, visual, fechas, símbolo, modelado, spread, etc.), pero **no ejecutar `02_M-Tester.ps1`** ni pedir permiso para ejecutarlo. El usuario decide y lo corre.
   - No proponer ni crear archivos .ini a menos que el usuario lo pida explícitamente. Se puede sugerir qué valores ajustar si el usuario edita un .ini.
   - Usar los ejemplos de `docs/backtesting-modos/*.ini` como referencia para sugerencias, no para crear archivos sin pedido.
   - Si el usuario comparte resultados/errores de backtest, ayudar a interpretarlos y proponer ajustes; iterar el EA y recompilar según sea necesario.

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
- Por defecto, configurar los flags de optimización en `Y` para los parámetros numéricos/bool que puedan optimizarse; usar `N` sólo si el usuario lo pide explícitamente.
   - Cada `.set` que prepare el agente debe empezar con la línea `;preset creado por agentes` (sin espacios extra). `02_M-Tester.ps1` aborta si falta o si el archivo es un autosave del tester (`; saved automatically on ...`). Colocar el `.set` limpio en `00_setup/Instancias/<instancia>/instalacion/MQL5/Presets/`; el script lo moverá a `Profiles/Tester` agregando `;preset movido por 02_M-Tester` encima.

## Observaciones recientes
- Cuando un `.set` tenga parámetros dependientes con orden lógico (p. ej. niveles RSI Low/High, SL < TP, fechas start < end), fijar rangos que respeten esa relación y eviten valores iguales/cruzados. Esto previene errores de compilación/optimización “incorrect input parameters” durante genética/forward.

## Post-compilación y presets
- Después de compilar con éxito un EA, crear su `.set` base en la instancia activa: `00_setup/Instancias/<instancia>/instalacion/MQL5/Presets/<EA>.set`. Si ya existe, confirmar con el usuario antes de sobrescribir.
- El agente genera el `.set` con input limpio (sin comentarios, solo líneas `Parametro=...` en el formato esperado). No añadir cabeceras ni marcas propias.
- Solo el usuario corre `M-Tester.ps1` (es interactivo). El agente puede sugerir correr primero `smoke` o `regresion_corta` para verificar trades.
- En modos con optimización, `M-Tester.ps1` mueve el `.set` desde `MQL5/Presets` a `MQL5/Profiles/Tester/<EA>.set`, agregando su propio comentario al inicio y borrándolo de `Presets`. Si no encuentra el `.set` en `Presets` pero sí en `Profiles/Tester` con el comentario `;preset creado por agentes`, lo reutiliza. Modos sin optimización no mueven/copian (permiten el autosave del tester).

Tono y ritmo:
- Ir despacio, ser muy claro para usuarios nuevos.
- Confirmar credencial antes de avanzar al código.
   - No ejecutar `00_setup/Instalador.ps1`; sí puedes generar EAs y, con permiso, correr `01_Compilador.ps1`.
