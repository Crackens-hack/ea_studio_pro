
//+------------------------------------------------------------------+
//| Expert Advisor: portales                                         |
//| Idea: Trend-momentum con filtros de volatilidad y sesión         |
//| Autor: Codex (asistente)                                         |
//| Fecha: 2026-03-04                                                |
//+------------------------------------------------------------------+
#property copyright "Libre uso interno"
#property link      "https://"
#property version   "1.000"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

input string   InpSymbol            = "";        // Símbolo (vacío = actual)
input ENUM_TIMEFRAMES InpTFSignal   = PERIOD_H1; // TF señales
input ENUM_TIMEFRAMES InpTFTrend    = PERIOD_H4; // TF filtro de tendencia
input int      InpMAPeriodFast      = 21;        // EMA rápida
input int      InpMAPeriodSlow      = 55;        // EMA lenta
input int      InpRSIPeriod         = 14;        // RSI filtro momentum
input double   InpRSIHigh           = 55.0;      // Umbral RSI compra
input double   InpRSILow            = 45.0;      // Umbral RSI venta
input int      InpATRPeriod         = 14;        // ATR para stops
input double   InpATRMultSL         = 2.0;       // Mult ATR stop loss
input double   InpATRMultTP         = 1.5;       // Relación TP respecto SL (multiplicador)
input double   InpATRTrailMult      = 1.0;       // Mult ATR trailing
input double   InpRiskPerTradePct   = 1.0;       // Riesgo % de equity
input double   InpMaxRiskPct        = 2.0;       // Riesgo máx permitido (% equity)
input int      InpMaxSpreadPoints   = 25;        // Spread máximo en puntos
input bool     InpUseTimeFilter     = true;      // Usar filtro horario
input int      InpSessionStartHour  = 7;         // Hora inicio (server)
input int      InpSessionEndHour    = 20;        // Hora fin (server, inclusive)
input int      InpSlippagePoints    = 5;         // Deslizamiento máx
input ulong    InpMagic             = 880001;    // Magic number
input bool     InpAllowHedging      = false;     // Permitir posiciones opuestas

// Variables globales
CTrade         trade;
CPositionInfo  posInfo;
datetime       last_bar_time = 0;

//+------------------------------------------------------------------+
//| Calcular tamaño de lote basado en riesgo porcentual              |
//+------------------------------------------------------------------+
double CalculateLot(double stop_points, string symbol)
{
   if(stop_points <= 0.0)
      return(0.0);

   double equity      = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_money  = equity * InpRiskPerTradePct / 100.0;
   double tick_value  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size   = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double contract_sz = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);

   if(tick_value <= 0 || tick_size <= 0 || contract_sz <= 0)
      return(0.0);

   double stop_value_per_lot = (stop_points * tick_value) / tick_size;
   double lots = risk_money / stop_value_per_lot;

   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   lots = MathMax(minLot, lots);
   lots = MathMin(maxLot, lots);
   lots = MathFloor(lots / step) * step;
   return(lots);
}

//+------------------------------------------------------------------+
//| Comprobar spread                                                 |
//+------------------------------------------------------------------+
bool SpreadOK(string symbol)
{
   double spread_points = (SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5)
                          ? SymbolInfoInteger(symbol, SYMBOL_SPREAD)
                          : SymbolInfoInteger(symbol, SYMBOL_SPREAD) * 1.0;
   return(spread_points <= InpMaxSpreadPoints);
}

//+------------------------------------------------------------------+
//| Helpers indicadores (valor en la barra actual)                  |
//+------------------------------------------------------------------+
double GetEMA(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   int handle = iMA(symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return(EMPTY_VALUE);
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) < 1) return(EMPTY_VALUE);
   return(buf[0]);
}

double GetRSI(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   int handle = iRSI(symbol, tf, period, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return(EMPTY_VALUE);
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) < 1) return(EMPTY_VALUE);
   return(buf[0]);
}

