//+------------------------------------------------------------------+
//|                                                  LTS_Edge_v4.mq4 |
//|                        Volatility Squeeze Breakout                 |
//|                        BB inside KC = squeeze, release = entry     |
//|                        v6.0 — Squeeze Strategy                     |
//+------------------------------------------------------------------+
#property copyright "LTS Edge v6.0"
#property link      ""
#property version   "6.00"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// --- Risk Management ---
input double   RiskPercent            = 1.5;     // Risk per trade (% of balance)
input double   RiskRewardRatio        = 2.0;     // TP as multiple of SL distance
input double   MaxDailyDrawdownPct    = 3.0;     // Max daily drawdown % — stop trading

// --- Squeeze Detection ---
input int      BBPeriod               = 20;      // Bollinger Bands period
input double   BBDeviation            = 2.0;     // Bollinger Bands std dev multiplier
input int      KCPeriod               = 20;      // Keltner Channel EMA period
input int      KCATRPeriod            = 10;      // Keltner Channel ATR period
input double   KCMultiplier           = 1.5;     // Keltner Channel ATR multiplier
input int      MinSqueezeBars         = 3;       // Min consecutive bars in squeeze before valid release

// --- Signal Timeframe ---
input int      SignalTimeframe        = PERIOD_H1; // Timeframe for squeeze detection

// --- Stop Loss ---
input int      ATRPeriodSL            = 14;      // ATR period for stop loss
input double   ATRMultiplierSL        = 1.5;     // ATR multiplier for stop loss

// --- Session Filter (UK time) ---
input int      SessionStartHour       = 8;       // Only enter trades after this hour (UK)
input int      SessionEndHour         = 16;      // Stop entering trades after this hour (UK)
input bool     CloseAtSessionEnd      = false;   // Close trades at session end (vs let TP/SL hit)

// --- Trend Filter ---
input bool     UseTrendFilter         = true;    // Only trade in D1 EMA trend direction
input int      TrendEMAPeriod         = 50;      // EMA period for trend filter
input int      TrendFilterTF          = PERIOD_D1; // Timeframe for trend EMA

// --- Filters ---
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

// --- Diagnostics ---
input bool     EnableDiagnostics      = true;    // Log detailed results per bar

// --- System ---
input int      MagicNumber            = 66666;   // EA magic number
input int      Slippage               = 5;       // Max slippage (points)

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
datetime g_lastBarTime     = 0;
double   g_pipSize         = 0;
int      g_pipDigits       = 0;
string   g_commentTag      = "LTSv6";
double   g_startBalance    = 0;
int      g_squeezeCount    = 0;     // Consecutive bars in squeeze

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

   Print("LTS Edge v6.0 (Squeeze Breakout) initialized on ", Symbol());
   Print("Pip size: ", g_pipSize, " Digits: ", Digits, " Point: ", Point);
   Print("Squeeze: BB(", BBPeriod, ", ", BBDeviation, ") vs KC(", KCPeriod, ", ATR ", KCATRPeriod, " x", KCMultiplier, ")");
   Print("Min squeeze bars: ", MinSqueezeBars);
   Print("Signal TF: ", SignalTimeframe, " min");
   Print("SL: ATR(", ATRPeriodSL, ") x", ATRMultiplierSL, " | RR: ", RiskRewardRatio);
   Print("Session: ", SessionStartHour, ":00-", SessionEndHour, ":00 UK",
         (UKSummerTime ? " (BST)" : " (GMT)"));

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
   Print("LTS Edge v6.0 removed. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Main tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check session close on every tick
   if(CloseAtSessionEnd)
      CheckSessionClose();

   UpdateChartDisplay();

   // Only process on new signal timeframe bars
   if(!IsNewSignalBar())
      return;

   // Update squeeze counter using the last completed bar
   UpdateSqueezeState();

   // Check for entry signal
   if(IsWithinSession() && IsTradingDay() && !CheckDailyDrawdown() && !HasOpenTrade())
   {
      CheckSqueezeEntry();
   }
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
   int serverStart = UKToServerHour(SessionStartHour);
   int serverEnd   = UKToServerHour(SessionEndHour);

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
   bool isInSqueeze = CheckSqueeze(1); // Check last completed bar

   if(isInSqueeze)
   {
      g_squeezeCount++;
   }
   else
   {
      // Squeeze count is preserved for one bar after release (for entry check)
      // It gets reset after the entry check in CheckSqueezeEntry()
   }
}

//+------------------------------------------------------------------+
//| Check if a specific bar is in squeeze (BB inside KC)              |
//+------------------------------------------------------------------+
bool CheckSqueeze(int shift)
{
   // Bollinger Bands
   double bbUpper = iBands(Symbol(), SignalTimeframe, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_UPPER, shift);
   double bbLower = iBands(Symbol(), SignalTimeframe, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_LOWER, shift);

   // Keltner Channel (manual calculation: EMA +/- ATR * multiplier)
   double kcMiddle = iMA(Symbol(), SignalTimeframe, KCPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);
   double kcATR    = iATR(Symbol(), SignalTimeframe, KCATRPeriod, shift);
   double kcUpper  = kcMiddle + KCMultiplier * kcATR;
   double kcLower  = kcMiddle - KCMultiplier * kcATR;

   // Squeeze = BB entirely inside KC
   return (bbUpper < kcUpper && bbLower > kcLower);
}

