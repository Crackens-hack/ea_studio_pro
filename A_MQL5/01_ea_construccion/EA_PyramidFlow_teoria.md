# EA_PyramidFlow — Esqueleto de maximización con control de pérdidas

Objetivo
- Maximizar ganancias dejando correr tendencias y controlando pérdidas mediante SL dinámico, TP parcial y piramidación solo a favor.

Lógica de señal (versión base)
- Tendencia: EMA rápida vs EMA lenta; filtro RSI para evitar sobrecompra/sobreventa extrema.
- Pullback: entrada al retomar la dirección tras retroceso (por EMA/RSI o cierre por encima/debajo de EMA rápida).
- Filtro de rango: ADX/ATR opcional para evitar sideways (se podrá activar/desactivar).

Gestión de riesgo y posiciones
- Riesgo por trade: % de balance.
- SL por ATR o swing reciente (parámetro).
- TP1 parcial (ej. 1–1.5R) para cerrar parte y mover SL a BE.
- TP final (ej. 2.5–4R) con trailing opcional.

Pyramiding controlado
- Entrada 1: tamaño base.
- Entrada 2: se activa si el precio avanza +0.5R a favor; tamaño menor (p.ej. 50% de la inicial); SL puede heredarse o ajustarse a último swing/ATR.
- Entrada 3: si avanza +1.0R; tamaño menor (p.ej. 25% de la inicial).
- Máx. capas configurables (0–3). Solo añadir si unrealized > 0 y condiciones siguen vigentes. No añadir tras TP1.
- Exposición total limitada (ej. 1.5× riesgo inicial).

Failsafes
- Spread máximo y horario opcional.
- Límite diario/semanal de pérdida (stop de sesión).

OnTester (mínimos)
- PF, DD%, recovery, winrate, payoff, RR, Sharpe/Sortino si disponible.
- Fitness sugerido: (PF * (0.55*winrate + 0.35*recovery + 0.10*sharpe)) / (1 + DD%/100).

Archivos relacionados
- Código: `EA_PyramidFlow.mq5` (por crear).
- Presets: `EA_PyramidFlow.set` (por crear en `MQL5/Profiles/Tester` de la instancia activa).
- Log de métricas/decisiones: a definir (CSV en MQL5\Files si se habilita).
