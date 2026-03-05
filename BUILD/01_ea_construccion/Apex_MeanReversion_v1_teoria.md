# Apex Mean Reversion v1 - Teoría y Lógica

## 1. Concepto de la Estrategia
Este EA busca explotar los excesos de mercado (sobrecompra/sobreventa) utilizando una combinación de indicadores de impulso y volatilidad. La premisa es que el precio tiende a regresar a su media cuando se aleja significativamente en condiciones de agotamiento.

## 2. Indicadores Utilizados
- **RSI (14)**: Identifica niveles de agotamiento. Umbrales típicos: 70/30 o 80/20.
- **Bollinger Bands (20, 2.0)**: Define el canal de volatilidad. Se busca que el precio cierre fuera de las bandas para confirmar el "exceso".
- **ATR (14)**: Utilizado exclusivamente para el cálculo dinámico de niveles de Stop Loss y Take Profit.

## 3. Reglas de Entrada
- **Compra (Long)**:
    1. El RSI está por debajo del nivel de sobreventa (ej. 30).
    2. El precio (Close[1]) ha cerrado por debajo de la banda inferior de Bollinger.
    3. (Opcional) Apertura de la posición al inicio de la siguiente vela.
- **Venta (Short)**:
    1. El RSI está por encima del nivel de sobrecompra (ej. 70).
    2. El precio (Close[1]) ha cerrado por encima de la banda superior de Bollinger.
    3. Apertura de la posición al inicio de la siguiente vela.

## 4. Gestión de Riesgo (Risk Management)
- **Volumen**: Lote fijo o porcentaje de riesgo basado en el balance.
- **Stop Loss Dinámico**: Basado en un multiplicador del ATR (ej. 1.5 * ATR).
- **Take Profit Dinámico**: Basado en un multiplicador del ATR (ej. 3.0 * ATR) para mantener un RR ratio de 1:2.
- **Breakeven**: Se mueve el SL al precio de entrada cuando el precio alcanza un % del objetivo.
- **Trailing Stop**: Seguimiento del precio basado en ATR o puntos fijos.

## 5. Parámetros de Optimización Clave
- Periodos de RSI y Bollinger.
- Umbrales de sobrecompra/sobreventa.
- Multiplicadores de ATR para SL y TP.
- Filtro horario (opcional para evitar sesiones de baja liquidez o noticias).

## 6. Métrica de Fitness (OnTester)
Se utiliza una métrica combinada:
`Fitness = (Profit Factor * WinRate) / (1 + MaxRelativeDrawdown)`
El objetivo es maximizar el retorno mientras se controla estrictamente el riesgo relativo.
