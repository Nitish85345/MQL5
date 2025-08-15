//+------------------------------------------------------------------+
//|                                   Head & Shoulder Pattern EA.mq5 |
//|                           Copyright 2025, Allan Munene Mutiiria. |
//|                                   https://t.me/Forex_Algo_Trader |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Allan Munene Mutiiria."
#property link      "https://t.me/Forex_Algo_Trader"
#property version   "1.00"

#include <Trade/Trade.mqh>
CTrade obj_Trade;

input int LookbackBars = 50;
input double ThresholdPoints = 50.0;
input double shoulderTolerancePoints = 30;
input double TroughTolerancePoints = 30;
input double BufferPoints = 20;
input double lotsize = 0.1;
input ulong magicNumber = 1234567;
input int maxBarRange = 30;
input int minBarRange = 5;
input double BarRangeMultiplier = 2.0;
input int validationBars = 3;
input double PriceTolerance = 5.0;
input double RightShoulderBreakoutMultiplier = 1.5;
input int MaxTradedPatterns = 20;
input bool UseTrailingStop = true;
input int MinTrailingPoints = 10;
input int TrailingPoints = 30;
input int priceOffsetForText = 10;

struct Extremum
  {
   int               bar;
   datetime          time;
   double            price;
   bool              isPeak;
  };

struct TradedPatterns
  {
   datetime          leftShoulderTime;
   double            leftShoulderPrice;
  };

