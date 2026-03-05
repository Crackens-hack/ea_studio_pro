# Plantillas auto para backtesting

Archivos en esta carpeta:
- `plantilla_single.ini`: corrida única (sin Optimización). Usa `ExpertParameters` vacío.
- `plantilla_genetica.ini`: optimización genética (`Optimization=2`, `OptimizationCriterion=6` para usar `OnTester`).
- `plantilla_forward.ini`: optimización con forward (`Optimization=2`, `ForwardMode=1` tiempo).
- `plantilla_genetica_fw50.ini`: optimización genética con forward 50/50 (`Optimization=2`, `ForwardMode=1`), report `report_geneticfw__`.

Placeholders a rellenar antes de lanzar `03_backtesteador.ps1`:
- `__LOGIN__`, `__PASSWORD__`, `__SERVER__`: credenciales de la instancia activa.
- `__EA_NAME__`: nombre del EA (sin extensión). Se usa en `Expert=Ea_Studio\__EA_NAME__.ex5` y en el `.set`.
- `Report`: ya viene con prefijo `report\` y sufijo según modo (`report_single__`, `report_genetic__`, `report_forward__` + nombre del EA).

Reglas rápidas:
- Single: `ExpertParameters=` debe quedar vacío; si querés presets fija Y->N en el `.set`.
- Genética/forward: `ExpertParameters` debe apuntar al `.set` del EA.
- Asegurarse de que `Expert=` siempre tenga el prefijo `Ea_Studio\`.
- Los demás campos (fechas, símbolo, modelo, spread) se ajustan manualmente según el run.
