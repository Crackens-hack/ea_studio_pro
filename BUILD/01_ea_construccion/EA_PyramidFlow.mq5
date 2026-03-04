//+------------------------------------------------------------------+
//|  EA_PyramidFlow.mq5                                             |
//|  Esqueleto: tendencia + pullback + pyramiding controlado          |
//|  Generado por asistente Codex                                     |
//+------------------------------------------------------------------+
#property copyright "ezequiel"
#property version   "1.000"
#property strict

#include <Trade/Trade.mqh>

//-------------------- Inputs principales ---------------------------//
input string   InpSymbol              = "";            // Símbolo (vacío = _Symbol)
input ENUM_TIMEFRAMES InpTF           = PERIOD_M15;    // Marco temporal
input double   InpRiskPerTradePct     = 1.0;           // Riesgo % saldo trade base
input int      InpFastEMA             = 21;            // EMA rápida
input int      InpSlowEMA             = 89;            // EMA lenta
input int      InpRSIPeriod           = 14;            // Periodo RSI filtro
input double   InpRSIHigh             = 65.0;          // Umbral sobrecompra
input double   InpRSILow              = 35.0;          // Umbral sobreventa
input int      InpATRPeriod           = 14;            // Periodo ATR
input double   InpSL_ATR_Mult         = 1.6;           // SL = ATR * mult
input double   InpTP1_R_Mult          = 1.2;           // TP1 en múltiplos de R
input double   InpTP_Final_R_Mult     = 3.0;           // TP final en R
input bool     InpUseTrailing         = true;          // Trailing en runner
input double   InpTrailATRMult        = 1.0;           // Trailing = ATR * mult
input int      InpMaxLayers           = 2;             // Capas extra (0-2)
input double   InpLayer2_SizePct      = 50.0;          // % de lote vs capa base
input double   InpLayer3_SizePct      = 25.0;          // % de lote vs capa base
input double   InpLayer2_TriggerR     = 0.5;           // Activar capa2 a +0.5R
input double   InpLayer3_TriggerR     = 1.0;           // Activar capa3 a +1.0R
input double   InpMaxSpreadPips       = 2.5;           // Spread máximo (pips)
input int      InpSlippagePoints      = 5;             // Slippage (points)
input int      InpMagic               = 24032028;      // Magic

//-------------------- Handles e instancias -------------------------//
int    hFastEMA = INVALID_HANDLE;
int    hSlowEMA = INVALID_HANDLE;
int    hRSI     = INVALID_HANDLE;
int    hATR     = INVALID_HANDLE;

CTrade trade;
datetime lastBarTime = 0;
string  gSymbol      = "";

//-------------------- Utilidades -----------------------------------//
string SymbolUsed()
{
   if(InpSymbol == "" || InpSymbol == "_Symbol")
      return _Symbol;
   return InpSymbol;
}

bool NewBar()
{
   datetime t = iTime(gSymbol, InpTF, 0);
   if(t != lastBarTime){ lastBarTime = t; return true; }
   return false;
}

bool SpreadOK()
{
   double spreadPoints = (SymbolInfoDouble(gSymbol, SYMBOL_ASK) - SymbolInfoDouble(gSymbol, SYMBOL_BID)) / _Point;
   int digits = (int)SymbolInfoInteger(gSymbol, SYMBOL_DIGITS);
   double pipFactor = (digits == 3 || digits == 5) ? 10.0 : 1.0;
   double spreadPips = spreadPoints / pipFactor;
   return (spreadPips <= InpMaxSpreadPips);
}

bool CopyIndicators(double &fast0, double &slow0, double &rsi0, double &atr0)
{
   double buf[];
   if(CopyBuffer(hFastEMA,0,0,1,buf)<1) return false; fast0 = buf[0];
   if(CopyBuffer(hSlowEMA,0,0,1,buf)<1) return false; slow0 = buf[0];
   if(CopyBuffer(hRSI,    0,0,1,buf)<1) return false; rsi0  = buf[0];
   if(CopyBuffer(hATR,    0,0,1,buf)<1) return false; atr0  = buf[0];
   return true;
}

