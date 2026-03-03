//+------------------------------------------------------------------+
//|                                           Ea_Con_Antigravity.mq5 |
//|                                  Copyright 2026, Agente Antigravity|
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Agente Antigravity"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Inclusión de la librería de trading
#include <Trade/Trade.mqh>

//--- Parámetros de entrada
input group "--- Filtros de Tendencia ---"
input int      InpEMAFast      = 20;          // Periodos EMA Rápida
input int      InpEMASlow      = 50;          // Periodos EMA Lenta
input int      InpEMATrend     = 200;         // Periodos EMA Tendencia (Filtro)

input group "--- Filtro de Impulso ---"
input int      InpRSIPeriod    = 14;          // Periodos RSI
input int      InpRSIUpper     = 70;          // Nivel Sobrecompra
input int      InpRSILower     = 30;          // Nivel Sobreventa

input group "--- Gestión de Riesgo (ATR) ---"
input int      InpATRPeriod    = 14;          // Periodos ATR
input double   InpATRMultiplierSL = 2.0;      // Multiplicador SL (Volatilidad)
input double   InpATRMultiplierTP = 4.0;      // Multiplicador TP (Ratio 1:2)
input double   InpRiskPercent  = 1.0;         // Riesgo por operación (% del Balance)

input group "--- Configuración General ---"
input int      InpMagicNumber  = 123456;      // Número Mágico
input int      InpStopLevel    = 10;          // Nivel de Stop (pips de seguridad)

//--- Variables Globales
CTrade   trade;
int      handleEMAFast, handleEMASlow, handleEMATrend;
int      handleRSI, handleATR;
double   bufferFast[], bufferSlow[], bufferTrend[], bufferRSI[], bufferATR[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Inicializar handles de indicadores
   handleEMAFast  = iMA(_Symbol, _Period, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   handleEMASlow  = iMA(_Symbol, _Period, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   handleEMATrend = iMA(_Symbol, _Period, InpEMATrend, 0, MODE_EMA, PRICE_CLOSE);
   handleRSI      = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   handleATR      = iATR(_Symbol, _Period, InpATRPeriod);

   // Verificar si los handles se crearon correctamente
   if(handleEMAFast == INVALID_HANDLE || handleEMASlow == INVALID_HANDLE || 
      handleEMATrend == INVALID_HANDLE || handleRSI == INVALID_HANDLE || 
      handleATR == INVALID_HANDLE)
   {
      PrintFormat("Error al crear los indicadores. Error: %d", GetLastError());
      return(INIT_FAILED);
   }

   // Configurar el objeto trade
   trade.SetExpertMagicNumber(InpMagicNumber);

   // Configurar arrays como series (el índice [0] es el más reciente)
   ArraySetAsSeries(bufferFast, true);
   ArraySetAsSeries(bufferSlow, true);
   ArraySetAsSeries(bufferTrend, true);
   ArraySetAsSeries(bufferRSI, true);
   ArraySetAsSeries(bufferATR, true);

   Print("EA AntiGravity iniciado con éxito.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Liberar los handles de memoria
   IndicatorRelease(handleEMAFast);
   IndicatorRelease(handleEMASlow);
   IndicatorRelease(handleEMATrend);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleATR);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Copiar datos de indicadores a los buffers
   if(CopyBuffer(handleEMAFast, 0, 0, 3, bufferFast) < 3) return;
   if(CopyBuffer(handleEMASlow, 0, 0, 3, bufferSlow) < 3) return;
   if(CopyBuffer(handleEMATrend, 0, 0, 3, bufferTrend) < 3) return;
   if(CopyBuffer(handleRSI, 0, 0, 3, bufferRSI) < 3) return;
   if(CopyBuffer(handleATR, 0, 0, 3, bufferATR) < 3) return;

   // Verificar si ya tenemos una posición abierta para este símbolo y Magic Number
   if(PositionSelectByMagic(_Symbol, InpMagicNumber)) return;

   // Lógica de Compra (Buy)
   // 1. Cruce alcista EMA20 > EMA50
   // 2. Precio por encima de EMA200
   // 3. RSI no está en sobrecompra ya (>70)
   bool buyCondition = bufferFast[1] > bufferSlow[1] && bufferFast[2] <= bufferSlow[2] && 
                       SymbolInfoDouble(_Symbol, SYMBOL_BID) > bufferTrend[1] &&
                       bufferRSI[1] < InpRSIUpper;

   if(buyCondition)
   {
      ExecuteTrade(ORDER_TYPE_BUY);
   }

   // Lógica de Venta (Sell)
   // 1. Cruce bajista EMA20 < EMA50
   // 2. Precio por debajo de EMA200
   // 3. RSI no está en sobreventa ya (<30)
   bool sellCondition = bufferFast[1] < bufferSlow[1] && bufferFast[2] >= bufferSlow[2] && 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK) < bufferTrend[1] &&
                        bufferRSI[1] > InpRSILower;

   if(sellCondition)
   {
      ExecuteTrade(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| Ejecución de la operación con gestión de riesgo                  |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE type)
{
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atrValue = bufferATR[1];
   
   // Calcular SL y TP basados en ATR
   double slDistance = atrValue * InpATRMultiplierSL;
   double tpDistance = atrValue * InpATRMultiplierTP;
   
   double sl = (type == ORDER_TYPE_BUY) ? price - slDistance : price + slDistance;
   double tp = (type == ORDER_TYPE_BUY) ? price + tpDistance : price - tpDistance;
   
   // Normalizar niveles de precios
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   sl = NormalizeDouble(MathRound(sl/tickSize) * tickSize, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   tp = NormalizeDouble(MathRound(tp/tickSize) * tickSize, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

   // Calcular Lote basado en riesgo
   double lot = CalculateLotSize(slDistance);
   
   if(lot > 0)
   {
      string comment = "Antigravity EA Entry";
      if(type == ORDER_TYPE_BUY)
         trade.Buy(lot, _Symbol, price, sl, tp, comment);
      else
         trade.Sell(lot, _Symbol, price, sl, tp, comment);
   }
}

//+------------------------------------------------------------------+
//| Cálculo del tamaño del lote basado en el porcentaje de riesgo    |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistanceInPoints)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(slDistanceInPoints <= 0 || tickValue <= 0) return 0;
   
   // Fórmula: Cantidad a arriesgar / (Distancia SL en ticks * Valor del tick)
   double lot = riskAmount / ((slDistanceInPoints / tickSize) * tickValue);
   
   // Ajustar a los límites del broker
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathFloor(lot / step) * step;
   
   if(lot < minLot) lot = 0; // Si el riesgo es demasiado pequeño para el lote mínimo
   if(lot > maxLot) lot = maxLot;
   
   return lot;
}

//+------------------------------------------------------------------+
//| Selección de posición por Magic Number y Símbolo                 |
//+------------------------------------------------------------------+
bool PositionSelectByMagic(string symbol, int magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_MAGIC) == magic)
            return true;
      }
   }
   return false;
}
