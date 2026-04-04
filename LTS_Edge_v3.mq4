//+------------------------------------------------------------------+
//|                                                  LTS_Edge_v3.mq4 |
//|                        London Mean Reversion — XAUUSD              |
//|                        Fades Asian range liquidity sweeps          |
//|                        v5.0 — Mean Reversion Strategy              |
//+------------------------------------------------------------------+
#property copyright "LTS Edge v5.0"
#property link      ""
#property version   "5.00"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// --- Risk Management ---
input double   RiskPercent            = 1.5;     // Risk per trade (% of balance)
input double   MaxDailyDrawdownPct    = 3.0;     // Max daily drawdown % — stop trading

// --- Asian Range Definition (UK time) ---
input int      RangeStartHour         = 0;       // Asian range start hour (UK time)
input int      RangeStartMinute       = 0;       // Asian range start minute
input int      RangeEndHour           = 7;       // Asian range end hour (UK time)
input int      RangeEndMinute         = 0;       // Asian range end minute

// --- Range Filters ---
input double   MinRangePips           = 3.0;     // Min Asian range size (pips)
input double   MaxRangePips           = 100.0;   // Max Asian range size (pips)

// --- Entry Window (UK time) ---
input int      EntryStartHour         = 8;       // Look for entries from (UK time)
input int      EntryEndHour           = 10;      // Stop looking for entries at (UK time)

// --- Mean Reversion Parameters ---
input double   MinExtensionPct        = 25.0;    // Min overextension (% of range width)
input double   MaxExtensionPct        = 100.0;   // Max overextension (% of range width) — beyond = real move
input double   ReversalBufferPips     = 3.0;     // Reversal candle must close within X pips of range edge
input double   SLBufferPips           = 2.0;     // SL buffer beyond the spike extreme

// --- Session Management ---
input int      CloseTradesHour        = 16;      // Close open trades at this hour (UK time)

// --- Filters ---
input double   MaxSpreadPips          = 0.5;     // Max allowed spread (pips)

// --- Time Settings ---
input int      BrokerUTCOffset        = 3;       // Broker server UTC offset (IC Markets: 3, Pepperstone: 2)
input bool     UKSummerTime           = false;   // UK is on BST (UTC+1) — set true late Mar-Oct

// --- Day Filter ---
input bool     TradeMonday            = false;   // Allow trades on Monday
input bool     TradeTuesday           = true;    // Allow trades on Tuesday
input bool     TradeWednesday         = true;    // Allow trades on Wednesday
input bool     TradeThursday          = true;    // Allow trades on Thursday
input bool     TradeFriday            = false;   // Allow trades on Friday

// --- Diagnostics ---
input bool     EnableDiagnostics      = true;    // Log detailed results per bar

