//+------------------------------------------------------------------+
//|                                      Our DEEP NEURAL NETWORK.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#define SIZEI 4
#define SIZEA 5
#define SIZEB 3


// include the library for exectution of trades
#include <Trade\Trade.mqh>
// include the library for obtaining the information on positions
#include <Trade/PositionInfo.mqh>

// entity for execution of trades >>> object from the class
CTrade Trade_Object;

CPositionInfo Positions_Object;

class DeepNeuralNetwork{
   private:    int numInput;
               int numHiddenA;
               int numHiddenB;
               int numOutput;
               
               double inputs[];
               
               double iaWeights[][SIZEI];
               double abWeights[][SIZEA];
               double boWeights[][SIZEB];
               
               double aBiases[];
               double bBiases[];
               double oBiases[];
               
               double aOutputs[];
               double bOutputs[];
               double outputs[];
               
   public:     // constructor
               DeepNeuralNetwork(int _numInput,int _numHiddenA,int _numHiddenB,int _numOutput){
                  this.numInput = _numInput; //assigns the value of the
                                             //variable "_numInput" to the 
                                             //"numInput" member variable of the
                                             //current object
                  this.numHiddenA = _numHiddenA;
                  this.numHiddenB = _numHiddenB;
                  this.numOutput = _numOutput;
                  
                  // resize the array // data
                  ArrayResize(inputs,numInput);

                  ArrayResize(iaWeights,numInput);
                  ArrayResize(abWeights,numHiddenA);
                  ArrayResize(boWeights,numHiddenB);
                  
                  ArrayResize(aBiases,numHiddenA);
                  ArrayResize(bBiases,numHiddenB);
                  ArrayResize(oBiases,numOutput);
                  
                  ArrayResize(aOutputs,numHiddenA);
                  ArrayResize(bOutputs,numHiddenB);
                  ArrayResize(outputs,numOutput);
               }
               // destructor
               //~DeepNeuralNetwork();
               
               // set weights
               void SetWeights(double &weights[]){
                  // make sure that we have enough weights to work with
                  int numTotalWeights_Biases = ((numInput*numHiddenA)+numHiddenA+(numHiddenA*numHiddenB)+
                                                numHiddenB + (numHiddenB*numOutput) + numOutput);
                  if (ArraySize(weights) != numTotalWeights_Biases){
                     Print("We have not enought weights to work with");
                     return;
                  }
                  
                  int k = 0;
                  //set the inputs to the hidden layer A weights (iaWeights)
                  for (int i = 0; i < numInput; ++i)
                     for (int j = 0; j < numHiddenA; ++j)
                     iaWeights[i][j] = NormalizeDouble(weights[k++],2);
                  // set hidden layer A Biases (aBiases)
                  for (int i = 0; i < numHiddenA; ++i)
                     aBiases[i] = NormalizeDouble(weights[k++],2);
                 
                  //set the hidden A to the hidden layer B weights (abWeights)
                  for (int i = 0; i < numHiddenA; ++i)
                     for (int j = 0; j < numHiddenB; ++j)
                     abWeights[i][j] = NormalizeDouble(weights[k++],2);
                  // set hidden layer B Biases (bBiases)
                  for (int i = 0; i < numHiddenB; ++i)
                     bBiases[i] = NormalizeDouble(weights[k++],2);
                 
                  //set the hidden B to the oUTPUT weights (boWeights)
                  for (int i = 0; i < numHiddenB; ++i)
                     for (int j = 0; j < numOutput; ++j)
                     boWeights[i][j] = NormalizeDouble(weights[k++],2);
                  // set output Biases (oBiases)
                  for (int i = 0; i < numOutput; ++i)
                     oBiases[i] = NormalizeDouble(weights[k++],2);
               }
               
