//+------------------------------------------------------------------+
//|                                              LTS_Edge_v4_5.mq4   |
//|                  Volatility Squeeze Breakout + Quality Filters   |
//|                  v4.5 — Path 1: Quality Over Quantity            |
//|                                                                  |
//|  Adds to v4:                                                     |
//|   1. Multi-timeframe squeeze (H1 + H4 both required)             |
//|   2. DXY confirmation (gold must align with inverse DXY)         |
//|   3. Prime session filter (first 2 hrs of London only, optional) |
//|   4. Volatility regime filter (ATR in 40-70th percentile)        |
//|                                                                  |
//|  All new filters have toggles — default config = "full Path 1"   |
//|  Set all to false = behaves identically to v4 (sanity baseline)  |
//+------------------------------------------------------------------+
#property copyright "LTS Edge v4.5 + FTMO Mode"
#property link      ""
#property version   "4.55"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// --- Risk Management ---
input double   RiskPercent            = 1.5;     // Risk per trade (% of balance)
input double   RiskRewardRatio        = 2.0;     // TP as multiple of SL distance
input double   MaxDailyDrawdownPct    = 3.0;     // Max daily drawdown % — stop trading

// --- Squeeze Detection (H1 primary) ---
input int      BBPeriod               = 20;      // Bollinger Bands period
input double   BBDeviation            = 2.0;     // Bollinger Bands std dev multiplier
input int      KCPeriod               = 20;      // Keltner Channel EMA period
input int      KCATRPeriod            = 10;      // Keltner Channel ATR period
input double   KCMultiplier           = 1.5;     // Keltner Channel ATR multiplier
input int      MinSqueezeBars         = 3;       // Min consecutive bars in squeeze

// --- Signal Timeframe ---
input int      SignalTimeframe        = PERIOD_H1; // Primary timeframe for squeeze detection

// --- PATH 1 FILTER: Multi-Timeframe Squeeze ---
input bool     UseMultiTFSqueeze      = true;    // Require squeeze on BOTH primary AND higher TF
input int      HigherTFForSqueeze     = PERIOD_H4; // Higher timeframe for confirmation

// --- PATH 1 FILTER: DXY Confirmation ---
input bool     UseDXYFilter           = false;   // Only trade gold when DXY confirms direction
input string   DXYSymbol              = "USDX";  // Broker's DXY symbol (try USDX, DXY, DX, or EURUSD)
input bool     DXYInverseFallback     = true;    // If DXY symbol missing, use EURUSD inverse
input int      DXYEMAPeriod           = 20;      // EMA period for DXY trend detection
input int      DXYTimeframe           = PERIOD_H1; // DXY timeframe

// --- PATH 1 FILTER: Volatility Regime ---
input bool     UseVolatilityRegime    = true;    // ATR must be in chosen percentile range
input int      VolRegimeLookback      = 100;     // Bars to calculate ATR percentile from
input double   VolRegimeMinPct        = 0.30;    // Min percentile (0.30 = 30th, skip if too calm)
input double   VolRegimeMaxPct        = 0.80;    // Max percentile (0.80 = 80th, skip if too chaotic)

// --- PATH 1 FILTER: Prime Session Only ---
input bool     UsePrimeSessionOnly    = false;   // Only trade first 2 hrs of London (8-10 UK)
input int      PrimeSessionEndHour    = 10;      // End hour for prime session (UK time)

// --- Stop Loss ---
input int      ATRPeriodSL            = 14;      // ATR period for stop loss
input double   ATRMultiplierSL        = 1.5;     // ATR multiplier for stop loss

// --- Session Filter (UK time) ---
input int      SessionStartHour       = 8;       // Only enter trades after this hour (UK)
input int      SessionEndHour         = 16;      // Stop entering trades after this hour (UK)
input bool     CloseAtSessionEnd      = false;   // Close trades at session end

// --- Trend Filter ---
input bool     UseTrendFilter         = true;    // Only trade in D1 EMA trend direction
input int      TrendEMAPeriod         = 50;      // EMA period for trend filter
input int      TrendFilterTF          = PERIOD_D1; // Timeframe for trend EMA

// --- Basic Filters ---
input double   MaxSpreadPips          = 2.0;     // Max allowed spread (pips)

// --- Time Settings ---
input int      BrokerUTCOffset        = 3;       // Broker server UTC offset
input bool     UKSummerTime           = false;   // UK is on BST (UTC+1)

// --- Day Filter ---
input bool     TradeMonday            = true;    // Allow trades on Monday
input bool     TradeTuesday           = true;    // Allow trades on Tuesday
input bool     TradeWednesday         = true;    // Allow trades on Wednesday
input bool     TradeThursday          = true;    // Allow trades on Thursday
input bool     TradeFriday            = true;    // Allow trades on Friday

// --- AI Filter ---
input bool     UseAIFilter            = false;   // Read AI signal file before trading
input string   AISignalFile           = "ai_signal.txt"; // Path to AI signal file