static datetime lastBartime = 0;
TradedPatterns tradedPatterns[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int chart_width = (int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
int chart_height = (int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
int chart_scale = (int)ChartGetInteger(0,CHART_SCALE);
int chart_first_vis_bar = (int)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR);
int chart_vis_bars = (int)ChartGetInteger(0,CHART_VISIBLE_BARS);
double chart_Prcmin = ChartGetDouble(0, CHART_PRICE_MIN,0);
double chart_Prcmax = ChartGetDouble(0, CHART_PRICE_MAX,0);

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int BarWidth(int scale) {return (int)pow(2,scale);}
int ShiftToX(int shift) {return (chart_first_vis_bar-shift)*BarWidth(chart_scale)-1;}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int PriceToY(double price)
  {
   if(chart_Prcmax - chart_Prcmin == 0.0)
      return 0;
   return (int)round(chart_height * (chart_Prcmax - price)/(chart_Prcmax-chart_Prcmin)-1);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsPatternTraded(datetime lsTime, double lsPrice)
  {
   int size = ArraySize(tradedPatterns);
   for(int i=0; i<size; i++)
     {
      if(tradedPatterns[i].leftShoulderTime == lsTime && MathAbs(tradedPatterns[i].leftShoulderPrice-lsPrice) < PriceTolerance *_Point)
        {
         Print("Pattern already traded: Left Shoulder Time = ",TimeToString(lsTime));
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ApplyTrailingStop(int minTrailPoints, int trailingPoints, CTrade &trade_object, ulong magicNo = 0)
  {
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && ticket > 0)
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            (magicNo == 0 || PositionGetInteger(POSITION_MAGIC)==magicNo)
           )
           {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentProfit = PositionGetDouble(POSITION_PROFIT)/(lotsize*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE));

            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
              {
               double profitPoints = (bid - openPrice)/_Point;
               if(profitPoints >= minTrailPoints+trailingPoints)
                 {
                  double newSl = NormalizeDouble(bid - trailingPoints*_Point,_Digits);
                  if(newSl > openPrice && (newSl > currentSL || currentSL == 0))
                    {
                     if(trade_object.PositionModify(ticket,newSl,PositionGetDouble(POSITION_TP)))
                       {
                        Print("Trailing Stop Updated: Ticket ",ticket,", New SL ",DoubleToString(newSl,_Digits));
                       }
                    }
                 }
              }
            else
               if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
                 {
                  double profitPoints = (openPrice - ask)/_Point;
                  if(profitPoints >= minTrailPoints+trailingPoints)
                    {
                     double newSl = NormalizeDouble(ask + trailingPoints*_Point,_Digits);
                     if(newSl < openPrice && (newSl < currentSL || currentSL == 0))
                       {
                        if(trade_object.PositionModify(ticket,newSl,PositionGetDouble(POSITION_TP)))
                          {
                           Print("Trailing Stop Updated: Ticket ",ticket,", New SL ",DoubleToString(newSl,_Digits));
                          }
                       }
                    }
                 }
           }
        }
     }

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AddTradedPattern(datetime lsTime, double lsPrice)
  {
   int size = ArraySize(tradedPatterns);
   if(size >= MaxTradedPatterns)
     {
      for(int i=0; i<size-1; i++)
        {
         tradedPatterns[i] = tradedPatterns[i+1];
        }
      ArrayResize(tradedPatterns,size-1);
      size--;
      Print("Removed oldest traded pattern to maintain max size of ",MaxTradedPatterns);
     }
   ArrayResize(tradedPatterns,size+1);
   tradedPatterns[size].leftShoulderTime = lsTime;
   tradedPatterns[size].leftShoulderPrice = lsPrice;
   Print("Added traded pattern: Left shoulder Time = ",TimeToString(lsTime));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawTrendLine(string name, datetime timestart, double pricestart, datetime timeend, double priceend, color linecolor, int width, int style)
  {
   if(ObjectCreate(0, name, OBJ_TREND, 0, timestart, pricestart,timeend,priceend))
     {
      ObjectSetInteger(0,name,OBJPROP_COLOR,linecolor);
      ObjectSetInteger(0,name,OBJPROP_STYLE,style);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ChartRedraw();
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawTriangle(string name, datetime time1, double price1, datetime time2, double price2, datetime time3, double price3, color fillcolor)
  {
   if(ObjectCreate(0, name, OBJ_TRIANGLE, 0, time1, price1,time2,price2,time3,price3))
     {
      ObjectSetInteger(0,name,OBJPROP_COLOR,fillcolor);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_FILL,true);
      ChartRedraw();
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawText(string name, datetime time, double price, string text, color textcolor, bool above, double angle = 0)
  {
   int chartScale = (int)ChartGetInteger(0,CHART_SCALE);
   int dynamicFontSize = 5 + int(chartScale*1.5);
   double priceOffset = (above ? priceOffsetForText : -priceOffsetForText) *_Point;
   if(ObjectCreate(0, name, OBJ_TEXT, 0, time, price+priceOffset))
     {
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetInteger(0,name,OBJPROP_COLOR,textcolor);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,dynamicFontSize);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_CENTER);
      ObjectSetDouble(0,name,OBJPROP_ANGLE,angle);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ChartRedraw();
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NeckLineCrossesBar(double necklineprice, int barIndex)
  {
   double high = iHigh(_Symbol,_Period,barIndex);
   double low = iLow(_Symbol,_Period,barIndex);
   return (necklineprice >= low && necklineprice <= high);
  }


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   obj_Trade.SetExpertMagicNumber(magicNumber);
   ArrayResize(tradedPatterns,0);
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

// if (UseTrailingStop && PositionsTotal() > 0){
//    ApplyTrailingStop(MinTrailingPoints,TrailingPoints,obj_Trade,magicNumber);
// }

   datetime currentBarTime = iTime(_Symbol,_Period,0);
   if(currentBarTime == lastBartime)
      return;

   lastBartime = currentBarTime;

   chart_width = (int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   chart_height = (int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   chart_scale = (int)ChartGetInteger(0,CHART_SCALE);
   chart_first_vis_bar = (int)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR);
   chart_vis_bars = (int)ChartGetInteger(0,CHART_VISIBLE_BARS);
   chart_Prcmin = ChartGetDouble(0, CHART_PRICE_MIN,0);
   chart_Prcmax = ChartGetDouble(0, CHART_PRICE_MAX,0);

   if(PositionsTotal() > 0)
      return;

   Extremum extrema[];
   FindExtrema(extrema,LookbackBars);

   int leftShoulderIdx, headIdx, rightShoulderIdx, necklineStartIdx, necklineEndIdx;

   if(DetectHeadAndShoulders(extrema,leftShoulderIdx,headIdx,rightShoulderIdx,necklineStartIdx,necklineEndIdx))
     {
      double closePrice = iClose(_Symbol,_Period,1);
      double necklinePrice = extrema[necklineEndIdx].price;

      if(closePrice < necklinePrice)
        {
         datetime lsTime = extrema[leftShoulderIdx].time;
         double lsPrice = extrema[leftShoulderIdx].price;

         if(IsPatternTraded(lsTime,lsPrice))
            return;

         datetime breakoutTime = iTime(_Symbol,_Period,1);
         int lsBar = extrema[leftShoulderIdx].bar;
         int headBar = extrema[headIdx].bar;
         int rsBar = extrema[rightShoulderIdx].bar;
         int necklineStartBar = extrema[necklineStartIdx].bar;
         int necklineEndBar = extrema[necklineEndIdx].bar;
         int breakoutBar = 1;

         int lsToHead = lsBar - headBar;
         int headToRs = headBar - rsBar;
         int rsToBreakout = rsBar - breakoutBar;
         int lsToNeckStart = lsBar - necklineStartBar;
         double avgPatternRange = (lsToHead+headToRs)/2.0;

         if(rsToBreakout > avgPatternRange *RightShoulderBreakoutMultiplier)
           {
            Print("Pattern rejected....");
            return;
           }

         double necklineStartPrice = extrema[necklineStartIdx].price;
         double necklineEndPrice = extrema[necklineEndIdx].price;
         datetime necklineStartTime = extrema[necklineStartIdx].time;
         datetime necklineEndTime = extrema[necklineEndIdx].time;
         int barDiff = necklineStartBar - necklineEndBar;
         double slope = (necklineEndPrice - necklineStartPrice)/barDiff;
         double breakoutNecklinePrice = necklineStartPrice+slope *(necklineStartBar-breakoutBar);

         int extendedBar = necklineStartBar;
         datetime extendedNeckLineStartTime = necklineStartTime;
         double extendedNeckLineStartPrice = necklineStartPrice;
         bool foundCrossing = false;

         for(int i=necklineStartBar+1; i<Bars(_Symbol,_Period); i++)
           {
            double checkPrice = necklineStartPrice - slope*(i-necklineStartBar);
            if(NeckLineCrossesBar(checkPrice,i))
              {
               int distance = i-necklineStartBar;
               if(distance <= avgPatternRange*RightShoulderBreakoutMultiplier)
                 {
                  extendedBar = i;
                  extendedNeckLineStartTime = iTime(_Symbol,_Period,i);
                  extendedNeckLineStartPrice = checkPrice;
                  foundCrossing = true;
                  Print("Neckline extended to first crossing bar within uniformity: Bar ",extendedBar);
                  break;
                 }
               else
                 {
                  Print("Crossing bar ",i," exceeds uniformity!");
                  break;
                 }
              }
           }

         if(!foundCrossing)
           {
            int barsToExtend = 2*lsToNeckStart;
            extendedBar = necklineStartBar+barsToExtend;
            if(extendedBar >= Bars(_Symbol,_Period))
               extendedBar = Bars(_Symbol,_Period)-1;
            extendedNeckLineStartTime = iTime(_Symbol,_Period,extendedBar);
            extendedNeckLineStartPrice = necklineStartPrice - slope*(extendedBar-necklineStartBar);
            Print("Neckline extended to fallback (2x LS to Neckline start)");
           }

         string prefix = "HS_"+TimeToString(extrema[headIdx].time,TIME_MINUTES);

         DrawTrendLine(prefix+"_LeftToNeckStart",lsTime,lsPrice,necklineStartTime,necklineStartPrice,clrRed,3,STYLE_SOLID);
         DrawTrendLine(prefix+"_NeckStartToHead",necklineStartTime,necklineStartPrice,extrema[headIdx].time,extrema[headIdx].price,clrRed,3,STYLE_SOLID);
         DrawTrendLine(prefix+"_HeadToNeckEnd",extrema[headIdx].time,extrema[headIdx].price,necklineEndTime,necklineEndPrice,clrRed,3,STYLE_SOLID);
         DrawTrendLine(prefix+"_NeckEndToRight",necklineEndTime,necklineEndPrice,extrema[rightShoulderIdx].time,extrema[rightShoulderIdx].price,clrRed,3,STYLE_SOLID);
         DrawTrendLine(prefix+"_Neckline",extendedNeckLineStartTime,extendedNeckLineStartPrice,breakoutTime,breakoutNecklinePrice,clrRed,3,STYLE_SOLID);
         DrawTrendLine(prefix+"_RightToBreakout",extrema[rightShoulderIdx].time,extrema[rightShoulderIdx].price,breakoutTime,breakoutNecklinePrice,clrRed,3,STYLE_SOLID);
         DrawTrendLine(prefix+"_ExtendedToLeftShoulder",extendedNeckLineStartTime,extendedNeckLineStartPrice,lsTime,lsPrice,clrRed,3,STYLE_SOLID);

         DrawTriangle(prefix+"_LeftShoulderTriangle",lsTime,lsPrice,necklineStartTime,necklineStartPrice,extendedNeckLineStartTime,extendedNeckLineStartPrice,clrLightCoral);
         DrawTriangle(prefix+"_HeadTriangle",extrema[headIdx].time,extrema[headIdx].price,necklineStartTime,necklineStartPrice,necklineEndTime,necklineEndPrice,clrLightCoral);
         DrawTriangle(prefix+"_RightShoulderTriangle",extrema[rightShoulderIdx].time,extrema[rightShoulderIdx].price,necklineEndTime,necklineEndPrice,breakoutTime,breakoutNecklinePrice,clrLightCoral);

         DrawText(prefix+"_LS_Label",lsTime,lsPrice,"LS",clrRed,true);
         DrawText(prefix+"_Head_Label",extrema[headIdx].time,extrema[headIdx].price,"HEAD",clrRed,true);
         DrawText(prefix+"_RS_Label",extrema[rightShoulderIdx].time,extrema[rightShoulderIdx].price,"RS",clrRed,true);

         datetime necklineMidTime = extendedNeckLineStartTime+(breakoutTime-extendedNeckLineStartTime)/2;
         double necklineMidPrice = extendedNeckLineStartPrice+slope*(iBarShift(_Symbol,_Period,extendedNeckLineStartTime)-iBarShift(_Symbol,_Period,necklineMidTime));

         int x1 = ShiftToX(iBarShift(_Symbol,_Period,extendedNeckLineStartTime));
         int y1 = PriceToY(extendedNeckLineStartPrice);
         int x2 = ShiftToX(iBarShift(_Symbol,_Period,breakoutTime));
         int y2 = PriceToY(breakoutNecklinePrice);

         double pixelSlope = (y2-y1)/double (x2-x1);
         double necklineAngle = -atan(pixelSlope) *180/M_PI;

         DrawText(prefix+"_Neckline_Label",necklineMidTime,necklineMidPrice,"NECKLINE",clrBlue,false,necklineAngle);

         double entryPrice = 0;
         double sl = extrema[rightShoulderIdx].price+BufferPoints*_Point;
         double patternHeight = extrema[headIdx].price - necklinePrice;
         double tp = closePrice - patternHeight;

         if(sl > closePrice && tp < closePrice)
           {
            if(obj_Trade.Sell(lotsize,_Symbol,entryPrice,sl,tp,"Head & Shoulders"))
              {
               AddTradedPattern(lsTime,lsPrice);
               Print("Sell trade opened: SL ",DoubleToString(sl,_Digits),", TP ",DoubleToString(tp,_Digits));
              }
           }
        }
     }

   if(DetectInversedHeadAndShoulders(extrema,leftShoulderIdx,headIdx,rightShoulderIdx,necklineStartIdx,necklineEndIdx))
     {
      double closePrice = iClose(_Symbol,_Period,1);
      double necklinePrice = extrema[necklineEndIdx].price;

      if(closePrice > necklinePrice)
        {
         datetime lsTime = extrema[leftShoulderIdx].time;
         double lsPrice = extrema[leftShoulderIdx].price;

         if(IsPatternTraded(lsTime,lsPrice))
            return;

         datetime breakoutTime = iTime(_Symbol,_Period,1);
         int lsBar = extrema[leftShoulderIdx].bar;
         int headBar = extrema[headIdx].bar;
         int rsBar = extrema[rightShoulderIdx].bar;
         int necklineStartBar = extrema[necklineStartIdx].bar;
         int necklineEndBar = extrema[necklineEndIdx].bar;
         int breakoutBar = 1;

         int lsToHead = lsBar - headBar;
         int headToRs = headBar - rsBar;
         int rsToBreakout = rsBar - breakoutBar;
         int lsToNeckStart = lsBar - necklineStartBar;
         double avgPatternRange = (lsToHead+headToRs)/2.0;

         if(rsToBreakout > avgPatternRange *RightShoulderBreakoutMultiplier)
           {
            Print("Pattern rejected....");
            return;
           }

         double necklineStartPrice = extrema[necklineStartIdx].price;
         double necklineEndPrice = extrema[necklineEndIdx].price;
         datetime necklineStartTime = extrema[necklineStartIdx].time;
         datetime necklineEndTime = extrema[necklineEndIdx].time;
         int barDiff = necklineStartBar - necklineEndBar;
         double slope = (necklineEndPrice - necklineStartPrice)/barDiff;
         double breakoutNecklinePrice = necklineStartPrice+slope *(necklineStartBar-breakoutBar);

         int extendedBar = necklineStartBar;
         datetime extendedNeckLineStartTime = necklineStartTime;
         double extendedNeckLineStartPrice = necklineStartPrice;
         bool foundCrossing = false;

         for(int i=necklineStartBar+1; i<Bars(_Symbol,_Period); i++)
           {
            double checkPrice = necklineStartPrice - slope*(i-necklineStartBar);
            if(NeckLineCrossesBar(checkPrice,i))
              {
               int distance = i-necklineStartBar;
               if(distance <= avgPatternRange*RightShoulderBreakoutMultiplier)
                 {
                  extendedBar = i;
                  extendedNeckLineStartTime = iTime(_Symbol,_Period,i);
                  extendedNeckLineStartPrice = checkPrice;
                  foundCrossing = true;
                  Print("Neckline extended to first crossing bar within uniformity: Bar ",extendedBar);
                  break;
                 }
               else
                 {
                  Print("Crossing bar ",i," exceeds uniformity!");
                  break;
                 }
              }
           }

         if(!foundCrossing)
           {
            int barsToExtend = 2*lsToNeckStart;
            extendedBar = necklineStartBar+barsToExtend;
            if(extendedBar >= Bars(_Symbol,_Period))
               extendedBar = Bars(_Symbol,_Period)-1;
            extendedNeckLineStartTime = iTime(_Symbol,_Period,extendedBar);
            extendedNeckLineStartPrice = necklineStartPrice - slope*(extendedBar-necklineStartBar);
            Print("Neckline extended to fallback (2x LS to Neckline start)");
           }

         string prefix = "IHS_"+TimeToString(extrema[headIdx].time,TIME_MINUTES);

         DrawTrendLine(prefix+"_LeftToNeckStart",lsTime,lsPrice,necklineStartTime,necklineStartPrice,clrGreen,3,STYLE_SOLID);
         DrawTrendLine(prefix+"_NeckStartToHead",necklineStartTime,necklineStartPrice,extrema[headIdx].time,extrema[headIdx].price,clrGreen,3,STYLE_SOLID);
         DrawTrendLine(prefix+"_HeadToNeckEnd",extrema[headIdx].time,extrema[headIdx].price,necklineEndTime,necklineEndPrice,clrGreen,3,STYLE_SOLID);
         DrawTrendLine(prefix+"_NeckEndToRight",necklineEndTime,necklineEndPrice,extrema[rightShoulderIdx].time,extrema[rightShoulderIdx].price,clrGreen,3,STYLE_SOLID);
         DrawTrendLine(prefix+"_Neckline",extendedNeckLineStartTime,extendedNeckLineStartPrice,breakoutTime,breakoutNecklinePrice,clrGreen,3,STYLE_SOLID);
         DrawTrendLine(prefix+"_RightToBreakout",extrema[rightShoulderIdx].time,extrema[rightShoulderIdx].price,breakoutTime,breakoutNecklinePrice,clrGreen,3,STYLE_SOLID);
         DrawTrendLine(prefix+"_ExtendedToLeftShoulder",extendedNeckLineStartTime,extendedNeckLineStartPrice,lsTime,lsPrice,clrGreen,3,STYLE_SOLID);

         DrawTriangle(prefix+"_LeftShoulderTriangle",lsTime,lsPrice,necklineStartTime,necklineStartPrice,extendedNeckLineStartTime,extendedNeckLineStartPrice,clrLightGreen);
         DrawTriangle(prefix+"_HeadTriangle",extrema[headIdx].time,extrema[headIdx].price,necklineStartTime,necklineStartPrice,necklineEndTime,necklineEndPrice,clrLightGreen);
         DrawTriangle(prefix+"_RightShoulderTriangle",extrema[rightShoulderIdx].time,extrema[rightShoulderIdx].price,necklineEndTime,necklineEndPrice,breakoutTime,breakoutNecklinePrice,clrLightGreen);

         DrawText(prefix+"_LS_Label",lsTime,lsPrice,"LS",clrGreen,false);
         DrawText(prefix+"_Head_Label",extrema[headIdx].time,extrema[headIdx].price,"HEAD",clrGreen,false);
         DrawText(prefix+"_RS_Label",extrema[rightShoulderIdx].time,extrema[rightShoulderIdx].price,"RS",clrGreen,false);

         datetime necklineMidTime = extendedNeckLineStartTime+(breakoutTime-extendedNeckLineStartTime)/2;
         double necklineMidPrice = extendedNeckLineStartPrice+slope*(iBarShift(_Symbol,_Period,extendedNeckLineStartTime)-iBarShift(_Symbol,_Period,necklineMidTime));

         int x1 = ShiftToX(iBarShift(_Symbol,_Period,extendedNeckLineStartTime));
         int y1 = PriceToY(extendedNeckLineStartPrice);
         int x2 = ShiftToX(iBarShift(_Symbol,_Period,breakoutTime));
         int y2 = PriceToY(breakoutNecklinePrice);

         double pixelSlope = (y2-y1)/double (x2-x1);
         double necklineAngle = -atan(pixelSlope) *180/M_PI;

         DrawText(prefix+"_Neckline_Label",necklineMidTime,necklineMidPrice,"NECKLINE",clrBlue,true,necklineAngle);

         double entryPrice = 0;
         double sl = extrema[rightShoulderIdx].price-BufferPoints*_Point;
         double patternHeight = necklinePrice - extrema[headIdx].price;
         double tp = closePrice + patternHeight;

         if(sl < closePrice && tp > closePrice)
           {
            if(obj_Trade.Buy(lotsize,_Symbol,entryPrice,sl,tp,"Iversed Head & Shoulders"))
              {
               AddTradedPattern(lsTime,lsPrice);
               Print("Buy trade opened: SL ",DoubleToString(sl,_Digits),", TP ",DoubleToString(tp,_Digits));
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void FindExtrema(Extremum &extrema[], int lookback)
  {
   ArrayFree(extrema);
   int bars = Bars(_Symbol,_Period);
   if(lookback >= bars)
      lookback = bars-1;

   double highs[], lows[];
   ArraySetAsSeries(highs,true);
   ArraySetAsSeries(lows,true);
   CopyHigh(_Symbol,_Period,0,lookback+1,highs);
   CopyLow(_Symbol,_Period,0,lookback+1,lows);

   bool isUpTrend = highs[lookback] < highs[lookback-1];// this is incorrect
   double lastHigh = highs[lookback];
   double lastLow = lows[lookback];
   int lastExtremumBar = lookback;

   for(int i=lookback-1; i>= 0; i--)
     {
      if(isUpTrend)
        {
         if(highs[i] > lastHigh)
           {
            lastHigh = highs[i];
            lastExtremumBar = i;
           }
         else
            if(lows[i] < lastHigh-ThresholdPoints*_Point)
              {
               int size = ArraySize(extrema);
               ArrayResize(extrema,size+1);
               extrema[size].bar = lastExtremumBar;
               extrema[size].time = iTime(_Symbol,_Period,lastExtremumBar);// This seems to be incorrect
               extrema[size].price = lastHigh;
               extrema[size].isPeak = true;
               isUpTrend = false;
               lastLow = lows[i];
               lastExtremumBar = i;
              }
        }
      else
        {
         if(lows[i] < lastLow)
           {
            lastLow = lows[i];
            lastExtremumBar = i;
           }
         else
            if(highs[i] > lastLow+ThresholdPoints*_Point)
              {
               int size = ArraySize(extrema);
               ArrayResize(extrema,size+1);
               extrema[size].bar = lastExtremumBar;
               extrema[size].time = iTime(_Symbol,_Period,lastExtremumBar);
               extrema[size].price = lastLow;
               extrema[size].isPeak = false;
               isUpTrend = true;
               lastHigh = highs[i];
               lastExtremumBar = i;
              }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool DetectHeadAndShoulders(Extremum &extrema[], int &leftshoulderIdx, int &headIdx, int &rightShoulderIdx, int &necklineStartIdx, int &neckLineEndIdx)
  {
   int size = ArraySize(extrema);
   if(size < 6)
      return false;

   for(int i=size-6; i>=0; i--)
     {
      if(!extrema[i].is Peak && extrema[i+1].isPeak && !extrema[i+2].isPeak && extrema[i+3].isPeak && !extrema[i+4].isPeak && extrema[i+5].isPeak)
        {
         double leftShoulder = extrema[i+1].price;
         double head = extrema[i+3].price;
         double rightShoulder  = extrema[i+5].price;
         double trough1 = extrema[i+2].price;
         double trough2 = extrema[i+4].price;

         bool isHeadHighest = true;
         for(int j=MathMax(0,i-5); j<MathMin(size,i+10); j++)
           {
            if(extrema[j].isPeak && extrema[j].price > head && j != i+3)
              {
               isHeadHighest = false;
               break;
              }
           }

         int lsBar = extrema[i+1].bar;
         int headBar = extrema[i+3].bar;
         int rsBar = extrema[i+5].bar;
         int lsToHead = lsBar - headBar;
         int headToRs = headBar - rsBar;

         if(lsToHead < minBarRange || lsToHead > maxBarRange || headToRs < minBarRange || headToRs > maxBarRange)
            continue;

         int minRange = MathMin(lsToHead, headToRs);
         if(lsToHead > minRange*BarRangeMultiplier || headToRs > minRange*BarRangeMultiplier)
            continue;

         bool rsValid = false;
         int rsBarIndex = extrema[i+5].bar;
         for(int j=rsBarIndex-1; j>=MathMax(0,rsBarIndex-validationBars); j--)
           {
            if(iLow(_Symbol,_Period,j) < rightShoulder-ThresholdPoints*_Point)
              {
               rsValid = true;
               break;
              }
           }
         if(!rsValid)
            continue;

         if(isHeadHighest && head > leftShoulder && head > rightShoulder && MathAbs(leftShoulder-rightShoulder) < shoulderTolerancePoints *_Point && MathAbs(trough1 - trough2) < TroughTolerancePoints *_Point)
           {
            leftshoulderIdx = i+1;
            headIdx = i+3;
            rightShoulderIdx = i+5;
            necklineStartIdx = i+2;
            neckLineEndIdx = i+4;
            Print("Bar ranges: LS to Head = ",lsToHead,", Head to RS = ",headToRs);
            return true;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool DetectInversedHeadAndShoulders(Extremum &extrema[], int &leftshoulderIdx, int &headIdx, int &rightShoulderIdx, int &necklineStartIdx, int &neckLineEndIdx)
  {
   int size = ArraySize(extrema);
   if(size < 6)
      return false;

   for(int i=size-6; i>=0; i--)
     {
      if(extrema[i].isPeak && !extrema[i+1].isPeak && extrema[i+2].isPeak && !extrema[i+3].isPeak && extrema[i+4].isPeak && !extrema[i+5].isPeak)
        {
         double leftShoulder = extrema[i+1].price;
         double head = extrema[i+3].price;
         double rightShoulder  = extrema[i+5].price;
         double peak1 = extrema[i+2].price;
         double peak2 = extrema[i+4].price;

         bool isHeadLowest = true;
         int headBar = extrema[i+3].bar;
         for(int j=MathMax(0,headBar-5); j<=MathMin(Bars(_Symbol,_Period)-1,headBar+5); j++)
           {
            if(iLow(_Symbol,_Period,j) < head)
              {
               isHeadLowest = false;
               break;
              }
           }

         int lsBar = extrema[i+1].bar;
         int rsBar = extrema[i+5].bar;
         int lsToHead = lsBar - headBar;
         int headToRs = headBar - rsBar;

         if(lsToHead < minBarRange || lsToHead > maxBarRange || headToRs < minBarRange || headToRs > maxBarRange)
            continue;

         int minRange = MathMin(lsToHead, headToRs);
         if(lsToHead > minRange*BarRangeMultiplier || headToRs > minRange*BarRangeMultiplier)
            continue;

         bool rsValid = false;
         int rsBarIndex = extrema[i+5].bar;
         for(int j=rsBarIndex-1; j>=MathMax(0,rsBarIndex-validationBars); j--)
           {
            if(iHigh(_Symbol,_Period,j) > rightShoulder+ThresholdPoints*_Point)
              {
               rsValid = true;
               break;
              }
           }
         if(!rsValid)
            continue;

         if(isHeadLowest && head < leftShoulder && head < rightShoulder && MathAbs(leftShoulder-rightShoulder) < shoulderTolerancePoints *_Point && MathAbs(peak1 - peak2) < TroughTolerancePoints *_Point)
           {
            leftshoulderIdx = i+1;
            headIdx = i+3;
            rightShoulderIdx = i+5;
            necklineStartIdx = i+2;
            neckLineEndIdx = i+4;
            Print("Bar ranges: LS to Head = ",lsToHead,", Head to RS = ",headToRs);
            return true;
           }
        }
     }
   return false;
  }
//+------------------------------------------------------------------+
