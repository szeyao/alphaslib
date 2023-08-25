//+------------------------------------------------------------------+
//|                                           TickChartAggressor.mq5 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"

input int ticksInBar = 21;
input int loadedTicks = 3000000;

MqlTick latestTick[];
MqlTick histTick[];
MqlRates generateRates[];
MqlTick generateHist[];

string trackedSymbol = "";

datetime lastUpdate = 1440*60;
int tickCount = 0, aggressorCount = 0, lastCount = 0;
int totalTicks = 0;
long chartAnchor = 0;
long lastTime = 0;

// Add session separators as objects: 1 for 09:00, 1 for 14:30 each day
string currentDate = "";
bool newMorning = false;
string morningStart = "09:00:00";
bool newAfternoon = false;
string afternoonStart = "14:30:00";
int sep = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //---
   trackedSymbol = Symbol() + "_TICK_" + IntegerToString(ticksInBar);
   bool isCustom;
   if (!SymbolExist(trackedSymbol, isCustom)) 
   {
      if (!CustomSymbolCreate(trackedSymbol)) return(INIT_FAILED);
      CustomSymbolSetInteger(trackedSymbol, SYMBOL_DIGITS, 3);
      CustomSymbolSetInteger(trackedSymbol, SYMBOL_CHART_MODE, SYMBOL_CHART_MODE_LAST);
      CustomSymbolSetInteger(trackedSymbol, SYMBOL_TRADE_STOPS_LEVEL, 0);
      CustomSymbolSetInteger(trackedSymbol, SYMBOL_TRADE_FREEZE_LEVEL, 0);
      CustomSymbolSetInteger(trackedSymbol, SYMBOL_TRADE_CALC_MODE, SYMBOL_CALC_MODE_EXCH_STOCKS);
      CustomSymbolSetDouble(trackedSymbol, SYMBOL_VOLUME_MIN, 1.0);
      CustomSymbolSetDouble(trackedSymbol, SYMBOL_VOLUME_MAX, 1000000.0);
      CustomSymbolSetDouble(trackedSymbol, SYMBOL_VOLUME_STEP, 1.0);
      CustomSymbolSetDouble(trackedSymbol, SYMBOL_TRADE_CONTRACT_SIZE, 100.0);
      CustomSymbolSetDouble(trackedSymbol, SYMBOL_TRADE_TICK_SIZE, SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE));
      CustomSymbolSetString(trackedSymbol, SYMBOL_CURRENCY_MARGIN, "MYR");
      CustomSymbolSetString(trackedSymbol, SYMBOL_CURRENCY_PROFIT, "MYR");
      CustomSymbolSetSessionQuote(trackedSymbol, MONDAY, 0, 0, 24*60*60);
      CustomSymbolSetSessionQuote(trackedSymbol, TUESDAY, 0, 0, 24*60*60);
      CustomSymbolSetSessionQuote(trackedSymbol, WEDNESDAY, 0, 0, 24*60*60);
      CustomSymbolSetSessionQuote(trackedSymbol, THURSDAY, 0, 0, 24*60*60);
      CustomSymbolSetSessionQuote(trackedSymbol, FRIDAY, 0, 0, 24*60*60);
      CustomSymbolSetSessionQuote(trackedSymbol, SATURDAY, 0, 0, 24*60*60);
      CustomSymbolSetSessionQuote(trackedSymbol, SUNDAY, 0, 0, 24*60*60);
      CustomSymbolSetSessionTrade(trackedSymbol, MONDAY, 0, 0, 24*60*60);
      CustomSymbolSetSessionTrade(trackedSymbol, TUESDAY, 0, 0, 24*60*60);
      CustomSymbolSetSessionTrade(trackedSymbol, WEDNESDAY, 0, 0, 24*60*60);
      CustomSymbolSetSessionTrade(trackedSymbol, THURSDAY, 0, 0, 24*60*60);
      CustomSymbolSetSessionTrade(trackedSymbol, FRIDAY, 0, 0, 24*60*60);
      CustomSymbolSetSessionTrade(trackedSymbol, SATURDAY, 0, 0, 24*60*60);
      CustomSymbolSetSessionTrade(trackedSymbol, SUNDAY, 0, 0, 24*60*60);
   }
   SymbolSelect(trackedSymbol, true);
   
   long chartCurrent = ChartFirst(), chartPrev = ChartFirst();
   while (chartPrev >= 0)
   {
      chartCurrent = ChartNext(chartPrev);
      if (ChartSymbol(chartPrev) == trackedSymbol)
      {
         chartAnchor = chartPrev;
         break;
      }
      chartPrev = chartCurrent;
   }
   ObjectsDeleteAll(chartAnchor, IntegerToString(chartAnchor) + "-Separator-");
   
   if (chartAnchor == 0)
   {
      chartAnchor = ChartOpen(trackedSymbol, PERIOD_M1);
      if (chartAnchor == 0) return(INIT_FAILED);
   }
   
   int res = 0;
   ArrayFree(histTick);
   if ((res = CopyTicks(Symbol(), histTick, COPY_TICKS_TRADE, 0, loadedTicks)) < 0) return(INIT_FAILED);
   //res = CopyTicks(Symbol(), histTick, COPY_TICKS_TRADE, 0, 10000);
   Print("Ticks copied: ", res);
   if ((res = CustomTicksDelete(trackedSymbol, 0, TimeCurrent()*1000)) < 0) return(INIT_FAILED);
   Print("Ticks deleted: ", res);
   //res = CustomTicksDelete("MAYBANK_TICK", 0, TimeCurrent()*1000);
   //Print("Ticks deleted: ", res);
   if ((res = CustomRatesDelete(trackedSymbol, 0, TimeCurrent()*1000)) < 0) return(INIT_FAILED);
   Print("Bars deleted: ", res);
   //Print(TimeToString(histTick[0].time, TIME_DATE|TIME_SECONDS));
   ArrayFree(generateHist);
   ArrayResize(generateHist, ArraySize(histTick));
   lastTime = histTick[0].time_msc;
   for (int i = 0; i < ArraySize(histTick); i++)
   {
      if (lastTime < histTick[i].time_msc)
      {
         tickCount++;
         aggressorCount = 0;
      }
      lastTime = histTick[i].time_msc;
      
      if (tickCount >= ticksInBar)
      {
         totalTicks++;
         lastUpdate = (datetime)((totalTicks + 1440)*60);
         tickCount = 0;
      }
      if (currentDate != TimeToString(histTick[i].time, TIME_DATE))
      {
         newMorning = true;
         newAfternoon = true;
         currentDate = TimeToString(histTick[i].time, TIME_DATE);
      }
      if (newAfternoon)
      {
         if (histTick[i].time >= StringToTime(currentDate + " " + afternoonStart))
         {
            // Draw new separator for afternoon session
            SeparatorCreate(chartAnchor, lastUpdate, sep, false, currentDate + " " + afternoonStart);
            newAfternoon = false;
            newMorning = false;
         }
      }
      if (newMorning)
      {
         if (histTick[i].time >= StringToTime(currentDate + " " + morningStart))
         {
            // Draw new separator for morning session
            SeparatorCreate(chartAnchor, lastUpdate, sep, true, currentDate + " " + morningStart);
            newMorning = false;
         }
      }
      generateHist[i].time = lastUpdate;
      generateHist[i].time_msc = lastUpdate*1000;
      generateHist[i].last = histTick[i].last;
      generateHist[i].bid = histTick[i].bid;
      generateHist[i].ask = histTick[i].ask;
      generateHist[i].volume = histTick[i].volume;
      
      aggressorCount++;
   }
   
   //res = CustomTicksAdd("MAYBANK_TICK", generateHist);
   if ((res = CustomTicksAdd(trackedSymbol, generateHist)) < 0) return(INIT_FAILED);
   Print("Ticks added: ", res);
   
   ArrayFree(histTick);
   if ((res = CopyTicks(Symbol(), histTick, COPY_TICKS_TRADE, 0, loadedTicks)) < 0) return(INIT_FAILED);
   //res = CopyTicks(Symbol(), histTick, COPY_TICKS_TRADE, 0, 10000);
   Print("Ticks copied: ", res);
   ArrayFree(generateRates);
   if ((res = CopyRates(trackedSymbol, PERIOD_M1, (datetime)0, TimeCurrent(), generateRates)) < 0) return(INIT_FAILED);
   //res = CopyRates("MAYBANK_TICK", PERIOD_M1, (datetime)0, TimeCurrent(), generateRates);
   Print("Rates copied: ", res);
   ArrayResize(latestTick, 1);
   EventSetMillisecondTimer(100);
   //---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //---
   EventKillTimer();
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //---
   int res = 0;
   //ArrayFree(histTick);
   res = CopyTicks(Symbol(), histTick, COPY_TICKS_TRADE, 0, 200);
   if (res < 0) return;
   int startPt = 0, endPt = ArraySize(histTick);
   for (int i = ArraySize(histTick) - 1; i >= 0; i--)
   {
      if (histTick[i].time_msc > lastTime)
         endPt = i;
      else if (histTick[i].time_msc < lastTime)
      {
         startPt = i;
         break;
      }
   }
   
   lastCount = aggressorCount;
   if (endPt < ArraySize(histTick))
      Print(lastTime, " ", startPt, " ", histTick[startPt].time_msc, " ", endPt, " ", histTick[endPt].time_msc);
   else
      Print(lastTime, " ", startPt, " ", histTick[startPt].time_msc);
   
   long anchorTime = lastTime;
   //ArrayFree(generateHist);
   ArrayResize(generateHist, ArraySize(histTick) - (startPt + lastCount + 1));
   for (int i = startPt + lastCount + 1; i < ArraySize(histTick); i++)
   {
      if (lastTime < histTick[i].time_msc)
      {
         tickCount++;
         aggressorCount = 0;
      }
      lastTime = histTick[i].time_msc;
      
      if (tickCount >= ticksInBar)
      {
         totalTicks++;
         lastUpdate = (datetime)((totalTicks + 1440)*60);
         tickCount = 0;
      }
      if (currentDate != TimeToString(histTick[i].time, TIME_DATE))
      {
         newMorning = true;
         newAfternoon = true;
         currentDate = TimeToString(histTick[i].time, TIME_DATE);
      }
      if (newAfternoon)
      {
         if (histTick[i].time >= StringToTime(currentDate + " " + afternoonStart))
         {
            // Draw new separator for afternoon session
            SeparatorCreate(chartAnchor, lastUpdate, sep, false, currentDate + " " + afternoonStart);
            newAfternoon = false;
            newMorning = false;
         }
      }
      if (newMorning)
      {
         if (histTick[i].time >= StringToTime(currentDate + " " + morningStart))
         {
            // Draw new separator for morning session
            SeparatorCreate(chartAnchor, lastUpdate, sep, true, currentDate + " " + morningStart);
            newMorning = false;
         }
      }
      
      generateHist[i - (startPt + lastCount + 1)].time = lastUpdate;
      generateHist[i - (startPt + lastCount + 1)].time_msc = lastUpdate*1000;
      generateHist[i - (startPt + lastCount + 1)].last = histTick[i].last;
      generateHist[i - (startPt + lastCount + 1)].bid = histTick[i].bid;
      generateHist[i - (startPt + lastCount + 1)].ask = histTick[i].ask;
      generateHist[i - (startPt + lastCount + 1)].volume = histTick[i].volume;
      
      aggressorCount++;
   }
   //for (int i = 0; i < ArraySize(generateHist); i++)
   //   Print(generateHist[i].time_msc, " ", generateHist[i].volume);
   if (ArraySize(generateHist) > 0)
   {
      res = CustomTicksAdd(trackedSymbol, generateHist);
      //Print(res);
      if (res < 0) Print("Failed to update tick chart: ", GetLastError());
   }
}
//+------------------------------------------------------------------+

