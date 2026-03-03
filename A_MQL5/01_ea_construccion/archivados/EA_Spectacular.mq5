//+------------------------------------------------------------------+
//|  EA_Spectacular.mq5                                             |
//|  Tendencial con breakout + gestión por ATR                       |
//|  Generado por asistente Codex                                    |
//+------------------------------------------------------------------+
#property copyright "ezequiel"
#property version   "1.000"
#property strict

#include <Trade/Trade.mqh>

input string   InpSymbol              = "";            // Símbolo a operar (vacío = _Symbol)
input ENUM_TIMEFRAMES InpTF           = PERIOD_H1;     // Marco temporal
input double   InpRiskPerTradePct     = 1.0;           // Riesgo % saldo por trade
input int      InpFastEMA             = 21;            // EMA rápida
input int      InpSlowEMA             = 55;            // EMA lenta
input int      InpBreakoutPeriod      = 50;            // Máximo/mínimo de ruptura
input int      InpATRPeriod           = 14;            // Periodo ATR
input double   InpATR_SL_Mult         = 1.6;           // SL = ATR * mult
input double   InpATR_TP_Mult         = 3.0;           // TP = ATR * mult
input bool     InpUseTrailing         = true;          // Activar trailing por ATR
input double   InpTrailATRMult        = 1.0;           // Trailing = ATR * mult
input double   InpMaxSpreadPips       = 2.5;           // Spread máximo permitido (pips)
input int      InpSlippagePoints      = 5;             // Deslizamiento máximo (points)
input int      InpMagic               = 24032026;      // Magic number

// Handles
int    hFastEMA = INVALID_HANDLE;
int    hSlowEMA = INVALID_HANDLE;
int    hATR     = INVALID_HANDLE;

CTrade trade;
datetime lastBarTime = 0;
string  gSymbol      = "";

string SymbolUsed()
{
   if(InpSymbol == "" || InpSymbol == "_Symbol")
      return _Symbol;
   return InpSymbol;
}

//+------------------------------------------------------------------+
//| Utilidades                                                       |
//+------------------------------------------------------------------+
bool NewBar()
{
   datetime currentBarTime = iTime(gSymbol, InpTF, 0);
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

bool SpreadOK()
{
   double spreadPoints = (SymbolInfoDouble(gSymbol, SYMBOL_ASK) - SymbolInfoDouble(gSymbol, SYMBOL_BID)) / _Point;
   // Conversión dinámica a pips según dígitos
   int digits = (int)SymbolInfoInteger(gSymbol, SYMBOL_DIGITS);
   double pipFactor = (digits == 3 || digits == 5) ? 10.0 : 1.0;
   double spreadPips = spreadPoints / pipFactor;
   return (spreadPips <= InpMaxSpreadPips);
}

bool CopyIndicatorBuffers(double &fast, double &slow, double &atr)
{
   double buf[];
   if(CopyBuffer(hFastEMA, 0, 0, 1, buf) <= 0) return false;
   fast = buf[0];
   if(CopyBuffer(hSlowEMA, 0, 0, 1, buf) <= 0) return false;
   slow = buf[0];
   if(CopyBuffer(hATR,     0, 0, 1, buf)  <= 0) return false;
   atr  = buf[0];
   return true;
}

double HighestHigh(int period)
{
   double hh[];
   if(CopyHigh(gSymbol, InpTF, 1, period, hh) < period) return 0;
   double max = hh[0];
   for(int i=1;i<ArraySize(hh);i++) if(hh[i] > max) max = hh[i];
   return max;
}

double LowestLow(int period)
{
   double ll[];
   if(CopyLow(gSymbol, InpTF, 1, period, ll) < period) return 0;
   double min = ll[0];
   for(int i=1;i<ArraySize(ll);i++) if(ll[i] < min) min = ll[i];
   return min;
}

double PointsToMoney(double points)
{
   double tickValue = SymbolInfoDouble(gSymbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(gSymbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize == 0) return 0;
   return points * (_Point / tickSize) * tickValue;
}

double CalcLotByRisk(double stopPoints)
{
   if(stopPoints <= 0) return 0;
   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney   = balance * InpRiskPerTradePct / 100.0;
   double moneyPerLot = PointsToMoney(stopPoints); // riesgo en divisa por 1 lote
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

void TrailPositions(double atr)
{
   if(!InpUseTrailing) return;
   double trailDistance = atr * InpTrailATRMult;
   double ask = SymbolInfoDouble(gSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(gSymbol, SYMBOL_BID);

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != gSymbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)  != InpMagic) continue;

      long   type     = PositionGetInteger(POSITION_TYPE);
      double priceOp  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl       = PositionGetDouble(POSITION_SL);
      double newSL;

      if(type == POSITION_TYPE_BUY)
      {
         newSL = bid - trailDistance;
         if(newSL > sl && newSL < bid)
            trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
      }
      else if(type == POSITION_TYPE_SELL)
      {
         newSL = ask + trailDistance;
         if((sl == 0 || newSL < sl) && newSL > ask)
            trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
      }
   }
}

bool HasOpenPosition()
{
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)==gSymbol && PositionGetInteger(POSITION_MAGIC)==InpMagic)
         return true;
   }
   return false;
}

