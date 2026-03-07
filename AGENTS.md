# AGENTS

Contexto: usar siempre la terminal integrada de VS Code / Cursor / Antigravity. El agente avanza despacio, explica y confirma cada paso; no asume permisos ni lanza instaladores por su cuenta.

Regla clave:
- **00_setup/Instalador.ps1 (antes 01_init_0.ps1) no lo ejecuta el agente.** Solo guía al usuario sobre cómo correrlo y qué responder. Otros scripts pueden evaluarse caso a caso.

Flujo recomendado en cada sesión:

0) **EL LLAMADO (CRÍTICO)**:
   - **`llamado.md` es el sensor de pulso del proyecto**. El Agente DEBE leerlo antes de cualquier acción.
   - Si el archivo está vacío o es una sesión nueva, preguntar obligatoriamente:
     - "¿Cuál es tu objetivo con este repositorio? ¿Por qué creíste en este proyecto?"
     - "¿Cuál es tu perfil? (Socio técnico, trader con experiencia, o vienes de otra rama?)"
     - "¿Conoces de trading algorítmico o estás aquí para diseñar la visión mientras yo ejecuto?"
   - **Misión de Bitácora**: El Agente documenta en `llamado.md` los objetivos, el nivel técnico y la urgencia. Si hay una meta con urgencia, el Agente acelera el paso y documenta cada decisión estratégica aquí para mantener la simbiosis.

1) Verificar credencial activa (sin ejecutar nada):
   - Revisar si existe `00_setup/Instancias/credencial_en_uso.json`.
   - Si existe, mostrar cuenta y servidor al usuario y preguntar: “¿Querés trabajar con esta credencial?”  
     - Si la credencial no es la correcta: indicar que reejecute `00_setup/Instalador.ps1` opción 3 (o 2+3 si necesita cargar otra) y detenerse hasta que confirme.
     - Si no existe el archivo: pedir que ejecute `00_setup/Instalador.ps1` y siga opciones 2 y 3. El agente no lo ejecuta.
   - Antes de usar scripts (compilar/normalizar), si no hay venv, sugerir al usuario crearlo e instalar dependencias de `00_setup/requirements.txt`:
     - `python -m venv .venv`
     - `.\.venv\Scripts\activate`
     - `pip install -r 00_setup/requirements.txt`

2) Preparar EA (el agente es quien genera/edita código MQL5):
   - Explicar que los .mq5/.mql5 van en `BUILD/01_ea_construccion`.
   - Ofrecer crear un EA nuevo según reglas del usuario o editar uno existente.
   - Cada EA debe acompañarse con un archivo de teoría `BUILD/01_ea_construccion/<nombre>_teoria.md` describiendo lógica, entradas/salidas, gestión de riesgo y parámetros clave.
   - Si el EA necesita iteraciones/mejoras, moverlo (con su `_teoria.md` y, si aplica, .set) a `BUILD/02_ea_mejorar` y usar `03_Recompilador.ps1` para las siguientes compilaciones. En `02_ea_mejorar` también se archiva automáticamente el EA menos reciente para evitar sobrescrituras.
   - Futuro flujo: al consolidar mejoras, los EAs listos para pruebas combinadas pasarán a `BUILD/03_portfolio` (criterios a definir: estabilidad forward, métricas mínimas y convergencia de optimizaciones).
- No crear plantillas .ini de backtesting salvo que el usuario lo pida explícitamente. Sólo generar el .set en la instancia activa.
   - Flujo después de crear el EA y el .set: **preguntar si compilar y preferentemente compilar el agente** (ejecutando `01_Compilador.ps1` si el usuario lo autoriza). No saltar directo a backtests hasta completar la compilación.

3) Compilar:
   - Preguntar si el usuario quiere que el agente ejecute `01_Compilador.ps1`; sólo ejecutarlo si el usuario lo autoriza explícitamente. La expectativa por defecto es que el agente compile, pero debe solicitar permiso antes.
    - Si lo prefiere hacer manual: indicar `powershell -ExecutionPolicy Bypass -File .\\01_Compilador.ps1`.
   - Para EAs en iteración dentro de `BUILD/02_ea_mejorar`, usar `03_Recompilador.ps1` (mismo flujo de logs en `Compilacion/logs` y copia a `Experts/Ea_Studio`).
   - Promoción a portfolio: los agentes deciden el pase a `BUILD/03_PORTAFOLIO` cuando el EA cumple criterios mínimos (ver sección Portfolio más abajo) y la teoría/presets están actualizados. Mantener una copia histórica en `02_ea_mejorar/archivados` antes de mover.
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
   - **MODO $1,000 (VALIDACIÓN TÉCNICA)**: Todo backtest debe configurarse con un balance inicial de **$1,000 USD** como estándar de validación de lógica (salvo instrucción específica en `llamado.md`). Esto evita descartar estrategias ganadoras por falta de margen inicial, permitiendo encontrar el "Edge" antes del aterrizaje a la cuenta real de $100.
   - **SIN SESGO CONSERVADOR**: El Agente no debe dar sermones sobre "riesgo estándar". Si el fundador pide una meta 10x con urgencia, el Agente debe trabajar en la lógica matemática y de ejecución para lograrlo, priorizando la máxima eficiencia y la protección del drawdown dentro de ese contexto agresivo.
   - Cada `.set` que prepare el agente debe empezar con la línea `;preset creado por agentes` (sin espacios extra). `02_M-Tester.ps1` aborta si falta o si el archivo es un autosave del tester (`; saved automatically on ...`). Colocar el `.set` limpio en `00_setup/Instancias/<instancia>/instalacion/MQL5/Presets/`; el script lo moverá a `Profiles/Tester` agregando `;preset movido por 02_M-Tester` encima.