void OnTimer()
{
   //Print("Timer event");
   for (int i = 0; i < sep; i++)
      ObjectSetDouble(chartAnchor, IntegerToString(chartAnchor) + "-Separator-Session-" + IntegerToString(i), OBJPROP_PRICE, ChartGetDouble(chartAnchor, CHART_PRICE_MAX));
   ChartRedraw(chartAnchor);   
}

void SeparatorCreate(long id, datetime time, int& idx, bool isMorning, string session)
{
   ObjectCreate(id, IntegerToString(id) + "-Separator-" + IntegerToString(idx), OBJ_VLINE, 0, time, 0);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-" + IntegerToString(idx), OBJPROP_COLOR, clrSilver);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-" + IntegerToString(idx), OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-" + IntegerToString(idx), OBJPROP_SELECTABLE, false);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-" + IntegerToString(idx), OBJPROP_SELECTED, false);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-" + IntegerToString(idx), OBJPROP_BACK, true);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-" + IntegerToString(idx), OBJPROP_RAY, true);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-" + IntegerToString(idx), OBJPROP_HIDDEN, true);
   
   ObjectCreate(id, IntegerToString(id) + "-Separator-Session-" + IntegerToString(idx), OBJ_TEXT, 0, time, ChartGetDouble(id, CHART_PRICE_MAX));
   ObjectSetString(id, IntegerToString(id) + "-Separator-Session-" + IntegerToString(idx), OBJPROP_TEXT, session);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-Session-" + IntegerToString(idx), OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-Session-" + IntegerToString(idx), OBJPROP_COLOR, clrSilver);
   ObjectSetDouble(id, IntegerToString(id) + "-Separator-Session-" + IntegerToString(idx), OBJPROP_ANGLE, 90);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-Session-" + IntegerToString(idx), OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-Session-" + IntegerToString(idx), OBJPROP_SELECTABLE, false);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-Session-" + IntegerToString(idx), OBJPROP_SELECTED, false);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-Session-" + IntegerToString(idx), OBJPROP_BACK, true);
   ObjectSetInteger(id, IntegerToString(id) + "-Separator-Session-" + IntegerToString(idx), OBJPROP_HIDDEN, true);
   idx++;
}