//+------------------------------------------------------------------+
//| Check for squeeze release and enter trade                         |
//+------------------------------------------------------------------+
void CheckSqueezeEntry()
{
   // Bar 1 = last completed bar
   bool currentSqueeze = CheckSqueeze(1);

   // If still in squeeze, no entry
   if(currentSqueeze)
      return;

   // Check if we had enough consecutive squeeze bars before this release
   if(g_squeezeCount < MinSqueezeBars)
   {
      if(EnableDiagnostics && g_squeezeCount > 0)
         Print("Squeeze released but only ", g_squeezeCount, " bars (need ", MinSqueezeBars, ")");
      g_squeezeCount = 0;
      return;
   }

   // SQUEEZE RELEASE CONFIRMED — determine direction
   double close1  = iClose(Symbol(), SignalTimeframe, 1);
   double ema20   = iMA(Symbol(), SignalTimeframe, BBPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);

   // Trend filter — only trade in direction of D1 EMA
   if(UseTrendFilter)
   {
      double trendEMA = iMA(Symbol(), TrendFilterTF, TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
      double price = (Ask + Bid) / 2.0;
      bool trendBullish = (price > trendEMA);

      bool momentumBuy  = (close1 > ema20);
      bool momentumSell = (close1 < ema20);

      // Block trades against the trend
      if(trendBullish && momentumSell)
      {
         if(EnableDiagnostics)
            Print("Squeeze release SELL blocked — trend is BULLISH (price > D1 EMA ", DoubleToString(trendEMA, Digits), ")");
         g_squeezeCount = 0;
         return;
      }
      if(!trendBullish && momentumBuy)
      {
         if(EnableDiagnostics)
            Print("Squeeze release BUY blocked — trend is BEARISH (price < D1 EMA ", DoubleToString(trendEMA, Digits), ")");
         g_squeezeCount = 0;
         return;
      }

      if(EnableDiagnostics)
         Print("Trend filter: ", (trendBullish ? "BULLISH" : "BEARISH"), " | D1 EMA(", TrendEMAPeriod, ")=", DoubleToString(trendEMA, Digits));
   }

   // Check spread
   double spreadPips = (Ask - Bid) / g_pipSize;
   if(spreadPips > MaxSpreadPips)
   {
      if(EnableDiagnostics)
         Print("Squeeze release — spread too high: ", DoubleToString(spreadPips, 1), " > ", MaxSpreadPips);
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

   // Determine direction
   bool goBuy  = (close1 > ema20);
   bool goSell = (close1 < ema20);

   if(!goBuy && !goSell)
   {
      g_squeezeCount = 0;
      return;
   }

   if(EnableDiagnostics)
   {
      Print("=== SQUEEZE RELEASE === Bars in squeeze: ", g_squeezeCount,
            " | Close: ", DoubleToString(close1, Digits),
            " | EMA20: ", DoubleToString(ema20, Digits),
            " | Direction: ", (goBuy ? "BUY" : "SELL"),
            " | ATR: ", DoubleToString(atr, Digits),
            " | SL pips: ", DoubleToString(slDistancePips, 1));
   }

   // Calculate lot size
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
         Print("BUY opened. Ticket: ", ticket,
               " Entry: ", DoubleToString(entry, Digits),
               " SL: ", DoubleToString(sl, Digits),
               " TP: ", DoubleToString(tp, Digits),
               " Lots: ", DoubleToString(lots, 2),
               " Squeeze bars: ", g_squeezeCount);
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
         Print("SELL opened. Ticket: ", ticket,
               " Entry: ", DoubleToString(entry, Digits),
               " SL: ", DoubleToString(sl, Digits),
               " TP: ", DoubleToString(tp, Digits),
               " Lots: ", DoubleToString(lots, 2),
               " Squeeze bars: ", g_squeezeCount);
      }
   }

   // Reset squeeze counter after entry attempt
   g_squeezeCount = 0;
}

//+------------------------------------------------------------------+
//| Close open trades at session end                                  |
//+------------------------------------------------------------------+
void CheckSessionClose()
{
   int hour = TimeHour(TimeCurrent());
   int serverCloseHour = UKToServerHour(SessionEndHour);

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
   bool inSqueeze = CheckSqueeze(0); // Current bar

   string display = "";
   display += "=== LTS Edge v6.0 (Squeeze Breakout) ===\n";
   display += "Symbol: " + Symbol() + " | TF: " + IntegerToString(SignalTimeframe) + "min\n";

   if(inSession)
      display += "Status: SESSION ACTIVE\n";
   else
      display += "Status: Outside session\n";

   display += "Spread: " + DoubleToString(spreadPips, 1) + " pips\n";
   display += "Squeeze: " + (inSqueeze ? "YES (" + IntegerToString(g_squeezeCount) + " bars)" : "NO") + "\n";

   // Show BB vs KC values
   double bbUpper = iBands(Symbol(), SignalTimeframe, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
   double bbLower = iBands(Symbol(), SignalTimeframe, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_LOWER, 0);
   double kcMiddle = iMA(Symbol(), SignalTimeframe, KCPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double kcATR    = iATR(Symbol(), SignalTimeframe, KCATRPeriod, 0);
   double kcUpper  = kcMiddle + KCMultiplier * kcATR;
   double kcLower  = kcMiddle - KCMultiplier * kcATR;

   display += "BB: " + DoubleToString(bbLower, Digits) + " - " + DoubleToString(bbUpper, Digits) + "\n";
   display += "KC: " + DoubleToString(kcLower, Digits) + " - " + DoubleToString(kcUpper, Digits) + "\n";

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
