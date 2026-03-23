//+------------------------------------------------------------------+
//|                                                  LTS_Edge_v1.mq4 |
//|                        Trend-Following Pullback EA with Filters   |
//|                        Dual-timeframe: M15 trend + M5 entry       |
//+------------------------------------------------------------------+
#property copyright "LTS Edge v1"
#property link      ""
#property version   "1.00"
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
input double   MinCandleSizePips      = 5.0;     // Min candle size to avoid low-vol entries
input double   MinADRPips             = 40.0;    // Min Average Daily Range (pips)
input double   MaxADRPips             = 200.0;   // Max Average Daily Range (pips)

// --- Session Filter (server time) ---
input int      SessionStartHour       = 8;       // Session start hour
input int      SessionStartMinute     = 0;       // Session start minute
input int      SessionEndHour         = 11;      // Session end hour
input int      SessionEndMinute       = 0;       // Session end minute

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
input bool     RequireStrongCandle    = true;     // Require engulfing or pin bar pattern
input double   MinEMASlopePoints      = 10.0;    // Min 200 EMA slope over 5 bars (points)

// --- Trade Limits ---
input int      MaxTradesPerDay        = 3;       // Max trades per day

// --- System ---
input int      MagicNumber            = 12345;   // EA magic number
input int      Slippage               = 3;       // Max slippage (points)

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
datetime g_lastBarTime = 0;         // Track last processed bar time
double   g_pipSize     = 0;         // Pip size for this symbol
int      g_pipDigits   = 0;         // Number of digits for pip rounding
string   g_commentTag  = "LTSv1";   // Order comment prefix
double   g_startBalance = 0;        // Balance at start of day for DD calc

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

   Print("LTS Edge v1 initialized. Pip size: ", g_pipSize, " Digits: ", Digits);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("LTS Edge v1 removed. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Main tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // Always manage open trades (trailing, BE, partial close)
   ManageOpenTrades();

   // Only check for new entries on a new M5 bar
   if(!IsNewBar())
      return;

   // Reset daily balance tracker at start of new day
   ResetDailyBalance();

   // Skip if we already have an open trade on this symbol
   if(HasOpenTrade())
      return;

   // Run all filters
   if(!PassesAllFilters())
      return;

   // Check for entry signals
   if(CheckBuySignal())
   {
      ExecuteBuy();
   }
   else if(CheckSellSignal())
   {
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
//|                     FILTER FUNCTIONS                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Master filter check — all conditions must pass                    |
//+------------------------------------------------------------------+
bool PassesAllFilters()
{
   // Spread filter
   double spreadPips = (Ask - Bid) / g_pipSize;
   if(spreadPips > MaxSpreadPips)
   {
      return false;
   }

   // Session time filter
   if(!IsWithinSession())
   {
      return false;
   }

   // Day of week filter
   if(!IsTradingDay())
   {
      return false;
   }

   // Max trades per day
   if(CountTradesToday() >= MaxTradesPerDay)
   {
      return false;
   }

   // Minimum candle size on M5 (last closed bar)
   double candleSize = MathAbs(iHigh(Symbol(), PERIOD_M5, 1) - iLow(Symbol(), PERIOD_M5, 1)) / g_pipSize;
   if(candleSize < MinCandleSizePips)
   {
      return false;
   }

   // ADR filter
   double adr = GetADR();
   if(adr < MinADRPips || adr > MaxADRPips)
   {
      return false;
   }

   // Daily drawdown limit
   if(CheckDailyDrawdown())
   {
      return false;
   }

   // EMA 200 slope filter — market must be trending
   double slope = GetEMA200Slope();
   if(MathAbs(slope) < MinEMASlopePoints * Point)
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check if current time is within trading session                   |
//+------------------------------------------------------------------+
bool IsWithinSession()
{
   int hour   = TimeHour(TimeCurrent());
   int minute = TimeMinute(TimeCurrent());

   int currentMinutes = hour * 60 + minute;
   int startMinutes   = SessionStartHour * 60 + SessionStartMinute;
   int endMinutes     = SessionEndHour * 60 + SessionEndMinute;

   return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
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
      default: return false; // Weekend
   }
}

//+------------------------------------------------------------------+
//| Count trades opened today with our magic number                   |
//+------------------------------------------------------------------+
int CountTradesToday()
{
   int count = 0;
   datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   // Check open orders
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

   // Check closed orders in history
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
   // Calculate today's total P&L (closed + floating)
   double closedPL   = 0;
   double floatingPL = 0;
   datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   // Closed P&L today
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

   // Floating P&L
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
//| Check all BUY conditions                                          |
//+------------------------------------------------------------------+
bool CheckBuySignal()
{
   // 1. M15 trend: price above 200 EMA
   double ema200_m15 = iMA(Symbol(), PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE, 0);
   if(iClose(Symbol(), PERIOD_M15, 0) <= ema200_m15)
      return false;

   // 2. EMA slope must be positive (uptrend)
   if(GetEMA200Slope() <= 0)
      return false;

   // 3. M5 pullback: price touched or pierced the 20 EMA
   double ema20_m5 = iMA(Symbol(), PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double low1 = iLow(Symbol(), PERIOD_M5, 1);
   if(low1 > ema20_m5 + 1.0 * g_pipSize)  // Must touch or pierce
      return false;

   // 4. RSI confirmation: standard turn OR divergence
   if(!CheckRSIBuyCondition())
      return false;

   // 5. Candle pattern: bullish close, optionally require strong pattern
   double close1 = iClose(Symbol(), PERIOD_M5, 1);
   double open1  = iOpen(Symbol(), PERIOD_M5, 1);
   if(close1 <= open1)  // Must be bullish
      return false;

   if(RequireStrongCandle)
   {
      if(!IsBullishEngulfingOrPinBar())
         return false;
   }

   // 6. HTF alignment (optional)
   if(UseHTFAlignment)
   {
      double htfEMA = iMA(Symbol(), HTFPeriod, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
      if(Ask <= htfEMA)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check all SELL conditions                                         |
//+------------------------------------------------------------------+
bool CheckSellSignal()
{
   // 1. M15 trend: price below 200 EMA
   double ema200_m15 = iMA(Symbol(), PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE, 0);
   if(iClose(Symbol(), PERIOD_M15, 0) >= ema200_m15)
      return false;

   // 2. EMA slope must be negative (downtrend)
   if(GetEMA200Slope() >= 0)
      return false;

   // 3. M5 pullback: price touched or pierced the 20 EMA
   double ema20_m5 = iMA(Symbol(), PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double high1 = iHigh(Symbol(), PERIOD_M5, 1);
   if(high1 < ema20_m5 - 1.0 * g_pipSize)  // Must touch or pierce
      return false;

   // 4. RSI confirmation: standard turn OR divergence
   if(!CheckRSISellCondition())
      return false;

   // 5. Candle pattern: bearish close, optionally require strong pattern
   double close1 = iClose(Symbol(), PERIOD_M5, 1);
   double open1  = iOpen(Symbol(), PERIOD_M5, 1);
   if(close1 >= open1)  // Must be bearish
      return false;

   if(RequireStrongCandle)
   {
      if(!IsBearishEngulfingOrPinBar())
         return false;
   }

   // 6. HTF alignment (optional)
   if(UseHTFAlignment)
   {
      double htfEMA = iMA(Symbol(), HTFPeriod, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
      if(Bid >= htfEMA)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| RSI buy condition: turn upward from below 40 OR bullish divergence|
//+------------------------------------------------------------------+
bool CheckRSIBuyCondition()
{
   double rsi1 = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, 1);
   double rsi2 = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, 2);

   // Standard condition: RSI was below 40 and turned up
   bool standardTurn = (rsi2 < 40.0 && rsi1 > rsi2);

   if(standardTurn)
      return true;

   // RSI divergence: price made lower low but RSI made higher low
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

   // Standard condition: RSI was above 60 and turned down
   bool standardTurn = (rsi2 > 60.0 && rsi1 < rsi2);

   if(standardTurn)
      return true;

   // RSI divergence: price made higher high but RSI made lower high
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

   // Find the most recent swing low in price (bar 1)
   double priceLow1 = iLow(Symbol(), PERIOD_M5, 1);
   double rsiLow1   = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, 1);

   // Find a previous swing low within lookback
   for(int i = 3; i <= lookback; i++)
   {
      double priceLowI = iLow(Symbol(), PERIOD_M5, i);
      double rsiLowI   = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, i);

      // Check if bar i is a local low (lower than neighbors)
      if(priceLowI <= iLow(Symbol(), PERIOD_M5, i-1) &&
         priceLowI <= iLow(Symbol(), PERIOD_M5, i+1))
      {
         // Bullish divergence: price made lower low, RSI made higher low
         if(priceLow1 < priceLowI && rsiLow1 > rsiLowI)
         {
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
         // Bearish divergence: price made higher high, RSI made lower high
         if(priceHigh1 > priceHighI && rsiHigh1 < rsiHighI)
         {
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
   double body2 = MathAbs(close2 - open2);

   // Engulfing: current bullish body fully engulfs previous bearish body
   bool engulfing = (close2 < open2) &&                    // Previous was bearish
                    (close1 > open1) &&                     // Current is bullish
                    (close1 > open2) && (open1 < close2);   // Body engulfs

   // Pin bar: long lower wick (rejection), wick >= 2x body
   double lowerWick = MathMin(open1, close1) - low1;
   double upperWick = high1 - MathMax(open1, close1);
   bool pinBar = (close1 > open1) &&                       // Bullish
                 (lowerWick >= 2.0 * body1) &&             // Long lower wick
                 (upperWick < body1);                       // Short upper wick

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
   double body2 = MathAbs(close2 - open2);

   // Engulfing: current bearish body fully engulfs previous bullish body
   bool engulfing = (close2 > open2) &&                    // Previous was bullish
                    (close1 < open1) &&                     // Current is bearish
                    (open1 > close2) && (close1 < open2);   // Body engulfs

   // Pin bar: long upper wick (rejection), wick >= 2x body
   double upperWick = high1 - MathMax(open1, close1);
   double lowerWick = MathMin(open1, close1) - low1;
   bool pinBar = (close1 < open1) &&                       // Bearish
                 (upperWick >= 2.0 * body1) &&             // Long upper wick
                 (lowerWick < body1);                       // Short lower wick

   return (engulfing || pinBar);
}

//+------------------------------------------------------------------+
//|                     STOP LOSS FUNCTIONS                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate stop loss distance in pips for a BUY                    |
//+------------------------------------------------------------------+
double CalculateBuyStopLoss()
{
   double slPrice;

   if(UseATRStopLoss)
   {
      // ATR-based SL
      double atr = iATR(Symbol(), PERIOD_M5, ATRPeriod, 1);
      double atrSL = Ask - atr * ATRMultiplier;

      // Check swing low — use whichever gives more room
      double swingLow = FindSwingLow(10);
      if(swingLow > 0)
      {
         double swingSL = swingLow - 1.0 * g_pipSize; // Buffer below swing
         slPrice = MathMin(atrSL, swingSL);            // Use the wider (lower) SL

         // Cap at 2x ATR to prevent absurd stops
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
      // Fixed pip fallback
      slPrice = Ask - FixedStopLossPips * g_pipSize;

      // Still check swing low
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
//| Calculate stop loss distance in pips for a SELL                   |
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
         slPrice = MathMax(atrSL, swingSL);  // Use the wider (higher) SL

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

      // Simple fractal: lower than both neighbors
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
   if(slDistancePips <= 0)
      return MarketInfo(Symbol(), MODE_MINLOT);

   double accountRisk = AccountBalance() * RiskPercent / 100.0;
   double tickValue   = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize    = MarketInfo(Symbol(), MODE_TICKSIZE);

   if(tickValue <= 0 || tickSize <= 0)
      return MarketInfo(Symbol(), MODE_MINLOT);

   // Convert SL pips to price distance
   double slDistance = slDistancePips * g_pipSize;

   // Calculate pip value per lot
   double pipValuePerLot = tickValue * (g_pipSize / tickSize);

   if(pipValuePerLot <= 0)
      return MarketInfo(Symbol(), MODE_MINLOT);

   double lots = accountRisk / (slDistancePips * pipValuePerLot);

   return NormalizeLots(lots);
}

//+------------------------------------------------------------------+
//| Normalize lot size to broker constraints                          |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(lotStep <= 0) lotStep = 0.01;

   // Round to lot step
   lots = MathFloor(lots / lotStep) * lotStep;

   // Clamp to min/max
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
   }
}

//+------------------------------------------------------------------+
//| Execute a SELL trade                                              |
//+------------------------------------------------------------------+
void ExecuteSell()
{
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

      double openPrice    = OrderOpenPrice();
      double currentSL    = OrderStopLoss();
      double currentTP    = OrderTakeProfit();
      double slDistance    = 0;
      double currentProfit = 0;
      bool   isPartialDone = (StringFind(OrderComment(), "P") >= 0);

      if(OrderType() == OP_BUY)
      {
         slDistance    = (openPrice - currentSL);
         currentProfit = Bid - openPrice;
      }
      else // SELL
      {
         slDistance    = (currentSL - openPrice);
         currentProfit = openPrice - Ask;
      }

      // Avoid division by zero
      if(slDistance <= 0) continue;

      double profitInR = currentProfit / slDistance;

      // 1. Partial close at 1R
      if(EnablePartialClose && !isPartialDone && profitInR >= 1.0)
      {
         HandlePartialClose(OrderTicket(), OrderType(), OrderLots());
      }

      // 2. Break-even at 1R
      if(EnableBreakEven && profitInR >= 1.0)
      {
         HandleBreakEven(OrderTicket(), OrderType(), openPrice, currentSL);
      }

      // 3. Trailing stop after 1R
      if(EnableTrailingStop && profitInR >= 1.0)
      {
         HandleTrailingStop(OrderTicket(), OrderType(), openPrice, currentSL);
      }
   }
}

//+------------------------------------------------------------------+
//| Close partial position at 1R profit                               |
//+------------------------------------------------------------------+
void HandlePartialClose(int ticket, int orderType, double lots)
{
   double closeLots = NormalizeLots(lots * PartialClosePercent / 100.0);

   // Ensure we don't close more than we have
   if(closeLots >= lots)
      return;

   // Ensure remaining lots are valid
   double remainingLots = NormalizeLots(lots - closeLots);
   if(remainingLots < MarketInfo(Symbol(), MODE_MINLOT))
      return;

   double closePrice = (orderType == OP_BUY) ? Bid : Ask;

   bool result = OrderClose(ticket, closeLots, NormalizeDouble(closePrice, Digits), Slippage, clrYellow);

   if(result)
   {
      Print("Partial close executed. Ticket: ", ticket, " Closed: ", closeLots, " lots");

      // Mark remaining order with "P" comment to prevent repeated partial closes
      // After partial close, the remaining position gets a new ticket
      // Find it and modify the comment
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            {
               if(StringFind(OrderComment(), "P") < 0)
               {
                  // We can't change comments via OrderModify, but the partial close
                  // tracking works via lot size comparison. Mark via SL movement instead.
                  // The break-even handler will handle the SL move.
               }
            }
         }
      }
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
      // Only move SL up, never down
      if(currentSL >= newSL)
         return;
   }
   else // SELL
   {
      newSL = NormalizeDouble(openPrice - 1.0 * g_pipSize, Digits);
      // Only move SL down, never up
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
      if(err != 1) // Suppress "no error" spam
         Print("Break-even modify failed. Error: ", err, " - ", ErrorDescription(err));
   }
}

//+------------------------------------------------------------------+
//| Trail stop loss after 1R profit using ATR or fixed distance       |
//+------------------------------------------------------------------+
void HandleTrailingStop(int ticket, int orderType, double openPrice, double currentSL)
{
   double trailDistance;

   if(UseATRTrailing)
   {
      double atr = iATR(Symbol(), PERIOD_M5, ATRPeriod, 0);
      trailDistance = atr * ATRTrailingMultiplier;
   }
   else
   {
      // Use original SL distance as trailing distance
      trailDistance = MathAbs(openPrice - currentSL);
   }

   if(trailDistance <= 0)
      return;

   double newSL;

   if(orderType == OP_BUY)
   {
      newSL = NormalizeDouble(Bid - trailDistance, Digits);
      // Only move SL up
      if(newSL <= currentSL)
         return;
      // Don't trail below entry
      if(newSL < openPrice)
         return;
   }
   else // SELL
   {
      newSL = NormalizeDouble(Ask + trailDistance, Digits);
      // Only move SL down
      if(currentSL > 0 && newSL >= currentSL)
         return;
      // Don't trail above entry
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
