import os
import re
from bs4 import BeautifulSoup

# Configuración de rutas
htm_file = r'c:\Users\ezequiel\Desktop\.eastudio\DATA\RoboForex-Pro_hub\reports\report_single_full__Apex_MeanReversion_v1.htm'
output_file = r'c:\Users\ezequiel\Desktop\.eastudio\DATA\RoboForex-Pro_hub\reports\RESUMEN__Apex_MeanReversion_v1.md'

def extraer_seccion_inputs(texto):
    match = re.search(r"Inputs:\s+(.*?)(?=Company:|Currency:|Initial Deposit:)", texto, re.DOTALL)
    if match:
        inputs_raw = match.group(1).strip()
        lines = [line.strip() for line in inputs_raw.split("\n") if line.strip() and line.strip() != "="]
        return "\n".join(lines)
    return "No encontrado"

def analizar_y_guardar():
    if not os.path.exists(htm_file):
        print(f"Error: No encontré el archivo {htm_file}")
        return

    try:
        with open(htm_file, 'r', encoding='utf-16') as f:
            content = f.read()
        
        soup = BeautifulSoup(content, 'html.parser')
        texto = soup.get_text(separator='  ') 

        # 1. EXTRACCIÓN DE SETTINGS
        settings_patterns = {
            "Expert": r"Expert:\s+(.*)",
            "Symbol": r"Symbol:\s+(.*)",
            "Period": r"Period:\s+(.*)",
            "History Quality": r"History Quality:\s+([\d%]+)",
            "Bars": r"Bars:\s+(\d+)",
            "Ticks": r"Ticks:\s+(\d+)",
            "Initial Deposit": r"Initial Deposit:\s+([\d\s\.,-]+)",
            "Leverage": r"Leverage:\s+([\d:]+)"
        }
        
        resumen_set = {}
        for k, p in settings_patterns.items():
            m = re.search(p, texto)
            resumen_set[k] = m.group(1).strip() if m else "N/A"
        
        inputs_utilizados = extraer_seccion_inputs(texto)

        # 2. PATRONES DE RESULTADOS (Regex mejorado)
        patrones = {
            # Financieros
            "Net Profit": r"Total Net Profit:\s+([\d\s\.,-]+)",
            "Gross Profit": r"Gross Profit:\s+([\d\s\.,-]+)",
            "Gross Loss": r"Gross Loss:\s+([\d\s\.,-]+)",
            
            # Drawdowns Balance
            "DD Bal Abs": r"Balance Drawdown Absolute:\s+([\d\s\.,-]+)",
            "DD Bal Max": r"Balance Drawdown Maximal:\s+([\d\s\.,-]+\s+\(.*?%\))",
            "DD Bal Rel": r"Balance Drawdown Relative:\s+([\d\s\.,%]+\s+\(.*?[\d\s\.,-]+\))",
            
            # Drawdowns Equity
            "DD Eq Abs": r"Equity Drawdown Absolute:\s+([\d\s\.,-]+)",
            "DD Eq Max": r"Equity Drawdown Maximal:\s+([\d\s\.,-]+\s+\(.*?%\))",
            "DD Eq Rel": r"Equity Drawdown Relative:\s+([\d\s\.,%]+\s+\(.*?[\d\s\.,-]+\))",
            
            # Ratios
            "Profit Factor": r"Profit Factor:\s+([\d\s\.,-]+)",
            "Expected Payoff": r"Expected Payoff:\s+([\d\s\.,-]+)",
            "Recovery Factor": r"Recovery Factor:\s+([\d\s\.,-]+)",
            "Sharpe Ratio": r"Sharpe Ratio:\s+([\d\s\.,-]+)",
            "Z-Score": r"Z-Score:\s+([\d\s\.,-]+\s+\(.*?%\))",
            "Margin Level": r"Margin Level:\s+([\d\s\.,%-]+)",
            
            # Estadísticas Avanzadas
            "AHPR": r"AHPR:\s+([\d\s\.,-]+\s+\(.*?%\))",
            "GHPR": r"GHPR:\s+([\d\s\.,-]+\s+\(.*?%\))",
            "LR Correlation": r"LR Correlation:\s+([\d\s\.,-]+)",
            "LR Std Error": r"LR Standard Error:\s+([\d\s\.,-]+)",
            "OnTester": r"OnTester result:\s+([\d\s\.,-]+)",
            
            # Operativa
            "Total Trades": r"Total Trades:\s+(\d+)",
            "Total Deals": r"Total Deals:\s+(\d+)",
            "Short Won": r"Short Trades \(won %\):\s+\d+\s+\((.*?)\)",
            "Long Won": r"Long Trades \(won %\):\s+\d+\s+\((.*?)\)",
            "Profit Trades Pct": r"Profit Trades \(% of total\):\s+\d+\s+\((.*?)\)",
            "Loss Trades Pct": r"Loss Trades \(% of total\):\s+\d+\s+\((.*?)\)",
            
            # Operaciones Extremas
            "Largest Profit": r"Largest profit trade:\s+([\d\s\.,-]+)",
            "Largest Loss": r"Largest loss trade:\s+([\d\s\.,-]+)",
            "Average Profit": r"Average profit trade:\s+([\d\s\.,-]+)",
            "Average Loss": r"Average loss trade:\s+([\d\s\.,-]+)",
            
            # Rachas
            "Consec Wins $": r"Maximum consecutive wins \(\$\):\s+([\d\s\.,-]+\s+\(.*?[\d\s\.,-]+\))",
            "Consec Loss $": r"Maximum consecutive losses \(\$\):\s+([\d\s\.,-]+\s+\(.*?[\d\s\.,-]+\))",
            "Consec Profit Count": r"Maximal consecutive profit \(count\):\s+([\d\s\.,-]+\s+\(\d+\))",
            "Consec Loss Count": r"Maximal consecutive loss \(count\):\s+([\d\s\.,-]+\s+\(\d+\))",
            "Avg Wins": r"Average consecutive wins:\s+(\d+)",
            "Avg Loss": r"Average consecutive losses:\s+(\d+)",
            
            # Correlaciones
            "Corr Profits MFE": r"Correlation \(Profits,MFE\):\s+([\d\s\.,-]+)",
            "Corr Profits MAE": r"Correlation \(Profits,MAE\):\s+([\d\s\.,-]+)",
            "Corr MFE MAE": r"Correlation \(MFE,MAE\):\s+([\d\s\.,-]+)",
            
            # Tiempos
            "Min Hold": r"Minimal position holding time:\s+([\d:]+)",
            "Max Hold": r"Maximal position holding time:\s+([\d:]+)",
            "Avg Hold": r"Average position holding time:\s+([\d:]+)"
        }

        res = {}
        for k, p in patrones.items():
            m = re.search(p, texto, re.IGNORECASE)
            res[k] = m.group(1).strip() if m else "N/A"

        # 3. GENERACIÓN DEL MARKDOWN "PREMIUM"
        markdown = f"""# 📊 INFORME DE ESTRATEGIA: {resumen_set['Expert']}
---
## 📋 DATOS GENERALES DEL ESTRATEGIA
*   **Símbolo:** {resumen_set['Symbol']}
*   **Periodo:** {resumen_set['Period']}
*   **Calidad de Historia:** {resumen_set['History Quality']}
*   **Barras / Ticks:** {resumen_set['Bars']} / {resumen_set['Ticks']}
*   **Depósito Inicial:** {resumen_set['Initial Deposit']}
*   **Apalancamiento:** {resumen_set['Leverage']}

---

## ⚙️ CONFIGURACIÓN DE PARÁMETROS (Inputs)
```ini
{inputs_utilizados}
```

---

## 💰 RENDIMIENTO FINANCIERO
*   **Beneficio Neto Total:** $ **{res['Net Profit']}**
*   **Beneficio Bruto:** $ {res['Gross Profit']} | **Pérdida Bruta:** $ {res['Gross Loss']}
*   **Profit Factor:** **{res['Profit Factor']}** | **Expected Payoff:** {res['Expected Payoff']}
*   **Sharpe Ratio:** {res['Sharpe Ratio']} | **Recovery Factor:** {res['Recovery Factor']}
*   **Resultado del Tester (OnTester):** {res['OnTester']}

### Métricas de Estabilidad
*   **Z-Score:** {res['Z-Score']}
*   **AHPR / GHPR:** {res['AHPR']} / {res['GHPR']}
*   **Correlación LR / Error Estándar:** {res['LR Correlation']} / {res['LR Std Error']}
*   **Margen Mínimo:** {res['Margin Level']}

---

## 🛡️ ANÁLISIS DE RIESGO (DRAWDOWN)
| Tipo | Absoluto | Máximo | Relativo |
| :--- | :--- | :--- | :--- |
| **Balance** | $ {res['DD Bal Abs']} | $ {res['DD Bal Max']} | {res['DD Bal Rel']} |
| **Equity**  | $ {res['DD Eq Abs']} | $ **{res['DD Eq Max']}** | {res['DD Eq Rel']} |

---

## 🎯 ESTADÍSTICAS OPERATIVAS
*   **Total Trades / Deals:** {res['Total Trades']} / {res['Total Deals']}
*   **Win Rate Total:** **{res['Profit Trades Pct']}**
*   **Trades Perdedores:** {res['Loss Trades Pct']}
*   **Efectividad Shorts (Sell):** {res['Short Won']}
*   **Efectividad Longs (Buy):**  {res['Long Won']}

### Análisis de Operaciones
*   **Mayor Ganancia / Pérdida:** $ {res['Largest Profit']} / $ {res['Largest Loss']}
*   **Promedio Ganancia / Pérdida:** $ {res['Average Profit']} / $ {res['Average Loss']}

### Análisis de Rachas Consecutivas
*   **Máximo Profit (USD / Conteo):** {res['Consec Profit Count']} / $ {res['Consec Wins $']}
*   **Máximo Loss (USD / Conteo):**  {res['Consec Loss Count']} / $ {res['Consec Loss $']}
*   **Promedio de Rachas (Ganadas/Perdidas):** {res['Avg Wins']} / {res['Avg Loss']}

---

## 📉 CORRELACIONES Y TIEMPOS
*   **Correlación (Profits, MFE):** {res['Corr Profits MFE']}
*   **Correlación (Profits, MAE):** {res['Corr Profits MAE']}
*   **Correlación (MFE, MAE):** {res['Corr MFE MAE']}

### Tiempo de Retención (Holding Time)
*   **Mínimo:** {res['Min Hold']}
*   **Máximo:** {res['Max Hold']}
*   **Promedio:** {res['Avg Hold']}

---
*Reporte Técnico Generado para Apex Trading Studio - AI Agent*
"""

        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(markdown)

        print(f"\n✅ ¡INFORME COMPLETO GENERADO!")
        print(f"📦 Resumen disponible en: {output_file}")

    except Exception as e:
        print(f"Error procesando el reporte: {e}")

if __name__ == "__main__":
    analizar_y_guardar()