// --- FTMO Prop Firm Compliance Mode ---
// When FTMOMode=true, EA enforces strict prop firm rules:
//   - Uses FTMORiskPercent instead of RiskPercent
//   - Halts trading if daily loss limit hit (until next day)
//   - Halts trading PERMANENTLY if max overall loss hit
//   - Stops trading once profit target reached (Phase 1 = 10%, Phase 2 = 5%)
//   - Halts trading after N consecutive losses
//   - Halts trading around major news (NFP, CPI, FOMC)
input bool     FTMOMode                 = false;  // Enable FTMO prop firm rules
input int      FTMOPhase                = 1;      // 1=Challenge (10% target), 2=Verification (5%), 3=Funded (no target)
input double   FTMORiskPercent          = 0.75;   // Risk % per trade in FTMO mode (overrides RiskPercent)
input double   FTMOMaxDailyLossPct      = 4.0;    // Max daily loss % (FTMO is 5%, leave 1% buffer)
input double   FTMOMaxOverallLossPct    = 8.0;    // Max overall loss % (FTMO is 10%, leave 2% buffer)
input double   FTMOPhase1TargetPct      = 10.0;   // Phase 1 (Challenge) profit target %
input double   FTMOPhase2TargetPct      = 5.0;    // Phase 2 (Verification) profit target %
input int      FTMOMaxConsecutiveLosses = 3;      // Halt for day after N consecutive losses
input bool     FTMONewsFilter           = true;   // Halt trading around major news (NFP, CPI, FOMC)

// --- Diagnostics ---
input bool     EnableDiagnostics      = true;    // Log detailed results per bar

// --- System ---
input int      MagicNumber            = 77777;   // EA magic number (different from v4's 66666)
input int      Slippage               = 5;       // Max slippage (points)

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
datetime g_lastBarTime     = 0;
double   g_pipSize         = 0;
int      g_pipDigits       = 0;
string   g_commentTag      = "LTSv4.5";
double   g_startBalance    = 0;
int      g_squeezeCount    = 0;     // Consecutive bars in squeeze
string   g_activeDXYSymbol = "";    // Resolved DXY symbol (or "EURUSD_INV" if using fallback)

// Filter counters for session summary
int      g_filterRejectMTF     = 0;
int      g_filterRejectDXY     = 0;
int      g_filterRejectVol     = 0;
int      g_filterRejectTrend   = 0;
int      g_filterRejectSpread  = 0;
int      g_filterPassed        = 0;

// FTMO Mode state tracking
double   g_ftmoStartOfDayEquity   = 0;       // Equity at start of trading day
datetime g_ftmoDayStart           = 0;       // Start of current trading day (server time)
int      g_ftmoConsecutiveLosses  = 0;       // Consecutive losing trades today
datetime g_ftmoLastTradeCloseTime = 0;       // Last closed trade timestamp (for loss tracking)
int      g_ftmoLastTradeTicket    = 0;       // Last processed closed ticket
bool     g_ftmoHaltedToday        = false;   // Daily halt flag (resets next day)
bool     g_ftmoHaltedPermanent    = false;   // Permanent halt (max DD breached — never trade again)
bool     g_ftmoTargetHit          = false;   // Profit target reached (stop trading until reset)

// FTMO halt counters for diagnostics
int      g_ftmoHaltsDaily         = 0;       // # times daily limit triggered
int      g_ftmoHaltsConsecutive   = 0;       // # times consecutive loss limit triggered
int      g_ftmoHaltsNews          = 0;       // # times news filter blocked
int      g_ftmoHaltsTarget        = 0;       // # times profit target stop triggered

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   // Detect pip size based on symbol digits
   if(Digits == 5 || Digits == 3)
   {
      g_pipSize   = Point * 10;
      g_pipDigits = 1;
   }
   else if(Digits <= 2)
   {
      g_pipSize   = 1.0;
      g_pipDigits = 0;
   }
   else
   {
      g_pipSize   = Point;
      g_pipDigits = 0;
   }

   g_startBalance = AccountBalance();

   // Resolve DXY symbol if filter is enabled
   if(UseDXYFilter)
      ResolveDXYSymbol();

   // Initialize FTMO state
   if(FTMOMode)
   {
      g_ftmoStartOfDayEquity   = AccountEquity();
      g_ftmoDayStart           = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
      g_ftmoConsecutiveLosses  = 0;
      g_ftmoHaltedToday        = false;
      g_ftmoHaltedPermanent    = false;
      g_ftmoTargetHit          = false;
   }

   Print("=============================================");
   Print("LTS Edge v4.5 (Squeeze + Quality Filters) initialized on ", Symbol());
   Print("Pip size: ", g_pipSize, " Digits: ", Digits, " Point: ", Point);
   Print("Squeeze: BB(", BBPeriod, ", ", BBDeviation, ") vs KC(", KCPeriod, ", ATR ", KCATRPeriod, " x", KCMultiplier, ")");
   Print("Min squeeze bars: ", MinSqueezeBars, " | Signal TF: ", SignalTimeframe, " min");
   Print("SL: ATR(", ATRPeriodSL, ") x", ATRMultiplierSL, " | RR: ", RiskRewardRatio);
   Print("Session: ", SessionStartHour, ":00-",
         (UsePrimeSessionOnly ? PrimeSessionEndHour : SessionEndHour), ":00 UK",
         (UKSummerTime ? " (BST)" : " (GMT)"),
         (UsePrimeSessionOnly ? " [PRIME ONLY]" : ""));
   Print("--- Path 1 Quality Filters ---");
   Print("MTF Squeeze: ", (UseMultiTFSqueeze ? "ON (H1+" + IntegerToString(HigherTFForSqueeze) + "m)" : "OFF"));
   Print("DXY Filter: ", (UseDXYFilter ? "ON (symbol: " + g_activeDXYSymbol + ")" : "OFF"));
   Print("Vol Regime: ", (UseVolatilityRegime ? "ON (" + DoubleToString(VolRegimeMinPct*100,0) + "-" + DoubleToString(VolRegimeMaxPct*100,0) + "%ile)" : "OFF"));
   Print("Prime Session: ", (UsePrimeSessionOnly ? "ON (8-" + IntegerToString(PrimeSessionEndHour) + " UK)" : "OFF"));
   Print("Trend Filter: ", (UseTrendFilter ? "ON (D1 EMA" + IntegerToString(TrendEMAPeriod) + ")" : "OFF"));

   // FTMO Mode banner
   if(FTMOMode)
   {
      Print("--- FTMO PROP FIRM MODE: ENABLED ---");
      string phaseLabel = "";
      if(FTMOPhase == 1)      phaseLabel = "Challenge (target " + DoubleToString(FTMOPhase1TargetPct, 1) + "%)";
      else if(FTMOPhase == 2) phaseLabel = "Verification (target " + DoubleToString(FTMOPhase2TargetPct, 1) + "%)";
      else                    phaseLabel = "Funded (no profit target)";
      Print("Phase: ", FTMOPhase, " — ", phaseLabel);
      Print("Risk per trade: ", FTMORiskPercent, "% (override RiskPercent)");
      Print("Max daily loss: ", FTMOMaxDailyLossPct, "% (FTMO limit 5%)");
      Print("Max overall loss: ", FTMOMaxOverallLossPct, "% (FTMO limit 10%)");
      Print("Max consecutive losses before halt: ", FTMOMaxConsecutiveLosses);
      Print("News filter: ", (FTMONewsFilter ? "ON (NFP/CPI/FOMC windows)" : "OFF"));
      Print("Start equity: ", DoubleToString(g_ftmoStartOfDayEquity, 2));
   }
   else
   {
      Print("FTMO Mode: OFF (using standard RiskPercent=", RiskPercent, "%)");
   }
   Print("=============================================");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Resolve DXY symbol — try various broker naming conventions        |
