//+------------------------------------------------------------------+
//|                                      LTS_Prop_Engine_v5.mq4       |
//|             Multi-strategy prop-firm engine for XAU/XAG/indices  |
//|                                                                  |
//|  Goal: maximize probability of reaching the phase target before  |
//|  breaching daily or overall loss limits. This EA is designed for |
//|  FTMO-style testing, not for guaranteed monthly returns.          |
//+------------------------------------------------------------------+
#property copyright "LTS Prop Engine v5"
#property link      ""
#property version   "5.10"
#property strict

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+

// --- Prop firm objective ---
input bool     PropMode                  = true;
input int      PropPhase                 = 1;       // 1=Challenge, 2=Verification, 3=Funded
input double   Phase1TargetPct           = 10.0;
input double   Phase2TargetPct           = 5.0;
input double   MaxDailyLossPct           = 4.0;     // Buffer below FTMO 5%
input double   MaxOverallLossPct         = 8.0;     // Buffer below FTMO 10%
input double   RiskBufferPct             = 0.50;    // Keep this much room before hard loss limits
input double   ChallengePreserveLossPct  = 5.0;     // Stop challenge attempt before deep damage
input double   PeakDrawdownStopPct       = 5.0;     // Stop after giving back this much from peak equity
input double   DailySoftStopPct          = 2.5;     // Reduce risk after this daily drawdown
input int      MaxConsecutiveLosses      = 3;
input int      MaxTradesPerDay           = 3;
input bool     CloseAtTarget             = true;
input bool     UseNewsGuard              = true;

// --- Campaign mode ---
input bool     UseCampaignMode           = false;
input double   CampaignCheckpointPct     = 5.0;     // Protect once this profit is reached
input double   CampaignProfitFloorPct    = 3.0;     // Stop if checkpoint profit gives back to here
input int      CampaignPushMinScore      = 4;       // 0-5 regime score needed to continue after checkpoint
input double   CampaignMaxRiskPct        = 1.00;    // Max risk after checkpoint, even in strong regimes
input bool     CampaignHaltIfWeak        = false;   // Stop at checkpoint if regime is not strong
input bool     CampaignCloseOnWeak       = false;   // Close open trades when weak-stop triggers

// --- Master risk ---
input double   StandardRiskPct           = 0.75;
input double   ReducedRiskPct            = 0.25;
input double   HighConvictionRiskPct     = 1.00;
input double   MaxTotalOpenRiskPct       = 1.00;
input double   MinRiskPct                = 0.10;
input double   StrategyMaxLossPct        = 1.25;    // Disable a module after this closed loss
input int      StrategyMaxLossTrades     = 3;       // Disable a module after this many closed losses

// --- Trading session ---
input int      SessionStartHour          = 7;       // UK time
input int      SessionEndHour            = 18;      // UK time
input int      BrokerUTCOffset           = 3;
input bool     UKSummerTime              = false;
input bool     TradeMonday               = true;
input bool     TradeTuesday              = true;
input bool     TradeWednesday            = true;
input bool     TradeThursday             = true;
input bool     TradeFriday               = true;

// --- Execution filters ---
input double   MaxSpreadPips             = 15.0;
input int      Slippage                  = 5;
input int      MagicBase                 = 88000;
input bool     EnableDiagnostics         = true;

// --- Shared indicators ---
input int      ATRPeriod                 = 14;
input int      FastEMAPeriod             = 20;
input int      MidEMAPeriod              = 50;
input int      SlowEMAPeriod             = 200;
input int      ADXPeriod                 = 14;
input double   DirectionalADXMin         = 20.0;
input double   ChopADXMax                = 15.0;
input bool     RequireH4TrendAlignment   = true;
input double   H4TrendADXMin             = 18.0;

// --- DXY / USD confirmation ---
input bool     UseDXYConfirmation        = true;
input string   DXYSymbol                 = "USDX";
input bool     DXYInverseFallback        = true;
input int      DXYTimeframe              = PERIOD_H1;
input int      DXYEMAPeriod              = 20;
input bool     UseDXYForIndices          = false;   // Keep false for US30/NAS/SPX exploration

// --- Strategy A: v4.5 squeeze + DXY ---
input bool     UseSqueezeStrategy        = true;
input int      SqueezeTF                 = PERIOD_H1;
input int      BBPeriod                  = 20;
input double   BBDeviation               = 2.0;
input int      KCPeriod                  = 20;
input int      KCATRPeriod               = 10;
input double   KCMultiplier              = 1.5;
input int      MinSqueezeBars            = 3;
input double   SqueezeATRSLMult          = 1.5;
input double   SqueezeRR                 = 2.0;
input double   SqueezeRiskMultiplier     = 0.50;
input bool     SqueezeUseD1Trend         = true;

// --- Strategy B: directional momentum breakout ---
input bool     UseMomentumStrategy       = true;
input int      MomentumTF                = PERIOD_H1;
input int      MomentumLookbackBars      = 24;
input double   MomentumADXMin            = 28.0;
input double   MomentumATRSLMult         = 2.0;
input double   MomentumRR                = 1.8;
input bool     MomentumUseDXY            = true;
input bool     MomentumRequireH4Trend    = true;

