//+------------------------------------------------------------------+
//|                                                  ATR Channel.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window


// 
// Indicator properties
//
#property indicator_buffers 3;
#property indicator_plots   3;


// Main line properties
#property indicator_color1 clrGreen
#property indicator_label1 "Main"
#property indicator_style1 STYLE_SOLID
#property indicator_type1 DRAW_LINE
#property indicator_width1 3


// Upper line properties
#property indicator_color2 clrWhite
#property indicator_label2 "Upper"
#property indicator_style2 STYLE_SOLID
#property indicator_type2 DRAW_LINE
#property indicator_width2 1

// Lower line properties
#property indicator_color3 clrYellow
#property indicator_label3 "Lower"
#property indicator_style3 STYLE_SOLID
#property indicator_type3 DRAW_LINE
#property indicator_width3 1

//
// Inputs
//
// Moving Average
input int InpMABars = 10; // Moving avergae bars
input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // Moving average method
input ENUM_APPLIED_PRICE INpMAAppliedPrice = PRICE_CLOSE; // Moving average applied price

// ATR
input int InpATRBars = 10;
input double InpATRFactor = 3.0;

//
//Indicator data buffers
//
double BufferMain[];
double BufferUpper[];
double BufferLower[];

//
// Internal indicator handles
int HandleMA;
int HandleATR;
double ValuesMA[];
double ValuesATR[];


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
    SetIndexBuffer(BASE_LINE, BufferMain); // BASE_LINE = 0
    SetIndexBuffer(UPPER_BAND, BufferUpper); // UPPER_BAND = 1
    SetIndexBuffer(LOWER_BAND, BufferLower); // LOWER_BAND = 2

    // Number of buffer is done here
    ArraySetAsSeries(BufferMain, true);
    ArraySetAsSeries(BufferUpper, true);
    ArraySetAsSeries(BufferLower, true);

    HandleMA = iMA(Symbol(), Period(), InpMABars, 0, InpMAMethod, INpMAAppliedPrice);
    HandleATR = iATR(Symbol(), Period(), InpATRBars);

    ArraySetAsSeries(ValuesMA, true);
    ArraySetAsSeries(ValuesATR, true);

    if (HandleMA == INVALID_HANDLE || HandleATR == INVALID_HANDLE) {
      Print("Failed to create indicator handle");
      return( INIT_FAILED );
    }
   
//---
   return(INIT_SUCCEEDED);
  }

void OnDeinit( const int reason ) {
    IndicatorRelease( HandleMA );
    IndicatorRelease( HandleATR );
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, // No of bars in total
                const int prev_calculated, // Returned from the last call
                const datetime &time[], // Array of bar start times
                const double &open[], // Array of bar opening prices
                const double &high[], // Arrray of bar high prices
                const double &low[], // Array of bar low prices
                const double &close[], // close
                const long &tick_volume[], // tick volume
                const long &volume[], // volume
                const int &spread[]) // spread
  {
//---

    // How many bars to calculate
    int count = rates_total - prev_calculated; // no of bars - no already calculated
    // this logic is to ensure that last index of indicator is updated with price change
    if ( prev_calculated > 0) count++;

    if (CopyBuffer(HandleMA, 0, 0, count, ValuesMA) < count) return (0);
    if (CopyBuffer(HandleATR, 0, 0, count, ValuesATR) < count) return (0);

    // count down = from left to right, not essential for this
    // but for some indicators each value depends on values before
    for ( int i = count -1; i >=0; i-- ) {
        BufferMain[i] = ValuesMA[i];
        double channelWidth = InpATRFactor * ValuesATR[i];
        BufferUpper[i] = BufferMain[i] + channelWidth;
        BufferLower[i] = BufferMain[i] - channelWidth;
    }
   
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
