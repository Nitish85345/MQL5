//+------------------------------------------------------------------+
//|                                    Profitable_Gaussian_Based.mq5 |
//|                                     Copyright 2025, Nitish Kumar |
//|                                                 https://mql5.com |
//| 10.08.2025 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Nitish Kumar"
#property link      "https://mql5.com"
#property version   "1.02"

#include <Trade/Trade.mqh>
CTrade trade;

enum SignalType
{
   NO_SIGNAL = 0,
   BUY_SIGNAL,
   SELL_SIGNAL
};

int handleGauss;
double G[];

//--- Trading parameters
input double LotSize         = 0.1;
input int    TakeProfitPips  = 30000;
input int    StopLossPips    = 10000;
input ulong  InpMagic        = 12345;             // magic number for EA positions
// input int    SlippagePoints  = 10;                // allowed slippage in points
input string GaussIndicatorPath   = "custom\\gaussian_filter"; // indicator name (no .ex5)
input int MoveTriggerPoints = 20000; // When price moves this many points in favor
input int MoveTPPoints      = 20000; // Increase TP by this many points
input int MoveSLPoints      = 10000; // Increase SL by this many points

// datetime cooldownUntil = 0;

//+------------------------------------------------------------------+
//| Convert pips (user) to price distance (in symbol price units)    |
//+------------------------------------------------------------------+
// double PipsToPrice(int pips)
// {
//    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
//    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
//    int multiplier = (digits == 3 || digits == 5) ? 10 : 1; // 5-digit / 3-digit pairs have extra digit
//    return (double)pips * multiplier * point;
// }

//+------------------------------------------------------------------+
//| Determine signal type based on Gaussian values                   |
//+------------------------------------------------------------------+
SignalType CheckGaussianSignal()
{
   if(ArraySize(G) < 3) 
      return NO_SIGNAL;

   double diff1 = G[0] - G[1]; // latest slope
   double diff2 = G[1] - G[2]; // previous slope

   // BUY: Gaussian turns up + acceleration
   if(G[2] > G[1] && G[1] < G[0] && diff1 > diff2)
      return BUY_SIGNAL;

   // SELL: Gaussian turns down + acceleration
   if(G[2] < G[1] && G[1] > G[0] && diff1 < diff2)
      return SELL_SIGNAL;

   return NO_SIGNAL;
}


//+------------------------------------------------------------------+
//| Check if there is an open position in the current symbol         |
//+------------------------------------------------------------------+
int GetOpenPositionType()
{
   for(int pos = PositionsTotal()-1; pos >= 0; pos--)
   {
      ulong ticket = PositionGetTicket(pos);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            return (int)PositionGetInteger(POSITION_TYPE); // 0 = buy, 1 = sell
      }
   }
   return -1; // no position
}



// //+------------------------------------------------------------------+
// //| Close position by ticket (uses CTrade::PositionClose for symbol) |
// //+------------------------------------------------------------------+
// bool ClosePositionByTicket(ulong ticket)
// {
//    // select position by index first to get its symbol
//    bool found = false;
//    string pos_symbol = "";
//    int total = PositionsTotal();
//    for(int i = 0; i < total; ++i)
//    {
//       if(PositionSelectByIndex(i))
//       {
//          ulong t = (ulong)PositionGetInteger(POSITION_TICKET);
//          if(t == ticket)
//          {
//             pos_symbol = PositionGetString(POSITION_SYMBOL);
//             found = true;
//             break;
//          }
//       }
//    }
//    if(!found)
//    {
//       PrintFormat("ClosePositionByTicket: ticket %I64u not found.", ticket);
//       return false;
//    }

//    // Use CTrade to close position for that symbol (this will close the selected position(s) for that symbol)
//    if(!trade.PositionClose(pos_symbol))
//    {
//       PrintFormat("PositionClose failed for symbol %s (ticket=%I64u). Error: %d", pos_symbol, ticket, GetLastError());
//       return false;
//    }
//    PrintFormat("Position closed (ticket=%I64u) for symbol %s", ticket, pos_symbol);
//    return true;
// }

//+------------------------------------------------------------------+
//| Open Buy / Sell with SL/TP using CTrade                          |
//+------------------------------------------------------------------+
// bool OpenBuy()
// {
//    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
//    double sl = ask - PipsToPrice(StopLossPips);
//    double tp = ask + PipsToPrice(TakeProfitPips);

//    // Normalize SL/TP to correct digits
//    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
//    sl = NormalizeDouble(sl, digits);
//    tp = NormalizeDouble(tp, digits);

//    trade.SetExpertMagicNumber(InpMagic);
//    trade.SetDeviationInPoints(SlippagePoints);

//    bool ok = trade.Buy(LotSize, _Symbol, ask, sl, tp, "Gaussian BUY");
//    if(!ok) PrintFormat("Buy failed: %d", GetLastError());
//    else PrintFormat("Buy opened: lot=%.2f SL=%.5f TP=%.5f", LotSize, sl, tp);
//    return ok;
// }

// bool OpenSell()
// {
//    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
//    double sl = bid + PipsToPrice(StopLossPips);
//    double tp = bid - PipsToPrice(TakeProfitPips);

//    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
//    sl = NormalizeDouble(sl, digits);
//    tp = NormalizeDouble(tp, digits);

