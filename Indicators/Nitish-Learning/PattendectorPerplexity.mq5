//+------------------------------------------------------------------+
//|                                               PatternDetector.mq5|
//|          Detects Double Top/Bottom and Head & Shoulders          |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 0

//--- Input parameters
input int SwingLookback = 5;        // Bars to look back for swing points
input double PriceTolerance = 10;   // Price tolerance in points for pattern similarity
input int MaxBarsToScan = 500;      // Max bars to scan backward for patterns

//--- Struct to hold swing points
struct SwingPoint
  {
   int    index;    // Bar index
   double price;    // Price of swing high/low
   datetime time;   // Time of the bar
   bool   isHigh;   // true if swing high, false if swing low
  };

//--- Arrays for swing points
SwingPoint swingHighs[];
SwingPoint swingLows[];

//+------------------------------------------------------------------+
//| Find swing highs and lows                                        |
//+------------------------------------------------------------------+
void FindSwingPoints(int bars)
  {
   ArrayResize(swingHighs,0);
   ArrayResize(swingLows,0);

   for(int i=SwingLookback; i<bars-SwingLookback; i++)
     {
      bool isHigh=true;
      bool isLow=true;
      double currentHigh=High[i];
      double currentLow=Low[i];

      for(int j=i-SwingLookback; j<=i+SwingLookback; j++)
        {
         if(j==i) continue;
         if(High[j]>=currentHigh) isHigh=false;
         if(Low[j]<=currentLow) isLow=false;
        }

      if(isHigh)
        {
         SwingPoint sp;
         sp.index=i; sp.price=currentHigh; sp.time=Time[i]; sp.isHigh=true;
         ArrayResize(swingHighs,ArraySize(swingHighs)+1);
         swingHighs[ArraySize(swingHighs)-1] = sp;
        }
      if(isLow)
        {
         SwingPoint sp;
         sp.index=i; sp.price=currentLow; sp.time=Time[i]; sp.isHigh=false;
         ArrayResize(swingLows,ArraySize(swingLows)+1);
         swingLows[ArraySize(swingLows)-1] = sp;
        }
     }
  }

//+------------------------------------------------------------------+
//| Check if two prices are close within tolerance                   |
//+------------------------------------------------------------------+
bool PricesClose(double p1,double p2)
  {
   return(MathAbs(p1-p2) <= PriceTolerance * _Point);
  }

//+------------------------------------------------------------------+
//| Draw label on chart                                              |
//+------------------------------------------------------------------+
void DrawLabel(string name, datetime time, double price, string text, color clr)
  {
   if(ObjectFind(0,name) >= 0) ObjectDelete(0,name);
   ObjectCreate(0,name,OBJ_TEXT,0,time,price);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,12);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
  }

//+------------------------------------------------------------------+
//| Draw line between two points                                     |
//+------------------------------------------------------------------+
void DrawLine(string name, datetime t1, double p1, datetime t2, double p2, color clr)
  {
   if(ObjectFind(0,name) >= 0) ObjectDelete(0,name);
   ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
  }