## Observaciones recientes
- Cuando un `.set` tenga parámetros dependientes con orden lógico (p. ej. niveles RSI Low/High, SL < TP, fechas start < end), fijar rangos que respeten esa relación y eviten valores iguales/cruzados. Esto previene errores de compilación/optimización “incorrect input parameters” durante genética/forward.

## Post-compilación y presets
- Después de compilar con éxito un EA, crear su `.set` base en la instancia activa: `00_setup/Instancias/<instancia>/instalacion/MQL5/Presets/<EA>.set`. Si ya existe, confirmar con el usuario antes de sobrescribir.
- El agente genera el `.set` con input limpio (sin comentarios, solo líneas `Parametro=...` en el formato esperado). No añadir cabeceras ni marcas propias.
- Solo el usuario corre `M-Tester.ps1` (es interactivo). El agente puede sugerir correr primero `smoke` o `regresion_corta` para verificar trades.
- En modos con optimización, `M-Tester.ps1` mueve el `.set` desde `MQL5/Presets` a `MQL5/Profiles/Tester/<EA>.set`, agregando su propio comentario al inicio y borrándolo de `Presets`. Si no encuentra el `.set` en `Presets` pero sí en `Profiles/Tester` con el comentario `;preset creado por agentes`, lo reutiliza. Modos sin optimización no mueven/copian (permiten el autosave del tester).

## Portfolio (BUILD/03_PORTAFOLIO)
- Objetivo: reunir EAs listos para pruebas combinadas/demo en carpetas separadas (`BUILD/03_PORTAFOLIO/<EA>/`).
- Criterios mínimos (versión 1):
  - Forward válido: PF >= 1.3, RF >= 1.0, resultado > 0; ratio forward/back >= 0.8.
  - Robustez: >= 200 trades (o >= 100 si intradía con spreads bajos), DD% relativo <= 25%.
  - Estabilidad de parámetros: variaciones ±10–15% mantienen PF/RF dentro de -10% del mejor set.
  - Código y docs: `OnTester` implementado, teoría al día, presets en instancia activa, logs limpios.
  - Recencia: optimización/ajustes no mayores a 30 días.
- Antes de mover: archivar la versión previa en `02_ea_mejorar/archivados`. Copiar `_teoria.md` y `.set` junto con el `.mq5/.ex5`.
- Cada `_teoria.md` debe incluir un bloque “Expectativa demo/vivo” con: PF, RF, winrate, payoff, DD% esperado, número de trades/mes y horizonte de evaluación, más riesgos conocidos (rango de rachas negativas). Mantenerlo actualizado tras cada optimización relevante.
- Notar: `.eastudio` es el taller de fabricación/experimentación; el seguimiento en vivo se llevará en un repo aparte (cuando exista). Aquí los EAs deben quedar con expectativas realistas de rendimiento y riesgos (drawdowns esperables documentados).
- Al mover un EA a `BUILD/03_PORTAFOLIO`, el agente debe verificar/insertar el bloque “Expectativa demo/vivo” en su `_teoria.md`. Si falta, copiar la sección desde `BUILD/03_PORTAFOLIO/teoria_template.md` y completarla con las métricas más recientes.

## Normalización y análisis de resultados
- `script/A_Normalizador_Master.py` genera la carpeta `RESULTADOS/Reportes-Normalizados` con:
  - XML → CSV (estructura replicada de `reports`).
  - HTM → MD + JSON y copia del HTM (misma estructura).
- `script/B_Analista_Profesional.py` genera la carpeta `RESULTADOS/Reportes-Analizados` con lo que pasa los filtros:
  - CSV: aplica filtros de `analisis_conf.json["csv"]`, genera `_analysis.txt` y solo copia los análisis aprobados (no duplica CSV).
  - JSON (de HTM normalizados): aplica filtros/score de `analisis_conf.json["json"]`, genera `json_analysis.txt`, copia JSON/MD/HTM aprobados y lista descartes con motivo en `RESULTADOS/Reportes-Analizados/1_No_Pasan_Filtros/json_descartados.txt`.
- `script/Clear.py` ofrece un menú para limpiar `RESULTADOS` (analizados, normalizados, crudos de la instancia o todo). El enlace `RESULTADOS/Reportes-SinProcesar` se conserva siempre.
- El agente debe ajustar los umbrales en `script/analisis_conf.json` según etapa (exploración/afinado/forward) y usar esos veredictos para decidir si relajar/estrechar rangos, recompilar o descartar el EA.

Tono y ritmo:
- Ir despacio, ser muy claro para usuarios nuevos.
- Confirmar credencial antes de avanzar al código.
   - No ejecutar `00_setup/Instalador.ps1`; sí puedes generar EAs y, con permiso, correr `01_Compilador.ps1`.