//    trade.SetExpertMagicNumber(InpMagic);
//    trade.SetDeviationInPoints(SlippagePoints);

//    bool ok = trade.Sell(LotSize, _Symbol, bid, sl, tp, "Gaussian SELL");
//    if(!ok) PrintFormat("Sell failed: %d", GetLastError());
//    else PrintFormat("Sell opened: lot=%.2f SL=%.5f TP=%.5f", LotSize, sl, tp);
//    return ok;
// }

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   handleGauss = iCustom(_Symbol, PERIOD_CURRENT, GaussIndicatorPath);
   if(handleGauss == INVALID_HANDLE)
   {
      Print("Failed to load indicator: ", GaussIndicatorPath);
      return INIT_FAILED;
   }
   ArraySetAsSeries(G, true);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handleGauss != INVALID_HANDLE) IndicatorRelease(handleGauss);
}

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
   SimpleTrail();
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);

   // run only on new closed bar
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;

   // 1. Update loss tracking each new bar
   // CheckRecentLosses();

   // 2. If cooldown is active, skip trading
   // if(TimeCurrent() < cooldownUntil)
   // {
   //    PrintFormat("Cooldown active until %s - No trading", TimeToString(cooldownUntil));
   //    return;
   // }


   // copy last 3 closed Gaussian values (1 = skip current forming bar)
   if(CopyBuffer(handleGauss, 0, 1, 3, G) <= 0)
   {
      Print("CopyBuffer failed or no data yet");
      return;
   }

   PrintFormat("Gaussian last 3: %.6f, %.6f, %.6f", G[0], G[1], G[2]);
   SignalType sig = CheckGaussianSignal();

   double sl, tp;

   if(sig == BUY_SIGNAL)
   {
      int posType = GetOpenPositionType();
      if(posType == 1) // Close sell first
         trade.PositionClose(_Symbol);

      if(posType != 0) // No buy position, open new buy
      {
         double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         sl = NormalizeDouble(Ask - StopLossPips * _Point, _Digits);
         tp = NormalizeDouble(Ask + TakeProfitPips * _Point, _Digits);
         trade.Buy(LotSize, _Symbol, Ask, sl, tp);
         Print("BUY opened");
      }
   }
   else if(sig == SELL_SIGNAL)
   {
      int posType = GetOpenPositionType();
      if(posType == 0) // Close buy first
         trade.PositionClose(_Symbol);

      if(posType != 1) // No sell position, open new sell
      {
         double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         sl = NormalizeDouble(Bid + StopLossPips * _Point, _Digits);
         tp = NormalizeDouble(Bid - TakeProfitPips * _Point, _Digits);
         trade.Sell(LotSize, _Symbol, Bid, sl, tp);
         Print("SELL opened");
      }
   }
   else
   {
      Print("No signal");
   }
}

void SimpleTrail()
{
   for(int pos = PositionsTotal()-1; pos >= 0; pos--)
   {
      ulong ticket = PositionGetTicket(pos);
      if(!PositionSelectByTicket(ticket))
         continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      if(sym != _Symbol) continue;

      long type = PositionGetInteger(POSITION_TYPE); // 0=BUY, 1=SELL
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double price = (type == POSITION_TYPE_BUY) ? 
                     SymbolInfoDouble(sym, SYMBOL_BID) : 
                     SymbolInfoDouble(sym, SYMBOL_ASK);

      double point = SymbolInfoDouble(sym, SYMBOL_POINT);

      if(type == POSITION_TYPE_BUY)
      {
         if(price - openPrice >= MoveTriggerPoints * point)
         {
            double newSL = sl + MoveSLPoints * point;
            double newTP = tp + MoveTPPoints * point;
            trade.PositionModify(sym, NormalizeDouble(newSL, _Digits), NormalizeDouble(newTP, _Digits));
            PrintFormat("BUY SL updated to %.5f, TP updated to %.5f", newSL, newTP);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         if(openPrice - price >= MoveTriggerPoints * point)
         {
            double newSL = sl - MoveSLPoints * point;
            double newTP = tp - MoveTPPoints * point;
            trade.PositionModify(sym, NormalizeDouble(newSL, _Digits), NormalizeDouble(newTP, _Digits));
            PrintFormat("SELL SL updated to %.5f, TP updated to %.5f", newSL, newTP);
         }
      }
   }
}



// void CheckRecentLosses()
// {
//    datetime now = TimeCurrent();
//    datetime twoHoursAgo = now - 2 * 60 * 60; // 1 hours in seconds
//    int lossCount = 0;

//    // Select closed orders in the last 2 hours
//    if(!HistorySelect(twoHoursAgo, now))
//       return;

//    int deals = HistoryDealsTotal();
//    for(int i = deals - 1; i >= 0; i--)
//    {
//       ulong dealTicket = HistoryDealGetTicket(i);
//       if(dealTicket > 0)
//       {
//          string sym = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
//          if(sym != _Symbol) continue; // only count current symbol

//          long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
//          if(entryType != DEAL_ENTRY_OUT) continue; // only check closing deals

//          double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
//          if(profit < 0.0) // loss
//             lossCount++;
//       }
//    }

//    // If 2 or more losses in last 1 hours, set cooldown for 2 hours
//    if(lossCount >= 2)
//       cooldownUntil = now + 8 * 60 * 60;
// }

