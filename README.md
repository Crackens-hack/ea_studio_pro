# .eastudio

Objetivo central: pensar, diseñar y construir Asesores Expertos (EA) de alta calidad usando IA como copiloto, combinando herramientas automáticas y pasos manuales guiados.

Cómo trabajamos
- Ideación asistida por IA: definir lógica, métricas y criterios de fitness antes de escribir código.
- Desarrollo de EA: la IA genera/edita `.mq5` en `A_MQL5/01_ea_construccion`.
- Compilación y despliegue: scripts de la carpeta raíz (`02_compilador.ps1`, etc.) copian el `.ex5` a la instancia activa.
- Backtesting y optimización: `plantilla_funcional.ini` + `.set` en `MQL5/Profiles/Tester` controlan los runs; el usuario elige modo, fechas y símbolos.
- Iteración sobre resultados: leer logs, ajustar parámetros/código, repetir hasta obtener métricas limpias.

Principios
- IA + humano: la IA propone y ejecuta tareas acotadas; el humano valida credenciales, decide modos de prueba y lanza scripts sensibles.
- Transparencia: cada cambio queda documentado en los archivos de referencia (`AGENTS.md`, `01_documentacion_de_referencia/`).
- Calidad: siempre incluir `OnTester` con métricas clave (PF, DD, winrate, payoff, RR, Sharpe/Sortino cuando aplique).

Dónde mirar primero
- `AGENTS.md`: flujo operativo y reglas de seguridad (credenciales, compilación, backtesting).
- `01_documentacion_de_referencia/backtesting-modos/`: plantillas .ini y guía de modos.
- `01_documentacion_de_referencia/sets-ejemplo/`: ejemplos de `.set` (formato y convenciones).
