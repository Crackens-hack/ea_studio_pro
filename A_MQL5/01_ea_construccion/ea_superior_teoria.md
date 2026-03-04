# EA Superior

## Lógica de trading (símbolo único, H1 por defecto)
- **Filtro de tendencia:** EMA lenta (200). Solo compra si el precio actual > EMA200; solo vende si < EMA200.
- **Timing / pullback a la tendencia:**
  - EMA rápida (20) como guía de pullback.
  - RSI(14) buscando giro: para compras, RSI venía <35 y gira al alza; para ventas, RSI >65 y gira a la baja.
  - Alineación con EMA20: compras solo si close >= EMA20 y EMA20 > EMA200; ventas solo si close <= EMA20 y EMA20 < EMA200.
- **Stops y objetivos dinámicos:**
  - SL = ATR(14) * `SL_ATR_mult`.
  - TP = ATR(14) * `TP_ATR_mult`.
  - Trailing opcional con ATR*`Trail_ATR_mult`, solo si mejora el SL.
- **Gestión de riesgo:**
  - Riesgo por trade = `risk_percent` % del balance.
  - Tamaño de lote según distancia al SL, usando `tick_value/tick_size`, y acotado a `lot_min`, `lot_step`, `lot_max` del símbolo.
- **Control operativo:**
  - Filtro de spread máximo.
  - Ventana horaria opcional (server time).
  - Una sola posición por dirección en el símbolo; usa `MagicNumber` para identificar.
  - El símbolo se toma de `InpSymbol`; si está vacío, usa el símbolo del gráfico. No es multi-símbolo.

## Parámetros principales
- `Symbol` (string, vacío = gráfico), `Timeframe` (H1 default).
- `RiskPercent`, `SL_ATR_mult`, `TP_ATR_mult`, `Trail_ATR_mult`, `UseTrailing`.
- `RSI_Period`, `RSI_BuyLevel`, `RSI_SellLevel`.
- `EMASlow` / `EMAFast` (200 / 20).
- `MaxSpreadPoints`.
- `UseTradingWindow`, `TradeHourStart`, `TradeHourEnd`.
- `MagicNumber`.

## Métricas OnTester
Calcula: profit factor, max drawdown %, recovery factor, winrate, payoff ratio, número de trades, profit medio por trade, Sharpe (si disponible). Fitness: `(profitFactor * winrate) / (1 + maxDD)`.

## Notas de uso
- Diseñado para H1; funciona en otros TF ajustando niveles.
- Símbolo único para evitar complejidad en backtests. Ajustar spread en puntos (5 dígitos: 20 puntos ≈ 2.0 pips).
- Colocar .set en `00_setup/Instancias/instancia_01/instalacion/MQL5/Profiles/Tester/` con el mismo nombre del EA.
