//+------------------------------------------------------------------+
//|                                           MA Ribbon Fill.mq5     |
//|   Draw colored ribbon between two MAs with MA lines              |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   3

//--- Plot MA1
#property indicator_label1  "MA1"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrYellow
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot MA2
#property indicator_label2  "MA2"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrWhite
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Ribbon fill between MA1 and MA2
#property indicator_label3  "MA Ribbon"
#property indicator_type3   DRAW_FILLING
#property indicator_color3  clrGreen, clrRed

//--- input parameters
input int InpMABars1 = 9;
input ENUM_MA_METHOD InpMAMethod1 = MODE_EMA;
input ENUM_APPLIED_PRICE InpPrice1 = PRICE_CLOSE;

input int InpMABars2 = 21;
input ENUM_MA_METHOD InpMAMethod2 = MODE_SMA;
input ENUM_APPLIED_PRICE InpPrice2 = PRICE_CLOSE;

//--- indicator buffers
double MA1Buffer[];
double MA2Buffer[];
double FillUpper[];
double FillLower[];
double ColorIndex[];

//--- handles
int handleMA1, handleMA2;

//+------------------------------------------------------------------+
int OnInit()
  {
   // Assign buffers to plots
   SetIndexBuffer(0, MA1Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, MA2Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, FillUpper, INDICATOR_DATA);
   SetIndexBuffer(3, FillLower, INDICATOR_DATA);
   SetIndexBuffer(4, ColorIndex, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(MA1Buffer, true);
   ArraySetAsSeries(MA2Buffer, true);
   ArraySetAsSeries(FillUpper, true);
   ArraySetAsSeries(FillLower, true);
   ArraySetAsSeries(ColorIndex, true);

   PlotIndexSetInteger(2, PLOT_COLOR_INDEXES, 2);  // green and red

   // Create indicator handles
   handleMA1 = iMA(Symbol(), Period(), InpMABars1, 0, InpMAMethod1, InpPrice1);
   handleMA2 = iMA(Symbol(), Period(), InpMABars2, 0, InpMAMethod2, InpPrice2);

   if (handleMA1 == INVALID_HANDLE || handleMA2 == INVALID_HANDLE)
     {
      Print("❌ Failed to create MA handles");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(handleMA1);
   IndicatorRelease(handleMA2);
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
   int start = MathMax(prev_calculated - 1, 0);
   int copied = rates_total - start;

   if (CopyBuffer(handleMA1, 0, 0, copied, MA1Buffer) < 0 ||
       CopyBuffer(handleMA2, 0, 0, copied, MA2Buffer) < 0)
      return(0);

   for (int i = start; i < rates_total; i++)
     {
      // Fill region based on MA comparison
      if (MA1Buffer[i] > MA2Buffer[i])
        {
         FillUpper[i] = MA1Buffer[i];
         FillLower[i] = MA2Buffer[i];
         ColorIndex[i] = 0;  // Green
        }
      else
        {
         FillUpper[i] = MA2Buffer[i];
         FillLower[i] = MA1Buffer[i];
         ColorIndex[i] = 1;  // Red
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