// Almacenamos entradas para estimar tiempo medio en posición
struct PositionEntry
{
   ulong     id;
   datetime  time;
   double    volume;
};

int FindEntryIndex(ulong id, PositionEntry &arr[])
{
   for(int i=0;i<ArraySize(arr);i++)
      if(arr[i].id == id) return i;
   return -1;
}

double AverageHoldingSeconds()
{
   if(!HistorySelect(0, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   if(totalDeals == 0) return 0;

   PositionEntry entries[];
   double totalSeconds = 0.0;
   int    closedParts  = 0;

   for(int i=0; i<totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      if(dealSymbol != gSymbol) continue;

      int entryType = (int)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      int dealType  = (int)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) continue;

      ulong posId   = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      datetime dTime= (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);

      if(entryType == DEAL_ENTRY_IN)
      {
         int idx = FindEntryIndex(posId, entries);
         if(idx == -1)
         {
            PositionEntry p;
            p.id = posId; p.time = dTime; p.volume = volume;
            ArrayResize(entries, ArraySize(entries)+1);
            entries[ArraySize(entries)-1] = p;
         }
         else
         {
            entries[idx].volume += volume;
            entries[idx].time = dTime; // tomamos última entrada para netting
         }
      }
      else if(entryType == DEAL_ENTRY_OUT)
      {
         int idx = FindEntryIndex(posId, entries);
         if(idx >= 0)
         {
            double baseVol = entries[idx].volume;
            double weight  = (baseVol > 0) ? MathMin(1.0, volume / baseVol) : 1.0;
            totalSeconds  += (double)(dTime - entries[idx].time) * weight;
            entries[idx].volume -= volume;
            if(entries[idx].volume <= 0)
            {
               // eliminar manteniendo orden compacto
               for(int j=idx; j<ArraySize(entries)-1; j++)
                  entries[j] = entries[j+1];
               ArrayResize(entries, ArraySize(entries)-1);
            }
            closedParts++;
         }
      }
   }

   if(closedParts == 0) return 0;
   return totalSeconds / closedParts;
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   gSymbol = SymbolUsed();
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);

   hFastEMA = iMA(gSymbol, InpTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlowEMA = iMA(gSymbol, InpTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hATR     = iATR(gSymbol, InpTF, InpATRPeriod);

   if(hFastEMA==INVALID_HANDLE || hSlowEMA==INVALID_HANDLE || hATR==INVALID_HANDLE)
   {
      Print("Error creando indicadores");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(hFastEMA);
   IndicatorRelease(hSlowEMA);
   IndicatorRelease(hATR);
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!SpreadOK()) return;
   if(Bars(gSymbol, InpTF) < InpBreakoutPeriod + 10) return;

   double fast, slow, atr;
   if(!CopyIndicatorBuffers(fast, slow, atr)) return;

   TrailPositions(atr);

   if(!NewBar()) return;
   if(HasOpenPosition()) return;

   double hh = HighestHigh(InpBreakoutPeriod);
   double ll = LowestLow(InpBreakoutPeriod);
   double bid = SymbolInfoDouble(gSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(gSymbol, SYMBOL_ASK);

   // Tendencia alcista + ruptura
   if(fast > slow && bid > fast && bid > hh)
   {
      double sl = bid - atr * InpATR_SL_Mult;
      double tp = bid + atr * InpATR_TP_Mult;
      double stopPoints = (bid - sl) / _Point;
      double lots = CalcLotByRisk(stopPoints);
      if(lots > 0)
         trade.Buy(lots, gSymbol, ask, sl, tp, "Breakout long");
   }
   // Tendencia bajista + ruptura
   else if(fast < slow && ask < slow && ask < ll)
   {
      double sl = ask + atr * InpATR_SL_Mult;
      double tp = ask - atr * InpATR_TP_Mult;
      double stopPoints = (sl - ask) / _Point;
      double lots = CalcLotByRisk(stopPoints);
      if(lots > 0)
         trade.Sell(lots, gSymbol, bid, sl, tp, "Breakout short");
   }
}

//+------------------------------------------------------------------+
//| OnTester: métricas y fitness                                     |
//+------------------------------------------------------------------+
double OnTester()
{
   double profitFactor   = TesterStatistics(STAT_PROFIT_FACTOR);
   double maxDDRelPct    = TesterStatistics(STAT_EQUITY_DDREL_PERCENT); // %
   double recovery       = TesterStatistics(STAT_RECOVERY_FACTOR);
   double trades         = TesterStatistics(STAT_TRADES);
   double wins           = TesterStatistics(STAT_PROFIT_TRADES);
   double losses         = MathMax(0.0, trades - wins);
   double grossProfit    = TesterStatistics(STAT_GROSS_PROFIT);
   double grossLoss      = TesterStatistics(STAT_GROSS_LOSS);
   double sharpe         = TesterStatistics(STAT_SHARPE_RATIO);
   double winrate        = (trades > 0) ? (wins / trades) : 0.0;
   double payoff         = TesterStatistics(STAT_EXPECTED_PAYOFF); // dinero medio por trade
   double avgWin         = (wins   > 0) ? grossProfit / wins           : 0.0;
   double avgLoss        = (losses > 0) ? MathAbs(grossLoss) / losses  : 0.0;
   double payoffRatio    = (avgLoss > 0) ? avgWin / avgLoss            : 0.0; // win/loss medio
   double avgRR          = payoffRatio; // RR promedio equivalente
   double avgHoldSec     = AverageHoldingSeconds();

   double pf_safe        = MathMax(0.01, profitFactor);
   double dd_safe        = 1.0 + (maxDDRelPct / 100.0);

   // Fitness: favorece PF, winrate y recuperación; penaliza drawdown
    // Integra Sharpe para premiar estabilidad
   double fitness = (pf_safe * (0.55 * winrate + 0.35 * recovery + 0.10 * sharpe)) / dd_safe;

   PrintFormat("OnTester -> PF: %.2f | MaxDD: %.2f%% | Recov: %.2f | Winrate: %.2f%% | Trades: %.0f | Payoff: %.2f | PayoffRatio: %.2f | AvgRR: %.2f | Sharpe: %.2f | AvgHold: %.1f min | Fitness: %.4f",
               profitFactor, maxDDRelPct, recovery, winrate*100.0, trades, payoff, payoffRatio, avgRR, sharpe, avgHoldSec/60.0, fitness);
   Comment(StringFormat("PF: %.2f | DD: %.2f%% | Rec: %.2f | Win: %.1f%% | Trades: %.0f | Pay: %.2f | PR: %.2f | Sharpe: %.2f | Hold: %.1fmin | Fit: %.4f",
                        profitFactor, maxDDRelPct, recovery, winrate*100.0, trades, payoff, payoffRatio, sharpe, avgHoldSec/60.0, fitness));
   return fitness;
}