double GetATR(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   int handle = iATR(symbol, tf, period);
   if(handle == INVALID_HANDLE) return(EMPTY_VALUE);
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) < 1) return(EMPTY_VALUE);
   return(buf[0]);
}

//+------------------------------------------------------------------+
//| Filtro horario                                                   |
//+------------------------------------------------------------------+
bool TimeOK()
{
   if(!InpUseTimeFilter)
      return(true);
   datetime now = TimeCurrent();
   MqlDateTime t;
   TimeToStruct(now, t);
   int hour = t.hour;
   if(InpSessionStartHour <= InpSessionEndHour)
      return(hour >= InpSessionStartHour && hour <= InpSessionEndHour);
   // Sesiones que cruzan medianoche
   return(hour >= InpSessionStartHour || hour <= InpSessionEndHour);
}

//+------------------------------------------------------------------+
//| Comprobar tendencia HTF                                          |
//+------------------------------------------------------------------+
int TrendDirection(string symbol)
{
   double ema_fast = GetEMA(symbol, InpTFTrend, InpMAPeriodFast);
   double ema_slow = GetEMA(symbol, InpTFTrend, InpMAPeriodSlow);
   if(ema_fast > ema_slow) return(1);
   if(ema_fast < ema_slow) return(-1);
   return(0);
}

//+------------------------------------------------------------------+
//| Señal en TF de entrada                                           |
//+------------------------------------------------------------------+
int EntrySignal(string symbol)
{
   double ema_fast = GetEMA(symbol, InpTFSignal, InpMAPeriodFast);
   double ema_slow = GetEMA(symbol, InpTFSignal, InpMAPeriodSlow);
   double rsi      = GetRSI(symbol, InpTFSignal, InpRSIPeriod);

   if(ema_fast > ema_slow && rsi > InpRSIHigh)
      return(1);
   if(ema_fast < ema_slow && rsi < InpRSILow)
      return(-1);
   return(0);
}