// --- Strategy C: pullback continuation ---
input bool     UsePullbackStrategy       = true;
input int      PullbackTF                = PERIOD_H1;
input double   PullbackADXMin            = 26.0;
input double   PullbackATRSLMult         = 1.6;
input double   PullbackRR                = 2.0;
input int      PullbackMaxDistancePips   = 25;
input bool     PullbackUseDXY            = true;
input bool     PullbackRequireH4Trend    = true;
input bool     BlockChopRegime           = true;
input int      MinBarsBetweenTrades      = 4;

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
double   g_pipSize                  = 0;
double   g_startBalance             = 0;
double   g_dayStartEquity           = 0;
double   g_peakEquity               = 0;
datetime g_dayStart                 = 0;
datetime g_lastM5BarTime            = 0;
datetime g_lastSqueezeBarTime       = 0;
datetime g_lastMomentumBarTime      = 0;
datetime g_lastPullbackBarTime      = 0;
datetime g_lastTradeTime            = 0;
datetime g_lastClosedTradeTime      = 0;
int      g_lastClosedTicket         = 0;
int      g_consecutiveLosses        = 0;
int      g_tradesToday              = 0;
int      g_squeezeCount             = 0;
bool     g_haltedToday              = false;
bool     g_haltedPermanent          = false;
bool     g_targetHit                = false;
bool     g_campaignCheckpointHit    = false;
bool     g_campaignProtected        = false;
string   g_activeDXYSymbol          = "";

int      g_squeezeSignals           = 0;
int      g_momentumSignals          = 0;
int      g_pullbackSignals          = 0;
double   g_squeezeClosedPL          = 0;
double   g_momentumClosedPL         = 0;
double   g_pullbackClosedPL         = 0;
int      g_squeezeClosedTrades      = 0;
int      g_momentumClosedTrades     = 0;
int      g_pullbackClosedTrades     = 0;
int      g_squeezeClosedLosses      = 0;
int      g_momentumClosedLosses     = 0;
int      g_pullbackClosedLosses     = 0;
int      g_rejectRisk               = 0;
int      g_rejectRegime             = 0;
int      g_rejectDXY                = 0;
int      g_rejectSpread             = 0;
int      g_campaignScore            = 0;

//+------------------------------------------------------------------+
//| Trade setup structure                                             |
//+------------------------------------------------------------------+
struct TradeSetup
{
   bool   valid;
   int    orderType;
   int    magic;
   string label;
   double slDistance;
   double rr;
   double riskPct;
};

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   InitPipSize();
   g_startBalance   = AccountBalance();
   g_dayStart       = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   g_dayStartEquity = AccountEquity();
   g_peakEquity     = AccountEquity();

   if(UseDXYConfirmation || MomentumUseDXY || PullbackUseDXY)
      ResolveDXYSymbol();

   Print("=============================================");
   Print("LTS Prop Engine v5 initialized on ", Symbol());
   Print("Prop mode: ", (PropMode ? "ON" : "OFF"),
         " | Phase: ", PropPhase,
         " | Target: ", DoubleToString(GetTargetPct(), 1), "%");
   Print("Campaign mode: ", UseCampaignMode,
         " | checkpoint ", DoubleToString(CampaignCheckpointPct, 1),
         "% | push score ", CampaignPushMinScore);
   Print("Loss buffers: daily ", DoubleToString(MaxDailyLossPct, 1),
         "% | overall ", DoubleToString(MaxOverallLossPct, 1), "%");
   Print("Risk: standard ", DoubleToString(StandardRiskPct, 2),
         "% | reduced ", DoubleToString(ReducedRiskPct, 2),
         "% | high ", DoubleToString(HighConvictionRiskPct, 2), "%");
   Print("Strategies: Squeeze=", UseSqueezeStrategy,
         " Momentum=", UseMomentumStrategy,
         " Pullback=", UsePullbackStrategy);
   Print("DXY proxy: ", (StringLen(g_activeDXYSymbol) > 0 ? g_activeDXYSymbol : "none"));
   Print("=============================================");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
   Print("LTS Prop Engine v5 removed. Reason: ", reason);
   Print("Signals: squeeze=", g_squeezeSignals,
         " momentum=", g_momentumSignals,
         " pullback=", g_pullbackSignals);
   Print("Closed P/L: squeeze=", DoubleToString(g_squeezeClosedPL, 2), " (", g_squeezeClosedTrades, ")",
         " momentum=", DoubleToString(g_momentumClosedPL, 2), " (", g_momentumClosedTrades, ")",
         " pullback=", DoubleToString(g_pullbackClosedPL, 2), " (", g_pullbackClosedTrades, ")");
   Print("Closed losses: squeeze=", g_squeezeClosedLosses,
         " momentum=", g_momentumClosedLosses,
         " pullback=", g_pullbackClosedLosses);
   Print("Campaign: checkpoint=", g_campaignCheckpointHit,
         " protected=", g_campaignProtected,
         " score=", g_campaignScore,
         " return=", DoubleToString(CurrentReturnPct(), 2), "%");
   Print("Rejects: risk=", g_rejectRisk,
         " regime=", g_rejectRegime,
         " dxy=", g_rejectDXY,
         " spread=", g_rejectSpread);
}

//+------------------------------------------------------------------+
//| Main tick                                                         |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateDailyState();
   UpdatePeakEquity();
   UpdateClosedTradeState();
   ManageTargetLock();
   ManageCampaignMode();
   UpdateChartDisplay();

   if(g_haltedPermanent || g_targetHit)
      return;

   if(!IsNewBar(PERIOD_M5, g_lastM5BarTime))
      return;

   if(!CanTradeNow())
      return;

   EvaluateStrategies();
}

//+------------------------------------------------------------------+
//| Main strategy router                                              |
//+------------------------------------------------------------------+
void EvaluateStrategies()
{
   if(HasOpenTrade())
      return;

   if(MinBarsBetweenTrades > 0 && g_lastTradeTime > 0)
   {
      int secondsSinceTrade = (int)(TimeCurrent() - g_lastTradeTime);
      int minSeconds = MinBarsBetweenTrades * 3600;
      if(secondsSinceTrade < minSeconds)
         return;
   }

   TradeSetup setup;
   setup.valid = false;

   if(UseSqueezeStrategy && BuildSqueezeSetup(setup))
   {
      ExecuteSetup(setup);
      return;
   }

   if(UseMomentumStrategy && BuildMomentumSetup(setup))
   {
      ExecuteSetup(setup);
      return;
   }

   if(UsePullbackStrategy && BuildPullbackSetup(setup))
   {
      ExecuteSetup(setup);
      return;
   }
}