// --- System ---
input int      MagicNumber            = 55555;   // EA magic number
input int      Slippage               = 5;       // Max slippage (points)

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
datetime g_lastBarTime       = 0;
double   g_pipSize           = 0;
int      g_pipDigits         = 0;
string   g_commentTag        = "LTSv5";
double   g_startBalance      = 0;
bool     g_tradeTakenToday   = false;
int      g_lastTradeDay      = -1;
bool     g_rangeReady        = false;
double   g_rangeHigh         = 0;
double   g_rangeLow          = 999999;
double   g_spikeHigh         = 0;      // Track highest point of upward spike
double   g_spikeLow          = 999999; // Track lowest point of downward spike
bool     g_spikeUpDetected   = false;  // Price spiked above Asian range
bool     g_spikeDownDetected = false;  // Price spiked below Asian range

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   // Detect pip size based on symbol digits
   if(Digits == 5 || Digits == 3)
   {
      g_pipSize  = Point * 10;
      g_pipDigits = 1;
   }
   else if(Digits <= 2)
   {
      g_pipSize  = 1.0;
      g_pipDigits = 0;
   }
   else
   {
      g_pipSize  = Point;
      g_pipDigits = 0;
   }

   g_startBalance = AccountBalance();

   Print("LTS Edge v5.0 (London Mean Reversion) initialized on ", Symbol());
   Print("Pip size: ", g_pipSize, " Digits: ", Digits, " Point: ", Point);
   Print("Asian Range: ", RangeStartHour, ":", RangeStartMinute, "-",
         RangeEndHour, ":", RangeEndMinute, " UK",
         (UKSummerTime ? " (BST)" : " (GMT)"));
   Print("Entry window: ", EntryStartHour, ":00-", EntryEndHour, ":00 UK");
   Print("Close trades: ", CloseTradesHour, ":00 UK");
   Print("Risk: ", RiskPercent, "% | Extension: ", MinExtensionPct, "-", MaxExtensionPct, "%");
   Print("Reversal buffer: ", ReversalBufferPips, " pips | SL buffer: ", SLBufferPips, " pips");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
   Print("LTS Edge v5.0 removed. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Main tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // Always check session close on every tick
   CheckSessionClose();

   UpdateChartDisplay();

   if(!IsNewBar())
      return;

   // Reset daily tracker
   int today = TimeDay(TimeCurrent());
   if(today != g_lastTradeDay)
   {
      g_tradeTakenToday = false;
      g_lastTradeDay = today;
      g_startBalance = AccountBalance();
      g_rangeReady = false;
      g_rangeHigh = 0;
      g_rangeLow = 999999;
      g_spikeHigh = 0;
      g_spikeLow = 999999;
      g_spikeUpDetected = false;
      g_spikeDownDetected = false;
   }

   // Track range during Asian session
   if(IsInRangePeriod())
   {
      TrackRange();
   }

   // Check for mean reversion entry during London session
   if(IsInEntryWindow() && !g_tradeTakenToday && !HasOpenTrade() && g_rangeReady)
   {
      if(IsTradingDay() && !CheckDailyDrawdown())
      {
         CheckMeanReversionEntry();
      }
   }
}

//+------------------------------------------------------------------+
//| New bar detection on M5                                           |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(Symbol(), PERIOD_M5, 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Convert UK time to server minutes since midnight                  |
//+------------------------------------------------------------------+
int UKToServerMinutes(int ukHour, int ukMinute)
{
   int ukOffset = UKSummerTime ? 1 : 0;
   int serverMinutes = (ukHour - ukOffset + BrokerUTCOffset) * 60 + ukMinute;
   if(serverMinutes < 0) serverMinutes += 24 * 60;
   return serverMinutes % (24 * 60);
}

//+------------------------------------------------------------------+
//| Convert UK hour to server hour                                    |
//+------------------------------------------------------------------+
int UKToServerHour(int ukHour)
{
   int ukOffset = UKSummerTime ? 1 : 0;
   int serverHour = ukHour - ukOffset + BrokerUTCOffset;
   if(serverHour < 0) serverHour += 24;
   return serverHour % 24;
}

//+------------------------------------------------------------------+
//| Check if we're currently in the Asian range period                |
//+------------------------------------------------------------------+
bool IsInRangePeriod()
{
   int hour = TimeHour(TimeCurrent());
   int minute = TimeMinute(TimeCurrent());
   int currentMins = hour * 60 + minute;

   int startMins = UKToServerMinutes(RangeStartHour, RangeStartMinute);
   int endMins   = UKToServerMinutes(RangeEndHour, RangeEndMinute);

   if(startMins < endMins)
      return (currentMins >= startMins && currentMins < endMins);
   else
      return (currentMins >= startMins || currentMins < endMins);
}

//+------------------------------------------------------------------+
//| Track high/low during Asian range period                          |
//+------------------------------------------------------------------+
void TrackRange()
{
   double high = iHigh(Symbol(), PERIOD_M5, 0);
   double low  = iLow(Symbol(), PERIOD_M5, 0);

   double high1 = iHigh(Symbol(), PERIOD_M5, 1);
   double low1  = iLow(Symbol(), PERIOD_M5, 1);

   if(high > g_rangeHigh) g_rangeHigh = high;
   if(high1 > g_rangeHigh) g_rangeHigh = high1;
   if(low < g_rangeLow) g_rangeLow = low;
   if(low1 < g_rangeLow) g_rangeLow = low1;

   g_rangeReady = true;
}

