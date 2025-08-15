#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

double SignalBuffer[];

input int RSI_Period = 14;
input int Volume_Period = 20;
input double PriceTolerance = 0.0015;

int rsi_handle;

// === INIT ===
int OnInit() {
   SetIndexBuffer(0, SignalBuffer, INDICATOR_DATA);
   ArrayInitialize(SignalBuffer, EMPTY_VALUE);

   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);     // Set draw type
   PlotIndexSetInteger(0, PLOT_ARROW, 233);                 // Arrow code (233 = ↑)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrLime);        // Arrow color
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 1);              // Arrow width
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, STYLE_SOLID);    // Arrow style
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);          // Precision

   IndicatorSetString(INDICATOR_SHORTNAME, "PatternDetector");

   return INIT_SUCCEEDED;
}

// === HELPERS ===
double GetAverageVolume(const long &volume[], int index, int period) {
   double sum = 0;
   for (int i = index; i < index + period && i < ArraySize(volume); i++) {
      sum += (double)volume[i];
   }
   return (period > 0) ? sum / period : 0;
}

double FindMaxHigh(const double &high[], int from, int to) {
   double maxHigh = high[from];
   for (int i = from + 1; i <= to; i++) {
      if (high[i] > maxHigh)
         maxHigh = high[i];
   }
   return maxHigh;
}

bool IsLocalLow(const double &low[], int i, int rates_total) {
   return (i > 0 && i < rates_total - 1 && low[i] < low[i + 1] && low[i] < low[i - 1]);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {

   double rsiBuffer[];
   ArraySetAsSeries(rsiBuffer, true);

   for (int i = rates_total - 50; i >= 30; i--) {
      // === DOUBLE BOTTOM ===
      if (IsLocalLow(low, i, rates_total)) {
         double firstLow = low[i];
         if (i - 30 >= 0) {
            for (int j = i - 10; j >= i - 30; j--) {
               if (IsLocalLow(low, j, rates_total) && MathAbs(low[j] - firstLow) < firstLow * PriceTolerance) {
                  double neckline = FindMaxHigh(high, j, i);
                  if (close[j - 1] > neckline) {
                     if (CopyBuffer(rsi_handle, 0, j - 1, 1, rsiBuffer) <= 0) continue;
                     double rsi = rsiBuffer[0];
                     double vol = (double)volume[j - 1];
                     double avgVol = GetAverageVolume(volume, j - 1, Volume_Period);

                     if (rsi > 50 && vol > avgVol) {
                        SignalBuffer[j - 1] = low[j - 1] - 5 * _Point;

                        Print("Pattern Detected: Double Bottom");
                        Print("Time: ", TimeToString(time[j - 1], TIME_DATE | TIME_MINUTES));
                        Print("- RSI = ", DoubleToString(rsi, 2), ", Volume = ", vol, ", AvgVol = ", avgVol);
                        Print("Buy Signal ✅");
                     }
                  }
               }
            }
         }
      }

      // === INVERSE HEAD & SHOULDERS ===
      if (i + 8 < rates_total &&
          IsLocalLow(low, i, rates_total) &&
          IsLocalLow(low, i + 4, rates_total) &&
          IsLocalLow(low, i + 8, rates_total)) {

         double L1 = low[i + 8];
         double H1 = high[i + 6];
         double L2 = low[i + 4];
         double H2 = high[i + 2];
         double L3 = low[i];
         double neckline = MathMax(H1, H2);

         if (L2 < L1 && L2 < L3 && close[i - 1] > neckline) {
            if (CopyBuffer(rsi_handle, 0, i - 1, 1, rsiBuffer) <= 0) continue;
            double rsi = rsiBuffer[0];
            double vol = (double)volume[i - 1];
            double avgVol = GetAverageVolume(volume, i - 1, Volume_Period);

            if (rsi > 50 && vol > avgVol) {
               SignalBuffer[i - 1] = low[i - 1] - 5 * _Point;

               Print("Pattern Detected: Inverse Head and Shoulders");
               Print("Time: ", TimeToString(time[i - 1], TIME_DATE | TIME_MINUTES));
               Print("- RSI = ", DoubleToString(rsi, 2), ", Volume = ", vol, ", AvgVol = ", avgVol);
               Print("Buy Signal ✅");
            }
         }
      }
   }

   return rates_total;
}
