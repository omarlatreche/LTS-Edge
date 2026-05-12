//+------------------------------------------------------------------+
//|                                                  LTS_Edge_v2.mq4 |
//|                        London Session Breakout — GBPUSD / Forex    |
//|                        Trades the Asian range breakout at London    |
//|                        v4.0 — London Breakout Strategy             |
//+------------------------------------------------------------------+
#property copyright "LTS Edge v4.0"
#property link      ""
#property version   "4.00"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// --- Risk Management ---
input double   RiskPercent            = 1.0;     // Risk per trade (% of balance)
input double   RiskRewardRatio        = 1.5;     // TP as multiple of SL distance
input double   MaxDailyDrawdownPct    = 3.0;     // Max daily drawdown % — stop trading

// --- Asian Range Definition (UK time) ---
input int      RangeStartHour         = 0;       // Asian range start hour (UK time)
input int      RangeStartMinute       = 0;       // Asian range start minute
input int      RangeEndHour           = 7;       // Asian range end hour (UK time)
input int      RangeEndMinute         = 0;       // Asian range end minute

// --- Range Filters ---
input double   MinRangePips           = 20.0;    // Min Asian range size (pips)
input double   MaxRangePips           = 80.0;    // Max Asian range size (pips)
input double   BreakoutBufferPips     = 2.0;     // Pips beyond range for entry

// --- Session Management ---
input int      CloseTradesHour        = 16;      // Close open trades at this hour (UK time)
input int      CancelOrdersHour       = 10;      // Cancel unfilled pending orders (UK time)

// --- Trend Filter ---
input bool     UseTrendFilter         = true;    // Only trade breakout in trend direction
input int      TrendEMAPeriod         = 50;      // EMA period for trend filter
input int      TrendFilterTF          = PERIOD_D1; // Timeframe for trend EMA

// --- Bias ---
input int      TradeBias              = 0;       // 0 = both directions, 1 = long only, -1 = short only

// --- Filters ---
input double   MaxSpreadPips          = 2.0;     // Max allowed spread (pips)

// --- Time Settings ---
input int      BrokerUTCOffset        = 3;       // Broker server UTC offset (IC Markets: 3, Pepperstone: 2)
input bool     UKSummerTime           = false;   // UK is on BST (UTC+1) — set true late Mar-Oct

// --- Day Filter ---
input bool     TradeMonday            = true;    // Allow trades on Monday
input bool     TradeTuesday           = true;    // Allow trades on Tuesday
input bool     TradeWednesday         = true;    // Allow trades on Wednesday
input bool     TradeThursday          = true;    // Allow trades on Thursday
input bool     TradeFriday            = true;    // Allow trades on Friday

// --- Diagnostics ---
input bool     EnableDiagnostics      = true;    // Log detailed results per bar

