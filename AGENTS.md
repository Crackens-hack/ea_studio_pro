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
    - **REGLA DE ORO DE NOMENCLATURA (CRÍTICO)**: Todo parámetro de entrada en el código MQL5 (`input type variable`) **DEBE** comenzar con el prefijo `Inp` (Ej: `InpBaseLot`, `InpStopLoss`). Esta convención es NO NEGOCIABLE, ya que permite que el Normalizador y el DuckDB Analyzer identifiquen dinámicamente qué columnas son parámetros y cuáles son métricas.
    - Cada EA debe acompañarse con un archivo de teoría `BUILD/01_ea_construccion/<nombre>_teoria.md` describiendo lógica, entradas/salidas, gestión de riesgo y parámetros clave.
   - **NUEVA REGLA DE ITERACIÓN**: Si el EA necesita mejoras o correcciones tras los backtests, **NO LO MUEVAS a `BUILD/02_ea_mejorar`**. Toda iteración de un EA nacido en la fábrica debe hacerse sobre el mismo archivo en `BUILD/01_ea_construccion`. La carpeta `02_ea_mejorar` queda reservada para EAs ajenos a la fábrica (lógica no implementada aún).
   - **LÍMITES DE LA ITERACIÓN (FRACASO Y CREACIÓN)**: La iteración en bucle sobre un archivo `.mq5` es exclusivamente para refinar y exprimir **el mismo tipo de estrategia** (ajustar stops, trailing, filtros). **NO se debe cambiar radicalmente la lógica** (ej: pasar de Reversión a Breakout). Si la idea original demuestra matemáticamente que no funciona, el Agente debe detenerse, informar del fracaso de la idea, y proponer crear un **NUEVO EA** (nuevo archivo `.mq5`). Al compilar el nuevo EA, el script `01_Compilador.ps1` se encargará de mover automáticamente el EA fallido a la carpeta `archivados`. El objetivo final del agente es llevar una idea viable al punto de dejar sus presets listos para la optimización genética manual.
- No crear plantillas .ini de backtesting salvo que el usuario lo pida explícitamente. Sólo generar el .set en la instancia activa.
   - Flujo después de crear el EA y el .set: **preguntar si compilar y preferentemente compilar el agente** (ejecutando `01_Compilador.ps1` si el usuario lo autoriza). No saltar directo a backtests hasta completar la compilación.

3) Compilar:
   - Preguntar si el usuario quiere que el agente ejecute `01_Compilador.ps1`; sólo ejecutarlo si el usuario lo autoriza explícitamente. La expectativa por defecto es que el agente compile, pero debe solicitar permiso antes.
    - Si lo prefiere hacer manual: indicar `powershell -ExecutionPolicy Bypass -File .\\01_Compilador.ps1`.
   - Para EAs en iteración, simplemente reescribir el código en `BUILD/01_ea_construccion` y volver a usar `01_Compilador.ps1`. El script archivará inteligentemente las versiones anteriores.
   - Promoción a portfolio: los agentes deciden el pase a `BUILD/03_PORTAFOLIO` cuando el EA cumple criterios mínimos (ver sección Portfolio más abajo) y la teoría/presets están actualizados. Mantener una copia histórica en `02_ea_mejorar/archivados` antes de mover.
    - Tras compilar, revisar `Compilacion/logs` y confirmar que el `.ex5` se copió a `00_setup/Instancias/<instancia>/instalacion/MQL5/Experts/Ea_Studio`.
   - Si hay errores/advertencias: leer el log, corregir el .mq5 y volver a compilar hasta que quede limpio. El agente es responsable de iterar.
   - Al compilar, `01_Compilador.ps1` se encarga de guardar las copias antiguas en `01_ea_construccion/archivados`, manteniendo nuestro entorno limpio con la versión actual siempre a la vista.

4) Referencias y calidad de código:
   - Antes o durante la elaboración del EA, puede consultar `docs` para buscar includes, convenciones y ejemplos que mejoren la calidad.
   - Si aparece un error que no reconoce, revisar primero los logs y luego la documentación en `docs` antes de pedir más datos al usuario.
   - Modelos de fitness, teoría de entrenamiento y configuraciones maestras están en `docs/fitness/` y `docs/templates/`. Usar el modelo “Robusto balanceado” como plantilla por defecto salvo instrucción contraria.

