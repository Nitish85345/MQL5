//+------------------------------------------------------------------+
//|                                             create_box.mq5       |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

input color    BoxColor        = clrRed;  // Box color
input int      BoxTransparency = 50;      // Transparency (0-255)
input int      BoxWidth        = 2;       // Border width

bool isFirstRun = true;
datetime lastDrawTime = 0;

//+------------------------------------------------------------------+
//| Create a visual rectangle box on the chart                       |
//+------------------------------------------------------------------+
void CreateBox(double bottomPrice, double topPrice, datetime leftTime, datetime rightTime)
{
   if(bottomPrice > topPrice)
   {
      double tmp = bottomPrice;
      bottomPrice = topPrice;
      topPrice = tmp;
   }

   if(leftTime > rightTime)
   {
      datetime tmp = leftTime;
      leftTime = rightTime;
      rightTime = tmp;
   }

   string boxName = "SmallRangeBox_" + IntegerToString(TimeCurrent()) + "_" + IntegerToString(MathRand());

   if(!ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, leftTime, bottomPrice, rightTime, topPrice))
   {
      Print("Failed to create box: ", boxName, " Error: ", GetLastError());
      return;
   }

   ObjectSetInteger(0, boxName, OBJPROP_COLOR, BoxColor);
   ObjectSetInteger(0, boxName, OBJPROP_WIDTH, BoxWidth);
   ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
   ObjectSetInteger(0, boxName, OBJPROP_FILL, true);

   Print("✅ Box created: ", boxName);
}

//+------------------------------------------------------------------+
//| Draw a box covering the last 5 completed candles                 |
//+------------------------------------------------------------------+
void DrawLast5CandlesBox(const int rates_total, const datetime &time[], const double &high[], const double &low[])
{
   if(rates_total < 6)
      return;

   double box_high = high[1];
   double box_low = low[1];
   for(int i = 2; i <= 5; i++)
   {
      if(high[i] > box_high) box_high = high[i];
      if(low[i] < box_low) box_low = low[i];
   }

   PrintFormat("🟥 Creating box: High=%.5f, Low=%.5f, LeftTime=%s, RightTime=%s",
               box_high, box_low, TimeToString(time[5], TIME_DATE|TIME_MINUTES), TimeToString(time[1], TIME_DATE|TIME_MINUTES));

   CreateBox(box_low, box_high, time[5], time[1]);
}


//+------------------------------------------------------------------+
//| Limit the number of boxes on the chart                           |
//+------------------------------------------------------------------+
void LimitBoxCount(int maxBoxes)
{
   int count = 0;
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "SmallRangeBox_") == 0)
         count++;
   }

   if(count > maxBoxes)
   {
      for(int i = ObjectsTotal(0) - 1; i >= 0 && count > maxBoxes; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, "SmallRangeBox_") == 0)
         {
            ObjectDelete(0, name);
            count--;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ObjectsDeleteAll(0, "SmallRangeBox_");
   lastDrawTime = 0;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Called on every new tick                                         |
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

   if (rates_total < 6)
      return(rates_total);

   if (time[1] != lastDrawTime)
   {
      DrawLast5CandlesBox(rates_total, time, high, low);
      LimitBoxCount(10);
      lastDrawTime = time[1];
   }

   return(rates_total);
}
