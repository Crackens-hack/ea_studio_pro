# 📊 Modelos de Fitness de Alta Precisión (OnTester)

Esta guía define las fórmulas de optimización técnica que los agentes deben implementar. El objetivo es estandarizar la validación de estrategias, eliminando la subjetividad y el ruido estadístico.

---

### 🛡️ 1. El Filtro de Seguridad Universal
Antes de aplicar cualquier modelo, el EA debe superar este umbral de supervivencia. Si no lo hace, el fitness es **0.0**.

| Métrica | Umbral Crítico | Razón |
| :--- | :--- | :--- |
| **Profit Factor** | `<= 1.0` | El sistema no tiene ventaja matemática. |
| **Net Profit** | `<= 0` | El sistema pierde dinero. |
| **Muestra (Trades)** | *Ver tabla de TF* | Evitar el sesgo de suerte en muestras pequeñas. |

---

### ⏱️ 2. Relatividad por Timeframe (TF)
La exigencia de datos cambia según la velocidad del gráfico. El agente debe ajustar los "Guardas" y la "Rampa" según esta tabla:

| Timeframe | Mínimo Trades (Guarda) | Rampa de Escala (Saturación) |
| :--- | :--- | :--- |
| **M1 - M5** | `150` | `MathMin(1.0, trades / 500.0)` |
| **M15 - H1** | `50` | `MathMin(1.0, trades / 200.0)` |
| **H4 - D1** | `25` | `MathMin(1.0, trades / 80.0)` |

---

### 📂 3. Modelos Estratégicos

#### A. Modelo ROBUSTO (Por Defecto)
*   **Contexto**: Intradía (M15-H1). Buscamos equilibrio.
*   **Fórmula**: `(PF * RecoveryFactor * Payoff) * [Rampa_TF] / (1.0 + DrawdownRelativo)`

#### B. Modelo MERCENARIO (Scalpers)
*   **Contexto**: Alta frecuencia. Buscamos eficiencia y WinRate.
*   **Fórmula**: `(PF * WinRate) * [Rampa_TF]`

#### C. Modelo CAZADOR (Trend Following)
*   **Contexto**: Grandes recorridos. Buscamos Payoff Ratio (R:R).
*   **Fórmula**: `(PayoffRatio * RecoveryFactor) * [Rampa_TF] / (1.0 + DrawdownMaximo)`

#### D. Modelo PROFESIONAL (Smoothing)
*   **Contexto**: Gestión de fondos. Buscamos la línea recta.
*   **Fórmula**: `(Profit / DrawdownRelativo) * LR_Correlation`

#### E. Modelo S-CYCLES (Soft Fitness / Gradiente)
*   **Contexto**: Optimización inicial. Buscamos evitar resultados "planchados" permitiendo un gradiente en sets perdedores.
*   **Fórmula**: `(Payoff * RecoveryFactor * Rampa_Consistencia * Profit_Multiplier) / (1.0 + DrawdownRelativo)`
*   **Nota**: `Profit_Multiplier` es 1.0 si `Profit > 0` y 0.5 (penalización) si `Profit <= 0`.

---

### 💻 4. Template de Implementación (Copia/Pega)

```mql5
double OnTester()
{
   // --- 1. Captura de Datos ---
   const int    trades    = (int)TesterStatistics(STAT_TRADES);
   const double profit    = TesterStatistics(STAT_PROFIT);
   const double pf        = TesterStatistics(STAT_PROFIT_FACTOR);
   const double rf        = TesterStatistics(STAT_RECOVERY_FACTOR);
   const double dd_rel    = MathMax(0.0001, TesterStatistics(STAT_EQUITY_DDREL_PERCENT) / 100.0);
   const double g_loss    = MathAbs(TesterStatistics(STAT_GROSS_LOSS));
   const double payoff    = g_loss < 0.0001 ? 0.0 : TesterStatistics(STAT_GROSS_PROFIT) / g_loss;
   const double winrate   = 100.0 * (double)TesterStatistics(STAT_PROFIT_TRADES) / MathMax(1.0, (double)trades);

   // --- 2. Umbrales según Timeframe (Ajustar aquí) ---
   const int    min_trades = 50;  // 50 para H1/M15, 150 para M5, 25 para D1
   const double rampa_div  = 200.0; // 200 para H1/M15, 500 para M5, 80 para D1

   if(trades < min_trades || pf <= 1.0 || profit <= 0) return 0.0;

   // --- 3. Cálculo de Fitness (Modelo ROBUSTO) ---
   double rampa   = MathMin(1.0, (double)trades / rampa_div);
   double fitness = (pf * rf * payoff) * rampa / (1.0 + dd_rel);

   // --- 4. Log de Optimización ---
   PrintFormat("PF=%.2f RF=%.2f Payoff=%.2f WR=%.1f%% Trades=%d DD=%.2f%% Fit=%.4f",
               pf, rf, payoff, winrate, trades, dd_rel * 100.0, fitness);

   return fitness;
}
```

> **Directiva Agente**: Siempre usa este modelo en `OnTester()`. Facilita la toma de decisiones por DuckDB al normalizar los resultados de optimización.