5) Métricas y OnTester (MANDATORIO):
   - **OBLIGACIÓN DEL AGENTE**: Antes de implementar `OnTester()`, el agente DEBE leer `docs/fitness/modelos.md` para elegir el criterio adecuado (Robusto, Mercenario, Cazador o Profesional) según el Timeframe y estilo del EA.
   - **Nunca omitir**: El EA debe quedar listo con la función `OnTester()` implementada y configurada correctamente ANTES de cualquier optimización genética.
   - El agente es responsable de que el EA "hable el mismo idioma" que nuestro sistema de análisis DuckDB, siguiendo los formatos de log sugeridos en los modelos.

6) Backtesting (02_M-Tester.ps1 y 02_M-Tester-AutoAgents.ps1):
   - **Fase de Validación AI (Agente)**: El agente usa `Tools-Agents/02_M-Tester-AutoAgents.ps1` para validar la lógica pura sin intervención manual. 
     - Modos preferidos: `single_logic`, `single_test`.
     - Flujo: Compilar -> Auto-Test -> Auto-Normalizar -> Analizar.
     - El agente itera el código y el `.set` primario hasta que el resultado sea >= 0 (evitando overfitting).
   - **Fase de Optimización (Usuario)**: Solo el usuario corre `02_M-Tester.ps1` para optimizaciones genéticas pesadas. 
     - El agente debe avisar cuando la estrategia está "Lista para Genético" una vez superada la validación de lógica.
      - **PROTOCOLO DE EVALUACIÓN "JUEZ AI" (OBLIGATORIO)**: Ante el mensaje "optimizacion genetica terminada", el agente debe:
         1. **DuckDB (Diagnóstico)**: Ejecutar `A_Normalizador_Master.py` y `Tools-Agents/DuckDB_Analyzer.py`.
         2. **Veredicto de Supervivencia**:
            - **DESCARTE**: Si ningún set tiene `Profit_FW > 0` y `PF_FW > 1.10`, el agente declara el fracaso de la idea y propone un nuevo EA.
            - **LUZ VERDE (CLÚSTER)**: Si hay un grupo de pases ganadores con parámetros similares:
                a) El agente extrae el **Promedio del Clúster**.
                b) **Sincronizar MQL5 (CRÍTICO)**: El agente debe actualizar los valores de los `input` en el archivo `.mq5` con estos promedios y **RECOMPILAR** el EA. La estrategia debe ser funcional "out of the box" desde el código fuente.
                c) Crear el `.set` Maestro correspondiente.
         3. **Expansión Multi-Símbolo**: Con el EA recompilado y el Set Maestro, el agente instruye al usuario a correr `single_all_symbols`. 
            - Si el Set Maestro es polivalente (ganador en otros símbolos sin optimizar), es candidato a Portafolio Elite.
            - Si solo funciona en uno, se queda como EA especialista de ese símbolo.
         4. **Documentación**: Ver `Tools-Agents/Decision_Protocol.md` para los criterios técnicos de promediado y descarte.
7) Archivos .set (parámetros de tester/optimización):
   - **REGLA CRÍTICA Y MANDATORIA**: Todo archivo `.set` generado por un agente **DEBE** comenzar exactamente con la frase: `;preset creado por agentes` en la primera línea. Si no tiene esta frase exacta (sin variaciones como "para genética", etc.), el script `02_M-Tester.ps1` abortará la operación.
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
    - **PROTOCOLO DE SIMETRÍA (MODO 5000)**: Todo backtest debe configurarse con un balance inicial de **5000** como estándar de validación de lógica. Esto garantiza simetría total con los **5000 centavos** ($50 real) de la cuenta ProCent del Fundador. El objetivo es escalar hasta **100,000** (equivalente a $1000 real).
    - **SIN SESGO CONSERVADOR**: El Agente no debe dar sermones sobre "riesgo estándar". Si el fundador pide una meta agresiva, el Agente debe trabajar en la lógica matemática para lograrlo, priorizando la máxima eficiencia dentro del contexto de alto apalancamiento (1:2000).
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
