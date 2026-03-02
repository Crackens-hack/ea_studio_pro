#property copyright "Demo"
#property link      "https://example.local"
#property version   "1.00"
#property strict

// EA de ejemplo orientado a métricas y pruebas de backtest.
// Estrategia simple: cruce de medias, una posición a la vez por símbolo.
// Incluye trailing stop, control de riesgo por trade y reporte de métricas en OnTester.

#include <Trade/Trade.mqh>

input int    FastMAPeriod     = 12;
input int    SlowMAPeriod     = 26;
input double RiskPerTradePct  = 1.0;      // % del balance
input int    StopLossPips     = 200;      // SL en puntos (pips de 5 dígitos = 10 puntos)
input int    TakeProfitPips   = 400;      // TP en puntos
input int    TrailingPips     = 150;      // trailing en puntos (0 para desactivar)
input int    MaxTradesPerDay  = 3;
input ulong  Magic            = 27042026;

CTrade trade;
datetime lastTradeDay = 0;
int tradesToday = 0;
int fastHandle = INVALID_HANDLE;
int slowHandle = INVALID_HANDLE;

datetime DayStart(datetime t)
{
   MqlDateTime m;
   TimeToStruct(t, m);
   m.hour = 0;
   m.min  = 0;
   m.sec  = 0;
   return StructToTime(m);
}

// Utilidad: calcula volumen por riesgo fijo.
double LotByRisk(double stopPoints)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * (RiskPerTradePct / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue == 0 || tickSize == 0) return 0;
   double valuePerPoint = tickValue / (tickSize / _Point);
   double lot = riskMoney / (stopPoints * valuePerPoint);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lot = MathMin(maxLot, MathMax(minLot, MathFloor(lot / step) * step));
   return lot;
}

int OnInit()
{
   if(SlowMAPeriod <= FastMAPeriod)
   {
      Print("SlowMAPeriod debe ser mayor a FastMAPeriod");
      return(INIT_PARAMETERS_INCORRECT);
   }

   fastHandle = iMA(_Symbol, PERIOD_CURRENT, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowHandle = iMA(_Symbol, PERIOD_CURRENT, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(fastHandle == INVALID_HANDLE || slowHandle == INVALID_HANDLE)
   {
      Print("No se pudieron crear los handles de MA. Error: ", _LastError);
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(Magic);
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   // Reseteo diario de contador de trades.
   datetime today = DayStart(TimeCurrent());
   if(today != lastTradeDay)
   {
      lastTradeDay = today;
      tradesToday = 0;
   }

   // Si ya alcanzamos el máximo diario, solo gestionar trailing.
   if(tradesToday >= MaxTradesPerDay)
   {
      Trail();
      return;
   }

   // Si hay posición abierta, solo trailing.
   if(PositionSelect(_Symbol))
   {
      Trail();
      return;
   }

   double fast[2], slow[2];
   if(CopyBuffer(fastHandle, 0, 0, 2, fast) < 2) return;
   if(CopyBuffer(slowHandle, 0, 0, 2, slow) < 2) return;
   double fastNow = fast[0];
   double slowNow = slow[0];
   double fastPrev = fast[1];
   double slowPrev = slow[1];

   // Cruce alcista
   if(fastPrev <= slowPrev && fastNow > slowNow)
      Enter(ORDER_TYPE_BUY);
   // Cruce bajista
   else if(fastPrev >= slowPrev && fastNow < slowNow)
      Enter(ORDER_TYPE_SELL);
}

void Enter(ENUM_ORDER_TYPE type)
{
   double slPoints = StopLossPips * 10; // pips a puntos en símbolos de 5 dígitos.
   double tpPoints = TakeProfitPips * 10;
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot = LotByRisk(slPoints);
   if(lot <= 0)
   {
      Print("No se pudo calcular lotaje. Revisa RiskPerTradePct y StopLossPips.");
      return;
   }

   double sl = (type == ORDER_TYPE_BUY) ? price - slPoints * _Point : price + slPoints * _Point;
   double tp = (type == ORDER_TYPE_BUY) ? price + tpPoints * _Point : price - tpPoints * _Point;

   bool ok = (type == ORDER_TYPE_BUY) ? trade.Buy(lot, _Symbol, price, sl, tp, "ema crossover")
                                      : trade.Sell(lot, _Symbol, price, sl, tp, "ema crossover");
   if(ok)
      tradesToday++;
   else
      Print("Fallo order: ", _LastError);
}

void Trail()
{
   if(TrailingPips <= 0) return;
   if(!PositionSelect(_Symbol)) return;

   ulong ticket = PositionGetInteger(POSITION_TICKET);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double trailPoints = TrailingPips * 10 * _Point;

   if(type == POSITION_TYPE_BUY)
   {
      double newSl = price - trailPoints;
      if(newSl > sl && newSl < price)
         trade.PositionModify(ticket, newSl, PositionGetDouble(POSITION_TP));
   }
   else if(type == POSITION_TYPE_SELL)
   {
      double newSl = price + trailPoints;
      if((sl == 0 || newSl < sl) && newSl > price)
         trade.PositionModify(ticket, newSl, PositionGetDouble(POSITION_TP));
   }
}

double OnTester()
{
   // Métrica de fitness: PF penalizado por drawdown relativo.
   double pf     = TesterStatistics((ENUM_STATISTICS)STAT_PROFIT_FACTOR);
   double ddRel  = TesterStatistics((ENUM_STATISTICS)STAT_EQUITY_DDREL_PERCENT);
   double sharpe = TesterStatistics((ENUM_STATISTICS)STAT_SHARPE_RATIO);
   double trades = TesterStatistics((ENUM_STATISTICS)STAT_TRADES);
   double wins   = TesterStatistics((ENUM_STATISTICS)STAT_PROFIT_TRADES);
   double winPct = (trades > 0 ? wins * 100.0 / trades : 0.0);

   PrintFormat("METRICAS: PF=%.2f DD_rel=%.2f%% Sharpe=%.2f Trades=%.0f Win%%=%.2f",
               pf, ddRel, sharpe, trades, winPct);

   if(pf <= 0)
      return -1;
   double ddRel01 = ddRel / 100.0;
   return pf * (1.0 - ddRel01);
}
