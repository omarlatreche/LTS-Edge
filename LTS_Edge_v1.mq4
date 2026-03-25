//+------------------------------------------------------------------+
//|                                                  LTS_Edge_v1.mq4 |
//|                        Trend-Following Pullback EA with Filters   |
//|                        Dual-timeframe: M15 trend + M5 entry       |
//|                        v1.1 — Bug fixes + Diagnostics              |
//+------------------------------------------------------------------+
#property copyright "LTS Edge v1"
#property link      ""
#property version   "1.20"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// --- Risk Management ---
input double   RiskPercent            = 1.0;     // Risk per trade (% of balance)
input double   RiskRewardRatio        = 2.0;     // Take profit as multiple of SL
input double   MaxDailyDrawdownPct    = 3.0;     // Max daily drawdown % — stop trading

// --- Stop Loss ---
input bool     UseATRStopLoss         = true;    // Use ATR-based stop loss
input int      ATRPeriod              = 14;      // ATR period for SL calculation
input double   ATRMultiplier          = 1.5;     // ATR multiplier for SL
input double   FixedStopLossPips      = 15.0;    // Fixed SL fallback (pips)

// --- Trade Management ---
input bool     EnablePartialClose     = true;    // Close partial position at 1R
input int      PartialClosePercent    = 50;      // % of position to close at 1R
input bool     EnableBreakEven        = true;    // Move SL to breakeven at 1R
input bool     EnableTrailingStop     = true;    // Enable trailing stop after 1R
input bool     UseATRTrailing         = true;    // Use ATR-based trailing distance
input double   ATRTrailingMultiplier  = 1.5;     // ATR multiplier for trailing stop

// --- Filters ---
input double   MaxSpreadPips          = 2.0;     // Max allowed spread (pips)
input double   MinCandleSizePips      = 3.0;     // Min candle size to avoid low-vol entries
input double   MinADRPips             = 40.0;    // Min Average Daily Range (pips)
input double   MaxADRPips             = 200.0;   // Max Average Daily Range (pips)

// --- Session Filter (UK time — auto-converted to server time) ---
input int      SessionStartHour       = 8;       // London session start hour (UK time)
input int      SessionStartMinute     = 0;       // London session start minute
input int      SessionEndHour         = 11;      // London session end hour (UK time)
input int      SessionEndMinute       = 0;       // London session end minute
input int      BrokerUTCOffset        = 2;       // Broker server UTC offset (e.g. 2 for UTC+2)
input bool     UKSummerTime           = false;   // UK is on BST (UTC+1) — set true late Mar-Oct

// --- Day Filter ---
input bool     TradeMonday            = false;   // Allow trades on Monday
input bool     TradeTuesday           = true;    // Allow trades on Tuesday
input bool     TradeWednesday         = true;    // Allow trades on Wednesday
input bool     TradeThursday          = true;    // Allow trades on Thursday
input bool     TradeFriday            = false;   // Allow trades on Friday

// --- Confirmation ---
input bool     UseHTFAlignment        = true;    // Require H4 trend alignment
input int      HTFPeriod              = PERIOD_H4;// Higher timeframe for alignment
input bool     UseRSIDivergence       = true;    // Allow RSI divergence as entry signal
input bool     RequireStrongCandle    = false;    // Require engulfing or pin bar pattern
input double   MinEMASlopePoints      = 5.0;     // Min 200 EMA slope over 5 bars (points)

// --- Trade Limits ---
input int      MaxTradesPerDay        = 3;       // Max trades per day

// --- Diagnostics ---
input bool     EnableDiagnostics      = true;    // Log detailed filter/signal results per bar

// --- System ---
input int      MagicNumber            = 12345;   // EA magic number
input int      Slippage               = 3;       // Max slippage (points)

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
datetime g_lastBarTime    = 0;         // Track last processed bar time
double   g_pipSize        = 0;         // Pip size for this symbol
int      g_pipDigits      = 0;         // Number of digits for pip rounding
string   g_commentTag     = "LTSv1";   // Order comment prefix
double   g_startBalance   = 0;         // Balance at start of day for DD calc

// --- Partial close tracking (Bug 1 fix) ---
int      g_partialTickets[100];        // Tickets that have been partially closed
int      g_partialCount   = 0;         // Number of tracked partial closes

// --- Original SL distance tracking (Bug 2 fix) ---
int      g_slTickets[100];             // Tickets with stored SL distances
double   g_slDistances[100];           // Original SL distances (price units)
int      g_slCount        = 0;         // Number of tracked SL distances