               // ACTIVATION FUNCTION
               void ComputeOutputs(double &xValues[],double &yValues[]){
               // set the scratch arrays for holding the preliminary sums (b4 activation)
                  double aSums[];
                  double bSums[];
                  double oSums[];   // output sums nodes scrach array
                  
                  // resize the arrays 
                  ArrayResize(aSums,numHiddenA);
                  ArrayFill(aSums,0,numHiddenA,0);
                  ArrayResize(bSums,numHiddenB);
                  ArrayFill(bSums,0,numHiddenB,0);
                  ArrayResize(oSums,numOutput);
                  ArrayFill(oSums,0,numOutput,0);
                  
                  // we now copy the inputs values (X axis data)
                  int size  = ArraySize(xValues);
                  for (int i = 0; i < size; ++i)   // copy the x_values to inputs
                     this.inputs[i] = xValues[i];
                  
                  //compute the sums of ia weights * inputs
                  for (int j = 0; j < numHiddenA; ++j)
                     for (int i = 0; i < numInput; ++i)
                     aSums[j] += this.inputs[i]*this.iaWeights[i][j];
                  // add the biases to the a_sums
                  for (int i = 0; i < numHiddenA; ++i)
                     aSums[i] += this.aBiases[i];
                  //apply the activation function
                  for (int i = 0; i < numHiddenA; ++i)
                     this.aOutputs[i] = HyperTanhFunction(aSums[i]);
                     
                  //compute the sums of ab weights * a outputs
                  for (int j = 0; j < numHiddenB; ++j)
                     for (int i = 0; i < numHiddenA; ++i)
                     bSums[j] += this.aOutputs[i]*this.abWeights[i][j];
                  // add the biases to the b_sums
                  for (int i = 0; i < numHiddenB; ++i)
                     bSums[i] += this.bBiases[i];
                  //apply the activation function
                  for (int i = 0; i < numHiddenB; ++i)
                     this.bOutputs[i] = HyperTanhFunction(bSums[i]);
                     
                  //compute the sums of bo weights * b outputs
                  for (int j = 0; j < numOutput; ++j)
                     for (int i = 0; i < numHiddenB; ++i)
                     oSums[j] += this.bOutputs[i]*this.boWeights[i][j];
                  // add the biases to the o_sums
                  for (int i = 0; i < numOutput; ++i)
                     oSums[i] += this.oBiases[i];
                  
                  // activate all the outputs at once for efficiency
                  double softOut[];
                  SoftMax(oSums,softOut);
                  ArrayCopy(outputs,softOut);
                  ArrayCopy(yValues, this.outputs);
               }
               
      double HyperTanhFunction( double x){
         if (x < -20.0) return -1.0;
         else if (x > 20) return 1.0;
         else return (1-exp(-2*x)/1+exp(-2*x));
      }
      
      void SoftMax(double &oSums[], double &_softOut[]){
         // determine the maximum output sum
         // compute all the outputs so we don't have to re-compute each time
         int size = ArraySize(oSums);
         double max = oSums[0];
         for (int i = 0; i < size; ++i)
            if (oSums[i] > max) max = oSums[i];
         // determine the scaling factor 
         double scale = 0.0;
         for (int i = 0; i < size; ++i)
            scale += MathExp(oSums[i]-max);
         ArrayResize(_softOut, size);
         for (int i = 0; i < size; ++i)
            _softOut[i] = MathExp(oSums[i]-max)/scale;
      }               
};

int numInput = 4;
int numHiddenA = 4;
int numHiddenB = 5;
int numOutput = 3;

DeepNeuralNetwork dnn(numInput,numHiddenA,numHiddenB,numOutput);

