import pandas as pd
import numpy as np

csv_file = r'c:\Users\ezequiel\Desktop\.eastudio\DATA\RoboForex-Pro_hub\reports\report_genetic__Apex_MeanReversion_v1.csv'

try:
    df = pd.read_csv(csv_file)
    
    # Asegurarnos de que las columnas sean numéricas
    cols_to_fix = ['Result', 'Profit', 'Profit Factor', 'Recovery Factor', 'Equity DD %', 'Trades']
    for col in cols_to_fix:
        df[col] = pd.to_numeric(df[col], errors='coerce')

    print("--- ANÁLISIS DE OPTIMIZACIÓN GENÉTICA ---")
    print(f"Total de pasadas analizadas: {len(df)}")

    # 1. Top 5 por Fitness (Custom Result) - Con al menos 15 trades
    print("\n[TOP 5 POR FITNESS (Trades >= 15)]")
    top_fitness = df[df['Trades'] >= 15].sort_values(by='Result', ascending=False).head(5)
    print(top_fitness[['Pass', 'Result', 'Profit', 'Equity DD %', 'Trades', 'InpRSI_Period', 'InpBB_Period', 'InpStopLoss_ATR']])

    # 2. Top 5 por Mayor Cantidad de Trades (para ver robustez)
    print("\n[TOP 5 POR VOLUMEN (Trades >= 30)]")
    top_volume = df[df['Trades'] >= 30].sort_values(by='Result', ascending=False).head(5)
    if not top_volume.empty:
      print(top_volume[['Pass', 'Result', 'Profit', 'Equity DD %', 'Trades', 'InpRSI_Period', 'InpBB_Period', 'InpStopLoss_ATR']])
    else:
      print("No hay pasadas con >= 30 trades.")

    # 3. Top 5 por Recovery Factor (Profit / Drawdown)
    print("\n[TOP 5 POR RECOVERY FACTOR (Trades >= 15)]")
    top_recovery = df[df['Trades'] >= 15].sort_values(by='Recovery Factor', ascending=False).head(5)
    print(top_recovery[['Pass', 'Recovery Factor', 'Profit', 'Equity DD %', 'Trades', 'InpRSI_Period', 'InpBB_Period']])

    # 4. Estadísticas promedio de los mejores sets (Top 10%)
    top_10_percent = df.nlargest(int(len(df) * 0.1), 'Result')
    print("\n--- RANGOS OPTIMOS SUGERIDOS (Promedio Top 10%) ---")
    print(f"RSI Period: {top_10_percent['InpRSI_Period'].mean():.1f}")
    print(f"BB Period: {top_10_percent['InpBB_Period'].mean():.1f}")
    print(f"BB Deviation: {top_10_percent['InpBB_Deviation'].mean():.1f}")
    print(f"SL ATR Multiplier: {top_10_percent['InpStopLoss_ATR'].mean():.1f}")
    print(f"TP ATR Multiplier: {top_10_percent['InpTakeProfit_ATR'].mean():.1f}")
    print(f"Trailing Start: {top_10_percent['InpTrailingStart'].mean():.1f}")

except Exception as e:
    print(f"Error analizando datos: {e}")