// --- Session diagnostics counters ---
int      g_sessionBarsChecked   = 0;
int      g_sessionFiltersPassed = 0;
int      g_sessionSignalsFound  = 0;
int      g_sessionTrades        = 0;
bool     g_sessionSummaryPrinted = false;
int      g_lastSessionDay       = -1;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   // Calculate pip size based on broker digits
   if(Digits == 5 || Digits == 3)
   {
      g_pipSize  = Point * 10;
      g_pipDigits = 1;
   }
   else
   {
      g_pipSize  = Point;
      g_pipDigits = 0;
   }

   g_startBalance = AccountBalance();

   // Log session window in server time for verification
   int ukOffset = UKSummerTime ? 1 : 0;
   int serverStart = SessionStartHour - ukOffset + BrokerUTCOffset;
   int serverEnd   = SessionEndHour - ukOffset + BrokerUTCOffset;
   // Handle wrap
   if(serverStart < 0) serverStart += 24;
   if(serverEnd < 0) serverEnd += 24;
   serverStart = serverStart % 24;
   serverEnd   = serverEnd % 24;

   Print("LTS Edge v1.1 initialized. Pip size: ", g_pipSize, " Digits: ", Digits);
   Print("Session: ", SessionStartHour, ":00-", SessionEndHour, ":00 UK",
         (UKSummerTime ? " (BST)" : " (GMT)"),
         " = ", serverStart, ":00-", serverEnd, ":00 server (UTC+", BrokerUTCOffset, ")");
   Print("Inputs: Risk=", RiskPercent, "% RR=", RiskRewardRatio,
         " ATR_SL=", UseATRStopLoss, " ATR_Period=", ATRPeriod,
         " ATR_Mult=", ATRMultiplier);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");  // Clear chart overlay
   Print("LTS Edge v1.1 removed. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Main tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // Always manage open trades (trailing, BE, partial close)
   ManageOpenTrades();

   // Update on-chart display
   UpdateChartDisplay();

   // Only check for new entries on a new M5 bar
   if(!IsNewBar())
      return;

   // Reset daily balance tracker at start of new day
   ResetDailyBalance();

   // Reset session counters at start of new session day
   ResetSessionCounters();

   // Print session summary after session ends
   CheckSessionEnd();

   // Skip if we already have an open trade on this symbol
   if(HasOpenTrade())
      return;

   // Run all filters
   if(!PassesAllFilters())
      return;

   // Filters passed — check for entry signals
   g_sessionFiltersPassed++;

   // Check for entry signals
   int buyResult  = CheckBuySignalDiag();
   int sellResult = CheckSellSignalDiag();

   if(buyResult == 1)
   {
      g_sessionSignalsFound++;
      g_sessionTrades++;
      ExecuteBuy();
   }
   else if(sellResult == 1)
   {
      g_sessionSignalsFound++;
      g_sessionTrades++;
      ExecuteSell();
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
//| Reset daily balance at start of new trading day                   |
//+------------------------------------------------------------------+
void ResetDailyBalance()
{
   static int lastDay = -1;
   int today = TimeDay(TimeCurrent());
   if(today != lastDay)
   {
      g_startBalance = AccountBalance();
      lastDay = today;
   }
}

//+------------------------------------------------------------------+
//| Reset session diagnostic counters at start of each session day    |
//+------------------------------------------------------------------+
void ResetSessionCounters()
{
   int today = TimeDay(TimeCurrent());
   if(today != g_lastSessionDay)
   {
      g_sessionBarsChecked   = 0;
      g_sessionFiltersPassed = 0;
      g_sessionSignalsFound  = 0;
      g_sessionTrades        = 0;
      g_sessionSummaryPrinted = false;
      g_lastSessionDay       = today;
   }
}

//+------------------------------------------------------------------+
//| Print session summary after session ends                          |
//+------------------------------------------------------------------+
void CheckSessionEnd()
{
   if(g_sessionSummaryPrinted)
      return;

   // Check if we're past session end
   int hour   = TimeHour(TimeCurrent());
   int minute = TimeMinute(TimeCurrent());
   int currentMinutes = hour * 60 + minute;

   int ukOffset = UKSummerTime ? 1 : 0;
   int endMinutes = (SessionEndHour - ukOffset + BrokerUTCOffset) * 60 + SessionEndMinute;
   endMinutes = endMinutes % (24 * 60);
   if(endMinutes < 0) endMinutes += 24 * 60;

   // Only print summary if we're past session end AND we checked at least 1 bar
   if(currentMinutes >= endMinutes && g_sessionBarsChecked > 0)
   {
      Print("=== SESSION SUMMARY: ", g_sessionBarsChecked, " bars checked | ",
            g_sessionFiltersPassed, " passed filters | ",
            g_sessionSignalsFound, " signals | ",
            g_sessionTrades, " trades ===");
      g_sessionSummaryPrinted = true;
   }
}

//+------------------------------------------------------------------+
//|                     FILTER FUNCTIONS                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Master filter check — all conditions must pass                    |
//| With diagnostic logging when enabled                              |
//+------------------------------------------------------------------+
bool PassesAllFilters()
{
   bool inSession = IsWithinSession();

   // If not in session, skip everything (no diagnostics outside session)
   if(!inSession)
      return false;

   // We're in session — count this bar
   g_sessionBarsChecked++;

   // Evaluate all filters, log results when diagnostics enabled
   double spreadPips = (Ask - Bid) / g_pipSize;
   bool spreadOK = (spreadPips <= MaxSpreadPips);

   bool dayOK = IsTradingDay();

   int tradesToday = CountTradesToday();
   bool tradesOK = (tradesToday < MaxTradesPerDay);

   double candleSize = MathAbs(iHigh(Symbol(), PERIOD_M5, 1) - iLow(Symbol(), PERIOD_M5, 1)) / g_pipSize;
   bool candleOK = (candleSize >= MinCandleSizePips);

   double adr = GetADR();
   bool adrOK = (adr >= MinADRPips && adr <= MaxADRPips);

   bool ddOK = !CheckDailyDrawdown();

   double slope = GetEMA200Slope();
   double slopeThreshold = MinEMASlopePoints * Point;
   bool slopeOK = (MathAbs(slope) >= slopeThreshold);

   bool allPass = spreadOK && dayOK && tradesOK && candleOK && adrOK && ddOK && slopeOK;

   if(EnableDiagnostics)
   {
      string msg = "[FILTER] ";
      msg += "Spread:" + DoubleToString(spreadPips, 1) + (spreadOK ? " OK" : " FAIL") + " | ";
      msg += "Day:" + (dayOK ? "OK" : "FAIL") + " | ";
      msg += "Trades:" + IntegerToString(tradesToday) + "/" + IntegerToString(MaxTradesPerDay) + (tradesOK ? " OK" : " FAIL") + " | ";
      msg += "Candle:" + DoubleToString(candleSize, 1) + (candleOK ? " OK" : " FAIL(" + DoubleToString(MinCandleSizePips, 1) + ")") + " | ";
      msg += "ADR:" + DoubleToString(adr, 0) + (adrOK ? " OK" : " FAIL") + " | ";
      msg += "DD:" + (ddOK ? "OK" : "FAIL") + " | ";
      msg += "Slope:" + DoubleToString(MathAbs(slope) / Point, 1) + "pt" + (slopeOK ? " OK" : " FAIL(" + DoubleToString(MinEMASlopePoints, 1) + ")");
      msg += allPass ? " >>> ALL PASS" : "";
      Print(msg);
   }

   return allPass;
}

//+------------------------------------------------------------------+
//| Check if current time is within trading session                   |
//| Converts UK time to broker server time using UTC offset           |
//| Accounts for UK summer time (BST = UTC+1)                        |
//+------------------------------------------------------------------+
bool IsWithinSession()
{
   int hour   = TimeHour(TimeCurrent());
   int minute = TimeMinute(TimeCurrent());
   int currentMinutes = hour * 60 + minute;

   // UK is UTC+0 (GMT) in winter, UTC+1 (BST) in summer
   // Session inputs are in UK local time
   // To convert UK local → UTC: subtract ukOffset
   // To convert UTC → server: add BrokerUTCOffset
   int ukOffset = UKSummerTime ? 1 : 0;
   int startMinutes = (SessionStartHour - ukOffset + BrokerUTCOffset) * 60 + SessionStartMinute;
   int endMinutes   = (SessionEndHour - ukOffset + BrokerUTCOffset) * 60 + SessionEndMinute;

   // Handle wrap-around past midnight
   if(startMinutes < 0) startMinutes += 24 * 60;
   if(endMinutes < 0)   endMinutes += 24 * 60;
   startMinutes = startMinutes % (24 * 60);
   endMinutes   = endMinutes % (24 * 60);

   if(startMinutes < endMinutes)
      return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
   else
      return (currentMinutes >= startMinutes || currentMinutes < endMinutes);
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
//| Count trades opened today with our magic number                   |
//+------------------------------------------------------------------+
int CountTradesToday()
{
   int count = 0;
   datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderOpenTime() >= todayStart)
               count++;
         }
      }
   }

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderOpenTime() >= todayStart)
               count++;
         }
      }
   }

   return count;
}

