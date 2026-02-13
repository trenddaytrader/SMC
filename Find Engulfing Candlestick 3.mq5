//+------------------------------------------------------------------+
//|                                 Find Engulfing Candlestick 2.mq5 |
//|                                   Copyright 2025, TrendDayTrader |
//|                                   https://www.trenddaytrader.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, TrendDayTrader"
#property link      "https://www.trenddaytrader.com"
#property version   "1.00"


int barsTotal;

int dcValid_MN = 0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
// No need for ArraySetAsSeries since global arrays were removed
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
// Get the total number of bars for the current symbol and period
   int bars = iBars(_Symbol, PERIOD_CURRENT);

// Check if a new bar has just formed
   if(barsTotal != bars)
     {
      barsTotal = bars;

      // Check the last 8 *closed* bars for the pattern
      FindAndPrintEngulfingCandle_MN(8);
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Function to find a candle (rates[i]) using its full range        |
//| that completely contains the body (Open/Close) of all subsequent |
//| (newer) candles (rates[1] through rates[i-1]).                   |
//| Minimum of 3 subsequent candles must be checked (i must be >= 4).|
//+------------------------------------------------------------------+
int FindAndPrintEngulfingCandle_MN(int length)
  {
// OUTER DC state (persists across calls)
   static bool     hasDC   = false;
   static double   dcLow   = 0.0;
   static double   dcHigh  = 0.0;
   static datetime dcTime  = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

// Copy enough price bars for the check
   int copied = CopyRates(_Symbol, PERIOD_MN1, 0, 10, rates);

// Check if enough data was copied
// We need at least 4 completed bars for i=4 (to check 3 subsequent bars: 1, 2, 3)
   if(copied < 4)
      return 0;

// The outer loop's 'i' represents the potential DOMINATING Candle (DC).
// Start checking from 'length' down to index 4 (minimum for 3 subsequent bodies)
   for(int i = length; i >= 4; i--)
     {
      bool dominating = true;

      // I. Define the potential DOMINATING Candle (DC) range: USE ENTIRE RANGE (High/Low)
      double dominatingLow  = rates[i].low;   // The lowest point of the DC
      double dominatingHigh = rates[i].high;  // The highest point of the DC

      // II. Check the SUBSEQUENT candles (those that came *after* candle 'i')
      // These are the candles with indices j < i. We check from j=1 (newest completed bar)
      // up to j = i-1 (the bar right before candle 'i').
      for(int j = 1; j < i; j++)
        {
         // Define the subsequent (inner) candle's body range: USE BODY ONLY (Open/Close)
         double innerOpen  = rates[j].open;
         double innerClose = rates[j].close;

         double innerBodyLow  = MathMin(innerOpen, innerClose);   // The lower part of the body
         double innerBodyHigh = MathMax(innerOpen, innerClose);   // The upper part of the body

         // **The KEY CHECK:** The DC's full range MUST contain the body of the subsequent candle.
         if(innerBodyHigh > dominatingHigh || innerBodyLow < dominatingLow)
           {
            // If the subsequent candle's body is outside the DC's full range,
            // the pattern is broken.
            dominating = false;
            break;
           }
        }

      // III. If found, print and exit
      if(dominating)
        {
         // This means the candle at 'i' (using its entire range) dominates the bodies of all 'i-1' subsequent candles.
         // Since i is at least 4, this means a minimum of 3 subsequent candles were checked and dominated.
         // The engulfing candle is at index 'i'.
         Print("Engulfing candlestick found! Index: ", i, " (Time: ",
               TimeToString(rates[i].time), ")");
         createObj(rates[i].time, rates[i].low, 233, -1, clrFireBrick, "");

         // Store this OUTER DC so we can later detect when price closes outside (Step IV)
         hasDC  = true;
         dcLow  = dominatingLow;
         dcHigh = dominatingHigh;
         dcTime = rates[i].time;

         dcValid_MN = 1;
         return 1; // Found the most recent pattern, so we stop and exit.
        }
     }

// IV. The range confirmed in III above, we need to know when price closes outside the range
//     because it will happen eventually. then return 0.
   if(hasDC)
     {
      // Use the newest fully closed bar (index 1) to test CLOSE vs DC range
      double lastClose = rates[1].close;

      if(lastClose > dcHigh || lastClose < dcLow)
        {
         // Price has CLOSED outside the previously confirmed DC range
         Print("DC range broken by close at time ",
               TimeToString(rates[1].time),
               " | Close=", DoubleToString(lastClose, _Digits),
               " DC Low=", DoubleToString(dcLow, _Digits),
               " DC High=", DoubleToString(dcHigh, _Digits));

         // Clear OUTER DC state (box no longer valid)
         hasDC  = false;
         dcLow  = 0.0;
         dcHigh = 0.0;
         dcTime = 0;
         dcValid_MN = 0;
         return 0;
        }
     }

// For this run: no new DC formed. Return 0 as you specified.
   return 0;
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void createObj(datetime time, double price, int arrowCode, int direction, color clr, string txt)
  {
   string objName ="";
   StringConcatenate(objName, "Signal@", time, "at", DoubleToString(price, _Digits), "(", arrowCode, ")");

   double ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double spread=ask-bid;

   if(direction > 0)
     {
      price += 2*spread * _Point;
     }
   else
      if(direction < 0)
        {
         price -= 2*spread * _Point;
        }

   if(ObjectCreate(0, objName, OBJ_ARROW, 0, time, price))
     {
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      if(direction > 0)
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
      if(direction < 0)
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
     }
   string objNameDesc = objName + txt;
   if(ObjectCreate(0, objNameDesc, OBJ_TEXT, 0, time, price))
     {
      ObjectSetString(0, objNameDesc, OBJPROP_TEXT, "  " + txt);
      ObjectSetInteger(0, objNameDesc, OBJPROP_COLOR, clr);
      if(direction > 0)
         ObjectSetInteger(0, objNameDesc, OBJPROP_ANCHOR, ANCHOR_TOP);
      if(direction < 0)
         ObjectSetInteger(0, objNameDesc, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
     }
  }

//+------------------------------------------------------------------+