//+------------------------------------------------------------------+
void ResolveDXYSymbol()
{
   // Use iClose() instead of MarketInfo(MODE_BID) — MarketInfo returns 0 in
   // Strategy Tester for non-chart symbols, even if historical data exists.
   // iClose() reads from history and works in both live and tester modes.

   // First try the user-configured symbol
   if(StringLen(DXYSymbol) > 0)
   {
      double testPrice = iClose(DXYSymbol, DXYTimeframe, 1);
      if(testPrice > 0)
      {
         g_activeDXYSymbol = DXYSymbol;
         Print("DXY filter: using symbol '", DXYSymbol, "' (price=", testPrice, ")");
         return;
      }
      Print("DXY filter: symbol '", DXYSymbol, "' not available (no history)");
   }

   // Try common alternatives
   string candidates[] = {"USDX", "DXY", "DX", "USDollarIndex", "DXY.USD"};
   for(int i = 0; i < ArraySize(candidates); i++)
   {
      double testPrice = iClose(candidates[i], DXYTimeframe, 1);
      if(testPrice > 0)
      {
         g_activeDXYSymbol = candidates[i];
         Print("DXY filter: auto-resolved to '", candidates[i], "' (price=", testPrice, ")");
         return;
      }
   }

   // Fallback to EURUSD inverse if allowed
   if(DXYInverseFallback)
   {
      double eurPrice = iClose("EURUSD", DXYTimeframe, 1);
      if(eurPrice > 0)
      {
         g_activeDXYSymbol = "EURUSD_INV";
         Print("DXY filter: falling back to EURUSD inverse (EUR price=", eurPrice, ")");
         return;
      }
      Print("DXY filter: EURUSD also unavailable for fallback");
   }

   g_activeDXYSymbol = "";
   Print("WARNING: DXY filter enabled but no DXY symbol available — filter will default to PASS");
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
   Print("LTS Edge v4.5 removed. Reason: ", reason);
   Print("--- Filter Rejection Stats ---");
   Print("MTF rejects: ", g_filterRejectMTF);
   Print("DXY rejects: ", g_filterRejectDXY);
   Print("Vol regime rejects: ", g_filterRejectVol);
   Print("Trend rejects: ", g_filterRejectTrend);
   Print("Spread rejects: ", g_filterRejectSpread);
   Print("Filter passed (trades taken): ", g_filterPassed);

   if(FTMOMode)
   {
      Print("--- FTMO Halt Stats ---");
      Print("Daily loss halts: ", g_ftmoHaltsDaily);
      Print("Consecutive loss halts: ", g_ftmoHaltsConsecutive);
      Print("News filter halts: ", g_ftmoHaltsNews);
      Print("Profit target halts: ", g_ftmoHaltsTarget);
      Print("Permanent halt (max DD): ", (g_ftmoHaltedPermanent ? "YES — account would be terminated" : "no"));
      Print("Profit target hit at end: ", (g_ftmoTargetHit ? "YES — would have passed phase" : "no"));
      double finalReturn = (AccountEquity() - g_startBalance) / g_startBalance * 100.0;
      Print("Final return: ", DoubleToString(finalReturn, 2), "%");
   }
}

