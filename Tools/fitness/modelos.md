## Modelos de fitness sugeridos

Guía rápida para elegir o copiar fórmulas en `OnTester()`. Todas usan datos del tester (TesterStatistics o cálculos propios) y devuelven un `double`. Ajustá pesos si el EA lo requiere, pero mantené las validaciones tempranas para evitar falsos positivos.

### 0) Reglas comunes (usar en todos)
- Si `trades < 50` → return `0.0`.
- Si `profit_factor <= 1.0` o `profit <= 0` → return `0.0`.
- Usa un mínimo para divisores: `dd_rel = MathMax(0.0001, max_dd_rel); avg_loss = MathMax(0.0001, avg_loss); std_ret = MathMax(0.0001, std_ret);`.
- Logueá métricas clave (PF, RF, payoff, winrate, trades, DD) en `Comment`/`Print` para que queden visibles en optimización.

### 1) Robusto balanceado (plantilla por defecto)
```
fitness = (PF * Recovery * PayoffRatio)
          * MathMin(1.0, trades / 200.0)
          / (1.0 + dd_rel);
```
- Equilibra rentabilidad (PF), capacidad de recuperar pérdidas (Recovery) y calidad de trades (payoff).
- La rampa de trades penaliza muestras chicas; a partir de 200 deja de escalar.
- Usar como primera opción en nuevos EAs.

### 2) Riesgo/retorno clásico (Calmar simplificado)
```
fitness = profit / (1.0 + max_dd_abs);
```
- Útil cuando importa beneficio absoluto con control de drawdown monetario.
- Requiere profits en la divisa de la cuenta; conviene para optimizaciones de retiros fijos.

### 3) Eficiencia operativa
```
fitness = PF * winrate * MathMin(1.0, trades / 150.0);
```
- Favorece sistemas con buena tasa de aciertos y PF, pero sigue castigando pocas operaciones.
- Útil en estrategias de alta frecuencia con spreads bajos.

### 4) Estabilidad temporal
```
fitness = equity_slope / (1.0 + equity_vol);
```
- `equity_slope`: pendiente de regresión lineal sobre equity por trade.
- `equity_vol`: desviación estándar de los residuos (o de retornos por trade).
- Prioriza curvas suaves; requiere calcular arrays de equity.

### 5) Forward-aware simple
```
fitness = back_pf * 0.6 + fwd_pf * 1.4;
```
- Para optimizaciones con forward: pondera más el tramo forward.
- Si el forward falla (`fwd_pf <= 1`), devolver `0` para descartar combinaciones inestables.

### Ejemplo de plantilla `OnTester()`
```mql5
double OnTester()
{
  const int trades    = (int)TesterStatistics(STAT_TRADES);
  const double profit = TesterStatistics(STAT_PROFIT);
  const double pf     = TesterStatistics(STAT_PROFIT_FACTOR);
  const double rf     = TesterStatistics(STAT_RECOVERY_FACTOR);
  const double dd_rel = MathMax(0.0001, TesterStatistics(STAT_EQUITY_DDREL_PERCENT) / 100.0);
  const double gross_loss = MathAbs(TesterStatistics(STAT_LOSS_TRADES));
  const double payoff = gross_loss < 0.0001
                       ? 0.0
                       : TesterStatistics(STAT_PROFIT_TRADES) / gross_loss;

  if(trades < 50 || pf <= 1.0 || profit <= 0) return 0.0;

  double fitness = (pf * rf * payoff) * MathMin(1.0, trades / 200.0) / (1.0 + dd_rel);

  PrintFormat(\"PF=%.2f RF=%.2f Payoff=%.2f Winrate=%.1f%% Trades=%d DDrel=%.2f Fitness=%.4f\",
              pf, rf, payoff,
              100.0 * TesterStatistics(STAT_PROFIT_TRADES) / MathMax(1.0, trades),
              trades, dd_rel, fitness);

  return fitness;
}
```
- Adaptá el bloque central para usar cualquiera de los modelos anteriores.
- Mantén los guardas iniciales y el log para facilitar comparaciones en optimización.

> Nota: evita fórmulas más exóticas salvo requerimiento explícito; los modelos anteriores cubren la mayoría de los casos.