//+------------------------------------------------------------------+
//| Calculate Average Daily Range over last 10 days (in pips)         |
//+------------------------------------------------------------------+
double GetADR()
{
   double totalRange = 0;
   int days = 10;

   for(int i = 1; i <= days; i++)
   {
      double high = iHigh(Symbol(), PERIOD_D1, i);
      double low  = iLow(Symbol(), PERIOD_D1, i);
      totalRange += (high - low);
   }

   return (totalRange / days) / g_pipSize;
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
//| Get 200 EMA slope on M15 (EMA[0] - EMA[5])                       |
//+------------------------------------------------------------------+
double GetEMA200Slope()
{
   double ema0 = iMA(Symbol(), PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema5 = iMA(Symbol(), PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE, 5);
   return ema0 - ema5;
}

//+------------------------------------------------------------------+
//| Check if EA has an open trade on this symbol                      |
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
//|                     SIGNAL FUNCTIONS                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check BUY signal with diagnostic logging                          |
//| Returns: 1 = signal found, 0 = no signal                         |
//+------------------------------------------------------------------+
int CheckBuySignalDiag()
{
   // 1. M15 trend: price above 200 EMA
   double ema200_m15 = iMA(Symbol(), PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE, 0);
   double m15Close = iClose(Symbol(), PERIOD_M15, 0);
   bool trendOK = (m15Close > ema200_m15);

   // 2. EMA slope must be positive (uptrend)
   double slope = GetEMA200Slope();
   bool slopeOK = (slope > 0);

   // 3. M5 pullback: price touched or pierced the 20 EMA
   double ema20_m5 = iMA(Symbol(), PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double low1 = iLow(Symbol(), PERIOD_M5, 1);
   bool pullbackOK = (low1 <= ema20_m5 + 1.0 * g_pipSize);

   // 4. RSI confirmation
   bool rsiOK = CheckRSIBuyCondition();

   // 5. Candle pattern
   double close1 = iClose(Symbol(), PERIOD_M5, 1);
   double open1  = iOpen(Symbol(), PERIOD_M5, 1);
   bool bullishOK = (close1 > open1);
   bool patternOK = true;
   if(RequireStrongCandle && bullishOK)
      patternOK = IsBullishEngulfingOrPinBar();

   // 6. HTF alignment
   bool htfOK = true;
   double htfEMA = 0;
   if(UseHTFAlignment)
   {
      htfEMA = iMA(Symbol(), HTFPeriod, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
      htfOK = (Ask > htfEMA);
   }

   bool allPass = trendOK && slopeOK && pullbackOK && rsiOK && bullishOK && patternOK && htfOK;

   if(EnableDiagnostics)
   {
      string msg = "[BUY] ";
      msg += "M15trend:" + (trendOK ? "OK" : "FAIL(price " + DoubleToString(m15Close, Digits) + " vs EMA " + DoubleToString(ema200_m15, Digits) + ")") + " | ";
      msg += "Slope:" + (slopeOK ? "OK(+" + DoubleToString(slope/Point, 1) + "pt)" : "FAIL(neg)") + " | ";
      msg += "Pullback:" + (pullbackOK ? "OK" : "FAIL(low " + DoubleToString(low1, Digits) + " > EMA+" + DoubleToString(ema20_m5 + g_pipSize, Digits) + ")") + " | ";
      msg += "RSI:" + (rsiOK ? "OK" : "FAIL") + " | ";
      msg += "Bullish:" + (bullishOK ? "OK" : "FAIL") + " | ";
      msg += "Pattern:" + (patternOK ? "OK" : "FAIL(no engulf/pin)") + " | ";
      if(UseHTFAlignment)
         msg += "H4:" + (htfOK ? "OK" : "FAIL(Ask<EMA " + DoubleToString(htfEMA, Digits) + ")");
      if(allPass)
         msg += " >>> BUY SIGNAL";
      Print(msg);
   }

   return allPass ? 1 : 0;
}

//+------------------------------------------------------------------+
//| Check SELL signal with diagnostic logging                         |
//| Returns: 1 = signal found, 0 = no signal                         |
//+------------------------------------------------------------------+
int CheckSellSignalDiag()
{
   // 1. M15 trend: price below 200 EMA
   double ema200_m15 = iMA(Symbol(), PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE, 0);
   double m15Close = iClose(Symbol(), PERIOD_M15, 0);
   bool trendOK = (m15Close < ema200_m15);

   // 2. EMA slope must be negative (downtrend)
   double slope = GetEMA200Slope();
   bool slopeOK = (slope < 0);

   // 3. M5 pullback: price touched or pierced the 20 EMA
   double ema20_m5 = iMA(Symbol(), PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double high1 = iHigh(Symbol(), PERIOD_M5, 1);
   bool pullbackOK = (high1 >= ema20_m5 - 1.0 * g_pipSize);

   // 4. RSI confirmation
   bool rsiOK = CheckRSISellCondition();

   // 5. Candle pattern
   double close1 = iClose(Symbol(), PERIOD_M5, 1);
   double open1  = iOpen(Symbol(), PERIOD_M5, 1);
   bool bearishOK = (close1 < open1);
   bool patternOK = true;
   if(RequireStrongCandle && bearishOK)
      patternOK = IsBearishEngulfingOrPinBar();

   // 6. HTF alignment
   bool htfOK = true;
   double htfEMA = 0;
   if(UseHTFAlignment)
   {
      htfEMA = iMA(Symbol(), HTFPeriod, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
      htfOK = (Bid < htfEMA);
   }

   bool allPass = trendOK && slopeOK && pullbackOK && rsiOK && bearishOK && patternOK && htfOK;

   if(EnableDiagnostics)
   {
      string msg = "[SELL] ";
      msg += "M15trend:" + (trendOK ? "OK" : "FAIL(price " + DoubleToString(m15Close, Digits) + " vs EMA " + DoubleToString(ema200_m15, Digits) + ")") + " | ";
      msg += "Slope:" + (slopeOK ? "OK(" + DoubleToString(slope/Point, 1) + "pt)" : "FAIL(pos)") + " | ";
      msg += "Pullback:" + (pullbackOK ? "OK" : "FAIL(high " + DoubleToString(high1, Digits) + " < EMA-" + DoubleToString(ema20_m5 - g_pipSize, Digits) + ")") + " | ";
      msg += "RSI:" + (rsiOK ? "OK" : "FAIL") + " | ";
      msg += "Bearish:" + (bearishOK ? "OK" : "FAIL") + " | ";
      msg += "Pattern:" + (patternOK ? "OK" : "FAIL(no engulf/pin)") + " | ";
      if(UseHTFAlignment)
         msg += "H4:" + (htfOK ? "OK" : "FAIL(Bid>EMA " + DoubleToString(htfEMA, Digits) + ")");
      if(allPass)
         msg += " >>> SELL SIGNAL";
      Print(msg);
   }

   return allPass ? 1 : 0;
}

//+------------------------------------------------------------------+
//| RSI buy condition: turn upward from below 40 OR bullish divergence|
//+------------------------------------------------------------------+
bool CheckRSIBuyCondition()
{
   double rsi1 = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, 1);
   double rsi2 = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, 2);

   bool standardTurn = (rsi2 < 40.0 && rsi1 > rsi2);

   if(standardTurn)
      return true;

   if(UseRSIDivergence)
      return CheckBullishRSIDivergence();

   return false;
}

//+------------------------------------------------------------------+
//| RSI sell condition: turn downward from above 60 OR bearish diverg |
//+------------------------------------------------------------------+
bool CheckRSISellCondition()
{
   double rsi1 = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, 1);
   double rsi2 = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, 2);

   bool standardTurn = (rsi2 > 60.0 && rsi1 < rsi2);

   if(standardTurn)
      return true;

   if(UseRSIDivergence)
      return CheckBearishRSIDivergence();

   return false;
}

//+------------------------------------------------------------------+
//| Bullish RSI divergence: price lower low, RSI higher low           |
//+------------------------------------------------------------------+
bool CheckBullishRSIDivergence()
{
   int lookback = 10;

   double priceLow1 = iLow(Symbol(), PERIOD_M5, 1);
   double rsiLow1   = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, 1);

   for(int i = 3; i <= lookback; i++)
   {
      double priceLowI = iLow(Symbol(), PERIOD_M5, i);
      double rsiLowI   = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, i);

      if(priceLowI <= iLow(Symbol(), PERIOD_M5, i-1) &&
         priceLowI <= iLow(Symbol(), PERIOD_M5, i+1))
      {
         if(priceLow1 < priceLowI && rsiLow1 > rsiLowI)
         {
            if(EnableDiagnostics)
               Print("Bullish RSI divergence detected at bar ", i);
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Bearish RSI divergence: price higher high, RSI lower high         |
//+------------------------------------------------------------------+
bool CheckBearishRSIDivergence()
{
   int lookback = 10;

   double priceHigh1 = iHigh(Symbol(), PERIOD_M5, 1);
   double rsiHigh1   = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, 1);

   for(int i = 3; i <= lookback; i++)
   {
      double priceHighI = iHigh(Symbol(), PERIOD_M5, i);
      double rsiHighI   = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, i);

      if(priceHighI >= iHigh(Symbol(), PERIOD_M5, i-1) &&
         priceHighI >= iHigh(Symbol(), PERIOD_M5, i+1))
      {
         if(priceHigh1 > priceHighI && rsiHigh1 < rsiHighI)
         {
            if(EnableDiagnostics)
               Print("Bearish RSI divergence detected at bar ", i);
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Detect bullish engulfing or bullish pin bar on M5 bar 1           |
//+------------------------------------------------------------------+
bool IsBullishEngulfingOrPinBar()
{
   double open1  = iOpen(Symbol(), PERIOD_M5, 1);
   double close1 = iClose(Symbol(), PERIOD_M5, 1);
   double high1  = iHigh(Symbol(), PERIOD_M5, 1);
   double low1   = iLow(Symbol(), PERIOD_M5, 1);
   double open2  = iOpen(Symbol(), PERIOD_M5, 2);
   double close2 = iClose(Symbol(), PERIOD_M5, 2);

   double body1 = MathAbs(close1 - open1);

   // Engulfing: current bullish body fully engulfs previous bearish body
   bool engulfing = (close2 < open2) &&
                    (close1 > open1) &&
                    (close1 > open2) && (open1 < close2);

   // Pin bar: long lower wick (rejection), wick >= 2x body
   double lowerWick = MathMin(open1, close1) - low1;
   double upperWick = high1 - MathMax(open1, close1);
   bool pinBar = (close1 > open1) &&
                 (lowerWick >= 2.0 * body1) &&
                 (upperWick < body1);

   return (engulfing || pinBar);
}

//+------------------------------------------------------------------+
//| Detect bearish engulfing or bearish pin bar on M5 bar 1           |
//+------------------------------------------------------------------+
bool IsBearishEngulfingOrPinBar()
{
   double open1  = iOpen(Symbol(), PERIOD_M5, 1);
   double close1 = iClose(Symbol(), PERIOD_M5, 1);
   double high1  = iHigh(Symbol(), PERIOD_M5, 1);
   double low1   = iLow(Symbol(), PERIOD_M5, 1);
   double open2  = iOpen(Symbol(), PERIOD_M5, 2);
   double close2 = iClose(Symbol(), PERIOD_M5, 2);

   double body1 = MathAbs(close1 - open1);

   // Engulfing: current bearish body fully engulfs previous bullish body
   bool engulfing = (close2 > open2) &&
                    (close1 < open1) &&
                    (open1 > close2) && (close1 < open2);

   // Pin bar: long upper wick (rejection), wick >= 2x body
   double upperWick = high1 - MathMax(open1, close1);
   double lowerWick = MathMin(open1, close1) - low1;
   bool pinBar = (close1 < open1) &&
                 (upperWick >= 2.0 * body1) &&
                 (lowerWick < body1);

   return (engulfing || pinBar);
}

//+------------------------------------------------------------------+
//|                     STOP LOSS FUNCTIONS                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate stop loss price for a BUY                               |
//+------------------------------------------------------------------+
double CalculateBuyStopLoss()
{
   double slPrice;

   if(UseATRStopLoss)
   {
      double atr = iATR(Symbol(), PERIOD_M5, ATRPeriod, 1);
      double atrSL = Ask - atr * ATRMultiplier;

      double swingLow = FindSwingLow(10);
      if(swingLow > 0)
      {
         double swingSL = swingLow - 1.0 * g_pipSize;
         slPrice = MathMin(atrSL, swingSL);

         double maxSL = Ask - atr * ATRMultiplier * 2.0;
         if(slPrice < maxSL)
            slPrice = maxSL;
      }
      else
      {
         slPrice = atrSL;
      }
   }
   else
   {
      slPrice = Ask - FixedStopLossPips * g_pipSize;

      double swingLow = FindSwingLow(10);
      if(swingLow > 0)
      {
         double swingSL = swingLow - 1.0 * g_pipSize;
         slPrice = MathMin(slPrice, swingSL);
      }
   }

   return NormalizeDouble(slPrice, Digits);
}

//+------------------------------------------------------------------+
//| Calculate stop loss price for a SELL                              |
//+------------------------------------------------------------------+
double CalculateSellStopLoss()
{
   double slPrice;

   if(UseATRStopLoss)
   {
      double atr = iATR(Symbol(), PERIOD_M5, ATRPeriod, 1);
      double atrSL = Bid + atr * ATRMultiplier;

      double swingHigh = FindSwingHigh(10);
      if(swingHigh > 0)
      {
         double swingSL = swingHigh + 1.0 * g_pipSize;
         slPrice = MathMax(atrSL, swingSL);

         double maxSL = Bid + atr * ATRMultiplier * 2.0;
         if(slPrice > maxSL)
            slPrice = maxSL;
      }
      else
      {
         slPrice = atrSL;
      }
   }
   else
   {
      slPrice = Bid + FixedStopLossPips * g_pipSize;

      double swingHigh = FindSwingHigh(10);
      if(swingHigh > 0)
      {
         double swingSL = swingHigh + 1.0 * g_pipSize;
         slPrice = MathMax(slPrice, swingSL);
      }
   }

   return NormalizeDouble(slPrice, Digits);
}

//+------------------------------------------------------------------+
//| Find recent swing low (fractal-style) on M5                       |
//+------------------------------------------------------------------+
double FindSwingLow(int lookback)
{
   double lowestSwing = 0;

   for(int i = 2; i <= lookback; i++)
   {
      double low_i  = iLow(Symbol(), PERIOD_M5, i);
      double low_l  = iLow(Symbol(), PERIOD_M5, i - 1);
      double low_r  = iLow(Symbol(), PERIOD_M5, i + 1);

      if(low_i <= low_l && low_i <= low_r)
      {
         if(lowestSwing == 0 || low_i < lowestSwing)
            lowestSwing = low_i;
      }
   }

   return lowestSwing;
}

//+------------------------------------------------------------------+
//| Find recent swing high (fractal-style) on M5                      |
//+------------------------------------------------------------------+
double FindSwingHigh(int lookback)
{
   double highestSwing = 0;

   for(int i = 2; i <= lookback; i++)
   {
      double high_i = iHigh(Symbol(), PERIOD_M5, i);
      double high_l = iHigh(Symbol(), PERIOD_M5, i - 1);
      double high_r = iHigh(Symbol(), PERIOD_M5, i + 1);

      if(high_i >= high_l && high_i >= high_r)
      {
         if(highestSwing == 0 || high_i > highestSwing)
            highestSwing = high_i;
      }
   }

   return highestSwing;
}

//+------------------------------------------------------------------+
//|                     LOT SIZE CALCULATION                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate lot size based on risk % and SL distance                |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePips)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   if(minLot <= 0) minLot = 0.01;

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

   Print("LotCalc: risk=", DoubleToString(accountRisk, 2),
         " slPips=", DoubleToString(slDistancePips, 1),
         " pipVal=", DoubleToString(pipValuePerLot, 4),
         " rawLots=", DoubleToString(lots, 4),
         " minLot=", DoubleToString(MarketInfo(Symbol(), MODE_MINLOT), 4),
         " maxLot=", DoubleToString(MarketInfo(Symbol(), MODE_MAXLOT), 2));

   lots = NormalizeLots(lots);

   // Margin safety check — reduce lots until we can afford the trade
   int maxAttempts = 10;
   while(maxAttempts > 0 && lots > minLot)
   {
      double marginRequired = AccountFreeMarginCheck(Symbol(), OP_BUY, lots);
      if(marginRequired > 0)
         break;
      lots = NormalizeLots(lots * 0.5);
      maxAttempts--;
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

   // Fallback defaults if MarketInfo returns 0 (common in backtester)
   if(minLot  <= 0) minLot  = 0.01;
   if(maxLot  <= 0) maxLot  = 100.0;
   if(lotStep <= 0) lotStep = 0.01;

   // Hard cap: never risk more than 10 standard lots regardless of broker max
   if(maxLot > 10.0) maxLot = 10.0;

   lots = MathFloor(lots / lotStep) * lotStep;

   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//|                     TRADE EXECUTION                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Execute a BUY trade                                               |
//+------------------------------------------------------------------+
void ExecuteBuy()
{
   RefreshRates();  // Bug 3 fix: ensure fresh prices

   double slPrice = CalculateBuyStopLoss();
   double slDistancePips = (Ask - slPrice) / g_pipSize;

   if(slDistancePips <= 0)
   {
      Print("Invalid SL distance for BUY: ", slDistancePips);
      return;
   }

   double lots = CalculateLotSize(slDistancePips);
   double tpPrice = NormalizeDouble(Ask + slDistancePips * g_pipSize * RiskRewardRatio, Digits);

   string comment = g_commentTag;

   int ticket = OrderSend(
      Symbol(),
      OP_BUY,
      lots,
      NormalizeDouble(Ask, Digits),
      Slippage,
      slPrice,
      tpPrice,
      comment,
      MagicNumber,
      0,
      clrGreen
   );

   if(ticket < 0)
   {
      int err = GetLastError();
      Print("BUY OrderSend failed. Error: ", err, " - ", ErrorDescription(err));
   }
   else
   {
      Print("BUY opened. Ticket: ", ticket, " Lots: ", lots,
            " SL: ", slPrice, " TP: ", tpPrice,
            " SL pips: ", DoubleToString(slDistancePips, 1));

      // Store original SL distance for trailing stop (Bug 2 fix)
      StoreSLDistance(ticket, Ask - slPrice);
   }
}

//+------------------------------------------------------------------+
//| Execute a SELL trade                                              |
//+------------------------------------------------------------------+
void ExecuteSell()
{
   RefreshRates();  // Bug 3 fix: ensure fresh prices

   double slPrice = CalculateSellStopLoss();
   double slDistancePips = (slPrice - Bid) / g_pipSize;

   if(slDistancePips <= 0)
   {
      Print("Invalid SL distance for SELL: ", slDistancePips);
      return;
   }

   double lots = CalculateLotSize(slDistancePips);
   double tpPrice = NormalizeDouble(Bid - slDistancePips * g_pipSize * RiskRewardRatio, Digits);

   string comment = g_commentTag;

   int ticket = OrderSend(
      Symbol(),
      OP_SELL,
      lots,
      NormalizeDouble(Bid, Digits),
      Slippage,
      slPrice,
      tpPrice,
      comment,
      MagicNumber,
      0,
      clrRed
   );

   if(ticket < 0)
   {
      int err = GetLastError();
      Print("SELL OrderSend failed. Error: ", err, " - ", ErrorDescription(err));
   }
   else
   {
      Print("SELL opened. Ticket: ", ticket, " Lots: ", lots,
            " SL: ", slPrice, " TP: ", tpPrice,
            " SL pips: ", DoubleToString(slDistancePips, 1));

      // Store original SL distance for trailing stop (Bug 2 fix)
      StoreSLDistance(ticket, slPrice - Bid);
   }
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
//|                     TRADE MANAGEMENT                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Store original SL distance when trade opens (Bug 2 fix)           |
//+------------------------------------------------------------------+
void StoreSLDistance(int ticket, double distance)
{
   if(g_slCount < 100)
   {
      g_slTickets[g_slCount]   = ticket;
      g_slDistances[g_slCount] = distance;
      g_slCount++;
   }
}

//+------------------------------------------------------------------+
//| Get stored original SL distance for a ticket (Bug 2 fix)          |
//| Also checks the parent ticket for partially-closed orders         |
//+------------------------------------------------------------------+
double GetStoredSLDistance(int ticket)
{
   // Direct match
   for(int i = 0; i < g_slCount; i++)
   {
      if(g_slTickets[i] == ticket)
         return g_slDistances[i];
   }

   // After partial close, MT4 creates a new ticket. Try to find via comment
   // "from #XXXXX" pattern — extract parent ticket
   if(OrderSelect(ticket, SELECT_BY_TICKET))
   {
      string comment = OrderComment();
      int fromPos = StringFind(comment, "from #");
      if(fromPos >= 0)
      {
         string parentStr = StringSubstr(comment, fromPos + 6);
         int parentTicket = (int)StringToInteger(parentStr);
         if(parentTicket > 0)
         {
            for(int i = 0; i < g_slCount; i++)
            {
               if(g_slTickets[i] == parentTicket)
               {
                  // Cache this mapping for future lookups
                  StoreSLDistance(ticket, g_slDistances[i]);
                  return g_slDistances[i];
               }
            }
         }
      }
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Check if a ticket has been partially closed (Bug 1 fix)           |
//+------------------------------------------------------------------+
bool IsPartialDone(int ticket)
{
   for(int i = 0; i < g_partialCount; i++)
   {
      if(g_partialTickets[i] == ticket)
         return true;
   }

   // Also check if this is a child of a partially-closed order
   // After partial close, the new order comment contains "from #XXXXX"
   if(OrderSelect(ticket, SELECT_BY_TICKET))
   {
      string comment = OrderComment();
      if(StringFind(comment, "from #") >= 0)
         return true;  // This IS the remainder from a partial close
   }

   return false;
}

//+------------------------------------------------------------------+
//| Mark a ticket as partially closed (Bug 1 fix)                     |
//+------------------------------------------------------------------+
void MarkPartialDone(int ticket)
{
   if(g_partialCount < 100)
   {
      g_partialTickets[g_partialCount] = ticket;
      g_partialCount++;
   }
}

//+------------------------------------------------------------------+
//| Manage all open trades: partial close, break-even, trailing stop  |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      int    ticket       = OrderTicket();
      double openPrice    = OrderOpenPrice();
      double currentSL    = OrderStopLoss();
      double slDistance    = 0;
      double currentProfit = 0;

      // Use stored original SL distance if available (Bug 2 fix)
      double origSLDist = GetStoredSLDistance(ticket);

      if(OrderType() == OP_BUY)
      {
         slDistance    = (origSLDist > 0) ? origSLDist : (openPrice - currentSL);
         currentProfit = Bid - openPrice;
      }
      else
      {
         slDistance    = (origSLDist > 0) ? origSLDist : (currentSL - openPrice);
         currentProfit = openPrice - Ask;
      }

      if(slDistance <= 0) continue;

      double profitInR = currentProfit / slDistance;

      // 1. Partial close at 1R (Bug 1 fix: use global tracker instead of comment)
      if(EnablePartialClose && !IsPartialDone(ticket) && profitInR >= 1.0)
      {
         HandlePartialClose(ticket, OrderType(), OrderLots());
      }

      // 2. Break-even at 1R
      if(EnableBreakEven && profitInR >= 1.0)
      {
         HandleBreakEven(ticket, OrderType(), openPrice, currentSL);
      }

      // 3. Trailing stop after 1R (Bug 2 fix: pass original SL distance)
      if(EnableTrailingStop && profitInR >= 1.0)
      {
         HandleTrailingStop(ticket, OrderType(), openPrice, currentSL, origSLDist);
      }
   }
}

//+------------------------------------------------------------------+
//| Close partial position at 1R profit                               |
//+------------------------------------------------------------------+
void HandlePartialClose(int ticket, int orderType, double lots)
{
   double closeLots = NormalizeLots(lots * PartialClosePercent / 100.0);

   if(closeLots >= lots)
      return;

   double remainingLots = NormalizeLots(lots - closeLots);
   if(remainingLots < MarketInfo(Symbol(), MODE_MINLOT))
      return;

   double closePrice = (orderType == OP_BUY) ? Bid : Ask;

   bool result = OrderClose(ticket, closeLots, NormalizeDouble(closePrice, Digits), Slippage, clrYellow);

   if(result)
   {
      Print("Partial close executed. Ticket: ", ticket, " Closed: ", closeLots, " lots");
      // Bug 1 fix: mark this ticket as partially closed using global tracker
      MarkPartialDone(ticket);
   }
   else
   {
      int err = GetLastError();
      Print("Partial close failed. Error: ", err, " - ", ErrorDescription(err));
   }
}

//+------------------------------------------------------------------+
//| Move stop loss to break-even (entry + 1 pip)                      |
//+------------------------------------------------------------------+
void HandleBreakEven(int ticket, int orderType, double openPrice, double currentSL)
{
   double newSL;

   if(orderType == OP_BUY)
   {
      newSL = NormalizeDouble(openPrice + 1.0 * g_pipSize, Digits);
      if(currentSL >= newSL)
         return;
   }
   else
   {
      newSL = NormalizeDouble(openPrice - 1.0 * g_pipSize, Digits);
      if(currentSL > 0 && currentSL <= newSL)
         return;
   }

   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;

   bool result = OrderModify(ticket, openPrice, newSL, OrderTakeProfit(), 0, clrBlue);

   if(result)
   {
      Print("Break-even set. Ticket: ", ticket, " New SL: ", newSL);
   }
   else
   {
      int err = GetLastError();
      if(err != 1)
         Print("Break-even modify failed. Error: ", err, " - ", ErrorDescription(err));
   }
}

//+------------------------------------------------------------------+
//| Trail stop loss after 1R profit                                   |
//| Bug 2 fix: uses original SL distance, not current (which may be   |
//| break-even and thus ~1 pip)                                       |
//+------------------------------------------------------------------+
void HandleTrailingStop(int ticket, int orderType, double openPrice, double currentSL, double origSLDist)
{
   double trailDistance;

   if(UseATRTrailing)
   {
      double atr = iATR(Symbol(), PERIOD_M5, ATRPeriod, 0);
      trailDistance = atr * ATRTrailingMultiplier;
   }
   else
   {
      // Bug 2 fix: use ORIGINAL SL distance, not current (which is BE after break-even)
      if(origSLDist > 0)
         trailDistance = origSLDist;
      else
         trailDistance = MathAbs(openPrice - currentSL);  // Fallback
   }

   if(trailDistance <= 0)
      return;

   double newSL;

   if(orderType == OP_BUY)
   {
      newSL = NormalizeDouble(Bid - trailDistance, Digits);
      if(newSL <= currentSL)
         return;
      if(newSL < openPrice)
         return;
   }
   else
   {
      newSL = NormalizeDouble(Ask + trailDistance, Digits);
      if(currentSL > 0 && newSL >= currentSL)
         return;
      if(newSL > openPrice)
         return;
   }

   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;

   bool result = OrderModify(ticket, openPrice, newSL, OrderTakeProfit(), 0, clrAqua);

   if(result)
   {
      Print("Trailing stop updated. Ticket: ", ticket, " New SL: ", newSL);
   }
   else
   {
      int err = GetLastError();
      if(err != 1)
         Print("Trailing stop modify failed. Error: ", err, " - ", ErrorDescription(err));
   }
}

//+------------------------------------------------------------------+
//| On-chart display — shows live EA status                           |
//+------------------------------------------------------------------+
void UpdateChartDisplay()
{
   double spreadPips = (Ask - Bid) / g_pipSize;
   double adr = GetADR();
   double slope = GetEMA200Slope();
   double rsi = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, 0);
   bool inSession = IsWithinSession();
   int tradesToday = CountTradesToday();

   string display = "";
   display += "=== LTS Edge v1.1 ===\n";
   display += "Status: " + (inSession ? "SESSION ACTIVE" : "Outside session") + "\n";
   display += "Spread: " + DoubleToString(spreadPips, 1) + " pips" + (spreadPips <= MaxSpreadPips ? " OK" : " HIGH") + "\n";
   display += "RSI(14): " + DoubleToString(rsi, 1) + "\n";
   display += "ADR: " + DoubleToString(adr, 0) + " pips\n";
   display += "EMA Slope: " + DoubleToString(MathAbs(slope)/Point, 1) + " pts (min " + DoubleToString(MinEMASlopePoints, 1) + ")\n";
   display += "Trades today: " + IntegerToString(tradesToday) + "/" + IntegerToString(MaxTradesPerDay) + "\n";
   display += "Session bars: " + IntegerToString(g_sessionBarsChecked) + " | Filters OK: " + IntegerToString(g_sessionFiltersPassed) + " | Signals: " + IntegerToString(g_sessionSignalsFound) + "\n";
   display += "BST: " + (UKSummerTime ? "ON" : "OFF") + " | Offset: UTC+" + IntegerToString(BrokerUTCOffset) + "\n";

   Comment(display);
}

//+------------------------------------------------------------------+