//+------------------------------------------------------------------+
//| Main tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   if(CloseAtSessionEnd)
      CheckSessionClose();

   // FTMO mode: update daily tracking, check permanent halt
   if(FTMOMode)
   {
      UpdateFTMODailyTracking();
      UpdateFTMOConsecutiveLosses();

      if(g_ftmoHaltedPermanent)
      {
         UpdateChartDisplay();
         return;  // Account "blown" — never trade
      }

      if(CheckFTMOMaxLoss())
      {
         g_ftmoHaltedPermanent = true;
         Print("FTMO HALT (PERMANENT): Max overall loss limit hit — account would be terminated");
         return;
      }

      if(CheckFTMOTargetHit())
      {
         if(!g_ftmoTargetHit)  // Only increment once on first hit
         {
            g_ftmoHaltsTarget++;
            double currentReturn = (AccountEquity() - g_startBalance) / g_startBalance * 100.0;
            Print("FTMO TARGET HIT: ", DoubleToString(currentReturn, 2), "% return — closing all open positions to lock in profit");

            // Close all open positions immediately to LOCK IN the target
            // (a real smart FTMO trader would do this — don't let floating profits slip away)
            for(int i = OrdersTotal() - 1; i >= 0; i--)
            {
               if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
               {
                  if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
                  {
                     if(OrderType() == OP_BUY)
                     {
                        bool ok = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrYellow);
                        if(ok) Print("FTMO TARGET LOCK-IN: BUY #", OrderTicket(), " closed at ", Bid);
                     }
                     else if(OrderType() == OP_SELL)
                     {
                        bool ok = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrYellow);
                        if(ok) Print("FTMO TARGET LOCK-IN: SELL #", OrderTicket(), " closed at ", Ask);
                     }
                  }
               }
            }
         }
         g_ftmoTargetHit = true;
         UpdateChartDisplay();
         return;  // Profit target reached — stop trading
      }
   }

   UpdateChartDisplay();

   if(!IsNewSignalBar())
      return;

   UpdateSqueezeState();

   // FTMO mode: extra entry checks
   if(FTMOMode)
   {
      if(g_ftmoHaltedToday)
         return;  // Already halted for today

      if(CheckFTMODailyLoss())
      {
         g_ftmoHaltedToday = true;
         g_ftmoHaltsDaily++;
         if(EnableDiagnostics)
            Print("FTMO HALT (DAILY): Daily loss limit reached — no more trades today");
         return;
      }

      if(g_ftmoConsecutiveLosses >= FTMOMaxConsecutiveLosses)
      {
         g_ftmoHaltedToday = true;
         g_ftmoHaltsConsecutive++;
         if(EnableDiagnostics)
            Print("FTMO HALT: ", g_ftmoConsecutiveLosses, " consecutive losses — halted for day");
         return;
      }

      if(FTMONewsFilter && IsNearMajorNews())
      {
         g_ftmoHaltsNews++;
         if(EnableDiagnostics)
            Print("FTMO HALT: Near major news event — skipping");
         return;
      }
   }

   if(IsWithinSession() && IsTradingDay() && !CheckDailyDrawdown() && !HasOpenTrade())
   {
      CheckSqueezeEntry();
   }
}

//+------------------------------------------------------------------+
//| FTMO: Update daily tracking (equity at start of day, halts)       |
//+------------------------------------------------------------------+
void UpdateFTMODailyTracking()
{
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_ftmoDayStart)
   {
      g_ftmoDayStart           = today;
      g_ftmoStartOfDayEquity   = AccountEquity();
      g_ftmoConsecutiveLosses  = 0;     // Reset daily
      g_ftmoHaltedToday        = false; // Reset daily
      // Note: g_ftmoHaltedPermanent and g_ftmoTargetHit do NOT reset
   }
}

//+------------------------------------------------------------------+
//| FTMO: Check daily loss vs start-of-day equity                     |
//+------------------------------------------------------------------+
bool CheckFTMODailyLoss()
{
   double currentEquity = AccountEquity();
   double dailyLoss     = g_ftmoStartOfDayEquity - currentEquity;
   double maxDailyLoss  = g_ftmoStartOfDayEquity * FTMOMaxDailyLossPct / 100.0;
   return (dailyLoss >= maxDailyLoss);
}

//+------------------------------------------------------------------+
//| FTMO: Check overall max loss (from start balance)                 |
//+------------------------------------------------------------------+
bool CheckFTMOMaxLoss()
{
   double currentEquity = AccountEquity();
   double overallLoss   = g_startBalance - currentEquity;
   double maxOverall    = g_startBalance * FTMOMaxOverallLossPct / 100.0;
   return (overallLoss >= maxOverall);
}

//+------------------------------------------------------------------+
//| FTMO: Check if profit target hit (Challenge or Verification)      |
//+------------------------------------------------------------------+
bool CheckFTMOTargetHit()
{
   if(FTMOPhase >= 3) return false;  // Funded mode: no profit target

   double targetPct = (FTMOPhase == 1) ? FTMOPhase1TargetPct : FTMOPhase2TargetPct;
   double targetEquity = g_startBalance * (1.0 + targetPct / 100.0);
   return (AccountEquity() >= targetEquity);
}