//+------------------------------------------------------------------+
//| Check if current time is in the entry window                      |
//+------------------------------------------------------------------+
bool IsInEntryWindow()
{
   int hour = TimeHour(TimeCurrent());
   int minute = TimeMinute(TimeCurrent());
   int currentMins = hour * 60 + minute;

   int startMins = UKToServerMinutes(EntryStartHour, 0);
   int endMins   = UKToServerMinutes(EntryEndHour, 0);

   if(startMins < endMins)
      return (currentMins >= startMins && currentMins < endMins);
   else
      return (currentMins >= startMins || currentMins < endMins);
}

//+------------------------------------------------------------------+
//| Check if today is an allowed trading day                          |
//+------------------------------------------------------------------+
bool IsTradingDay()
{
   int dow = DayOfWeek();
   switch(dow)
   {
      case 1: return TradeMonday;
      case 2: return TradeTuesday;
      case 3: return TradeWednesday;
      case 4: return TradeThursday;
      case 5: return TradeFriday;
      default: return false;
   }
}

//+------------------------------------------------------------------+
//| Check if daily drawdown limit exceeded                            |
//+------------------------------------------------------------------+
bool CheckDailyDrawdown()
{
   double closedPL   = 0;
   double floatingPL = 0;
   datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderCloseTime() >= todayStart)
               closedPL += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            floatingPL += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }

   double totalPL = closedPL + floatingPL;
   double maxLoss = g_startBalance * MaxDailyDrawdownPct / 100.0;

   if(totalPL < 0 && MathAbs(totalPL) >= maxLoss)
   {
      Print("Daily drawdown limit reached: ", DoubleToString(totalPL, 2));
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check if EA has open trades                                       |
//+------------------------------------------------------------------+
bool HasOpenTrade()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == OP_BUY || OrderType() == OP_SELL)
               return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Mean reversion entry logic                                        |
