//+------------------------------------------------------------------+
//|                                              HeadAndShoulder.mq5 |
//|                                     Copyright 2025, Nitish Kumar |
//|                                                 https://mql5.com |
//| 14.07.2025 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Nitish Kumar"
#property link      "https://mql5.com"
#property version   "1.00"
//// https://www.youtube.com/watch?v=vo-2JIKWynI video : [PART 179] Head and shoulder

#include <Trade/Trade.mqh>
CTrade obj_Trade;

input int lookbackBars = 50;
input double ThresholdPoints = 50.0;
input double shoulderTolerancePoints = 30;
input double TroughTolerancePoints = 30;
input double BufferPoints = 20;
input double lotsize = 0.1;
input ulong magicNumber = 1234567;
input int maxBarRange = 30;
input int minBarRange = 5;
input double BarRangeMulitpler = 2.0;
input int validationBars = 3;
input double PriceTolerance = 5.0;
input double RightShoulderBreakoutMulitplier = 1.5;
input int MaxTradedPatterns = 20;
input bool UseTrailingStop = true;
input int MinTrailingPoints = 10;
input int TrailingPoints = 30;


struct Extremum {
   int bar;
   datetime time;
   double price;
   bool isPeak;
};

struct TradedPatterns {
   datetime leftShoulderTime;
   double leftShoulderPrice;
};

static datetime lastBartime = 0;
TradedPatterns tradedPatterns[];

bool IsPatternTraded(datetime lsTime, double lsPrice){
   int size = ArraySize(tradedPatterns);
   for(int i=0; i<size; i++){
      if (tradedPatterns[i].leftShoulderTime == lsTime && MathAbs(tradedPatterns[i].leftShoulderPrice - lsPrice) < PriceTolerance * _Point) {
         Print("Pattern already traded: Left shoulder Time =", TimeToString(lsTime));
         return true;
      }
   }
   return false; 
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
   {
//---
      obj_Trade.SetExpertMagicNumber(magicNumber);
      ArrayResize(tradedPatterns, 0);
    
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
      datetime currentBarTime = iTime(_Symbol, _Period, 0);
      if (currentBarTime == lastBartime) return;

      lastBartime = currentBarTime;

      if(PositionsTotal() > 0) return;

      Extremum extrema[];
      FindExtrema(extrema, lookbackBars);

      int leftShoulderIdx, headIdx, rightShoulderIdx, necklineStartIdx, necklineEndIdx;
      
      if(DetectHeadAndShoulders(extrema, leftShoulderIdx, headIdx, rightShoulderIdx, necklineStartIdx, necklineEndIdx)) {
         double closePrice = iClose(_Symbol, _Period, 1);
         double necklinePrice = extrema[necklineEndIdx].price;

         if(closePrice < necklinePrice){
            Print("Breakout happened!!");
         }
      }
   }

//+------------------------------------------------------------------+


void FindExtrema(Extremum &extrema[], int lookback) {
   ArrayFree(extrema);
   int bars = Bars(_Symbol,_Period);
   if(lookback >= bars) lookback = bars - 1;

   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true); 
   CopyHigh (_Symbol,_Period,0,lookback+1,highs);
   CopyLow(_Symbol,_Period,0,lookback+1,lows);

   bool isUpTrend = highs[lookback] < highs[lookback-1];
   double lastHigh = highs[lookback];
   double lastLow = lows[lookback];
   int lastExtremumBar = lookback;

   for (int i=lookback-1; i>=0; i--){
      if(isUpTrend){
         if(highs[i] > lastHigh){
            lastHigh = highs[i];
            lastExtremumBar = i;
         }
         else if (lows[i] < lastHigh - ThresholdPoints*_Point){
            int size = ArraySize(extrema);
            ArrayResize(extrema, size+1);
            extrema[size].bar = lastExtremumBar;
            extrema[size].time = iTime(_Symbol,_Period,lastExtremumBar);
            extrema[size].price = lastHigh;
            extrema[size].isPeak = true;
            isUpTrend = false;
            lastLow = lows[i];
            lastExtremumBar = i;
         } else {
            if(lows[i] < lastLow){
               lastLow = lows[i];
               lastExtremumBar = i;
            } else if (highs[i] > lastLow + ThresholdPoints*_Point){
               int size = ArraySize(extrema);
               ArrayResize(extrema, size+1);
               extrema[size].bar = lastExtremumBar;
               extrema[size].time = iTime(_Symbol,_Period,lastExtremumBar);
               extrema[size].price = lastLow;
               extrema[size].isPeak = false;
               isUpTrend =true;
               lastHigh = highs[i];
               lastExtremumBar = i;
            }
         }
      }
   }
}

bool DetectHeadAndShoulders(Extremum &extrema[], int &leftshoulderIdx, int &headIdx, int &rightShoulderIdx, int &necklineStartIdx, int &neckLineEndIdx ){
   int size = ArraySize(extrema);
   if (size < 6) return false;

   for (int i=size-6; i>=0; i--){
      if(!extrema[i].isPeak && extrema[i+1].isPeak && !extrema[i+2].isPeak && extrema[i+3].isPeak &&  !extrema[i+4].isPeak &&  extrema[i+5].isPeak){
         double leftShoulder = extrema[i+1].price;
         double head = extrema[i+3].price;
         double rightShoulder = extrema[i+5].price;
         double trough1 = extrema[i+2].price;
         double trough2 = extrema[i+4].price;

         bool isHeadHighest = true;
         for (int j=MathMax(0, i-5); j<MathMin(size, i+10); j++){
            if(extrema[j].isPeak && extrema[j].price > head && j!= i+3){
               isHeadHighest = false;
               break;
            }
         }

         int lsBar = extrema[i+1].bar;
         int headBar = extrema[i+3].bar;
         int rsBar = extrema[i+5].bar;
         int lsToHead = lsBar - headBar;
         int headToRs = headBar - rsBar;

         if(lsToHead < minBarRange || lsToHead > maxBarRange || headToRs < minBarRange || headToRs > maxBarRange) continue;
         
         int minRange = MathMin(lsToHead, headToRs);
         if(lsToHead > minRange*BarRangeMulitpler || headToRs > minRange*BarRangeMulitpler) continue;

         bool rsValid = false;
         int rsBarIndex = extrema[i+5].bar;
         for(int j=rsBarIndex-1; j>=MathMax(0,rsBarIndex-validationBars); j--){
            if(iLow(_Symbol, _Period, j) < rightShoulder-ThresholdPoints*_Point){
               rsValid = true;
               break;
            }
         }
         if(!rsValid) continue;

         if(isHeadHighest && head > leftShoulder && head > rightShoulder && head > rightShoulder &&  MathAbs(leftShoulder-rightShoulder) < shoulderTolerancePoints*_Point && MathAbs(trough1-trough2) < TroughTolerancePoints *_Point){
            leftshoulderIdx = i+1;
            headIdx = i+3;
            rightShoulderIdx = i+5;
            necklineStartIdx = i+2;
            neckLineEndIdx = i+4;
            Print("Bar ranges: LS to Head = ",lsToHead,", Head to RS = ", headToRs);
            return true;
         }
      }
   }  
   
   return false;  
}