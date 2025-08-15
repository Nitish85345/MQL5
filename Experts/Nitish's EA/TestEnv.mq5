//+------------------------------------------------------------------+
//|                                                      TestEnv.mq5 |
//|                                     Copyright 2025, Nitish Kumar |
//|                                                 https://mql5.com |
//| 26.07.2025 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Nitish Kumar"
#property link      "https://mql5.com"
#property version   "1.00"


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
   {
//---
    
//---
    return(INIT_SUCCEEDED);
   }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
   {
//---
    
   }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+

void OnTick()
   {
//---
      // datetime currentBarTime = iTime(_Symbol, _Period, 0);
      // Print("CurrentBarTime value = ", currentBarTime);

      // int bars = Bars(_Symbol, _Period);
      // Print("Total Bars =", bars);
      // double highs[];
      // ArraySetAsSeries(highs, true);
      // CopyHigh(_Symbol, _Period, 1, 5, highs);
      // Print("Highs are .....", highs[1], " ", highs[2], " ", highs[3]);

      double closePrice = iClose(_Symbol, _Period, 1);
      Print("Last candle close price ... ", closePrice);

   }

//+------------------------------------------------------------------+
