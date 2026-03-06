//+------------------------------------------------------------------+
//| EA_Atlas_Pullback_v1                                            |
//| Pullback a EMA20 con filtro de tendencia EMA200 y confirmación   |
//| RSI; gestión basada en ATR con trailing y break-even opcionales. |
//+------------------------------------------------------------------+
#property copyright "agente"
#property version   "1.000"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//--- Parámetros de entrada
input string  InpSymbol            = "";          // Símbolo (vacío = gráfico)
input int     InpMagic             = 20260306;    // Magic number
input double  InpRiskPercent       = 1.0;         // Riesgo % por operación
input double  InpSL_ATR_Mult       = 1.5;         // Multiplicador ATR para SL
input double  InpTP_ATR_Mult       = 2.5;         // Multiplicador ATR para TP
input double  InpTrailStartMult    = 1.0;         // Activación trailing (ATR)
input double  InpTrailStepMult     = 0.5;         // Paso trailing (ATR)
input double  InpBreakEvenMult     = 1.2;         // Activación break-even (ATR)
input int     InpFastEMA           = 20;          // EMA pullback
input int     InpSlowEMA           = 200;         // EMA tendencia
input int     InpRSIPeriod         = 14;          // Periodo RSI
input int     InpRSILow            = 45;          // Umbral RSI bajo
input int     InpRSIHigh           = 55;          // Umbral RSI alto
input int     InpATRPeriodFast     = 14;          // ATR rápido
input int     InpATRPeriodSlow     = 50;          // ATR lento (volatilidad)
input int     InpCooldownBars      = 3;           // Velas de enfriamiento
input double  InpMaxSpreadPoints   = 20;          // Spread máximo permitido (puntos)
input double  InpMaxSlippagePoints = 5;           // Desviación máxima (puntos)
input bool    InpUseTimeFilter     = true;        // Usar filtro horario
input int     InpStartHour         = 7;           // Hora inicio (servidor)
input int     InpEndHour           = 20;          // Hora fin (servidor)
input bool    InpUseTrailing       = true;        // Activar trailing
input bool    InpUseBreakEven      = true;        // Activar break-even

//--- Handles
int hFastEMA = INVALID_HANDLE;
int hSlowEMA = INVALID_HANDLE;
int hRSI     = INVALID_HANDLE;
int hATRFast = INVALID_HANDLE;
int hATRSlow = INVALID_HANDLE;

//--- Estado
MqlTick tick;
datetime lastBarTime = 0;
int lastBuyBar  = -1000;
int lastSellBar = -1000;

//+------------------------------------------------------------------+
//| Utilidades                                                       |
//+------------------------------------------------------------------+
string ActiveSymbol()
{
   if(InpSymbol == "" || InpSymbol == NULL) return _Symbol;
   return InpSymbol;
}

bool IsNewBar()
{
   datetime t = iTime(ActiveSymbol(), _Period, 0);
   if(t != lastBarTime)
   {
      lastBarTime = t;
      return true;
   }
   return false;
}

bool TimeAllowed()
{
   if(!InpUseTimeFilter) return true;
   MqlDateTime st;
   TimeToStruct(TimeCurrent(), st);
   int hour = st.hour;
   if(InpStartHour <= InpEndHour)
      return (hour >= InpStartHour && hour < InpEndHour);
   // Ventana que cruza medianoche
   return (hour >= InpStartHour || hour < InpEndHour);
}

bool SpreadOK()
{
   if(!SymbolInfoTick(ActiveSymbol(), tick)) return false;
   double spreadPoints = (tick.ask - tick.bid) / _Point;
   return (spreadPoints <= InpMaxSpreadPoints);
}

double GetBuffer(int handle, int shift)
{
   double value[];
   if(CopyBuffer(handle, 0, shift, 1, value) != 1) return EMPTY_VALUE;
   return value[0];
}

int CurrentBars()
{
   return Bars(ActiveSymbol(), _Period);
}

bool HasPosition(bool isBuy)
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetInteger(POSITION_TYPE) == (isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL))
         return true;
   }
   return false;
}