//+------------------------------------------------------------------+
//| Detect Double Top pattern                                         |
//+------------------------------------------------------------------+
void DetectDoubleTop()
  {
   for(int i=0; i<ArraySize(swingHighs)-1; i++)
     {
      SwingPoint h1 = swingHighs[i];
      for(int j=i+1; j<ArraySize(swingHighs); j++)
        {
         SwingPoint h2 = swingHighs[j];

         int barsBetween = h2.index - h1.index;
         if(barsBetween < 3 || barsBetween > 50) continue;
         if(!PricesClose(h1.price, h2.price)) continue;

         // Check for a swing low between h1 and h2 lower than both highs
         bool validLow = false;
         SwingPoint lowPoint;
         for(int k=0; k<ArraySize(swingLows); k++)
           {
            SwingPoint l = swingLows[k];
            if(l.index > h1.index && l.index < h2.index)
              {
               if(l.price < h1.price && l.price < h2.price)
                 {
                  validLow = true;
                  lowPoint = l;
                  break;
                 }
              }
           }
         if(validLow)
           {
            string baseName = "Pattern_DoubleTop_" + IntegerToString(h1.index) + "_" + IntegerToString(h2.index);
            DrawLine(baseName + "_line1", h1.time, h1.price, lowPoint.time, lowPoint.price, clrRed);
            DrawLine(baseName + "_line2", lowPoint.time, lowPoint.price, h2.time, h2.price, clrRed);
            DrawLabel(baseName + "_label", h2.time, h2.price + 10 * _Point, "Double Top", clrRed);
            break; // One pattern per h1
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Detect Double Bottom pattern                                      |
//+------------------------------------------------------------------+
void DetectDoubleBottom()
  {
   for(int i=0; i<ArraySize(swingLows)-1; i++)
     {
      SwingPoint l1 = swingLows[i];
      for(int j=i+1; j<ArraySize(swingLows); j++)
        {
         SwingPoint l2 = swingLows[j];

         int barsBetween = l2.index - l1.index;
         if(barsBetween < 3 || barsBetween > 50) continue;
         if(!PricesClose(l1.price, l2.price)) continue;

         // Check for a swing high between l1 and l2 higher than both lows
         bool validHigh = false;
         SwingPoint highPoint;
         for(int k=0; k<ArraySize(swingHighs); k++)
           {
            SwingPoint h = swingHighs[k];
            if(h.index > l1.index && h.index < l2.index)
              {
               if(h.price > l1.price && h.price > l2.price)
                 {
                  validHigh = true;
                  highPoint = h;
                  break;
                 }
              }
           }
         if(validHigh)
           {
            string baseName = "Pattern_DoubleBottom_" + IntegerToString(l1.index) + "_" + IntegerToString(l2.index);
            DrawLine(baseName + "_line1", l1.time, l1.price, highPoint.time, highPoint.price, clrGreen);
            DrawLine(baseName + "_line2", highPoint.time, highPoint.price, l2.time, l2.price, clrGreen);
            DrawLabel(baseName + "_label", l2.time, l2.price - 10 * _Point, "Double Bottom", clrGreen);
            break; // One pattern per l1
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Detect Head and Shoulders pattern                                |
//+------------------------------------------------------------------+
void DetectHeadAndShoulders()
  {
   for(int i=0; i<ArraySize(swingHighs)-2; i++)
     {
      SwingPoint leftShoulder = swingHighs[i];
      SwingPoint head = swingHighs[i+1];
      SwingPoint rightShoulder = swingHighs[i+2];

      int barsBetween1 = head.index - leftShoulder.index;
      int barsBetween2 = rightShoulder.index - head.index;

      if(barsBetween1 < 2 || barsBetween1 > 50) continue;
      if(barsBetween2 < 2 || barsBetween2 > 50) continue;

      if(head.price <= leftShoulder.price || head.price <= rightShoulder.price) continue;
      if(!PricesClose(leftShoulder.price, rightShoulder.price)) continue;

      // Find neckline lows between shoulders and head
      double neckline1 = DBL_MAX, neckline2 = DBL_MAX;
      bool foundNeckline1 = false, foundNeckline2 = false;

      for(int k=0; k<ArraySize(swingLows); k++)
        {
         SwingPoint low = swingLows[k];
         if(low.index > leftShoulder.index && low.index < head.index)
           {
            if(!foundNeckline1 || low.price < neckline1)
              {
               neckline1 = low.price;
               foundNeckline1 = true;
              }
           }
         if(low.index > head.index && low.index < rightShoulder.index)
           {
            if(!foundNeckline2 || low.price < neckline2)
              {
               neckline2 = low.price;
               foundNeckline2 = true;
              }
           }
        }

      if(!foundNeckline1 || !foundNeckline2) continue;

      string baseName = "Pattern_HeadAndShoulders_" + IntegerToString(leftShoulder.index) + "_" + IntegerToString(head.index) + "_" + IntegerToString(rightShoulder.index);

      DrawLine(baseName + "_LS_H", leftShoulder.time, leftShoulder.price, head.time, head.price, clrOrange);
      DrawLine(baseName + "_H_RS", head.time, head.price, rightShoulder.time, rightShoulder.price, clrOrange);
      DrawLine(baseName + "_Neckline", Time[leftShoulder.index], neckline1, Time[rightShoulder.index], neckline2, clrBlue);

      DrawLabel(baseName + "_LS_label", leftShoulder.time, leftShoulder.price + 10 * _Point, "Left Shoulder", clrOrange);
      DrawLabel(baseName + "_H_label", head.time, head.price + 10 * _Point, "Head", clrOrange);
      DrawLabel(baseName + "_RS_label", rightShoulder.time, rightShoulder.price + 10 * _Point, "Right Shoulder", clrOrange);
      DrawLabel(baseName + "_Neckline_label", Time[rightShoulder.index], MathMin(neckline1, neckline2) - 10 * _Point, "Neckline", clrBlue);

      i += 2; // Skip to avoid overlapping patterns
     }
  }

//+------------------------------------------------------------------+
//| Detect Inverted Head and Shoulders pattern                       |
//+------------------------------------------------------------------+
void DetectInvertedHeadAndShoulders()
  {
   for(int i=0; i<ArraySize(swingLows)-2; i++)
     {
      SwingPoint leftShoulder = swingLows[i];
      SwingPoint head = swingLows[i+1];
      SwingPoint rightShoulder = swingLows[i+2];

      int barsBetween1 = head.index - leftShoulder.index;
      int barsBetween2 = rightShoulder.index - head.index;

      if(barsBetween1 < 2 || barsBetween1 > 50) continue;
      if(barsBetween2 < 2 || barsBetween2 > 50) continue;

      if(head.price >= leftShoulder.price || head.price >= rightShoulder.price) continue;
      if(!PricesClose(leftShoulder.price, rightShoulder.price)) continue;

      // Find neckline highs between shoulders and head
      double neckline1 = -DBL_MAX, neckline2 = -DBL_MAX;
      bool foundNeckline1 = false, foundNeckline2 = false;

      for(int k=0; k<ArraySize(swingHighs); k++)
        {
         SwingPoint high = swingHighs[k];
         if(high.index > leftShoulder.index && high.index < head.index)
           {
            if(!foundNeckline1 || high.price > neckline1)
              {
               neckline1 = high.price;
               foundNeckline1 = true;
              }
           }
         if(high.index > head.index && high.index < rightShoulder.index)
           {
            if(!foundNeckline2 || high.price > neckline2)
              {
               neckline2 = high.price;
               foundNeckline2 = true;
              }
           }
        }

      if(!foundNeckline1 || !foundNeckline2) continue;

      string baseName = "Pattern_InvHeadAndShoulders_" + IntegerToString(leftShoulder.index) + "_" + IntegerToString(head.index) + "_" + IntegerToString(rightShoulder.index);

      DrawLine(baseName + "_LS_H", leftShoulder.time, leftShoulder.price, head.time, head.price, clrYellowGreen);
      DrawLine(baseName + "_H_RS", head.time, head.price, rightShoulder.time, rightShoulder.price, clrYellowGreen);
      DrawLine(baseName + "_Neckline", Time[leftShoulder.index], neckline1, Time[rightShoulder.index], neckline2, clrBlue);

      DrawLabel(baseName + "_LS_label", leftShoulder.time, leftShoulder.price - 10 * _Point, "Left Shoulder", clrYellowGreen);
      DrawLabel(baseName + "_H_label", head.time, head.price - 10 * _Point, "Head", clrYellowGreen);
      DrawLabel(baseName + "_RS_label", rightShoulder.time, rightShoulder.price - 10 * _Point, "Right Shoulder", clrYellowGreen);
      DrawLabel(baseName + "_Neckline_label", Time[rightShoulder.index], MathMax(neckline1, neckline2) + 10 * _Point, "Neckline", clrBlue);

      i += 2; // Skip to avoid overlapping patterns
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < SwingLookback * 3)
      return(0);

   // Clear previous pattern objects to avoid clutter
   int totalObjects = ObjectsTotal(0, 0, -1);
   for(int i = totalObjects - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, "Pattern_") != -1)
         ObjectDelete(0, name);
     }

   // Copy price arrays to global arrays for swing detection
   // (We can directly use high[], low[], time[] here)
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(Time, false);

   // Find swing points
   FindSwingPoints(MathMin(rates_total, MaxBarsToScan));

   // Detect patterns
   DetectDoubleTop();
   DetectDoubleBottom();
   DetectHeadAndShoulders();
   DetectInvertedHeadAndShoulders();

   return(rates_total);
  }
//+------------------------------------------------------------------+