//+------------------------------------------------------------------+
//| Strategy A: squeeze release + DXY                                 |
//+------------------------------------------------------------------+
bool BuildSqueezeSetup(TradeSetup &setup)
{
   if(!StrategyEnabled(1))
      return false;

   if(!IsNewBar(SqueezeTF, g_lastSqueezeBarTime))
      return false;

   bool inSqueeze = CheckSqueeze(Symbol(), SqueezeTF, 1);
   if(inSqueeze)
   {
      g_squeezeCount++;
      return false;
   }

   if(g_squeezeCount < MinSqueezeBars)
   {
      if(g_squeezeCount > 0 && EnableDiagnostics)
         Print("Squeeze released with only ", g_squeezeCount, " bars");
      g_squeezeCount = 0;
      return false;
   }

   double close1 = iClose(Symbol(), SqueezeTF, 1);
   double ema20  = iMA(Symbol(), SqueezeTF, FastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   bool buy      = close1 > ema20;
   bool sell     = close1 < ema20;

   if(!buy && !sell)
   {
      g_squeezeCount = 0;
      return false;
   }

   if(SqueezeUseD1Trend && !TrendAllows(buy))
   {
      g_squeezeCount = 0;
      g_rejectRegime++;
      return false;
   }

   if(UseDXYConfirmation && !DXYAllows(buy))
   {
      g_squeezeCount = 0;
      g_rejectDXY++;
      return false;
   }

   double atr = iATR(Symbol(), SqueezeTF, ATRPeriod, 1);
   if(atr <= 0)
   {
      g_squeezeCount = 0;
      return false;
   }

   setup.valid      = true;
   setup.orderType  = buy ? OP_BUY : OP_SELL;
   setup.magic      = MagicBase + 1;
   setup.label      = "LTSv5 SQZ";
   setup.slDistance = atr * SqueezeATRSLMult;
   setup.rr         = SqueezeRR;
   setup.riskPct    = CurrentRiskPct(false) * SqueezeRiskMultiplier;

   g_squeezeCount = 0;
   g_squeezeSignals++;
   return true;
}

//+------------------------------------------------------------------+
//| Strategy B: momentum breakout                                     |
//+------------------------------------------------------------------+
bool BuildMomentumSetup(TradeSetup &setup)
{
   if(!StrategyEnabled(2))
      return false;

   if(!IsNewBar(MomentumTF, g_lastMomentumBarTime))
      return false;

   double adx = iADX(Symbol(), MomentumTF, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   if(adx < MomentumADXMin)
   {
      g_rejectRegime++;
      return false;
   }

   double close1 = iClose(Symbol(), MomentumTF, 1);
   double ema50  = iMA(Symbol(), MomentumTF, MidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema200 = iMA(Symbol(), MomentumTF, SlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);

   double highest = HighestHigh(Symbol(), MomentumTF, MomentumLookbackBars, 2);
   double lowest  = LowestLow(Symbol(), MomentumTF, MomentumLookbackBars, 2);

   bool buy  = close1 > highest && close1 > ema50 && ema50 > ema200;
   bool sell = close1 < lowest  && close1 < ema50 && ema50 < ema200;

   if(!buy && !sell)
      return false;

   if(MomentumRequireH4Trend && !H4TrendAllows(buy))
   {
      g_rejectRegime++;
      return false;
   }

   if(MomentumUseDXY && DXYAppliesToThisSymbol() && !DXYAllows(buy))
   {
      g_rejectDXY++;
      return false;
   }

   double atr = iATR(Symbol(), MomentumTF, ATRPeriod, 1);
   if(atr <= 0)
      return false;

   setup.valid      = true;
   setup.orderType  = buy ? OP_BUY : OP_SELL;
   setup.magic      = MagicBase + 2;
   setup.label      = "LTSv5 MOM";
   setup.slDistance = atr * MomentumATRSLMult;
   setup.rr         = MomentumRR;
   setup.riskPct    = CurrentRiskPct(true);

   g_momentumSignals++;
   return true;
}

//+------------------------------------------------------------------+
//| Strategy C: pullback continuation                                 |
//+------------------------------------------------------------------+
bool BuildPullbackSetup(TradeSetup &setup)
{
   if(!StrategyEnabled(3))
      return false;

   if(!IsNewBar(PullbackTF, g_lastPullbackBarTime))
      return false;

   double adx = iADX(Symbol(), PullbackTF, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   if(adx < PullbackADXMin)
   {
      g_rejectRegime++;
      return false;
   }

   double close1 = iClose(Symbol(), PullbackTF, 1);
   double open1  = iOpen(Symbol(), PullbackTF, 1);
   double low1   = iLow(Symbol(), PullbackTF, 1);
   double high1  = iHigh(Symbol(), PullbackTF, 1);
   double ema20  = iMA(Symbol(), PullbackTF, FastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema50  = iMA(Symbol(), PullbackTF, MidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema200 = iMA(Symbol(), PullbackTF, SlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);

   double maxDistance = PullbackMaxDistancePips * g_pipSize;

   bool trendUp       = close1 > ema50 && ema50 > ema200 && TrendAllows(true);
   bool trendDown     = close1 < ema50 && ema50 < ema200 && TrendAllows(false);
   bool buyPullback   = trendUp && low1 <= ema20 + maxDistance && close1 > ema20 && close1 > open1;
   bool sellPullback  = trendDown && high1 >= ema20 - maxDistance && close1 < ema20 && close1 < open1;

   if(!buyPullback && !sellPullback)
      return false;

   bool buy = buyPullback;

   if(PullbackRequireH4Trend && !H4TrendAllows(buy))
   {
      g_rejectRegime++;
      return false;
   }

   if(PullbackUseDXY && DXYAppliesToThisSymbol() && !DXYAllows(buy))
   {
      g_rejectDXY++;
      return false;
   }

   double atr = iATR(Symbol(), PullbackTF, ATRPeriod, 1);
   if(atr <= 0)
      return false;

   setup.valid      = true;
   setup.orderType  = buy ? OP_BUY : OP_SELL;
   setup.magic      = MagicBase + 3;
   setup.label      = "LTSv5 PBK";
   setup.slDistance = atr * PullbackATRSLMult;
   setup.rr         = PullbackRR;
   setup.riskPct    = CurrentRiskPct(true);

   g_pullbackSignals++;
   return true;
}

//+------------------------------------------------------------------+
//| Execute setup                                                     |
//+------------------------------------------------------------------+
bool ExecuteSetup(TradeSetup &setup)
{
   if(!setup.valid)
      return false;

   double spreadPips = (Ask - Bid) / g_pipSize;
   if(spreadPips > MaxSpreadPips)
   {
      g_rejectSpread++;
      if(EnableDiagnostics)
         Print("Spread reject: ", DoubleToString(spreadPips, 1), " > ", MaxSpreadPips);
      return false;
   }

   if(setup.riskPct <= 0.0)
   {
      g_rejectRegime++;
      return false;
   }

   if(setup.riskPct < MinRiskPct)
      setup.riskPct = MinRiskPct;

   double slPips = setup.slDistance / g_pipSize;
   if(slPips <= 0)
      return false;

   if(!RiskGovernorAllows(setup.riskPct))
   {
      g_rejectRisk++;
      return false;
   }

   if(!PropRiskRoomAllows(setup.riskPct))
   {
      g_rejectRisk++;
      return false;
   }

   double lots = CalculateLotSize(slPips, setup.riskPct);
   RefreshRates();

   double entry = setup.orderType == OP_BUY ? Ask : Bid;
   double sl    = 0;
   double tp    = 0;

   if(setup.orderType == OP_BUY)
   {
      sl = NormalizeDouble(entry - setup.slDistance, Digits);
      tp = NormalizeDouble(entry + setup.slDistance * setup.rr, Digits);
   }
   else
   {
      sl = NormalizeDouble(entry + setup.slDistance, Digits);
      tp = NormalizeDouble(entry - setup.slDistance * setup.rr, Digits);
   }

   int ticket = OrderSend(Symbol(), setup.orderType, lots, entry, Slippage, sl, tp,
                          setup.label, setup.magic, 0,
                          setup.orderType == OP_BUY ? clrGreen : clrRed);

   if(ticket < 0)
   {
      int err = GetLastError();
      Print(setup.label, " order failed. Error ", err,
            " entry=", DoubleToString(entry, Digits),
            " sl=", DoubleToString(sl, Digits),
            " tp=", DoubleToString(tp, Digits),
            " lots=", DoubleToString(lots, 2));
      return false;
   }

   g_tradesToday++;
   g_lastTradeTime = TimeCurrent();

   Print(setup.label, " opened #", ticket,
         " ", (setup.orderType == OP_BUY ? "BUY" : "SELL"),
         " lots=", DoubleToString(lots, 2),
         " risk=", DoubleToString(setup.riskPct, 2), "%",
         " entry=", DoubleToString(entry, Digits),
         " sl=", DoubleToString(sl, Digits),
         " tp=", DoubleToString(tp, Digits));

   return true;
}

//+------------------------------------------------------------------+
//| Prop/risk governor                                                |
//+------------------------------------------------------------------+
bool CanTradeNow()
{
   if(!IsTradingDay() || !IsWithinSession())
      return false;

   if(g_haltedToday)
      return false;

   if(MaxTradesPerDay > 0 && g_tradesToday >= MaxTradesPerDay)
      return false;

   if(PropMode)
   {
      if(CheckDailyLoss())
      {
         g_haltedToday = true;
         Print("PROP HALT: daily loss buffer reached");
         return false;
      }

      if(CheckOverallLoss())
      {
         g_haltedPermanent = true;
         Print("PROP HALT: overall loss buffer reached");
         CloseAllOpenTrades("Overall loss halt");
         return false;
      }

      if(CheckPreservationStop())
      {
         g_haltedPermanent = true;
         Print("PROP PRESERVATION STOP: challenge drawdown reached ",
               DoubleToString(CurrentOverallLossPct(), 2), "%");
         CloseAllOpenTrades("Preservation stop");
         return false;
      }

      if(CheckPeakDrawdownStop())
      {
         g_haltedPermanent = true;
         Print("PROP PEAK DD STOP: peak drawdown reached ",
               DoubleToString(CurrentPeakDrawdownPct(), 2), "%");
         CloseAllOpenTrades("Peak DD stop");
         return false;
      }

      if(UseCampaignMode && g_campaignCheckpointHit && CampaignHaltIfWeak && !CampaignAllowsPush())
      {
         g_haltedPermanent = true;
         g_campaignProtected = true;
         Print("CAMPAIGN PROTECT: checkpoint held, regime score ",
               g_campaignScore, "/", CampaignPushMinScore,
               ". Standing down at ", DoubleToString(CurrentReturnPct(), 2), "%");
         if(CampaignCloseOnWeak)
            CloseAllOpenTrades("Campaign protect");
         return false;
      }

      if(g_consecutiveLosses >= MaxConsecutiveLosses)
      {
         g_haltedToday = true;
         Print("PROP HALT: consecutive loss limit reached");
         return false;
      }

      if(UseNewsGuard && IsNearMajorNews())
         return false;
   }

   return true;
}

bool RiskGovernorAllows(double nextRiskPct)
{
   double openRisk = EstimateOpenRiskPct();
   if(openRisk + nextRiskPct > MaxTotalOpenRiskPct)
      return false;

   if(PropMode)
   {
      double dailyLossPct = CurrentDailyLossPct();
      if(dailyLossPct >= DailySoftStopPct && nextRiskPct > ReducedRiskPct + 0.01)
         return false;
   }

   return true;
}

bool PropRiskRoomAllows(double nextRiskPct)
{
   if(!PropMode)
      return true;

   double dailyLossPct = CurrentDailyLossPct();
   double overallLossPct = CurrentOverallLossPct();

   double dailyRoom = MaxDailyLossPct - RiskBufferPct - dailyLossPct;
   double overallRoom = MaxOverallLossPct - RiskBufferPct - overallLossPct;

   if(dailyRoom <= 0 || overallRoom <= 0)
      return false;

   if(nextRiskPct > dailyRoom || nextRiskPct > overallRoom)
   {
      if(EnableDiagnostics)
      {
         Print("Risk room reject: nextRisk=", DoubleToString(nextRiskPct, 2),
               "% dailyRoom=", DoubleToString(dailyRoom, 2),
               "% overallRoom=", DoubleToString(overallRoom, 2), "%");
      }
      return false;
   }

   return true;
}

double CurrentRiskPct(bool highConviction)
{
   if(BlockChopRegime && IsChopRegime())
      return 0.0;

   if(PropMode && CurrentDailyLossPct() >= DailySoftStopPct)
      return CampaignAdjustedRisk(ReducedRiskPct);

   if(PropMode && CurrentOverallLossPct() >= MaxOverallLossPct * 0.50)
      return CampaignAdjustedRisk(ReducedRiskPct);

   if(g_consecutiveLosses > 0)
      return CampaignAdjustedRisk(ReducedRiskPct);

   if(highConviction && IsDirectionalRegime())
      return CampaignAdjustedRisk(HighConvictionRiskPct);

   return CampaignAdjustedRisk(StandardRiskPct);
}

double CampaignAdjustedRisk(double baseRiskPct)
{
   if(!UseCampaignMode || !g_campaignCheckpointHit)
      return baseRiskPct;

   if(!CampaignAllowsPush())
      return 0.0;

   if(CampaignMaxRiskPct > 0 && baseRiskPct > CampaignMaxRiskPct)
      return CampaignMaxRiskPct;

   return baseRiskPct;
}

void ManageTargetLock()
{
   if(!PropMode || g_targetHit)
      return;

   double targetPct = GetTargetPct();
   if(targetPct <= 0)
      return;

   double returnPct = (AccountEquity() - g_startBalance) / g_startBalance * 100.0;
   if(returnPct < targetPct)
      return;

   g_targetHit = true;
   Print("PROP TARGET HIT: ", DoubleToString(returnPct, 2), "%");

   if(CloseAtTarget)
      CloseAllOpenTrades("Target lock");
}

void ManageCampaignMode()
{
   if(!PropMode || !UseCampaignMode || g_targetHit || g_haltedPermanent)
      return;

   double targetPct = GetTargetPct();
   if(CampaignCheckpointPct <= 0 || targetPct <= CampaignCheckpointPct)
      return;

   double returnPct = CurrentReturnPct();

   if(!g_campaignCheckpointHit && returnPct >= CampaignCheckpointPct)
   {
      g_campaignCheckpointHit = true;
      g_peakEquity = MathMax(g_peakEquity, AccountEquity());
      Print("CAMPAIGN CHECKPOINT HIT: ", DoubleToString(returnPct, 2),
            "% | regime score ", CampaignRegimeScore(), "/", CampaignPushMinScore);
   }

   if(!g_campaignCheckpointHit)
      return;

   if(CampaignProfitFloorPct > 0 && returnPct <= CampaignProfitFloorPct)
   {
      g_haltedPermanent = true;
      g_campaignProtected = true;
      Print("CAMPAIGN PROFIT FLOOR STOP: return gave back to ",
            DoubleToString(returnPct, 2), "%");
      CloseAllOpenTrades("Campaign floor stop");
      return;
   }

   if(CampaignHaltIfWeak && !CampaignAllowsPush())
   {
      g_haltedPermanent = true;
      g_campaignProtected = true;
      Print("CAMPAIGN CHECKPOINT PROTECT: weak push score ",
            g_campaignScore, "/", CampaignPushMinScore,
            ". Standing down at ", DoubleToString(returnPct, 2), "%");
      if(CampaignCloseOnWeak)
         CloseAllOpenTrades("Campaign checkpoint protect");
   }
}

double CurrentReturnPct()
{
   if(g_startBalance <= 0)
      return 0.0;

   return (AccountEquity() - g_startBalance) / g_startBalance * 100.0;
}

bool CampaignAllowsPush()
{
   if(!UseCampaignMode || !g_campaignCheckpointHit)
      return true;

   return (CampaignRegimeScore() >= CampaignPushMinScore);
}

int CampaignRegimeScore()
{
   int score = 0;

   double h1Close = iClose(Symbol(), PERIOD_H1, 1);
   double h1Ema20 = iMA(Symbol(), PERIOD_H1, FastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double h1Ema50 = iMA(Symbol(), PERIOD_H1, MidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double h1Ema200 = iMA(Symbol(), PERIOD_H1, SlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double h1Adx = iADX(Symbol(), PERIOD_H1, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);

   double h4Close = iClose(Symbol(), PERIOD_H4, 1);
   double h4Ema50 = iMA(Symbol(), PERIOD_H4, MidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double h4Ema200 = iMA(Symbol(), PERIOD_H4, SlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double h4Adx = iADX(Symbol(), PERIOD_H4, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);

   if(h1Close <= 0 || h1Ema20 <= 0 || h1Ema50 <= 0 || h1Ema200 <= 0 ||
      h4Close <= 0 || h4Ema50 <= 0 || h4Ema200 <= 0)
   {
      g_campaignScore = 0;
      return g_campaignScore;
   }

   bool buyBias = h1Close > h1Ema50;
   bool h1Stack = buyBias
      ? (h1Close > h1Ema20 && h1Ema20 > h1Ema50 && h1Ema50 > h1Ema200)
      : (h1Close < h1Ema20 && h1Ema20 < h1Ema50 && h1Ema50 < h1Ema200);
   bool h4Stack = buyBias
      ? (h4Close > h4Ema50 && h4Ema50 > h4Ema200)
      : (h4Close < h4Ema50 && h4Ema50 < h4Ema200);

   if(h1Adx >= MomentumADXMin)
      score++;
   if(h4Adx >= H4TrendADXMin + 4.0)
      score++;
   if(h1Stack)
      score++;
   if(h4Stack)
      score++;
   if(!DXYAppliesToThisSymbol() || DXYAllows(buyBias))
      score++;

   g_campaignScore = score;
   return g_campaignScore;
}

double GetTargetPct()
{
   if(PropPhase == 1) return Phase1TargetPct;
   if(PropPhase == 2) return Phase2TargetPct;
   return 0.0;
}

bool CheckDailyLoss()
{
   double lossPct = CurrentDailyLossPct();
   return (lossPct >= MaxDailyLossPct);
}

bool CheckOverallLoss()
{
   double lossPct = CurrentOverallLossPct();
   return (lossPct >= MaxOverallLossPct);
}

bool CheckPreservationStop()
{
   if(ChallengePreserveLossPct <= 0)
      return false;

   return (CurrentOverallLossPct() >= ChallengePreserveLossPct);
}

bool CheckPeakDrawdownStop()
{
   if(PeakDrawdownStopPct <= 0)
      return false;

   return (CurrentPeakDrawdownPct() >= PeakDrawdownStopPct);
}

double CurrentOverallLossPct()
{
   if(g_startBalance <= 0)
      return 0.0;

   double lossPct = (g_startBalance - AccountEquity()) / g_startBalance * 100.0;
   return MathMax(0.0, lossPct);
}

double CurrentDailyLossPct()
{
   if(g_dayStartEquity <= 0)
      return 0.0;

   double lossPct = (g_dayStartEquity - AccountEquity()) / g_dayStartEquity * 100.0;
   return MathMax(0.0, lossPct);
}

double CurrentPeakDrawdownPct()
{
   if(g_peakEquity <= 0)
      return 0.0;

   double ddPct = (g_peakEquity - AccountEquity()) / g_peakEquity * 100.0;
   return MathMax(0.0, ddPct);
}

void UpdatePeakEquity()
{
   if(AccountEquity() > g_peakEquity)
      g_peakEquity = AccountEquity();
}

void UpdateDailyState()
{
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_dayStart)
   {
      g_dayStart       = today;
      g_dayStartEquity = AccountEquity();
      g_tradesToday    = 0;
      g_haltedToday    = false;
      g_consecutiveLosses = 0;
   }
}

void UpdateClosedTradeState()
{
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      int magic = OrderMagicNumber();
      if(magic < MagicBase || magic > MagicBase + 20)
         continue;

      if(OrderCloseTime() < g_dayStart)
         break;

      if(OrderTicket() != g_lastClosedTicket && OrderCloseTime() > g_lastClosedTradeTime)
      {
         double pl = OrderProfit() + OrderSwap() + OrderCommission();
         if(pl < 0)
            g_consecutiveLosses++;
         else
            g_consecutiveLosses = 0;

         if(magic == MagicBase + 1)
         {
            g_squeezeClosedPL += pl;
            g_squeezeClosedTrades++;
            if(pl < 0) g_squeezeClosedLosses++;
         }
         else if(magic == MagicBase + 2)
         {
            g_momentumClosedPL += pl;
            g_momentumClosedTrades++;
            if(pl < 0) g_momentumClosedLosses++;
         }
         else if(magic == MagicBase + 3)
         {
            g_pullbackClosedPL += pl;
            g_pullbackClosedTrades++;
            if(pl < 0) g_pullbackClosedLosses++;
         }

         g_lastClosedTicket    = OrderTicket();
         g_lastClosedTradeTime = OrderCloseTime();
         break;
      }
   }
}

bool StrategyEnabled(int strategyId)
{
   if(StrategyMaxLossPct <= 0 && StrategyMaxLossTrades <= 0)
      return true;

   double maxLossMoney = g_startBalance * StrategyMaxLossPct / 100.0;
   double pl = 0;
   int losses = 0;

   if(strategyId == 1)
   {
      pl = g_squeezeClosedPL;
      losses = g_squeezeClosedLosses;
   }
   else if(strategyId == 2)
   {
      pl = g_momentumClosedPL;
      losses = g_momentumClosedLosses;
   }
   else if(strategyId == 3)
   {
      pl = g_pullbackClosedPL;
      losses = g_pullbackClosedLosses;
   }

   if(StrategyMaxLossPct > 0 && pl <= -maxLossMoney)
   {
      g_rejectRisk++;
      return false;
   }

   if(StrategyMaxLossTrades > 0 && losses >= StrategyMaxLossTrades)
   {
      g_rejectRisk++;
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Market state helpers                                              |
//+------------------------------------------------------------------+
bool IsDirectionalRegime()
{
   double adx = iADX(Symbol(), PERIOD_H1, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   if(adx < DirectionalADXMin)
      return false;

   double ema50  = iMA(Symbol(), PERIOD_H1, MidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema200 = iMA(Symbol(), PERIOD_H1, SlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double close1 = iClose(Symbol(), PERIOD_H1, 1);

   return ((close1 > ema50 && ema50 > ema200) ||
           (close1 < ema50 && ema50 < ema200));
}

bool H4TrendAllows(bool wantBuy)
{
   if(!RequireH4TrendAlignment)
      return true;

   double adx = iADX(Symbol(), PERIOD_H4, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   if(adx > 0 && adx < H4TrendADXMin)
      return false;

   double close1 = iClose(Symbol(), PERIOD_H4, 1);
   double ema50  = iMA(Symbol(), PERIOD_H4, MidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema200 = iMA(Symbol(), PERIOD_H4, SlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);

   if(close1 <= 0 || ema50 <= 0 || ema200 <= 0)
      return true;

   if(wantBuy)
      return (close1 > ema50 && ema50 > ema200);

   return (close1 < ema50 && ema50 < ema200);
}

bool IsChopRegime()
{
   double adx = iADX(Symbol(), PERIOD_H1, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   return (adx > 0 && adx <= ChopADXMax);
}

bool TrendAllows(bool wantBuy)
{
   double ema = iMA(Symbol(), PERIOD_D1, MidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double price = (Ask + Bid) / 2.0;
   if(ema <= 0)
      return true;

   if(wantBuy)
      return price > ema;
   return price < ema;
}

bool CheckSqueeze(string symbol, int tf, int shift)
{
   double bbUpper = iBands(symbol, tf, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_UPPER, shift);
   double bbLower = iBands(symbol, tf, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_LOWER, shift);
   double kcMid   = iMA(symbol, tf, KCPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);
   double kcATR   = iATR(symbol, tf, KCATRPeriod, shift);
   double kcUpper = kcMid + KCMultiplier * kcATR;
   double kcLower = kcMid - KCMultiplier * kcATR;

   return (bbUpper < kcUpper && bbLower > kcLower);
}

double HighestHigh(string symbol, int tf, int bars, int startShift)
{
   double highest = -1;
   for(int i = startShift; i < startShift + bars; i++)
   {
      double value = iHigh(symbol, tf, i);
      if(value > highest)
         highest = value;
   }
   return highest;
}

double LowestLow(string symbol, int tf, int bars, int startShift)
{
   double lowest = 999999999;
   for(int i = startShift; i < startShift + bars; i++)
   {
      double value = iLow(symbol, tf, i);
      if(value > 0 && value < lowest)
         lowest = value;
   }
   return lowest;
}

//+------------------------------------------------------------------+
//| DXY helpers                                                       |
//+------------------------------------------------------------------+
void ResolveDXYSymbol()
{
   if(StringLen(DXYSymbol) > 0)
   {
      double testPrice = iClose(DXYSymbol, DXYTimeframe, 1);
      if(testPrice > 0)
      {
         g_activeDXYSymbol = DXYSymbol;
         return;
      }
   }

   string candidates[] = {"USDX", "DXY", "DX", "USDollarIndex", "DXY.USD"};
   for(int i = 0; i < ArraySize(candidates); i++)
   {
      double testPrice = iClose(candidates[i], DXYTimeframe, 1);
      if(testPrice > 0)
      {
         g_activeDXYSymbol = candidates[i];
         return;
      }
   }

   if(DXYInverseFallback)
   {
      double eurPrice = iClose("EURUSD", DXYTimeframe, 1);
      if(eurPrice > 0)
         g_activeDXYSymbol = "EURUSD_INV";
   }
}

bool DXYAppliesToThisSymbol()
{
   string symbol = Symbol();
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      return true;
   if(StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "SILVER") >= 0)
      return true;
   return UseDXYForIndices;
}

bool DXYAllows(bool wantBuy)
{
   if(!UseDXYConfirmation && !MomentumUseDXY && !PullbackUseDXY)
      return true;

   if(StringLen(g_activeDXYSymbol) == 0)
      return true;

   bool dxyFalling = false;
   bool dxyRising  = false;

   if(g_activeDXYSymbol == "EURUSD_INV")
   {
      double eurPrice = iClose("EURUSD", DXYTimeframe, 1);
      double eurEMA   = iMA("EURUSD", DXYTimeframe, DXYEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
      if(eurPrice <= 0 || eurEMA <= 0)
         return true;

      dxyFalling = eurPrice > eurEMA;
      dxyRising  = eurPrice < eurEMA;
   }
   else
   {
      double dxyPrice = iClose(g_activeDXYSymbol, DXYTimeframe, 1);
      double dxyEMA   = iMA(g_activeDXYSymbol, DXYTimeframe, DXYEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
      if(dxyPrice <= 0 || dxyEMA <= 0)
         return true;

      dxyFalling = dxyPrice < dxyEMA;
      dxyRising  = dxyPrice > dxyEMA;
   }

   if(wantBuy && dxyFalling)
      return true;
   if(!wantBuy && dxyRising)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Time and execution helpers                                        |
//+------------------------------------------------------------------+
bool IsNewBar(int tf, datetime &lastBarTime)
{
   datetime current = iTime(Symbol(), tf, 0);
   if(current != lastBarTime)
   {
      lastBarTime = current;
      return true;
   }
   return false;
}

int UKToServerHour(int ukHour)
{
   int ukOffset = UKSummerTime ? 1 : 0;
   int serverHour = ukHour - ukOffset + BrokerUTCOffset;
   while(serverHour < 0) serverHour += 24;
   return serverHour % 24;
}

bool IsWithinSession()
{
   int hour = TimeHour(TimeCurrent());
   int start = UKToServerHour(SessionStartHour);
   int end = UKToServerHour(SessionEndHour);

   if(start < end)
      return (hour >= start && hour < end);

   return (hour >= start || hour < end);
}

bool IsTradingDay()
{
   int dow = DayOfWeek();
   if(dow == 1) return TradeMonday;
   if(dow == 2) return TradeTuesday;
   if(dow == 3) return TradeWednesday;
   if(dow == 4) return TradeThursday;
   if(dow == 5) return TradeFriday;
   return false;
}

bool IsNearMajorNews()
{
   datetime t = TimeCurrent();
   int hour   = TimeHour(t);
   int day    = TimeDay(t);
   int dow    = DayOfWeek();
   int month  = TimeMonth(t);

   int utcHour = hour - BrokerUTCOffset;
   while(utcHour < 0) utcHour += 24;
   utcHour = utcHour % 24;

   if(dow == 5 && day <= 7 && utcHour == 13)
      return true;

   if(day >= 12 && day <= 14 && utcHour == 13)
      return true;

   bool fomcMonth = (month == 1 || month == 3 || month == 5 || month == 6 ||
                     month == 7 || month == 9 || month == 11);
   if(fomcMonth && dow == 3 && day >= 15 && day <= 21 && (utcHour == 18 || utcHour == 19))
      return true;

   return false;
}

bool HasOpenTrade()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      int magic = OrderMagicNumber();
      if(magic >= MagicBase && magic <= MagicBase + 20)
      {
         if(OrderType() == OP_BUY || OrderType() == OP_SELL)
            return true;
      }
   }
   return false;
}

double EstimateOpenRiskPct()
{
   double riskMoney = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol())
         continue;

      int magic = OrderMagicNumber();
      if(magic < MagicBase || magic > MagicBase + 20)
         continue;

      if(OrderStopLoss() <= 0)
         continue;

      double distance = MathAbs(OrderOpenPrice() - OrderStopLoss());
      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
      if(tickValue <= 0 || tickSize <= 0)
         continue;

      riskMoney += distance / tickSize * tickValue * OrderLots();
   }

   if(AccountBalance() <= 0)
      return 0;

   return riskMoney / AccountBalance() * 100.0;
}

void CloseAllOpenTrades(string reason)
{
   RefreshRates();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol())
         continue;

      int magic = OrderMagicNumber();
      if(magic < MagicBase || magic > MagicBase + 20)
         continue;

      bool ok = false;
      if(OrderType() == OP_BUY)
         ok = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrYellow);
      else if(OrderType() == OP_SELL)
         ok = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrYellow);

      if(ok)
         Print(reason, ": closed #", OrderTicket());
      else
         Print(reason, ": close failed #", OrderTicket(), " error=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Lot sizing                                                        |
//+------------------------------------------------------------------+
void InitPipSize()
{
   if(Digits == 5 || Digits == 3)
      g_pipSize = Point * 10;
   else if(Digits <= 2)
      g_pipSize = 1.0;
   else
      g_pipSize = Point;

   if(StringFind(Symbol(), "XAG") >= 0 && Digits <= 3)
      g_pipSize = 0.01;
}

double CalculateLotSize(double slDistancePips, double riskPct)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   if(minLot <= 0 || minLot > 99999)
      minLot = 0.01;

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tickValue <= 0 || tickSize <= 0 || slDistancePips <= 0)
      return minLot;

   double accountRisk = AccountBalance() * riskPct / 100.0;
   double pipValuePerLot = tickValue * (g_pipSize / tickSize);
   if(pipValuePerLot <= 0)
      return minLot;

   double lots = accountRisk / (slDistancePips * pipValuePerLot);
   return NormalizeLots(lots);
}

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

   int lotDecimals = LotStepDecimals(lotStep);
   return NormalizeDouble(lots, lotDecimals);
}

int LotStepDecimals(double lotStep)
{
   int decimals = 0;
   double step = lotStep;

   while(decimals < 8 && MathAbs(step - MathRound(step)) > 0.0000001)
   {
      step *= 10.0;
      decimals++;
   }

   return decimals;
}

//+------------------------------------------------------------------+
//| On-chart display                                                  |
//+------------------------------------------------------------------+
void UpdateChartDisplay()
{
   double returnPct = CurrentReturnPct();
   double spreadPips = (Ask - Bid) / g_pipSize;
   double targetPct = GetTargetPct();

   string text = "";
   text += "=== LTS Prop Engine v5.1 ===\n";
   text += "Symbol: " + Symbol() + " | Spread: " + DoubleToString(spreadPips, 1) + " pips\n";
   text += "Return: " + DoubleToString(returnPct, 2) + "%";
   if(targetPct > 0)
      text += " / " + DoubleToString(targetPct, 1) + "% target";
   text += "\n";
   text += "Daily loss: " + DoubleToString(CurrentDailyLossPct(), 2) + "% / " +
           DoubleToString(MaxDailyLossPct, 1) + "%\n";
   text += "Trades today: " + IntegerToString(g_tradesToday) +
           " | Loss streak: " + IntegerToString(g_consecutiveLosses) + "\n";
   text += "Regime: ";
   if(IsDirectionalRegime()) text += "DIRECTIONAL";
   else if(IsChopRegime()) text += "CHOP";
   else text += "NORMAL";
   text += "\n";
   if(UseCampaignMode)
   {
      text += "Campaign: ";
      if(g_campaignCheckpointHit)
         text += "CHECKPOINT | score " + IntegerToString(CampaignRegimeScore()) +
                 "/" + IntegerToString(CampaignPushMinScore);
      else
         text += "building to " + DoubleToString(CampaignCheckpointPct, 1) + "% checkpoint";
      text += "\n";
   }
   text += "Signals SQZ/MOM/PBK: " + IntegerToString(g_squeezeSignals) + "/" +
           IntegerToString(g_momentumSignals) + "/" +
           IntegerToString(g_pullbackSignals) + "\n";

   if(g_targetHit)
      text += ">>> TARGET HIT <<<\n";
   else if(g_haltedPermanent)
      text += ">>> HALTED PERMANENTLY <<<\n";
   else if(g_haltedToday)
      text += ">>> HALTED TODAY <<<\n";

   Comment(text);
}

//+------------------------------------------------------------------+