//+------------------------------------------------------------------+
void CheckMeanReversionEntry()
{
   // Check spread first
   double spreadPips = (Ask - Bid) / g_pipSize;
   if(spreadPips > MaxSpreadPips)
      return;

   double rangeWidthPips = (g_rangeHigh - g_rangeLow) / g_pipSize;

   // Validate range size
   if(rangeWidthPips < MinRangePips || rangeWidthPips > MaxRangePips)
   {
      if(EnableDiagnostics && !g_tradeTakenToday)
      {
         // Only log once per day to avoid spam
         static int lastRangeLogDay = -1;
         if(TimeDay(TimeCurrent()) != lastRangeLogDay)
         {
            if(rangeWidthPips < MinRangePips)
               Print("Range too small: ", DoubleToString(rangeWidthPips, 1), " < ", MinRangePips);
            else
               Print("Range too large: ", DoubleToString(rangeWidthPips, 1), " > ", MaxRangePips);
            lastRangeLogDay = TimeDay(TimeCurrent());
         }
      }
      return;
   }

   double rangeWidth = g_rangeHigh - g_rangeLow;
   double minExtension = rangeWidth * MinExtensionPct / 100.0;
   double maxExtension = rangeWidth * MaxExtensionPct / 100.0;

   // Get the last closed M5 bar (bar 1)
   double barHigh  = iHigh(Symbol(), PERIOD_M5, 1);
   double barLow   = iLow(Symbol(), PERIOD_M5, 1);
   double barClose = iClose(Symbol(), PERIOD_M5, 1);
   double barOpen  = iOpen(Symbol(), PERIOD_M5, 1);

   // Track spike extremes during entry window
   if(barHigh > g_spikeHigh) g_spikeHigh = barHigh;
   if(barLow < g_spikeLow) g_spikeLow = barLow;

   // Also check current bar for spike tracking
   double curHigh = iHigh(Symbol(), PERIOD_M5, 0);
   double curLow  = iLow(Symbol(), PERIOD_M5, 0);
   if(curHigh > g_spikeHigh) g_spikeHigh = curHigh;
   if(curLow < g_spikeLow) g_spikeLow = curLow;

   // --- Check for SELL setup (price spiked above Asian high, then reversed) ---
   double upExtension = barHigh - g_rangeHigh;
   if(upExtension >= minExtension && upExtension <= maxExtension)
   {
      g_spikeUpDetected = true;
   }

   if(g_spikeUpDetected)
   {
      // Check reversal: bar closed back near or below the Asian high
      double distFromHigh = barClose - g_rangeHigh;
      double reversalBufferPrice = ReversalBufferPips * g_pipSize;

      if(distFromHigh <= reversalBufferPrice)
      {
         // Reversal confirmed — place SELL
         double sl = NormalizeDouble(g_spikeHigh + SLBufferPips * g_pipSize, Digits);
         double tp = NormalizeDouble((g_rangeHigh + g_rangeLow) / 2.0, Digits);
         double slPips = (sl - Bid) / g_pipSize;
         double lots = CalculateLotSize(slPips);

         if(EnableDiagnostics)
         {
            Print("Asian Range: High=", DoubleToString(g_rangeHigh, Digits),
                  " Low=", DoubleToString(g_rangeLow, Digits),
                  " Width=", DoubleToString(rangeWidthPips, 1), " pips");
            Print("Spike UP detected: High=", DoubleToString(g_spikeHigh, Digits),
                  " Extension=", DoubleToString(upExtension / g_pipSize, 1), " pips (",
                  DoubleToString(upExtension / rangeWidth * 100, 0), "% of range)");
            Print("Reversal confirmed: Close=", DoubleToString(barClose, Digits),
                  " within ", ReversalBufferPips, " pips of Asian High");
         }

         int ticket = OrderSend(
            Symbol(), OP_SELL, lots,
            Bid, Slippage, sl, tp,
            g_commentTag + " SELL MR", MagicNumber, 0, clrRed
         );

         if(ticket < 0)
         {
            int err = GetLastError();
            Print("SELL failed. Error: ", err, " - ", ErrorDescription(err),
                  " Entry: ", Bid, " SL: ", sl, " TP: ", tp, " Lots: ", lots);
         }
         else
         {
            Print("MEAN REVERSION SELL placed. Ticket: ", ticket,
                  " Entry: ", DoubleToString(Bid, Digits),
                  " SL: ", DoubleToString(sl, Digits),
                  " TP: ", DoubleToString(tp, Digits),
                  " Lots: ", DoubleToString(lots, 2));
            g_tradeTakenToday = true;
         }
         return;
      }
   }

   // --- Check for BUY setup (price spiked below Asian low, then reversed) ---
   double downExtension = g_rangeLow - barLow;
   if(downExtension >= minExtension && downExtension <= maxExtension)
   {
      g_spikeDownDetected = true;
   }

   if(g_spikeDownDetected)
   {
      // Check reversal: bar closed back near or above the Asian low
      double distFromLow = g_rangeLow - barClose;
      double reversalBufferPrice = ReversalBufferPips * g_pipSize;

      if(distFromLow <= reversalBufferPrice)
      {
         // Reversal confirmed — place BUY
         double sl = NormalizeDouble(g_spikeLow - SLBufferPips * g_pipSize, Digits);
         double tp = NormalizeDouble((g_rangeHigh + g_rangeLow) / 2.0, Digits);
         double slPips = (Ask - sl) / g_pipSize;
         double lots = CalculateLotSize(slPips);

         if(EnableDiagnostics)
         {
            Print("Asian Range: High=", DoubleToString(g_rangeHigh, Digits),
                  " Low=", DoubleToString(g_rangeLow, Digits),
                  " Width=", DoubleToString(rangeWidthPips, 1), " pips");
            Print("Spike DOWN detected: Low=", DoubleToString(g_spikeLow, Digits),
                  " Extension=", DoubleToString(downExtension / g_pipSize, 1), " pips (",
                  DoubleToString(downExtension / rangeWidth * 100, 0), "% of range)");
            Print("Reversal confirmed: Close=", DoubleToString(barClose, Digits),
                  " within ", ReversalBufferPips, " pips of Asian Low");
         }

         int ticket = OrderSend(
            Symbol(), OP_BUY, lots,
            Ask, Slippage, sl, tp,
            g_commentTag + " BUY MR", MagicNumber, 0, clrGreen
         );

         if(ticket < 0)
         {
            int err = GetLastError();
            Print("BUY failed. Error: ", err, " - ", ErrorDescription(err),
                  " Entry: ", Ask, " SL: ", sl, " TP: ", tp, " Lots: ", lots);
         }
         else
         {
            Print("MEAN REVERSION BUY placed. Ticket: ", ticket,
                  " Entry: ", DoubleToString(Ask, Digits),
                  " SL: ", DoubleToString(sl, Digits),
                  " TP: ", DoubleToString(tp, Digits),
                  " Lots: ", DoubleToString(lots, 2));
            g_tradeTakenToday = true;
         }
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Close open trades at session end                                  |
//+------------------------------------------------------------------+
void CheckSessionClose()
{
   int hour = TimeHour(TimeCurrent());
   int serverCloseHour = UKToServerHour(CloseTradesHour);
   int serverRangeStartHour = UKToServerHour(RangeStartHour);

   bool pastClose;
   if(serverCloseHour > serverRangeStartHour)
   {
      pastClose = (hour >= serverCloseHour);
   }
   else
   {
      pastClose = (hour >= serverCloseHour && hour < serverRangeStartHour);
   }

   if(!pastClose)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == OP_BUY)
            {
               bool result = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrYellow);
               if(result)
                  Print("Session close: BUY closed at ", Bid);
               else
                  Print("Session close failed. Error: ", GetLastError());
            }
            else if(OrderType() == OP_SELL)
            {
               bool result = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrYellow);
               if(result)
                  Print("Session close: SELL closed at ", Ask);
               else
                  Print("Session close failed. Error: ", GetLastError());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk % and SL distance                |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePips)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   if(minLot <= 0 || minLot > 99999) minLot = 0.01;

   if(slDistancePips <= 0)
      return minLot;

   double accountRisk = AccountBalance() * RiskPercent / 100.0;
   double tickValue   = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize    = MarketInfo(Symbol(), MODE_TICKSIZE);

   if(tickValue <= 0 || tickSize <= 0)
      return minLot;

   double pipValuePerLot = tickValue * (g_pipSize / tickSize);

   if(pipValuePerLot <= 0)
      return minLot;

   double lots = accountRisk / (slDistancePips * pipValuePerLot);

   lots = NormalizeLots(lots);

   // Margin safety check
   int maxAttempts = 10;
   while(maxAttempts > 0 && lots > minLot)
   {
      double marginRequired = AccountFreeMarginCheck(Symbol(), OP_BUY, lots);
      if(marginRequired > 0)
         break;
      lots = NormalizeLots(lots * 0.5);
      maxAttempts--;
   }

   if(EnableDiagnostics)
   {
      Print("LotCalc: risk=", DoubleToString(accountRisk, 2),
            " slPips=", DoubleToString(slDistancePips, 1),
            " pipVal=", DoubleToString(pipValuePerLot, 4),
            " lots=", DoubleToString(lots, 2),
            " minLot=", DoubleToString(minLot, 2));
   }

   return lots;
}