// define weight values
input double w_i_0 = 1;
input double w_i_1 = 1;
input double w_i_2 = 1;
input double w_i_3 = 1;
input double w_i_4 = 1;
input double w_i_5 = 1;
input double w_i_6 = 1;
input double w_i_7 = 1;
input double w_i_8 = 1;
input double w_i_9 = 1;
input double w_i_10 = 1;
input double w_i_11 = 1;
input double w_i_12 = 1;
input double w_i_13 = 1;
input double w_i_14 = 1;
input double w_i_15 = 1;
input double b_HA_0 = 1;
input double b_HA_1 = 1;
input double b_HA_2 = 1;
input double b_HA_3 = 1.0;
input double w_HA_0 = 1.0;
input double w_HA_1 = 1.0;
input double w_HA_2 = 1.0;
input double w_HA_3 = 1.0;
input double w_HA_4 = 1.0;
input double w_HA_5 = 1.0;
input double w_HA_6 = 1.0;
input double w_HA_7 = 1.0;
input double w_HA_8 = 1.0;
input double w_HA_9 = 1.0;
input double w_HA_10 = 1.0;
input double w_HA_11 = 1.0;
input double w_HA_12 = 1.0;
input double w_HA_13 = 1.0;
input double w_HA_14 = 1.0;
input double w_HA_15 = 1.0;
input double w_HA_16 = 1.0;
input double w_HA_17 = 1.0;
input double w_HA_18 = 1.0;
input double w_HA_19 = 1.0;
input double b_HB_0 = 1.0;
input double b_HB_1 = 1.0;
input double b_HB_2 = 1.0;
input double b_HB_3 = 1.0;
input double b_HB_4 = 1.0;
input double w_HB_0 = 1.0;
input double w_HB_1 = 1.0;
input double w_HB_2 = 1.0;
input double w_HB_3 = 1.0;
input double w_HB_4 = 1.0;
input double w_HB_5 = 1.0;
input double w_HB_6 = 1.0;
input double w_HB_7 = 1.0;
input double w_HB_8 = 1.0;
input double w_HB_9 = 1.0;
input double w_HB_10 = 1.0;
input double w_HB_11 = 1.0;
input double w_HB_12 = 1.0;
input double w_HB_13 = 1.0;
input double w_HB_14 = 1.0;
input double b_O_0 = 1.0;
input double b_O_1 = 1.0;
input double b_O_2 = 1.0;

input double Lot = 0.01;
input long magic123 = 123456;

// array for storing the inputs >>> found on the x axis
double _XValues[4];
// array for storing the total weights
double weightsTotal[63];

// array to store out outputs >>> on the y axis
double OUT[];