double PointsToMoney(double points)
{
   double tickValue = SymbolInfoDouble(gSymbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(gSymbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize == 0) return 0;
   return points * (_Point / tickSize) * tickValue;
}

double CalcLotByRisk(double stopPoints, double riskPct)
{
   if(stopPoints <= 0) return 0;
   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney   = balance * riskPct / 100.0;
   double moneyPerLot = PointsToMoney(stopPoints);
   if(moneyPerLot <= 0) return 0;
   double lots = riskMoney / moneyPerLot;

   double minLot  = SymbolInfoDouble(gSymbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(gSymbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(gSymbol, SYMBOL_VOLUME_STEP);
   lots = MathMax(minLot, MathMin(maxLot, lots));
   int volDigits = (lotStep > 0) ? (int)MathRound(-MathLog10(lotStep)) : 2;
   lots = NormalizeDouble(MathFloor(lots / lotStep) * lotStep, volDigits);
   return lots;
}

//-------------------- Gestión de capas -----------------------------//
struct LayerState
{
   int    idx;
   bool   active;
   double triggerR;
   double sizePct;
};

LayerState layers[3];

void InitLayers()
{
   layers[0].idx = 0; layers[0].active = true;  layers[0].triggerR = 0;            layers[0].sizePct = 100.0;
   layers[1].idx = 1; layers[1].active = false; layers[1].triggerR = InpLayer2_TriggerR; layers[1].sizePct = InpLayer2_SizePct;
   layers[2].idx = 2; layers[2].active = false; layers[2].triggerR = InpLayer3_TriggerR; layers[2].sizePct = InpLayer3_SizePct;
}

int ActiveLayers()
{
   int n=0; for(int i=0;i<3;i++) if(layers[i].active) n++; return n;
}

//-------------------- Señal ----------------------------------------//
bool TrendUp(double fast0, double slow0){ return fast0 > slow0; }
bool TrendDown(double fast0, double slow0){ return fast0 < slow0; }

bool AllowLong(double rsi0){ return rsi0 <= InpRSIHigh; }
bool AllowShort(double rsi0){ return rsi0 >= InpRSILow; }

//-------------------- OnInit ---------------------------------------//
int OnInit()
{
   gSymbol = SymbolUsed();
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);

   hFastEMA = iMA(gSymbol, InpTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlowEMA = iMA(gSymbol, InpTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hRSI     = iRSI(gSymbol, InpTF, InpRSIPeriod, PRICE_CLOSE);
   hATR     = iATR(gSymbol, InpTF, InpATRPeriod);

   if(hFastEMA==INVALID_HANDLE || hSlowEMA==INVALID_HANDLE || hRSI==INVALID_HANDLE || hATR==INVALID_HANDLE)
   {
      Print("Error creando indicadores");
      return(INIT_FAILED);
   }

   InitLayers();
   return(INIT_SUCCEEDED);
}

//-------------------- OnDeinit -------------------------------------//
void OnDeinit(const int reason)
{
   IndicatorRelease(hFastEMA);
   IndicatorRelease(hSlowEMA);
   IndicatorRelease(hRSI);
   IndicatorRelease(hATR);
}

//-------------------- Helpers de órdenes ---------------------------//
int PositionsByMagic()
{
   int c=0;
   for(int i=0;i<PositionsTotal();i++)
      if(PositionSelectByTicket(PositionGetTicket(i)) &&
         PositionGetString(POSITION_SYMBOL)==gSymbol &&
         PositionGetInteger(POSITION_MAGIC)==InpMagic) c++;
   return c;
}

double EntryPriceByIndex(int idx)
{
   if(!PositionSelectByTicket(PositionGetTicket(idx))) return 0;
   return PositionGetDouble(POSITION_PRICE_OPEN);
}

//-------------------- OnTick ---------------------------------------//
void OnTick()
{
   if(!SpreadOK()) return;
   if(Bars(gSymbol, InpTF) < MathMax(InpSlowEMA, InpATRPeriod)+10) return;

   double fast0, slow0, rsi0, atr0;
   if(!CopyIndicators(fast0, slow0, rsi0, atr0)) return;

   double bid = SymbolInfoDouble(gSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(gSymbol, SYMBOL_ASK);
   bool up   = TrendUp(fast0, slow0) && AllowLong(rsi0);
   bool down = TrendDown(fast0, slow0) && AllowShort(rsi0);

   // Gestión de trailing en posiciones existentes (simplificado)
   if(InpUseTrailing)
   {
      double trail = atr0 * InpTrailATRMult;
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL)!=gSymbol || PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;

         long   type = PositionGetInteger(POSITION_TYPE);
         double sl   = PositionGetDouble(POSITION_SL);
         double tp   = PositionGetDouble(POSITION_TP);

         if(type==POSITION_TYPE_BUY)
         {
            double newSL = bid - trail;
            if(newSL > sl && newSL < bid)
               trade.PositionModify(ticket, newSL, tp);
         }
         else if(type==POSITION_TYPE_SELL)
         {
            double newSL = ask + trail;
            if((sl==0 || newSL < sl) && newSL > ask)
               trade.PositionModify(ticket, newSL, tp);
         }
      }
   }

   if(!NewBar()) return;

   int openCount = PositionsByMagic();
   double stopPoints = (InpSL_ATR_Mult * atr0) / _Point;

   // Señal de entrada inicial
   if(openCount==0)
   {
      if(up)
      {
         double sl = bid - atr0*InpSL_ATR_Mult;
         double tp1= bid + InpTP1_R_Mult * (atr0*InpSL_ATR_Mult);
         double tpF= bid + InpTP_Final_R_Mult * (atr0*InpSL_ATR_Mult);
         double lots = CalcLotByRisk(stopPoints, InpRiskPerTradePct);
         if(lots>0) trade.Buy(lots, gSymbol, ask, sl, tpF, "Base long");
      }
      else if(down)
      {
         double sl = ask + atr0*InpSL_ATR_Mult;
         double tp1= ask - InpTP1_R_Mult * (atr0*InpSL_ATR_Mult);
         double tpF= ask - InpTP_Final_R_Mult * (atr0*InpSL_ATR_Mult);
         double lots = CalcLotByRisk(stopPoints, InpRiskPerTradePct);
         if(lots>0) trade.Sell(lots, gSymbol, bid, sl, tpF, "Base short");
      }
      return;
   }

   // Piramidación: solo si ya hay ganancia flotante y capas disponibles
   // Simplificación: usa primera posición como referencia
   if(openCount > 0)
   {
      double avgPrice = PositionSelect(gSymbol) && PositionGetInteger(POSITION_MAGIC)==InpMagic
                        ? PositionGetDouble(POSITION_PRICE_OPEN) : 0;
      if(avgPrice==0) return;

      long type0 = PositionGetInteger(POSITION_TYPE);
      double rNow;
      if(type0==POSITION_TYPE_BUY)
         rNow = (bid - avgPrice) / (atr0*InpSL_ATR_Mult);
      else
         rNow = (avgPrice - ask) / (atr0*InpSL_ATR_Mult);

      // Activar capas según triggers
      if(InpMaxLayers>=1 && rNow >= InpLayer2_TriggerR && ActiveLayers()<2 && up)
      {
         double lot = CalcLotByRisk(stopPoints, InpRiskPerTradePct * InpLayer2_SizePct/100.0);
         if(lot>0)
         {
            if(type0==POSITION_TYPE_BUY) trade.Buy(lot, gSymbol, ask, bid - atr0*InpSL_ATR_Mult, 0, "Layer2 long");
            else                         trade.Sell(lot, gSymbol, bid, ask + atr0*InpSL_ATR_Mult, 0, "Layer2 short");
            layers[1].active = true;
         }
      }
      if(InpMaxLayers>=2 && rNow >= InpLayer3_TriggerR && ActiveLayers()<3 && up)
      {
         double lot = CalcLotByRisk(stopPoints, InpRiskPerTradePct * InpLayer3_SizePct/100.0);
         if(lot>0)
         {
            if(type0==POSITION_TYPE_BUY) trade.Buy(lot, gSymbol, ask, bid - atr0*InpSL_ATR_Mult, 0, "Layer3 long");
            else                         trade.Sell(lot, gSymbol, bid, ask + atr0*InpSL_ATR_Mult, 0, "Layer3 short");
            layers[2].active = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| OnTester: métricas y fitness                                     |
//+------------------------------------------------------------------+
double OnTester()
{
   double profitFactor   = TesterStatistics(STAT_PROFIT_FACTOR);
   double maxDDRelPct    = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double recovery       = TesterStatistics(STAT_RECOVERY_FACTOR);
   double trades         = TesterStatistics(STAT_TRADES);
   double wins           = TesterStatistics(STAT_PROFIT_TRADES);
   double losses         = MathMax(0.0, trades - wins);
   double grossProfit    = TesterStatistics(STAT_GROSS_PROFIT);
   double grossLoss      = TesterStatistics(STAT_GROSS_LOSS);
   double sharpe         = TesterStatistics(STAT_SHARPE_RATIO);
   double winrate        = (trades > 0) ? (wins / trades) : 0.0;
   double payoff         = TesterStatistics(STAT_EXPECTED_PAYOFF);
   double avgWin         = (wins   > 0) ? grossProfit / wins           : 0.0;
   double avgLoss        = (losses > 0) ? MathAbs(grossLoss) / losses  : 0.0;
   double payoffRatio    = (avgLoss > 0) ? avgWin / avgLoss            : 0.0;
   double avgRR          = payoffRatio;

   double pf_safe        = MathMax(0.01, profitFactor);
   double dd_safe        = 1.0 + (maxDDRelPct / 100.0);

   double fitness = (pf_safe * (0.55 * winrate + 0.35 * recovery + 0.10 * sharpe)) / dd_safe;

   PrintFormat("OnTester -> PF: %.2f | MaxDD: %.2f%% | Recov: %.2f | Win: %.2f%% | Trades: %.0f | Payoff: %.2f | PR: %.2f | Sharpe: %.2f | Fit: %.4f",
               profitFactor, maxDDRelPct, recovery, winrate*100.0, trades, payoff, payoffRatio, sharpe, fitness);
   Comment(StringFormat("PF: %.2f | DD: %.2f%% | Rec: %.2f | Win: %.1f%% | Trades: %.0f | Pay: %.2f | PR: %.2f | Sharpe: %.2f | Fit: %.4f",
                        profitFactor, maxDDRelPct, recovery, winrate*100.0, trades, payoff, payoffRatio, sharpe, fitness));
   return fitness;
}