//+------------------------------------------------------------------+
//| Normalize lot size to broker constraints                          |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(minLot <= 0 || minLot > 99999) minLot = 0.01;
   if(maxLot <= 0 || maxLot > 99999) maxLot = 100.0;
   if(lotStep <= 0 || lotStep > 99999) lotStep = 0.01;

   lots = MathFloor(lots / lotStep) * lotStep;

   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   int lotDecimals = (int)MathMax(0, -MathLog10(lotStep));
   return NormalizeDouble(lots, lotDecimals);
}

//+------------------------------------------------------------------+
//| Human-readable error description                                  |
//+------------------------------------------------------------------+
string ErrorDescription(int errorCode)
{
   switch(errorCode)
   {
      case 0:    return "No error";
      case 1:    return "No error but result unknown";
      case 2:    return "Common error";
      case 3:    return "Invalid trade parameters";
      case 4:    return "Trade server is busy";
      case 5:    return "Old version of client terminal";
      case 6:    return "No connection to trade server";
      case 7:    return "Not enough rights";
      case 8:    return "Too frequent requests";
      case 9:    return "Malfunctional trade operation";
      case 64:   return "Account disabled";
      case 65:   return "Invalid account";
      case 128:  return "Trade timeout";
      case 129:  return "Invalid price";
      case 130:  return "Invalid stops";
      case 131:  return "Invalid trade volume";
      case 132:  return "Market is closed";
      case 133:  return "Trade is disabled";
      case 134:  return "Not enough money";
      case 135:  return "Price changed";
      case 136:  return "Off quotes";
      case 137:  return "Broker is busy";
      case 138:  return "Requote";
      case 139:  return "Order is locked";
      case 140:  return "Long positions only allowed";
      case 141:  return "Too many requests";
      case 145:  return "Modification denied - too close to market";
      case 146:  return "Trade context is busy";
      case 147:  return "Expirations denied by broker";
      case 148:  return "Too many open/pending orders";
      default:   return "Unknown error " + IntegerToString(errorCode);
   }
}

