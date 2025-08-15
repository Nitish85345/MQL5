//+------------------------------------------------------------------+
//|                                          Moving Average Band.mq5 |
//|                                     Copyright 2025, Nitish Kumar |
//|                                                 https://mql5.com |
//| 01.07.2025 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Nitish Kumar"
#property link      "https://mql5.com"
#property version   "1.00"

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- MA1 Plot
#property indicator_label1  "MA1"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrYellow
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- MA2 Plot
#property indicator_label2  "MA2"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrWhite
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

// Inputs
input int InpMABars1 = 9;
input ENUM_MA_METHOD InpMAMethod1 = MODE_SMA;
input ENUM_APPLIED_PRICE InpMAAppliedPrice1 = PRICE_CLOSE;

input int InpMABars2 = 20;
input ENUM_MA_METHOD InpMAMethod2 = MODE_SMA;
input ENUM_APPLIED_PRICE InpMAAppliedPrice2 = PRICE_CLOSE;

// Buffers
double BufferMA1[];
double BufferMA2[];

// Handles
int HandleMA1;
int HandleMA2;
double ValuesMA1[];
double ValuesMA2[];

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferMA1);
   SetIndexBuffer(1, BufferMA2);

   ArraySetAsSeries(BufferMA1, true);
   ArraySetAsSeries(BufferMA2, true);
   ArraySetAsSeries(ValuesMA1, true);
   ArraySetAsSeries(ValuesMA2, true);

   HandleMA1 = iMA(Symbol(), Period(), InpMABars1, 0, InpMAMethod1, InpMAAppliedPrice1);
   HandleMA2 = iMA(Symbol(), Period(), InpMABars2, 0, InpMAMethod2, InpMAAppliedPrice2);

   if (HandleMA1 == INVALID_HANDLE || HandleMA2 == INVALID_HANDLE)
     {
      Print("❌ Failed to create indicator handles: MA1=", HandleMA1, " MA2=", HandleMA2);
      return(INIT_FAILED);
     }

   Print("✅ MA handles created: MA1=", HandleMA1, " MA2=", HandleMA2);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(HandleMA1);
   IndicatorRelease(HandleMA2);
   Print("🔻 Handles released");
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if (rates_total < MathMax(InpMABars1, InpMABars2))
     {
      Print("⚠️ Not enough bars to calculate. Need at least ", MathMax(InpMABars1, InpMABars2));
      return(0);
     }

   int calculated = MathMax(prev_calculated - 1, 0);
   int count = rates_total - calculated;

   if (CopyBuffer(HandleMA1, 0, 0, count, ValuesMA1) < count)
     {
      Print("❌ CopyBuffer MA1 failed at bar count = ", count);
      return(0);
     }

   if (CopyBuffer(HandleMA2, 0, 0, count, ValuesMA2) < count)
     {
      Print("❌ CopyBuffer MA2 failed at bar count = ", count);
      return(0);
     }

   for (int i = 0; i < count; i++)
     {
      BufferMA1[i] = ValuesMA1[i];
      BufferMA2[i] = ValuesMA2[i];
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
