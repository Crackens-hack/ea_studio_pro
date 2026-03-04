
# EA `portales` – Lógica y parámetros

## Idea general
EA tendencial-momentum con confirmación multi‑timeframe (H4 para tendencia, H1 para entrada), gestión de riesgo por ATR y métricas de rendimiento expuestas en `OnTester`. Busca operar solo cuando hay alineación de medias y momentum, filtrando spread y horario para evitar ruido.

## Reglas de entrada
- **Dirección de tendencia (HTF)**: EMA21 > EMA55 en H4 → solo compras; EMA21 < EMA55 → solo ventas.
- **Señal de entrada (TF señal)**: EMA21 vs EMA55 + RSI.
  - Compra: EMA rápida > EMA lenta **y** RSI > 55.
  - Venta: EMA rápida < EMA lenta **y** RSI < 45.
- **Filtros adicionales**:
  - Spread ≤ `InpMaxSpreadPoints`.
  - Horario servidor dentro de `[InpSessionStartHour, InpSessionEndHour]` si `InpUseTimeFilter=true`.

## Gestión de posiciones
- Solo una posición por símbolo/magic. Si `InpAllowHedging=false` y aparece señal contraria, se cierra y se revierte.
- **StopLoss**: `ATR(InpATRPeriod) * InpATRMultSL`.
- **TakeProfit**: `SL * InpATRMultTP`.
- **Trailing**: dinámico por ATR (`InpATRTrailMult`), ajusta SL a favor cuando el precio avanza.
- **Tamaño de lote**: riesgo fijo `InpRiskPerTradePct` de equity. Se calcula el lotaje que iguala ese riesgo a la distancia de SL (ajustado a step, min y max del símbolo). `InpMaxRiskPct` queda reservado para futuras validaciones de riesgo agregado.

## Gestión del riesgo
- Riesgo por trade controlado por porcentaje de equity.
- Filtro de spread para evitar ejecuciones malas.
- Filtro horario configurable para evitar sesiones ilíquidas o noticias si el usuario delimita la ventana.

## Salidas
- SL/TP fijados al abrir.
- Trailing por ATR; opcional break-even implícito cuando el trailing supera el SL previo.
- Cierre y reversión al recibir señal contraria si no se permite hedging.

## Métricas en `OnTester`
- Calcula: profit factor, drawdown relativo, winrate, payoff, recovery, Sharpe, expectancy, trades, tiempo medio en posición.
- `fitness = (PF * WinRate * max(Recovery,0.1) * max(Payoff,0.1)) / (1 + MaxDD)`.
- Imprime en el log del tester para monitoreo.

## Parámetros clave
- `InpTFSignal` (default H1), `InpTFTrend` (H4).
- `InpMAPeriodFast` / `InpMAPeriodSlow`, `InpRSIPeriod`, `InpRSIHigh/Low`.
- `InpATRMultSL/TP`, `InpATRTrailMult`.
- `InpRiskPerTradePct`, `InpMaxSpreadPoints`, `InpUseTimeFilter`, ventana horaria.
- `InpMagic`, `InpAllowHedging`.

## Ubicación
- Código: `A_MQL5/01_ea_construccion/portales.mq5`
- Teoría: `A_MQL5/01_ea_construccion/portales_teoria.md`

## Próximos pasos sugeridos
1) Opcional: ajustar umbrales RSI y ATR según par/período objetivo.
2) Compilar con `02_compilador.ps1` (autorízame y lo lanzo, o ejecútalo: `powershell -ExecutionPolicy Bypass -File .\\02_compilador.ps1`).
3) Backtest: definir símbolo, fechas, modelado y modo en `plantilla_funcional.ini` y correr `03_backtesteador.ps1`.
4) Afinar fitness y parámetros tras primeras optimizaciones.