//+------------------------------------------------------------------+
//| Trailing stop dinámico                                           |
//+------------------------------------------------------------------+
void ManageTrailing(string symbol)
{
   if(posInfo.Select(symbol))
   {
      if(posInfo.Magic() != InpMagic)
         return;

      double atr = GetATR(symbol, InpTFSignal, InpATRPeriod);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double trail = atr * InpATRTrailMult;
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

      // Para 5 dígitos, trail en precio
      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double new_sl = NormalizeDouble(bid - trail, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
         if(new_sl > posInfo.StopLoss())
            trade.PositionModify(posInfo.Ticket(), new_sl, posInfo.TakeProfit());
      }
      else if(posInfo.PositionType() == POSITION_TYPE_SELL)
      {
         double new_sl = NormalizeDouble(ask + trail, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
         if(new_sl < posInfo.StopLoss() || posInfo.StopLoss() == 0.0)
            trade.PositionModify(posInfo.Ticket(), new_sl, posInfo.TakeProfit());
      }
   }
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   string symbol = (InpSymbol == "" ? _Symbol : InpSymbol);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

   if(!SpreadOK(symbol) || !TimeOK())
   {
      Comment("portales: spread/time filtro activo");
      return;
   }

   // Esperar nueva barra en TF señal
   datetime cur_bar_time = iTime(symbol, InpTFSignal, 0);
   if(cur_bar_time == last_bar_time)
   {
      ManageTrailing(symbol);
      return;
   }
   last_bar_time = cur_bar_time;

   int trend   = TrendDirection(symbol);
   int signal  = EntrySignal(symbol);
   int dir     = 0;

   if(signal != 0 && trend == signal)
      dir = signal;

   // Manejo de posiciones existentes
   bool has_position = posInfo.Select(symbol) && posInfo.Magic() == InpMagic;

   if(has_position)
   {
      // Si la señal cambió de sentido, cerrar y revertir
      if(!InpAllowHedging && dir != 0 && dir != (posInfo.PositionType() == POSITION_TYPE_BUY ? 1 : -1))
      {
         trade.PositionClose(posInfo.Ticket());
         has_position = false;
      }
      else
      {
         ManageTrailing(symbol);
         Comment("portales activo | Ticket:", posInfo.Ticket(), " Dir:", posInfo.PositionType(), " SL:", posInfo.StopLoss(), " TP:", posInfo.TakeProfit());
         return;
      }
   }

   if(dir == 0)
   {
      Comment("portales: sin señal válida");
      return;
   }

   double atr = GetATR(symbol, InpTFSignal, InpATRPeriod);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double sl_distance = atr * InpATRMultSL;
   double tp_distance = sl_distance * InpATRMultTP;

   double stop_points = sl_distance / point;
   if(stop_points <= 0)
   {
      Comment("portales: stop inválido");
      return;
   }

   double lots = CalculateLot(stop_points, symbol);
   if(lots <= 0)
   {
      Comment("portales: lotaje inválido");
      return;
   }

   double price_sl = 0.0, price_tp = 0.0;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   if(dir == 1) // buy
   {
      price_sl = NormalizeDouble(bid - sl_distance, digits);
      price_tp = NormalizeDouble(bid + tp_distance, digits);
      trade.Buy(lots, symbol, 0.0, price_sl, price_tp, "portales buy");
   }
   else if(dir == -1) // sell
   {
      price_sl = NormalizeDouble(ask + sl_distance, digits);
      price_tp = NormalizeDouble(ask - tp_distance, digits);
      trade.Sell(lots, symbol, 0.0, price_sl, price_tp, "portales sell");
   }

   Comment(StringFormat("portales: orden %s lots %.2f SL %.1f TP %.1f", dir==1?"BUY":"SELL", lots, sl_distance/point, tp_distance/point));
}

//+------------------------------------------------------------------+
//| OnTester: métricas clave                                         |
//+------------------------------------------------------------------+
double OnTester()
{
   double profit_factor   = TesterStatistics(STAT_PROFIT_FACTOR);
   double max_dd_rel_pct  = TesterStatistics(STAT_BALANCE_DDREL_PERCENT); // porcentaje
   double win_trades      = TesterStatistics(STAT_PROFIT_TRADES);
   double loss_trades     = TesterStatistics(STAT_LOSS_TRADES);
   double total_trades    = TesterStatistics(STAT_TRADES);
   double gross_profit    = TesterStatistics(STAT_GROSS_PROFIT);
   double gross_loss      = TesterStatistics(STAT_GROSS_LOSS);
   double avg_win         = (win_trades  > 0) ? (gross_profit / win_trades) : 0.0;
   double avg_loss        = (loss_trades > 0) ? MathAbs(gross_loss / loss_trades) : 0.0;
   double sharpe          = TesterStatistics(STAT_SHARPE_RATIO);
   double recovery        = TesterStatistics(STAT_RECOVERY_FACTOR);
   double expectancy      = TesterStatistics(STAT_EXPECTED_PAYOFF);
   double avg_trade_time  = 0.0; // No disponible en enum estándar, se deja 0

   double winrate = (total_trades > 0) ? (win_trades / total_trades) : 0.0;
   double payoff  = (avg_loss != 0.0) ? MathAbs(avg_win / avg_loss) : 0.0;

   double fitness = 0.0;
   double dd_term = 1.0 + max_dd_rel_pct/100.0;
   fitness = (profit_factor * winrate * MathMax(recovery, 0.1) * MathMax(payoff, 0.1)) / dd_term;

   PrintFormat("OnTester | PF: %.2f | WinRate: %.2f | Payoff: %.2f | MaxDD%%: %.2f | Recovery: %.2f | Sharpe: %.2f | Expectancy: %.2f | Trades: %.0f | AvgHold(s): %.0f | Fitness: %.4f",
               profit_factor, winrate*100.0, payoff, max_dd_rel_pct, recovery, sharpe, expectancy, total_trades, avg_trade_time, fitness);
   return(fitness);
}

//+------------------------------------------------------------------+
//| Utilidades opcionales                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
}