// --- System ---
input int      MagicNumber            = 44444;   // EA magic number
input int      Slippage               = 5;       // Max slippage (points)

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
datetime g_lastBarTime    = 0;
double   g_pipSize        = 0;
int      g_pipDigits      = 0;
string   g_commentTag     = "LTSv4";
double   g_startBalance   = 0;
bool     g_ordersPlacedToday = false;
int      g_lastOrderDay   = -1;
bool     g_rangeReady     = false;
double   g_rangeHigh      = 0;
double   g_rangeLow       = 999999;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   // Detect pip size based on symbol digits
   if(Digits == 5 || Digits == 3)
   {
      // Forex with extra digit (e.g. GBPUSD 1.12345)
      g_pipSize  = Point * 10;
      g_pipDigits = 1;
   }
   else if(Digits <= 2)
   {
      // Indices / Gold — 1 pip = 1 full point
      g_pipSize  = 1.0;
      g_pipDigits = 0;
   }
   else
   {
      // Standard 4-digit forex
      g_pipSize  = Point;
      g_pipDigits = 0;
   }

   g_startBalance = AccountBalance();

   Print("LTS Edge v4.0 (London Breakout) initialized on ", Symbol());
   Print("Pip size: ", g_pipSize, " Digits: ", Digits, " Point: ", Point);
   Print("Asian Range: ", RangeStartHour, ":", RangeStartMinute, "-",
         RangeEndHour, ":", RangeEndMinute, " UK",
         (UKSummerTime ? " (BST)" : " (GMT)"));
   Print("Close trades: ", CloseTradesHour, ":00 UK | Cancel pending: ", CancelOrdersHour, ":00 UK");
   Print("Risk: ", RiskPercent, "% RR: ", RiskRewardRatio,
         " Bias: ", (TradeBias == 1 ? "LONG ONLY" : (TradeBias == -1 ? "SHORT ONLY" : "BOTH")));
   Print("Trend filter: ", UseTrendFilter, " EMA(", TrendEMAPeriod, ") on TF ", TrendFilterTF);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
   Print("LTS Edge v4.0 removed. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Main tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // Always check OCO and session close on every tick
   ManageOCO();
   CheckSessionClose();
   CheckCancelPending();

   UpdateChartDisplay();

   if(!IsNewBar())
      return;

   // Reset daily tracker
   int today = TimeDay(TimeCurrent());
   if(today != g_lastOrderDay)
   {
      g_ordersPlacedToday = false;
      g_lastOrderDay = today;
      g_startBalance = AccountBalance();
      g_rangeReady = false;
      g_rangeHigh = 0;
      g_rangeLow = 999999;
   }

   // Track range during Asian session
   if(IsInRangePeriod())
   {
      TrackRange();
   }

   // At range end (London open), place breakout orders
   if(IsRangeEndTime() && !g_ordersPlacedToday && !HasPendingOrOpenTrade() && g_rangeReady)
   {
      if(IsTradingDay() && !CheckDailyDrawdown())
      {
         PlaceBreakoutOrders();
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

   // Also check bar 1 in case we just entered the range period
   double high1 = iHigh(Symbol(), PERIOD_M5, 1);
   double low1  = iLow(Symbol(), PERIOD_M5, 1);

   if(high > g_rangeHigh) g_rangeHigh = high;
   if(high1 > g_rangeHigh) g_rangeHigh = high1;
   if(low < g_rangeLow) g_rangeLow = low;
   if(low1 < g_rangeLow) g_rangeLow = low1;

   g_rangeReady = true;
}

//+------------------------------------------------------------------+
//| Check if current time is the range end (London open)              |
//+------------------------------------------------------------------+
bool IsRangeEndTime()
{
   int hour = TimeHour(TimeCurrent());
   int minute = TimeMinute(TimeCurrent());
   int currentMins = hour * 60 + minute;

   int endMins = UKToServerMinutes(RangeEndHour, RangeEndMinute);

   // Match within the current M5 bar (5-minute window)
   return (currentMins >= endMins && currentMins < endMins + 5);
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
//| Check if EA has pending or open trades                            |
//+------------------------------------------------------------------+
bool HasPendingOrOpenTrade()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Place breakout pending orders above and below Asian range         |
//+------------------------------------------------------------------+
void PlaceBreakoutOrders()
{
   // Check spread
   double spreadPips = (Ask - Bid) / g_pipSize;
   if(spreadPips > MaxSpreadPips)
   {
      if(EnableDiagnostics)
         Print("Spread too high: ", DoubleToString(spreadPips, 1), " > ", MaxSpreadPips);
      return;
   }

   double rangeWidthPips = (g_rangeHigh - g_rangeLow) / g_pipSize;

   // Check range size
   if(rangeWidthPips < MinRangePips)
   {
      if(EnableDiagnostics)
         Print("Range too small: ", DoubleToString(rangeWidthPips, 1), " < ", MinRangePips);
      return;
   }

   if(rangeWidthPips > MaxRangePips)
   {
      if(EnableDiagnostics)
         Print("Range too large: ", DoubleToString(rangeWidthPips, 1), " > ", MaxRangePips);
      return;
   }

   if(EnableDiagnostics)
   {
      Print("Asian Range: High=", DoubleToString(g_rangeHigh, Digits),
            " Low=", DoubleToString(g_rangeLow, Digits),
            " Width=", DoubleToString(rangeWidthPips, 1), " pips");
   }

   double buffer = BreakoutBufferPips * g_pipSize;

   // --- Trend filter ---
   bool allowBuy = true;
   bool allowSell = true;

   // Apply trade bias
   if(TradeBias == 1)
      allowSell = false;
   else if(TradeBias == -1)
      allowBuy = false;

   // Apply trend filter
   if(UseTrendFilter)
   {
      double trendEMA = iMA(Symbol(), TrendFilterTF, TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
      double price = (Ask + Bid) / 2.0;

      if(price > trendEMA)
      {
         allowSell = false;
         if(EnableDiagnostics)
            Print("Trend filter: BULLISH (price > D1 EMA ", DoubleToString(trendEMA, Digits), ") — BUY only");
      }
      else
      {
         allowBuy = false;
         if(EnableDiagnostics)
            Print("Trend filter: BEARISH (price < D1 EMA ", DoubleToString(trendEMA, Digits), ") — SELL only");
      }
   }

   if(!allowBuy && !allowSell)
   {
      if(EnableDiagnostics)
         Print("No direction allowed (bias + trend conflict). Skipping.");
      g_ordersPlacedToday = true;
      return;
   }

   // --- Calculate SL distance ---
   // SL = opposite side of range + buffer
   double slDistancePips = rangeWidthPips + (BreakoutBufferPips * 2.0);

   // Place BUY STOP (or market buy if already broken out)
   if(allowBuy)
   {
      double buyEntry = NormalizeDouble(g_rangeHigh + buffer, Digits);
      double buySL    = NormalizeDouble(g_rangeLow - buffer, Digits);
      double buySlPips = (buyEntry - buySL) / g_pipSize;
      double buyTP    = NormalizeDouble(buyEntry + buySlPips * g_pipSize * RiskRewardRatio, Digits);
      double buyLots  = CalculateLotSize(buySlPips);

      int buyOrderType;
      double buyPrice;

      if(Ask >= buyEntry)
      {
         // Price already above breakout level — use market order
         buyOrderType = OP_BUY;
         buyPrice = Ask;
         // Recalculate TP based on actual entry
         buyTP = NormalizeDouble(buyPrice + buySlPips * g_pipSize * RiskRewardRatio, Digits);
         if(EnableDiagnostics)
            Print("Price already broke out upward (Ask=", Ask, " >= Entry=", buyEntry, ") — using MARKET BUY");
      }
      else
      {
         buyOrderType = OP_BUYSTOP;
         buyPrice = buyEntry;
      }

      int buyTicket = OrderSend(
         Symbol(), buyOrderType, buyLots,
         buyPrice, Slippage, buySL, buyTP,
         g_commentTag + " BUY", MagicNumber, 0, clrGreen
      );

      if(buyTicket < 0)
      {
         int err = GetLastError();
         Print((buyOrderType == OP_BUY ? "MARKET BUY" : "BUY STOP"),
               " failed. Error: ", err, " - ", ErrorDescription(err),
               " Entry: ", buyPrice, " SL: ", buySL, " TP: ", buyTP, " Lots: ", buyLots);
      }
      else
      {
         Print((buyOrderType == OP_BUY ? "MARKET BUY" : "BUY STOP"),
               " placed. Ticket: ", buyTicket,
               " Entry: ", DoubleToString(buyPrice, Digits),
               " SL: ", DoubleToString(buySL, Digits),
               " TP: ", DoubleToString(buyTP, Digits),
               " Lots: ", DoubleToString(buyLots, 2));
      }
   }

   // Place SELL STOP (or market sell if already broken out)
   if(allowSell)
   {
      double sellEntry = NormalizeDouble(g_rangeLow - buffer, Digits);
      double sellSL    = NormalizeDouble(g_rangeHigh + buffer, Digits);
      double sellSlPips = (sellSL - sellEntry) / g_pipSize;
      double sellTP    = NormalizeDouble(sellEntry - sellSlPips * g_pipSize * RiskRewardRatio, Digits);
      double sellLots  = CalculateLotSize(sellSlPips);

      int sellOrderType;
      double sellPrice;

      if(Bid <= sellEntry)
      {
         // Price already below breakout level — use market order
         sellOrderType = OP_SELL;
         sellPrice = Bid;
         // Recalculate TP based on actual entry
         sellTP = NormalizeDouble(sellPrice - sellSlPips * g_pipSize * RiskRewardRatio, Digits);
         if(EnableDiagnostics)
            Print("Price already broke out downward (Bid=", Bid, " <= Entry=", sellEntry, ") — using MARKET SELL");
      }
      else
      {
         sellOrderType = OP_SELLSTOP;
         sellPrice = sellEntry;
      }

      int sellTicket = OrderSend(
         Symbol(), sellOrderType, sellLots,
         sellPrice, Slippage, sellSL, sellTP,
         g_commentTag + " SELL", MagicNumber, 0, clrRed
      );

      if(sellTicket < 0)
      {
         int err = GetLastError();
         Print((sellOrderType == OP_SELL ? "MARKET SELL" : "SELL STOP"),
               " failed. Error: ", err, " - ", ErrorDescription(err),
               " Entry: ", sellPrice, " SL: ", sellSL, " TP: ", sellTP, " Lots: ", sellLots);
      }
      else
      {
         Print((sellOrderType == OP_SELL ? "MARKET SELL" : "SELL STOP"),
               " placed. Ticket: ", sellTicket,
               " Entry: ", DoubleToString(sellPrice, Digits),
               " SL: ", DoubleToString(sellSL, Digits),
               " TP: ", DoubleToString(sellTP, Digits),
               " Lots: ", DoubleToString(sellLots, 2));
      }
   }

   g_ordersPlacedToday = true;

   if(EnableDiagnostics)
   {
      Print("=== LONDON BREAKOUT ORDERS PLACED === Range: ", DoubleToString(rangeWidthPips, 1), " pips",
            " Buy:", (allowBuy ? "YES" : "NO"),
            " Sell:", (allowSell ? "YES" : "NO"));
   }
}

//+------------------------------------------------------------------+
//| OCO: when one pending order triggers, cancel the other            |
//+------------------------------------------------------------------+
void ManageOCO()
{
   bool hasOpenTrade = false;
   bool hasPending = false;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == OP_BUY || OrderType() == OP_SELL)
               hasOpenTrade = true;
            else if(OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP)
               hasPending = true;
         }
      }
   }

   if(hasOpenTrade && hasPending)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            {
               if(OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP)
               {
                  bool result = OrderDelete(OrderTicket());
                  if(result)
                     Print("OCO: Cancelled pending order ", OrderTicket());
               }
            }
         }
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

   // Handle midnight wrap
   // For London strategy: range starts at 00:00 UK (03:00 server UTC+3)
   // Close at 16:00 UK (19:00 server UTC+3)
   // So serverCloseHour (19) > serverRangeStartHour (3) — no wrap, simple comparison
   bool pastClose;
   if(serverCloseHour > serverRangeStartHour)
   {
      // Normal case: close is after range start, same day
      pastClose = (hour >= serverCloseHour);
   }
   else
   {
      // Wraps midnight
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
//| Cancel unfilled pending orders after cancel hour                  |
//+------------------------------------------------------------------+
void CheckCancelPending()
{
   int hour = TimeHour(TimeCurrent());
   int serverCancelHour = UKToServerHour(CancelOrdersHour);
   int serverRangeEndHour = UKToServerHour(RangeEndHour);

   // Cancel pending if past cancel hour but still within session day
   bool pastCancel;
   if(serverCancelHour > serverRangeEndHour)
   {
      pastCancel = (hour >= serverCancelHour);
   }
   else
   {
      pastCancel = (hour >= serverCancelHour && hour < serverRangeEndHour);
   }

   if(!pastCancel)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP)
            {
               bool result = OrderDelete(OrderTicket());
               if(result)
                  Print("Cancel hour: Deleted pending order ", OrderTicket());
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

   // Fallback if MarketInfo returns bad values
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
   int currentMins = hour * 60 + minute;

   int rangeStartMins = UKToServerMinutes(RangeStartHour, RangeStartMinute);
   int rangeEndMins   = UKToServerMinutes(RangeEndHour, RangeEndMinute);
   int closeMins      = UKToServerHour(CloseTradesHour) * 60;

   bool inRange = IsInRangePeriod();

   int pendingCount = 0;
   int openCount = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == OP_BUY || OrderType() == OP_SELL)
               openCount++;
            else
               pendingCount++;
         }
      }
   }

   string display = "";
   display += "=== LTS Edge v4.0 (London Breakout) ===\n";
   display += "Symbol: " + Symbol() + "\n";

   if(inRange)
      display += "Status: BUILDING ASIAN RANGE\n";
   else if(g_ordersPlacedToday)
      display += "Status: LONDON SESSION ACTIVE\n";
   else
      display += "Status: Waiting for Asian session\n";

   display += "Spread: " + DoubleToString(spreadPips, 1) + " pips\n";

   if(g_rangeReady)
   {
      double rangeWidth = (g_rangeHigh - g_rangeLow) / g_pipSize;
      display += "Asian Range: " + DoubleToString(g_rangeLow, Digits) + " - " + DoubleToString(g_rangeHigh, Digits) +
                 " (" + DoubleToString(rangeWidth, 1) + " pips)\n";
   }
   else
   {
      display += "Asian Range: Not yet built\n";
   }

   display += "Open: " + IntegerToString(openCount) + " | Pending: " + IntegerToString(pendingCount) + "\n";
   display += "Orders today: " + (g_ordersPlacedToday ? "YES" : "NO") + "\n";
   display += "Bias: " + (TradeBias == 1 ? "LONG ONLY" : (TradeBias == -1 ? "SHORT ONLY" : "BOTH")) + "\n";
   display += "BST: " + (UKSummerTime ? "ON" : "OFF") + " | UTC+" + IntegerToString(BrokerUTCOffset) + "\n";

   Comment(display);
}

//+------------------------------------------------------------------+