//+------------------------------------------------------------------+
//| On-chart display                                                  |
//+------------------------------------------------------------------+
void UpdateChartDisplay()
{
   double spreadPips = (Ask - Bid) / g_pipSize;
   int hour = TimeHour(TimeCurrent());
   int minute = TimeMinute(TimeCurrent());

   bool inRange = IsInRangePeriod();
   bool inEntry = IsInEntryWindow();

   int openCount = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == OP_BUY || OrderType() == OP_SELL)
               openCount++;
         }
      }
   }

   string display = "";
   display += "=== LTS Edge v5.0 (Mean Reversion) ===\n";
   display += "Symbol: " + Symbol() + "\n";

   if(inRange)
      display += "Status: BUILDING ASIAN RANGE\n";
   else if(inEntry && !g_tradeTakenToday)
      display += "Status: SCANNING FOR REVERSAL\n";
   else if(g_tradeTakenToday)
      display += "Status: TRADE TAKEN TODAY\n";
   else
      display += "Status: Outside session\n";

   display += "Spread: " + DoubleToString(spreadPips, 1) + " pips\n";

   if(g_rangeReady)
   {
      double rangeWidth = (g_rangeHigh - g_rangeLow) / g_pipSize;
      display += "Asian Range: " + DoubleToString(g_rangeLow, Digits) + " - " + DoubleToString(g_rangeHigh, Digits) +
                 " (" + DoubleToString(rangeWidth, 1) + " pips)\n";
      display += "Midpoint (TP): " + DoubleToString((g_rangeHigh + g_rangeLow) / 2.0, Digits) + "\n";
   }
   else
   {
      display += "Asian Range: Not yet built\n";
   }

   if(g_spikeUpDetected)
      display += "Spike UP detected: " + DoubleToString(g_spikeHigh, Digits) + "\n";
   if(g_spikeDownDetected)
      display += "Spike DOWN detected: " + DoubleToString(g_spikeLow, Digits) + "\n";

   display += "Open trades: " + IntegerToString(openCount) + "\n";
   display += "Trade taken: " + (g_tradeTakenToday ? "YES" : "NO") + "\n";
   display += "BST: " + (UKSummerTime ? "ON" : "OFF") + " | UTC+" + IntegerToString(BrokerUTCOffset) + "\n";

   Comment(display);
}

//+------------------------------------------------------------------+