string Our_Symbol;
ENUM_TIMEFRAMES Our_Tf;
double Our_Volume;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Our_Symbol = Symbol();
   Our_Tf = PERIOD_CURRENT;
   Our_Volume = Lot;
   
   Trade_Object.SetExpertMagicNumber(magic123);
   
   
   // initializxe the weights
   weightsTotal[0] = w_i_0;
   weightsTotal[1] = w_i_1;
   weightsTotal[2] = w_i_2;
   weightsTotal[3] = w_i_3;
   weightsTotal[4] = w_i_4;
   weightsTotal[5] = w_i_5;
   weightsTotal[6] = w_i_6;
   weightsTotal[7] = w_i_7;
   weightsTotal[8] = w_i_8;
   weightsTotal[9] = w_i_9;
   weightsTotal[10] = w_i_10;
   weightsTotal[11] = w_i_11;
   weightsTotal[12] = w_i_12;
   weightsTotal[13] = w_i_13;
   weightsTotal[14] = w_i_14;
   weightsTotal[15] = w_i_15;
   weightsTotal[16] = b_HA_0;
   weightsTotal[17] = b_HA_1;
   weightsTotal[18] = b_HA_2;
   weightsTotal[19] = b_HA_3;
   weightsTotal[20] = w_HA_0;
   weightsTotal[21] = w_HA_1;
   weightsTotal[22] = w_HA_2;
   weightsTotal[23] = w_HA_3;
   weightsTotal[24] = w_HA_4;
   weightsTotal[25] = w_HA_5;
   weightsTotal[26] = w_HA_6;
   weightsTotal[27] = w_HA_7;
   weightsTotal[28] = w_HA_8;
   weightsTotal[29] = w_HA_9;
   weightsTotal[30] = w_HA_10;
   weightsTotal[31] = w_HA_12;
   weightsTotal[32] = w_HA_12;
   weightsTotal[33] = w_HA_13;
   weightsTotal[34] = w_HA_14;
   weightsTotal[35] = w_HA_15;
   weightsTotal[36] = w_HA_16;
   weightsTotal[37] = w_HA_17;
   weightsTotal[38] = w_HA_18;
   weightsTotal[39] = w_HA_19;
   weightsTotal[40] = b_HB_0;
   weightsTotal[41] = b_HB_1;
   weightsTotal[42] = b_HB_2;
   weightsTotal[43] = b_HB_3;
   weightsTotal[44] = b_HB_4;
   weightsTotal[45] = w_HB_0;
   weightsTotal[46] = w_HB_1;
   weightsTotal[47] = w_HB_2;
   weightsTotal[48] = w_HB_3;
   weightsTotal[49] = w_HB_4;
   weightsTotal[50] = w_HB_5;
   weightsTotal[51] = w_HB_6;
   weightsTotal[52] = w_HB_7;
   weightsTotal[53] = w_HB_8;
   weightsTotal[54] = w_HB_9;
   weightsTotal[55] = w_HB_10;
   weightsTotal[56] = w_HB_11;
   weightsTotal[57] = w_HB_12;
   weightsTotal[58] = w_HB_13;
   weightsTotal[59] = w_HB_14;
   weightsTotal[60] = b_O_0;
   weightsTotal[61] = b_O_1;
   weightsTotal[62] = b_O_2;
   
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
   // copy the price data 
   MqlRates rates[];
   // set the rates data as time series
   ArraySetAsSeries(rates,true);
   int copiedRatesData = CopyRates(_Symbol,PERIOD_CURRENT,1,5,rates);
   
   // use the data to calcu;late the inputs [4];
   int err_CandleStickValue = candlePatterns(rates[0].high,rates[0].low,rates[0].open,rates[0].close,
                              rates[0].close - rates[0].open,_XValues);
   if (err_CandleStickValue < 0) return;
   
   dnn.SetWeights(weightsTotal);
   dnn.ComputeOutputs(_XValues,OUT);
   
   Print(OUT[0]);
   
   // carry out tarding activity
   // do this if we have values greater than 60%
   if (OUT[0] > 0.6){
      // buy
      if (Positions_Object.Select(Our_Symbol)){
         if (Positions_Object.PositionType()==POSITION_TYPE_SELL)
            Trade_Object.PositionClose(Our_Symbol);
         if (Positions_Object.PositionType()==POSITION_TYPE_BUY) return;
      }
      Trade_Object.Buy(Our_Volume,Our_Symbol); // open a long position
   }
   if (OUT[1] > 0.6){
      // sell
      if (Positions_Object.Select(Our_Symbol)){
         if (Positions_Object.PositionType()==POSITION_TYPE_BUY)
            Trade_Object.PositionClose(Our_Symbol);
         if (Positions_Object.PositionType()==POSITION_TYPE_SELL) return;
      }
      Trade_Object.Sell(Our_Volume,Our_Symbol); // open a short position
   }
   if (OUT[2] > 0.6){
      // hold >>> no signal
      // close all positions
      Trade_Object.PositionClose(Our_Symbol); // close any position openend by the EA
   }
  }
//+------------------------------------------------------------------+

// % of each bar respecting the total body size of the bar OHLC
int candlePatterns(double high, double low, double open, double close, double barSize, double &XInputs[]){
   double barsize100per = high - low;
   double higherPer = 0;
   double lowerPer = 0;
   double bodyPer = 0;
   double trend = 0;
   
   if (barSize > 0){
      higherPer = high - close;
      lowerPer = open - low;
      bodyPer = close - open;
      trend = 1;
   }
   else {
      higherPer = high - open;
      lowerPer = close - low;
      bodyPer = open - close;
      trend = 0;
   }
   if (barsize100per == 0) return (-1);
      XInputs[0] = higherPer/barsize100per;
      XInputs[1] = lowerPer/barsize100per;
      XInputs[2] = bodyPer/barsize100per;
      XInputs[3] = trend;
   return (1);
}


