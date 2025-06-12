//+------------------------------------------------------------------+
//|                                                    detect_box.mq5 |
//|                                       Copyright 2025, Custom User |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Custom User"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

// Input parameters
input int      BoxHeight = 1000;   // Box height in points
input color    BoxColor = clrDodgerBlue;  // Box color
input int      BoxTransparency = 50;      // Box transparency (0-255)
input bool     ShowPriceRange = true;     // Show price range text
input color    TextColor = clrWhite;      // Text color
input int      TextSize = 8;              // Text size

// Global variables
int totalBoxes = 0;
string indicatorName = "DetectBox";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator short name
   IndicatorSetString(INDICATOR_SHORTNAME, "Detect Box");
   
   // Delete any existing objects from previous indicator runs
   ObjectsDeleteAll(0, indicatorName);
   
   // Reset box counter
   totalBoxes = 0;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   // Calculate only for new bars
   int limit = rates_total - prev_calculated;
   
   // If this is the first calculation or after indicator parameters change
   if(prev_calculated == 0)
   {
      // Delete all existing boxes
      ObjectsDeleteAll(0, indicatorName);
      totalBoxes = 0;
      
      // Create initial boxes based on price levels
      CreateBoxes(rates_total, time, high, low);
   }
   else if(limit > 0)
   {
      // Check if we need to create new boxes for new bars
      UpdateBoxes(rates_total, limit, time, high, low);
   }
   
   // Return value of prev_calculated for next call
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Create boxes based on price levels                               |
//+------------------------------------------------------------------+
void CreateBoxes(const int rates_total, const datetime &time[], const double &high[], const double &low[])
{
   // Get the highest and lowest prices in the visible chart area
   double chartHighest = ChartGetDouble(0, CHART_PRICE_MAX);
   double chartLowest = ChartGetDouble(0, CHART_PRICE_MIN);
   
   // Calculate how many boxes we need to cover the visible chart area
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double boxHeightPrice = BoxHeight * pointValue;
   
   // Calculate the number of boxes needed
   int numBoxes = (int)MathCeil((chartHighest - chartLowest) / boxHeightPrice) + 1;
   
   // Calculate the starting price level (round down to nearest box height)
   double startPrice = MathFloor(chartLowest / boxHeightPrice) * boxHeightPrice;
   
   // Create boxes
   for(int i = 0; i < numBoxes; i++)
   {
      double boxBottom = startPrice + (i * boxHeightPrice);
      double boxTop = boxBottom + boxHeightPrice;
      
      // Create the box
      CreateBox(boxBottom, boxTop, time[rates_total-1]);
   }
}

//+------------------------------------------------------------------+
//| Update boxes for new bars                                        |
//+------------------------------------------------------------------+
void UpdateBoxes(const int rates_total, const int limit, const datetime &time[], const double &high[], const double &low[])
{
   // Check if chart scale has changed significantly
   double chartHighest = ChartGetDouble(0, CHART_PRICE_MAX);
   double chartLowest = ChartGetDouble(0, CHART_PRICE_MIN);
   
   // Get the current boxes
   int totalObjects = ObjectsTotal(0);
   bool needsReset = true;
   
   // Check if we have any boxes
   for(int i = 0; i < totalObjects; i++)
   {
      string objName = ObjectName(0, i);
      if(StringFind(objName, indicatorName) >= 0)
      {
         needsReset = false;
         break;
      }
   }
   
   // If no boxes exist or chart scale changed significantly, recreate all boxes
   if(needsReset)
   {
      // Delete all existing boxes
      ObjectsDeleteAll(0, indicatorName);
      totalBoxes = 0;
      
      // Create new boxes
      CreateBoxes(rates_total, time, high, low);
   }
}

//+------------------------------------------------------------------+
//| Create a single box at the specified price levels                |
//+------------------------------------------------------------------+
void CreateBox(double bottomPrice, double topPrice, datetime rightTime)
{
   // Generate unique name for this box
   string boxName = indicatorName + "_Box_" + IntegerToString(totalBoxes);
   
   // Calculate the left time (30 bars back from right time)
   datetime leftTime = rightTime - PeriodSeconds(PERIOD_CURRENT) * 30;
   
   // Create rectangle object
   if(!ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, leftTime, bottomPrice, rightTime, topPrice))
   {
      Print("Failed to create box object: ", GetLastError());
      return;
   }
   
   // Set box properties
   ObjectSetInteger(0, boxName, OBJPROP_COLOR, BoxColor);
   ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
   ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
   
   // Set transparency
   ObjectSetInteger(0, boxName, OBJPROP_TRANSPARENCY, BoxTransparency);
   
   // Create price range text if enabled
   if(ShowPriceRange)
   {
      string textName = indicatorName + "_Text_" + IntegerToString(totalBoxes);
      string priceRangeText = DoubleToString(bottomPrice, _Digits) + " - " + DoubleToString(topPrice, _Digits);
      
      // Create text object
      if(!ObjectCreate(0, textName, OBJ_TEXT, 0, rightTime, (bottomPrice + topPrice) / 2))
      {
         Print("Failed to create text object: ", GetLastError());
      }
      else
      {
         // Set text properties
         ObjectSetString(0, textName, OBJPROP_TEXT, priceRangeText);
         ObjectSetInteger(0, textName, OBJPROP_COLOR, TextColor);
         ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, TextSize);
         ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
      }
   }
   
   // Increment box counter
   totalBoxes++;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Remove all objects created by this indicator
   ObjectsDeleteAll(0, indicatorName);
}