//+------------------------------------------------------------------+
//| FTMO: Update consecutive loss counter from order history          |
//+------------------------------------------------------------------+
void UpdateFTMOConsecutiveLosses()
{
   datetime todayStart = g_ftmoDayStart;

   // Find newest closed order for this EA today
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if(OrderCloseTime() < todayStart) break;  // Older than today, stop

      // New closed order we haven't processed yet?
      if(OrderTicket() != g_ftmoLastTradeTicket && OrderCloseTime() > g_ftmoLastTradeCloseTime)
      {
         double pl = OrderProfit() + OrderSwap() + OrderCommission();
         if(pl < 0)
            g_ftmoConsecutiveLosses++;
         else
            g_ftmoConsecutiveLosses = 0;  // Win resets streak

         g_ftmoLastTradeTicket    = OrderTicket();
         g_ftmoLastTradeCloseTime = OrderCloseTime();
         break;  // Only process newest one per call
      }
   }
}

//+------------------------------------------------------------------+
//| FTMO: Detect major news windows (UTC-based recurring schedule)    |
//+------------------------------------------------------------------+
bool IsNearMajorNews()
{
   datetime t       = TimeCurrent();
   int hour         = TimeHour(t);
   int minute       = TimeMinute(t);
   int day          = TimeDay(t);
   int dow          = DayOfWeek();
   int month        = TimeMonth(t);

   // Convert server hour to UTC
   int utcHour = hour - BrokerUTCOffset;
   if(utcHour < 0) utcHour += 24;
   if(utcHour >= 24) utcHour -= 24;

   // NFP: First Friday of month, 13:30 UTC ±30min (so 13:00-14:00 UTC)
   if(dow == 5 && day <= 7 && utcHour == 13)
      return true;

   // CPI: 12th-14th of month, 13:30 UTC ±30min
   if(day >= 12 && day <= 14 && utcHour == 13)
      return true;

   // FOMC: ~3rd Wednesday of Jan/Mar/May/Jun/Jul/Sep/Nov, 19:00 UTC ±30min
   bool fomcMonth = (month == 1 || month == 3 || month == 5 || month == 6 ||
                     month == 7 || month == 9 || month == 11);
   if(fomcMonth && dow == 3 && day >= 15 && day <= 21 && utcHour == 18)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| FTMO: Get effective risk % for lot calc (override or default)     |
//+------------------------------------------------------------------+
double GetEffectiveRiskPercent()
{
   return FTMOMode ? FTMORiskPercent : RiskPercent;
}

//+------------------------------------------------------------------+
//| New bar detection on signal timeframe                             |
//+------------------------------------------------------------------+
bool IsNewSignalBar()
{
   datetime currentBarTime = iTime(Symbol(), SignalTimeframe, 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      return true;
   }
   return false;
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
//| Check if within trading session                                   |
//+------------------------------------------------------------------+
bool IsWithinSession()
{
   int hour = TimeHour(TimeCurrent());
   int effectiveEnd = UsePrimeSessionOnly ? PrimeSessionEndHour : SessionEndHour;

   int serverStart = UKToServerHour(SessionStartHour);
   int serverEnd   = UKToServerHour(effectiveEnd);

   if(serverStart < serverEnd)
      return (hour >= serverStart && hour < serverEnd);
   else
      return (hour >= serverStart || hour < serverEnd);
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
            floatingPL += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }

   double totalPL = closedPL + floatingPL;
   double maxLoss = g_startBalance * MaxDailyDrawdownPct / 100.0;

   if(totalPL < 0 && MathAbs(totalPL) >= maxLoss)
   {
      if(EnableDiagnostics)
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
//| Update squeeze state — track consecutive squeeze bars             |
//+------------------------------------------------------------------+
void UpdateSqueezeState()
{
   bool isInSqueeze = CheckSqueeze(Symbol(), SignalTimeframe, 1);

   if(isInSqueeze)
      g_squeezeCount++;
}

//+------------------------------------------------------------------+
//| Check if a specific bar/TF is in squeeze (BB inside KC)           |
//+------------------------------------------------------------------+
bool CheckSqueeze(string symbol, int tf, int shift)
{
   double bbUpper = iBands(symbol, tf, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_UPPER, shift);
   double bbLower = iBands(symbol, tf, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_LOWER, shift);

   double kcMiddle = iMA(symbol, tf, KCPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);
   double kcATR    = iATR(symbol, tf, KCATRPeriod, shift);
   double kcUpper  = kcMiddle + KCMultiplier * kcATR;
   double kcLower  = kcMiddle - KCMultiplier * kcATR;

   return (bbUpper < kcUpper && bbLower > kcLower);
}

//+------------------------------------------------------------------+
//| PATH 1 FILTER: Check higher timeframe squeeze                     |
//+------------------------------------------------------------------+
bool CheckHigherTFSqueeze()
{
   if(!UseMultiTFSqueeze)
      return true;

   // Check if the higher TF is currently in squeeze OR was just in squeeze recently
   // We allow a small window — HTF squeeze on bar 0 or 1 counts
   bool htfSqueeze0 = CheckSqueeze(Symbol(), HigherTFForSqueeze, 0);
   bool htfSqueeze1 = CheckSqueeze(Symbol(), HigherTFForSqueeze, 1);

   return (htfSqueeze0 || htfSqueeze1);
}

//+------------------------------------------------------------------+
//| PATH 1 FILTER: Check DXY alignment (gold usually inverse to DXY)  |
//+------------------------------------------------------------------+
bool CheckDXYAlignment(bool wantBuy)
{
   if(!UseDXYFilter)
      return true;

   if(StringLen(g_activeDXYSymbol) == 0)
      return true;  // No DXY available — pass by default

   // Fetch DXY trend direction
   double dxyPrice = 0, dxyEMA = 0;
   bool dxyFalling = false, dxyRising = false;

   if(g_activeDXYSymbol == "EURUSD_INV")
   {
      // Use EURUSD inverse — when EURUSD falls, DXY rises
      double eurPrice = iClose("EURUSD", DXYTimeframe, 1);
      double eurEMA   = iMA("EURUSD", DXYTimeframe, DXYEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
      if(eurPrice <= 0 || eurEMA <= 0)
         return true;  // Data not available
      dxyFalling = (eurPrice > eurEMA);  // EUR up = DXY down
      dxyRising  = (eurPrice < eurEMA);  // EUR down = DXY up
   }
   else
   {
      dxyPrice = iClose(g_activeDXYSymbol, DXYTimeframe, 1);
      dxyEMA   = iMA(g_activeDXYSymbol, DXYTimeframe, DXYEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
      if(dxyPrice <= 0 || dxyEMA <= 0)
         return true;  // Data not available
      dxyFalling = (dxyPrice < dxyEMA);
      dxyRising  = (dxyPrice > dxyEMA);
   }

   // Gold inverse to DXY:
   //   Buy gold when DXY falling (dollar weakening)
   //   Sell gold when DXY rising (dollar strengthening)
   if(wantBuy && dxyFalling) return true;
   if(!wantBuy && dxyRising) return true;

   return false;
}

//+------------------------------------------------------------------+
//| PATH 1 FILTER: Check volatility regime (ATR percentile)           |
//+------------------------------------------------------------------+
bool CheckVolatilityRegime()
{
   if(!UseVolatilityRegime)
      return true;

   // Current ATR
   double currentATR = iATR(Symbol(), SignalTimeframe, ATRPeriodSL, 1);
   if(currentATR <= 0)
      return true;

   // Count how many of the last VolRegimeLookback bars have lower ATR
   int lowerCount = 0;
   int validBars = 0;
   for(int i = 2; i <= VolRegimeLookback + 1; i++)
   {
      double histATR = iATR(Symbol(), SignalTimeframe, ATRPeriodSL, i);
      if(histATR > 0)
      {
         validBars++;
         if(histATR < currentATR)
            lowerCount++;
      }
   }

   if(validBars < 20)
      return true;  // Not enough data — pass by default

   double percentile = (double)lowerCount / (double)validBars;

   bool inRange = (percentile >= VolRegimeMinPct && percentile <= VolRegimeMaxPct);

   if(!inRange && EnableDiagnostics)
   {
      Print("Vol regime reject: ATR=", DoubleToString(currentATR, Digits),
            " percentile=", DoubleToString(percentile*100, 1), "%",
            " (need ", DoubleToString(VolRegimeMinPct*100, 0), "-",
            DoubleToString(VolRegimeMaxPct*100, 0), "%)");
   }

   return inRange;
}

//+------------------------------------------------------------------+
//| Check for squeeze release and enter trade                         |
//+------------------------------------------------------------------+
void CheckSqueezeEntry()
{
   bool currentSqueeze = CheckSqueeze(Symbol(), SignalTimeframe, 1);

   // If still in squeeze, no entry
   if(currentSqueeze)
      return;

   // Check minimum consecutive squeeze bars
   if(g_squeezeCount < MinSqueezeBars)
   {
      if(EnableDiagnostics && g_squeezeCount > 0)
         Print("Squeeze released but only ", g_squeezeCount, " bars (need ", MinSqueezeBars, ")");
      g_squeezeCount = 0;
      return;
   }

   // PATH 1 FILTER 1: Multi-timeframe squeeze
   if(!CheckHigherTFSqueeze())
   {
      if(EnableDiagnostics)
         Print("MTF squeeze filter: rejected — no squeeze on ", HigherTFForSqueeze, "min TF");
      g_filterRejectMTF++;
      g_squeezeCount = 0;
      return;
   }

   // PATH 1 FILTER 2: Volatility regime (check before direction for speed)
   if(!CheckVolatilityRegime())
   {
      g_filterRejectVol++;
      g_squeezeCount = 0;
      return;
   }

   // AI FILTER — check if conditions are safe
   if(UseAIFilter)
   {
      string aiSignal = ReadAISignal();
      if(StringFind(aiSignal, "SKIP") == 0)
      {
         string reason = "";
         int pipePos = StringFind(aiSignal, "|");
         if(pipePos > 0)
            reason = StringSubstr(aiSignal, pipePos + 1);

         if(EnableDiagnostics)
            Print("AI FILTER: SKIP — ", reason);
         g_squeezeCount = 0;
         return;
      }
      else if(EnableDiagnostics)
         Print("AI FILTER: TRADE — conditions clear");
   }

   // Determine direction from squeeze release
   double close1 = iClose(Symbol(), SignalTimeframe, 1);
   double ema20  = iMA(Symbol(), SignalTimeframe, BBPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);

   bool goBuy  = (close1 > ema20);
   bool goSell = (close1 < ema20);

   if(!goBuy && !goSell)
   {
      g_squeezeCount = 0;
      return;
   }

   // Trend filter — only trade in direction of D1 EMA
   if(UseTrendFilter)
   {
      double trendEMA = iMA(Symbol(), TrendFilterTF, TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
      double price = (Ask + Bid) / 2.0;
      bool trendBullish = (price > trendEMA);

      if(trendBullish && goSell)
      {
         if(EnableDiagnostics)
            Print("Trend filter: SELL blocked — D1 trend BULLISH (price > EMA ", DoubleToString(trendEMA, Digits), ")");
         g_filterRejectTrend++;
         g_squeezeCount = 0;
         return;
      }
      if(!trendBullish && goBuy)
      {
         if(EnableDiagnostics)
            Print("Trend filter: BUY blocked — D1 trend BEARISH (price < EMA ", DoubleToString(trendEMA, Digits), ")");
         g_filterRejectTrend++;
         g_squeezeCount = 0;
         return;
      }
   }

   // PATH 1 FILTER 3: DXY alignment (direction known at this point)
   if(!CheckDXYAlignment(goBuy))
   {
      if(EnableDiagnostics)
         Print("DXY filter: ", (goBuy ? "BUY" : "SELL"), " blocked — DXY not confirming");
      g_filterRejectDXY++;
      g_squeezeCount = 0;
      return;
   }

   // Spread check
   double spreadPips = (Ask - Bid) / g_pipSize;
   if(spreadPips > MaxSpreadPips)
   {
      if(EnableDiagnostics)
         Print("Spread too high: ", DoubleToString(spreadPips, 1), " > ", MaxSpreadPips);
      g_filterRejectSpread++;
      g_squeezeCount = 0;
      return;
   }

   // ATR for stop loss
   double atr = iATR(Symbol(), SignalTimeframe, ATRPeriodSL, 1);
   double slDistance = atr * ATRMultiplierSL;
   double slDistancePips = slDistance / g_pipSize;

   if(slDistancePips <= 0)
   {
      Print("Invalid SL distance. ATR=", atr);
      g_squeezeCount = 0;
      return;
   }

   if(EnableDiagnostics)
   {
      Print("=== ALL FILTERS PASSED === Squeeze bars: ", g_squeezeCount,
            " | Direction: ", (goBuy ? "BUY" : "SELL"),
            " | Close: ", DoubleToString(close1, Digits),
            " | EMA20: ", DoubleToString(ema20, Digits),
            " | ATR: ", DoubleToString(atr, Digits),
            " | SL pips: ", DoubleToString(slDistancePips, 1));
   }

   double lots = CalculateLotSize(slDistancePips);

   RefreshRates();

   if(goBuy)
   {
      double entry = Ask;
      double sl    = NormalizeDouble(entry - slDistance, Digits);
      double tp    = NormalizeDouble(entry + slDistance * RiskRewardRatio, Digits);

      int ticket = OrderSend(Symbol(), OP_BUY, lots, entry, Slippage, sl, tp,
                             g_commentTag + " SQZ BUY", MagicNumber, 0, clrGreen);

      if(ticket < 0)
      {
         int err = GetLastError();
         Print("BUY failed. Error: ", err, " - ", ErrorDescription(err),
               " Entry: ", entry, " SL: ", sl, " TP: ", tp, " Lots: ", lots);
      }
      else
      {
         g_filterPassed++;
         Print("BUY opened. Ticket: ", ticket,
               " Entry: ", DoubleToString(entry, Digits),
               " SL: ", DoubleToString(sl, Digits),
               " TP: ", DoubleToString(tp, Digits),
               " Lots: ", DoubleToString(lots, 2));
      }
   }
   else if(goSell)
   {
      double entry = Bid;
      double sl    = NormalizeDouble(entry + slDistance, Digits);
      double tp    = NormalizeDouble(entry - slDistance * RiskRewardRatio, Digits);

      int ticket = OrderSend(Symbol(), OP_SELL, lots, entry, Slippage, sl, tp,
                             g_commentTag + " SQZ SELL", MagicNumber, 0, clrRed);

      if(ticket < 0)
      {
         int err = GetLastError();
         Print("SELL failed. Error: ", err, " - ", ErrorDescription(err),
               " Entry: ", entry, " SL: ", sl, " TP: ", tp, " Lots: ", lots);
      }
      else
      {
         g_filterPassed++;
         Print("SELL opened. Ticket: ", ticket,
               " Entry: ", DoubleToString(entry, Digits),
               " SL: ", DoubleToString(sl, Digits),
               " TP: ", DoubleToString(tp, Digits),
               " Lots: ", DoubleToString(lots, 2));
      }
   }

   g_squeezeCount = 0;
}

//+------------------------------------------------------------------+
//| Close open trades at session end                                  |
//+------------------------------------------------------------------+
void CheckSessionClose()
{
   int hour = TimeHour(TimeCurrent());
   int effectiveEnd = UsePrimeSessionOnly ? PrimeSessionEndHour : SessionEndHour;
   int serverCloseHour = UKToServerHour(effectiveEnd);

   if(hour != serverCloseHour)
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
               if(result) Print("Session close: BUY closed at ", Bid);
               else Print("Session close failed. Error: ", GetLastError());
            }
            else if(OrderType() == OP_SELL)
            {
               bool result = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrYellow);
               if(result) Print("Session close: SELL closed at ", Ask);
               else Print("Session close failed. Error: ", GetLastError());
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

   double accountRisk = AccountBalance() * GetEffectiveRiskPercent() / 100.0;
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
            " lots=", DoubleToString(lots, 2));
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
//| Read AI signal file                                               |
//+------------------------------------------------------------------+
string ReadAISignal()
{
   if(!UseAIFilter)
      return "TRADE";

   string filePath = AISignalFile;

   int handle = FileOpen(filePath, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      if(EnableDiagnostics)
         Print("AI signal file not found: ", filePath, " — defaulting to TRADE");
      return "TRADE";
   }

   string content = "";
   if(!FileIsEnding(handle))
      content = FileReadString(handle);

   FileClose(handle);

   if(StringLen(content) == 0)
   {
      if(EnableDiagnostics)
         Print("AI signal file empty — defaulting to TRADE");
      return "TRADE";
   }

   // Check if signal is stale (older than 60 minutes)
   int firstPipe = StringFind(content, "|");
   int secondPipe = -1;
   if(firstPipe > 0)
      secondPipe = StringFind(content, "|", firstPipe + 1);

   if(secondPipe > 0)
   {
      string timestampStr = StringSubstr(content, secondPipe + 1);
      int utcPos = StringFind(timestampStr, " UTC");
      if(utcPos > 0)
         timestampStr = StringSubstr(timestampStr, 0, utcPos);

      datetime signalTime = StringToTime(timestampStr);
      datetime serverTime = TimeCurrent();

      if(serverTime - signalTime > 3600)
      {
         if(EnableDiagnostics)
            Print("AI signal is stale (", TimeToString(signalTime), " vs ", TimeToString(serverTime), ") — defaulting to TRADE");
         return "TRADE";
      }
   }

   return content;
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
      case 6:    return "No connection to trade server";
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
      case 145:  return "Modification denied - too close to market";
      case 146:  return "Trade context is busy";
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
   bool inSession = IsWithinSession();
   bool inSqueeze = CheckSqueeze(Symbol(), SignalTimeframe, 0);
   bool htfSqueeze = UseMultiTFSqueeze ? CheckSqueeze(Symbol(), HigherTFForSqueeze, 0) : true;

   string display = "";
   display += "=== LTS Edge v4.5 (Squeeze + Quality) ===\n";
   display += "Symbol: " + Symbol() + " | TF: " + IntegerToString(SignalTimeframe) + "min\n";

   if(inSession)
      display += "Status: SESSION ACTIVE\n";
   else
      display += "Status: Outside session\n";

   display += "Spread: " + DoubleToString(spreadPips, 1) + " pips\n";
   display += "H1 Squeeze: " + (inSqueeze ? "YES (" + IntegerToString(g_squeezeCount) + " bars)" : "NO") + "\n";

   if(UseMultiTFSqueeze)
      display += IntegerToString(HigherTFForSqueeze) + "m Squeeze: " + (htfSqueeze ? "YES" : "NO") + "\n";

   // Active filter summary
   display += "--- Active Filters ---\n";
   display += "MTF: " + (UseMultiTFSqueeze ? "ON" : "off");
   display += " | DXY: " + (UseDXYFilter ? "ON" : "off");
   display += " | Vol: " + (UseVolatilityRegime ? "ON" : "off");
   display += " | Trend: " + (UseTrendFilter ? "ON" : "off");
   display += (UsePrimeSessionOnly ? " | PRIME" : "") + "\n";

   // Filter reject stats
   display += "Rejects: MTF=" + IntegerToString(g_filterRejectMTF);
   display += " DXY=" + IntegerToString(g_filterRejectDXY);
   display += " Vol=" + IntegerToString(g_filterRejectVol);
   display += " Trend=" + IntegerToString(g_filterRejectTrend);
   display += " | Taken=" + IntegerToString(g_filterPassed) + "\n";

   // FTMO mode display
   if(FTMOMode)
   {
      double currentReturn = (AccountEquity() - g_startBalance) / g_startBalance * 100.0;
      double dailyLossPct  = (g_ftmoStartOfDayEquity > 0)
         ? (g_ftmoStartOfDayEquity - AccountEquity()) / g_ftmoStartOfDayEquity * 100.0 : 0;
      double targetPct = (FTMOPhase == 1) ? FTMOPhase1TargetPct : FTMOPhase2TargetPct;

      display += "--- FTMO MODE ---\n";
      display += "Phase " + IntegerToString(FTMOPhase) + " | Return: " + DoubleToString(currentReturn, 2) + "%";
      if(FTMOPhase < 3)
         display += " / " + DoubleToString(targetPct, 1) + "% target";
      display += "\n";
      display += "Daily loss: " + DoubleToString(dailyLossPct, 2) + "% / " + DoubleToString(FTMOMaxDailyLossPct, 1) + "%\n";
      display += "Consec losses: " + IntegerToString(g_ftmoConsecutiveLosses) + " / " + IntegerToString(FTMOMaxConsecutiveLosses) + "\n";

      if(g_ftmoHaltedPermanent)
         display += ">>> HALTED PERMANENTLY (max DD breached) <<<\n";
      else if(g_ftmoTargetHit)
         display += ">>> TARGET HIT — phase passed <<<\n";
      else if(g_ftmoHaltedToday)
         display += ">>> HALTED FOR TODAY <<<\n";
   }

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
   display += "Open trades: " + IntegerToString(openCount) + "\n";
   display += "BST: " + (UKSummerTime ? "ON" : "OFF") + " | UTC+" + IntegerToString(BrokerUTCOffset) + "\n";

   Comment(display);
}

//+------------------------------------------------------------------+
