# EA_Atlas_Pullback_v1

## Idea
Pullback a EMA20 dentro de una tendencia definida por EMA200. Se exige confirmación de impulso con RSI y un umbral de volatilidad (ATR rápido por encima del ATR lento). Gestión 100% basada en ATR: SL, TP, trailing y break-even dinámicos. Solo una posición por dirección y enfriamiento entre entradas.

## Señales
- **Tendencia:** precio frente a EMA200 (solo compras encima, ventas debajo).
- **Pullback:** vela previa cierra al otro lado de EMA20 y la vela actual vuelve a favor de la tendencia.
- **Confirmación RSI:** cruce desde la zona contraria (RSI sube de Low→High para buys; baja de High→Low para sells).
- **Volatilidad mínima:** ATR(14) > 0.5 × ATR(50) (evita compresión).
- **Filtros adicionales:** spread máximo, horario operable, cooldown de `InpCooldownBars` velas, una operación por dirección.

## Gestión de riesgo y trade
- **Riesgo por operación:** `%` del balance (`InpRiskPercent`) calculado contra la distancia a SL (ATR × `InpSL_ATR_Mult`).
- **SL/TP:** SL = ATR × `InpSL_ATR_Mult`; TP = ATR × `InpTP_ATR_Mult` (RR≈1:1.67 por defecto).
- **Break-even opcional:** a `InpBreakEvenMult` × ATR.
- **Trailing opcional:** se activa a `InpTrailStartMult` × ATR; paso `InpTrailStepMult` × ATR.
- **Máx. 1 trade por lado, cooldown y horario** (`InpStartHour`–`InpEndHour`).
- **Filtros de ejecución:** spread y slippage máximos en puntos.

## Parámetros clave (optimizables)
- Tendencia/pullback: `InpFastEMA`, `InpSlowEMA`.
- Momentum: `InpRSIPeriod`, `InpRSILow`, `InpRSIHigh`.
- Riesgo/gestión: `InpRiskPercent`, `InpSL_ATR_Mult`, `InpTP_ATR_Mult`, `InpTrailStartMult`, `InpTrailStepMult`, `InpBreakEvenMult`.
- Filtros: `InpATRPeriodFast`, `InpATRPeriodSlow`, `InpMaxSpreadPoints`, `InpMaxSlippagePoints`, `InpCooldownBars`, `InpStartHour`, `InpEndHour`.
- Magic number: `InpMagic`.

## Métricas en OnTester (siempre activas)
Calcula y registra: Profit Factor, Max Drawdown, Recovery Factor, Winrate, Payoff ratio, Avg RR, Nº trades, Profit medio por trade, Sharpe, Sortino (aprox.), tiempo medio en posición. Fitness devuelto: `(ProfitFactor * Winrate) / (1 + DDrel)`.

## Entregables
- Código: `BUILD/01_ea_construccion/EA_Atlas_Pullback_v1.mq5`
- Preset base (para la instancia activa RoboForex): `00_setup/Instancias/RoboForex/instalacion/MQL5/Presets/EA_Atlas_Pullback_v1.set`

## Uso sugerido
1) Abrir en H1 (o timeframe deseado) del símbolo que se quiera operar.
2) Ajustar spreads y horario al servidor del broker.
3) Optimizar los parámetros marcados con flag `Y` en el `.set`.
4) Compilar con `Compilador.ps1` (previo permiso) y luego ejecutar backtests con `M-Tester` según el modo preferido.