double PointValue()
{
   double tickValue = SymbolInfoDouble(ActiveSymbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(ActiveSymbol(), SYMBOL_TRADE_TICK_SIZE);
   return (tickSize == 0.0) ? 0.0 : tickValue * (_Point / tickSize);
}

double CalcVolume(double stopDistance)
{
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   double perLotRisk = (stopDistance / _Point) * PointValue();
   if(perLotRisk <= 0.0) return 0.0;

   double vol = riskMoney / perLotRisk;
   double minLot = SymbolInfoDouble(ActiveSymbol(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(ActiveSymbol(), SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(ActiveSymbol(), SYMBOL_VOLUME_STEP);

   vol = MathMax(minLot, MathMin(maxLot, vol));
   int volDigits = 2;
   if(step > 0)
   {
      vol = MathFloor(vol / step) * step;
      volDigits = (int)MathMin(8.0, MathRound(-MathLog10(step)));
   }
   return NormalizeDouble(vol, volDigits);
}

void TrailAndBE()
{
   int total = PositionsTotal();
   for(int i=total-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      long type   = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double atr  = GetBuffer(hATRFast, 0);
      if(atr == EMPTY_VALUE || atr <= 0) continue;

      double desiredSL = sl;
      double move, price;

      if(type == POSITION_TYPE_BUY)
      {
         price = SymbolInfoDouble(ActiveSymbol(), SYMBOL_BID);
         move  = price - open;
         if(InpUseBreakEven && move >= atr * InpBreakEvenMult)
            desiredSL = MathMax(desiredSL, open + _Point);
         if(InpUseTrailing && move >= atr * InpTrailStartMult)
            desiredSL = MathMax(desiredSL, price - atr * InpTrailStepMult);
         if(desiredSL > sl + _Point)
            trade.PositionModify(ticket, NormalizeDouble(desiredSL, _Digits), PositionGetDouble(POSITION_TP));
      }
      else if(type == POSITION_TYPE_SELL)
      {
         price = SymbolInfoDouble(ActiveSymbol(), SYMBOL_ASK);
         move  = open - price;
         if(InpUseBreakEven && move >= atr * InpBreakEvenMult)
            desiredSL = (sl == 0.0 ? open - _Point : MathMin(desiredSL, open - _Point));
         if(InpUseTrailing && move >= atr * InpTrailStartMult)
            desiredSL = (desiredSL == 0.0 ? price + atr * InpTrailStepMult : MathMin(desiredSL, price + atr * InpTrailStepMult));
         if(desiredSL < sl - _Point || sl == 0.0)
            trade.PositionModify(ticket, NormalizeDouble(desiredSL, _Digits), PositionGetDouble(POSITION_TP));
      }
   }
}

//+------------------------------------------------------------------+
//| Entrada                                                          |
//+------------------------------------------------------------------+
void CheckEntries()
{
   if(!IsNewBar()) return; // evaluamos con barras cerradas
   if(!SymbolInfoTick(ActiveSymbol(), tick)) return;
   if(!TimeAllowed()) return;
   if(!SpreadOK()) return;

   // Usamos la última barra cerrada (shift 1) y la previa (shift 2)
   int s1 = 1, s2 = 2;
   double emaFast1 = GetBuffer(hFastEMA, s1);
   double emaFast2 = GetBuffer(hFastEMA, s2);
   double emaSlow1 = GetBuffer(hSlowEMA, s1);
   double emaSlow2 = GetBuffer(hSlowEMA, s2);
   double rsi1     = GetBuffer(hRSI, s1);
   double rsi2     = GetBuffer(hRSI, s2);
   double atrFast  = GetBuffer(hATRFast, s1);
   double atrSlow  = GetBuffer(hATRSlow, s1);
   double close1   = iClose(ActiveSymbol(), _Period, s1);
   double close2   = iClose(ActiveSymbol(), _Period, s2);
   if(emaFast1==EMPTY_VALUE || emaFast2==EMPTY_VALUE || emaSlow1==EMPTY_VALUE || emaSlow2==EMPTY_VALUE ||
      rsi1==EMPTY_VALUE || rsi2==EMPTY_VALUE || atrFast==EMPTY_VALUE || atrSlow==EMPTY_VALUE ||
      close1==EMPTY_VALUE || close2==EMPTY_VALUE)
      return;

   if(atrFast <= 0 || atrFast < 0.5 * atrSlow) return; // evita baja volatilidad

   int bars = CurrentBars();

   //--- Señal BUY (bar cerrada)
   bool trendUp   = (close1 > emaSlow1);
   bool pullBackU = (close2 < emaFast2) && (close1 > emaFast1);
   bool rsiUp     = (rsi2 < InpRSILow && rsi1 > InpRSIHigh);

   if(trendUp && pullBackU && rsiUp && !HasPosition(true) && (bars - lastBuyBar) >= InpCooldownBars)
   {
      double stopDist = atrFast * InpSL_ATR_Mult;
      double volume   = CalcVolume(stopDist);
      if(volume > 0.0)
      {
         double sl = NormalizeDouble(tick.bid - stopDist, _Digits);
         double tp = NormalizeDouble(tick.bid + atrFast * InpTP_ATR_Mult, _Digits);
         if(trade.Buy(volume, ActiveSymbol(), tick.ask, sl, tp, "Atlas Buy"))
            lastBuyBar = bars;
      }
   }

   //--- Señal SELL (bar cerrada)
   bool trendDn   = (close1 < emaSlow1);
   bool pullBackD = (close2 > emaFast2) && (close1 < emaFast1);
   bool rsiDn     = (rsi2 > InpRSIHigh && rsi1 < InpRSILow);

   if(trendDn && pullBackD && rsiDn && !HasPosition(false) && (bars - lastSellBar) >= InpCooldownBars)
   {
      double stopDist = atrFast * InpSL_ATR_Mult;
      double volume   = CalcVolume(stopDist);
      if(volume > 0.0)
      {
         double sl = NormalizeDouble(tick.ask + stopDist, _Digits);
         double tp = NormalizeDouble(tick.ask - atrFast * InpTP_ATR_Mult, _Digits);
         if(trade.Sell(volume, ActiveSymbol(), tick.bid, sl, tp, "Atlas Sell"))
            lastSellBar = bars;
      }
   }
}

//+------------------------------------------------------------------+
//| OnInit / OnDeinit                                                |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpRSILow >= InpRSIHigh)
   {
      Print("Error: InpRSILow debe ser menor que InpRSIHigh");
      return(INIT_PARAMETERS_INCORRECT);
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints((int)InpMaxSlippagePoints);

   hFastEMA = iMA(ActiveSymbol(), _Period, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlowEMA = iMA(ActiveSymbol(), _Period, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hRSI     = iRSI(ActiveSymbol(), _Period, InpRSIPeriod, PRICE_CLOSE);
   hATRFast = iATR(ActiveSymbol(), _Period, InpATRPeriodFast);
   hATRSlow = iATR(ActiveSymbol(), _Period, InpATRPeriodSlow);

   if(hFastEMA==INVALID_HANDLE || hSlowEMA==INVALID_HANDLE || hRSI==INVALID_HANDLE ||
      hATRFast==INVALID_HANDLE || hATRSlow==INVALID_HANDLE)
   {
      Print("No se pudieron crear los indicadores.");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   IndicatorRelease(hFastEMA);
   IndicatorRelease(hSlowEMA);
   IndicatorRelease(hRSI);
   IndicatorRelease(hATRFast);
   IndicatorRelease(hATRSlow);
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   TrailAndBE();
   CheckEntries();
}

//+------------------------------------------------------------------+
//| Métricas personalizadas para optimización                        |
//+------------------------------------------------------------------+
double OnTester()
{
   double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
   double ddAbs        = 0.0;
   double ddRel        = 0.0;
   double recovery     = TesterStatistics(STAT_RECOVERY_FACTOR);
   double expectedPay  = TesterStatistics(STAT_EXPECTED_PAYOFF);
   double tradesTotal  = TesterStatistics(STAT_TRADES);
   double profitTrades = TesterStatistics(STAT_PROFIT_TRADES);
   double lossTrades   = TesterStatistics(STAT_LOSS_TRADES);
   double winrate      = (tradesTotal > 0 ? (profitTrades / tradesTotal) * 100.0 : 0.0);

   // Métricas adicionales desde historial (payoff y avg RR aproximado)
   double sumPos = 0.0, sumNeg = 0.0, rrSum = 0.0;
   int w = 0, l = 0, n = 0;
   ulong deals = HistoryDealsTotal();
   for(uint i=0; i<deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((long)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      if((string)HistoryDealGetString(ticket, DEAL_SYMBOL) != ActiveSymbol()) continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic) continue;

      double p = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_COMMISSION) + HistoryDealGetDouble(ticket, DEAL_SWAP);
      n++;
      if(p > 0){ w++; sumPos += p; }
      else if(p < 0){ l++; sumNeg += p; }
   }

   double payoffRatio = (l > 0 ? (sumPos / MathMax(1, w)) / MathAbs(sumNeg / MathMax(1, l)) : 0.0);
   double avgRR       = (n > 0 ? (sumPos + sumNeg) / MathMax(1, n) : 0.0); // aproximación simple

   double ddRelPerc = (ddRel > 0 ? ddRel : 0.0001);
   double fitness = (profitFactor * winrate) / (1.0 + ddRelPerc);

   PrintFormat("OnTester -> PF: %.2f | DDabs: %.2f | DDrel: %.2f | Recov: %.2f | Win%%: %.2f | Payoff: %.2f | AvgRR: %.2f | Trades: %.0f | ExpPayoff: %.2f | Fitness: %.4f",
               profitFactor, ddAbs, ddRel, recovery, winrate, payoffRatio, avgRR, tradesTotal, expectedPay, fitness);
   return fitness;
}
//+------------------------------------------------------------------+
