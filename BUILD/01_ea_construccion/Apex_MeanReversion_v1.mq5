//+------------------------------------------------------------------+
//|                                       Apex_MeanReversion_v1.mq5 |
//|                                  Copyright 2026, Asistente IA    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Asistente IA"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- INPUT PARAMETERS
input group "--- Strategy Parameters ---"
input int      InpRSI_Period     = 27;          // RSI Period
input int      InpRSI_Overbought = 74;          // RSI Overbought Level
input int      InpRSI_Oversold   = 34;          // RSI Oversold Level
input int      InpBB_Period      = 23;          // Bollinger Period
input double   InpBB_Deviation   = 2.5;         // Bollinger Deviation
input int      InpBB_Shift       = 0;           // Bollinger Shift

input group "--- Trade Management ---"
input double   InpLotSize        = 0.1;         // Fixed Lot Size
input int      InpStopLoss_ATR   = 45;          // SL Multiplier (x0.1 ATR)
input int      InpTakeProfit_ATR = 80;          // TP Multiplier (x0.1 ATR)
input int      InpATR_Period     = 11;          // ATR Period for SL/TP
input double   InpTrailingStart  = 2.5;         // Trailing Start (ATR Multiplier)
input double   InpTrailingStep   = 0.3;         // Trailing Step (ATR Multiplier)

input group "--- Miscellaneous ---"
input int      InpMagic          = 123456;      // Magic Number
input int      InpMaxSlippage    = 3;           // Max Slippage

//--- GLOBAL VARIABLES
CTrade         trade;
int            handleRSI;
int            handleBB;
int            handleATR;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   
   handleRSI = iRSI(_Symbol, _Period, InpRSI_Period, PRICE_CLOSE);
   handleBB  = iBands(_Symbol, _Period, InpBB_Period, InpBB_Shift, InpBB_Deviation, PRICE_CLOSE);
   handleATR = iATR(_Symbol, _Period, InpATR_Period);
   
   if(handleRSI == INVALID_HANDLE || handleBB == INVALID_HANDLE || handleATR == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleBB);
   IndicatorRelease(handleATR);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for only one entry per bar
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, _Period, 0);
   
   // Logic for managing existing positions (Trailing Stop)
   ManagePositions();

   if(lastBar == currentBar) return;
   
   // Logic for entry
   CheckEntry();
   
   lastBar = currentBar;
}

//+------------------------------------------------------------------+
//| Check entry conditions                                           |
//+------------------------------------------------------------------+
void CheckEntry()
{
   double rsi[], bbUpper[], bbLower[], atr[];
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(bbUpper, true);
   ArraySetAsSeries(bbLower, true);
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(handleRSI, 0, 0, 3, rsi) < 3) return;
   if(CopyBuffer(handleBB, 1, 0, 3, bbUpper) < 3) return;
   if(CopyBuffer(handleBB, 2, 0, 3, bbLower) < 3) return;
   if(CopyBuffer(handleATR, 0, 0, 3, atr) < 3) return;
   
   double close1 = iClose(_Symbol, _Period, 1);
   
   // Check if we already have a position
   if(PositionSelectByMagic(_Symbol, InpMagic)) return;

   // BUY: Price closed below BB lower AND RSI < Oversold
   if(close1 < bbLower[1] && rsi[1] < InpRSI_Oversold)
   {
      double sl = close1 - (atr[1] * InpStopLoss_ATR * 0.1);
      double tp = close1 + (atr[1] * InpTakeProfit_ATR * 0.1);
      
      if(trade.Buy(InpLotSize, _Symbol, 0, sl, tp, "Apex Buy"))
      {
         Print("Buy order placed");
      }
   }
   // SELL: Price closed above BB upper AND RSI > Overbought
   else if(close1 > bbUpper[1] && rsi[1] > InpRSI_Overbought)
   {
      double sl = close1 + (atr[1] * InpStopLoss_ATR * 0.1);
      double tp = close1 - (atr[1] * InpTakeProfit_ATR * 0.1);
      
      if(trade.Sell(InpLotSize, _Symbol, 0, sl, tp, "Apex Sell"))
      {
         Print("Sell order placed");
      }
   }
}

//+------------------------------------------------------------------+
//| Manage existing positions (Trailing Stop)                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(!PositionSelectByMagic(_Symbol, InpMagic)) return;
   
   double atr_val[];
   ArraySetAsSeries(atr_val, true);
   if(CopyBuffer(handleATR, 0, 0, 1, atr_val) < 1) return;
   
   long type = PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL = PositionGetDouble(POSITION_SL);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   ulong  ticket = PositionGetInteger(POSITION_TICKET);
   
   if(type == POSITION_TYPE_BUY)
   {
      double targetSL = bid - (atr_val[0] * InpTrailingStart);
      if(bid > openPrice + (atr_val[0] * InpTrailingStart))
      {
         if(targetSL > curSL + (atr_val[0] * InpTrailingStep))
         {
            trade.PositionModify(ticket, targetSL, PositionGetDouble(POSITION_TP));
         }
      }
   }
   else if(type == POSITION_TYPE_SELL)
   {
      double targetSL = ask + (atr_val[0] * InpTrailingStart);
      if(ask < openPrice - (atr_val[0] * InpTrailingStart))
      {
         if(targetSL < curSL - (atr_val[0] * InpTrailingStep) || curSL == 0)
         {
            trade.PositionModify(ticket, targetSL, PositionGetDouble(POSITION_TP));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Custom function to check position by symbol and magic            |
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

//+------------------------------------------------------------------+
//| Custom Tester Function                                           |
//+------------------------------------------------------------------+
double OnTester()
{
   double profit = TesterStatistics(STAT_PROFIT);
   double pf     = TesterStatistics(STAT_PROFIT_FACTOR);
   double dd     = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double winrate = 0;
   
   double totalTrades = TesterStatistics(STAT_TRADES);
   if(totalTrades > 0)
      winrate = TesterStatistics(STAT_PROFIT_TRADES) / totalTrades;
   
   // Combined Fitness Function
   if(dd <= 0) dd = 0.01;
   
   double fitness = (pf * winrate * 100.0) / (dd);
   if(profit <= 0) fitness = profit;
   
   return fitness;
}
//+------------------------------------------------------------------+
