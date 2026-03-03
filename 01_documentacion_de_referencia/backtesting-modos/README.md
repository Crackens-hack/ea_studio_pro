# Backtesting: modos y ejemplos rápidos

Archivos de ejemplo ya existentes:
- `01_backtesting-single.ini`: corrida simple sin preset.
- `02_backtesting-single_predefinido.ini`: corrida simple usando un `.set`.
- `03_backtesting-genetico.ini`: optimización genética.

Cómo elegir el modo en `plantilla_funcional.ini` (se actualiza antes de lanzar el tester):

- Corrida single rápida  
  - `Optimization=0`, `UseDate=0` (usa todo el historial), `Visual=0`.
- Single con preset (.set)  
  - `Optimization=0`, `ExpertParameters=tu_archivo.set`.
- Optimización genética  
  - `Optimization=1`, `OptimizationCriterion=6` si usas `OnTester` como fitness; si no, deja el criterio estándar.
- Forward test  
  - `Optimization=3` y `ForwardMode` distinto de 0 (por tiempo o porcentaje).
- Visual  
  - `Visual=1` (solo para single run; no aplica en optimizaciones).

Otros campos clave:
- `Model`: 0=Every tick, 4=Real ticks (más lento, más preciso), 2=Open prices (rápido).
- `Spread`: 0 = actual; fija un valor para escenarios estables.
- `UseDate`, `FromDate`, `ToDate`: delimitar rango de prueba.
- `Report`: ruta del HTML relativo a la instancia activa.
- `Deposit`, `Currency`, `Leverage`: capital y apalancamiento para la simulación.
