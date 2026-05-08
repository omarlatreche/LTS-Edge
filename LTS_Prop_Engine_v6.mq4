//+------------------------------------------------------------------+
//|                                      LTS_Prop_Engine_v6.mq4       |
//|             Regime-gated FTMO campaign engine for XAUUSD          |
//|                                                                  |
//|  Goal: maximize probability of reaching the phase target before  |
//|  breaching daily or overall loss limits. v6 waits for suitable   |
//|  gold campaign conditions before starting an attempt.             |
//+------------------------------------------------------------------+
#property copyright "LTS Prop Engine v6"
#property link      ""
#property version   "6.20"
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
input double   PeakDrawdownStopPct       = 7.0;     // Stop after giving back this much from peak equity
input double   DailySoftStopPct          = 2.5;     // Reduce risk after this daily drawdown
input int      MaxConsecutiveLosses      = 3;
input int      MaxTradesPerDay           = 3;
input bool     CloseAtTarget             = true;
input bool     UseNewsGuard              = true;

// --- v6 start gate / campaign start filter ---
input bool     XAUUSDOnly                = true;
input bool     UseStartGate              = true;
input int      StartGateMinScore         = 7;       // 0-8 score required to start attempt
input double   StartGateH1ADXMin         = 20.0;
input double   StartGateH4ADXMin         = 18.0;
input double   StartGateMaxD1ExtensionATR = 2.50;   // Avoid starting when price is too far from D1 EMA50
input int      StartGateATRFastPeriod    = 14;
input int      StartGateATRSlowPeriod    = 50;
input double   StartGateMinATRRatio      = 0.85;    // H1 ATR14 / H1 ATR50
input bool     StartGateRequireDXY       = true;

// --- Campaign mode ---
input bool     UseCampaignMode           = true;
input double   CampaignCheckpointPct     = 5.0;     // Protect once this profit is reached
input double   CampaignProfitFloorPct    = 1.5;     // Stop if checkpoint profit gives back to here
input int      CampaignPushMinScore      = 4;       // 0-5 regime score needed to continue after checkpoint
input double   CampaignMaxRiskPct        = 1.00;    // Max risk after checkpoint, even in strong regimes
input bool     UseCheckpointWeakPushGuard = false;  // Stop new trades after checkpoint if push score is weak
input bool     CheckpointWeakGuardCloseTrades = false; // Close open trades when weak guard blocks
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
input bool     UseAdaptiveStrategyLossLimit = true; // Allow more module runway after checkpoint
input int      StrategyMaxLossTradesStrong = 4;     // Module loss limit after checkpoint

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
input int      MagicBase                 = 89000;
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
input string   DXYSymbol                 = "";      // Blank = use broker-portable EURUSD inverse fallback
input bool     DXYInverseFallback        = true;
input int      DXYTimeframe              = PERIOD_H1;
input int      DXYEMAPeriod              = 20;
input bool     UseDXYForIndices          = false;   // Keep false for US30/NAS/SPX exploration

// --- Strategy A: v4.5 squeeze + DXY ---
input bool     UseSqueezeStrategy        = false;
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
enum V6CampaignState
{
   WAITING_FOR_START = 0,
   ACTIVE_CHALLENGE  = 1,
   PROTECTING_PROFIT = 2,
   TARGET_HIT        = 3,
   FAILED_STANDDOWN  = 4
};

double   g_pipSize                  = 0;
double   g_startBalance             = 0;
double   g_dayStartEquity           = 0;
double   g_peakEquity               = 0;
double   g_maxDrawdownMoney         = 0;
double   g_maxDrawdownPct           = 0;
datetime g_dayStart                 = 0;
datetime g_testStartTime            = 0;
datetime g_lastM5BarTime            = 0;
datetime g_lastSqueezeBarTime       = 0;
datetime g_lastMomentumBarTime      = 0;
datetime g_lastPullbackBarTime      = 0;
datetime g_lastStartGateBarTime     = 0;
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
bool     g_startGateOpened          = false;
datetime g_startGateOpenTime        = 0;
datetime g_targetHitTime            = 0;
datetime g_checkpointHitTime        = 0;
int      g_campaignState            = WAITING_FOR_START;
int      g_startGateScore           = 0;
int      g_startGateDirection       = 0;
int      g_rejectStartGate          = 0;
string   g_startGateReason          = "not evaluated";
string   g_campaignStateReason      = "initialized";
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
int      g_rejectRiskOpenCap        = 0;
int      g_rejectRiskDailySoft      = 0;
int      g_rejectRiskPropRoom       = 0;
int      g_rejectRiskStrategyPL     = 0;
int      g_rejectRiskStrategyLosses = 0;
int      g_rejectRegime             = 0;
int      g_rejectDXY                = 0;
int      g_rejectSpread             = 0;
int      g_campaignScore            = 0;
bool     g_strategyPLCounted[4];
bool     g_strategyLossCounted[4];
int      g_checkpointWeakGuardBlocks = 0;
bool     g_checkpointWeakGuardActive = false;

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
   g_testStartTime  = TimeCurrent();
   g_dayStart       = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   g_dayStartEquity = AccountEquity();
   g_peakEquity     = AccountEquity();
   g_campaignState  = (UseStartGate && PropMode) ? WAITING_FOR_START : ACTIVE_CHALLENGE;
   g_startGateOpened = (g_campaignState == ACTIVE_CHALLENGE);

   if(UseDXYConfirmation || MomentumUseDXY || PullbackUseDXY)
      ResolveDXYSymbol();

   if(XAUUSDOnly && !IsXauSymbol())
   {
      g_haltedPermanent = true;
      g_campaignState = FAILED_STANDDOWN;
      Print("V6 symbol guard: ", Symbol(), " is not XAU/GOLD. EA halted because XAUUSDOnly=true.");
   }

   Print("=============================================");
   Print("LTS Prop Engine v6 initialized on ", Symbol());
   Print("Prop mode: ", (PropMode ? "ON" : "OFF"),
         " | Phase: ", PropPhase,
         " | Target: ", DoubleToString(GetTargetPct(), 1), "%");
   Print("State: ", CampaignStateName(),
         " | Start gate: ", (UseStartGate ? "ON" : "OFF"),
         " | min score ", StartGateMinScore, "/8");
   Print("Campaign mode: ", UseCampaignMode,
         " | checkpoint ", DoubleToString(CampaignCheckpointPct, 1),
         "% | push score ", CampaignPushMinScore);
   Print("Checkpoint weak guard: ", UseCheckpointWeakPushGuard,
         " | close trades=", CheckpointWeakGuardCloseTrades);
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
void GetClosedTradeStats(int &totalTrades,
                         int &profitTrades,
                         int &lossTrades,
                         int &longTrades,
                         int &longWins,
                         int &shortTrades,
                         int &shortWins,
                         double &grossProfit,
                         double &grossLoss)
{
   totalTrades = 0;
   profitTrades = 0;
   lossTrades = 0;
   longTrades = 0;
   longWins = 0;
   shortTrades = 0;
   shortWins = 0;
   grossProfit = 0.0;
   grossLoss = 0.0;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      int magic = OrderMagicNumber();
      if(magic < MagicBase || magic > MagicBase + 20)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      double pl = OrderProfit() + OrderSwap() + OrderCommission();
      totalTrades++;

      if(type == OP_BUY)
      {
         longTrades++;
         if(pl > 0) longWins++;
      }
      else if(type == OP_SELL)
      {
         shortTrades++;
         if(pl > 0) shortWins++;
      }

      if(pl > 0)
      {
         grossProfit += pl;
         profitTrades++;
      }
      else if(pl < 0)
      {
         grossLoss += pl;
         lossTrades++;
      }
   }
}

string TimeOrDash(datetime value)
{
   if(value <= 0)
      return "-";
   return TimeToString(value, TIME_DATE | TIME_MINUTES);
}

void PrintTestSummary(const int reason)
{
   int totalTrades;
   int profitTrades;
   int lossTrades;
   int longTrades;
   int longWins;
   int shortTrades;
   int shortWins;
   double grossProfit;
   double grossLoss;

   GetClosedTradeStats(totalTrades, profitTrades, lossTrades, longTrades, longWins,
                       shortTrades, shortWins, grossProfit, grossLoss);

   double netProfit = AccountBalance() - g_startBalance;
   double balanceReturnPct = (g_startBalance > 0) ? netProfit / g_startBalance * 100.0 : 0.0;
   double equityReturnPct = CurrentReturnPct();
   double profitFactor = (grossLoss < 0) ? grossProfit / MathAbs(grossLoss) : 0.0;
   double expectedPayoff = (totalTrades > 0) ? netProfit / totalTrades : 0.0;
   double winRate = (totalTrades > 0) ? 100.0 * profitTrades / totalTrades : 0.0;
   double longWinRate = (longTrades > 0) ? 100.0 * longWins / longTrades : 0.0;
   double shortWinRate = (shortTrades > 0) ? 100.0 * shortWins / shortTrades : 0.0;

   Print("========== V6 TEST SUMMARY ==========");
   Print("Result: state=", CampaignStateName(),
         " | reason=", g_campaignStateReason,
         " | targetHit=", g_targetHit,
         " | deinit=", reason);
   Print("Dates: testerStart=", TimeOrDash(g_testStartTime),
         " | gateOpen=", TimeOrDash(g_startGateOpenTime),
         " | checkpoint=", TimeOrDash(g_checkpointHitTime),
         " | target=", TimeOrDash(g_targetHitTime));
   Print("Account: start=", DoubleToString(g_startBalance, 2),
         " | balance=", DoubleToString(AccountBalance(), 2),
         " | equity=", DoubleToString(AccountEquity(), 2),
         " | net=", DoubleToString(netProfit, 2),
         " | returnBalance=", DoubleToString(balanceReturnPct, 2), "%",
         " | returnEquity=", DoubleToString(equityReturnPct, 2), "%");
   Print("Report: PF=", DoubleToString(profitFactor, 2),
         " | expectedPayoff=", DoubleToString(expectedPayoff, 2),
         " | grossProfit=", DoubleToString(grossProfit, 2),
         " | grossLoss=", DoubleToString(grossLoss, 2),
         " | maxDD=", DoubleToString(g_maxDrawdownMoney, 2),
         " (", DoubleToString(g_maxDrawdownPct, 2), "%)");
   Print("Trades: total=", totalTrades,
         " | wins=", profitTrades,
         " | losses=", lossTrades,
         " | winRate=", DoubleToString(winRate, 2), "%",
         " | longs=", longTrades, " (", DoubleToString(longWinRate, 2), "%)",
         " | shorts=", shortTrades, " (", DoubleToString(shortWinRate, 2), "%)");
   Print("Modules: squeeze=", DoubleToString(g_squeezeClosedPL, 2), " (", g_squeezeClosedTrades, " trades, ", g_squeezeClosedLosses, " losses)",
         " | momentum=", DoubleToString(g_momentumClosedPL, 2), " (", g_momentumClosedTrades, " trades, ", g_momentumClosedLosses, " losses)",
         " | pullback=", DoubleToString(g_pullbackClosedPL, 2), " (", g_pullbackClosedTrades, " trades, ", g_pullbackClosedLosses, " losses)");
   Print("Signals: squeeze=", g_squeezeSignals,
         " | momentum=", g_momentumSignals,
         " | pullback=", g_pullbackSignals);
   Print("Campaign: checkpoint=", g_campaignCheckpointHit,
         " | protected=", g_campaignProtected,
         " | score=", g_campaignScore,
         " | weakGuardActive=", g_checkpointWeakGuardActive,
         " | weakGuardBlocks=", g_checkpointWeakGuardBlocks,
         " | peakEquity=", DoubleToString(g_peakEquity, 2),
         " | startGateOpened=", g_startGateOpened,
         " | startScore=", g_startGateScore, "/8",
         " | direction=", DirectionName(g_startGateDirection),
         " | gateReason=", g_startGateReason);
   Print("Rejects: risk=", g_rejectRisk,
         " | regime=", g_rejectRegime,
         " | startGate=", g_rejectStartGate,
         " | dxy=", g_rejectDXY,
         " | spread=", g_rejectSpread);
   Print("RiskRejectDetail: openCap=", g_rejectRiskOpenCap,
         " | dailySoft=", g_rejectRiskDailySoft,
         " | propRoom=", g_rejectRiskPropRoom,
         " | strategyPL=", g_rejectRiskStrategyPL,
         " | strategyLosses=", g_rejectRiskStrategyLosses);
   Print("Settings: gateMin=", StartGateMinScore,
         " | squeeze=", UseSqueezeStrategy,
         " | momentum=", UseMomentumStrategy,
         " | pullback=", UsePullbackStrategy,
         " | peakDDStop=", DoubleToString(PeakDrawdownStopPct, 1),
         " | checkpoint=", DoubleToString(CampaignCheckpointPct, 1),
         " | floor=", DoubleToString(CampaignProfitFloorPct, 1),
         " | weakGuard=", UseCheckpointWeakPushGuard,
         " | riskStd=", DoubleToString(StandardRiskPct, 2),
         " | riskHigh=", DoubleToString(HighConvictionRiskPct, 2),
         " | maxOpenRisk=", DoubleToString(MaxTotalOpenRiskPct, 2),
         " | lossTrades=", StrategyMaxLossTrades,
         " | adaptiveLoss=", UseAdaptiveStrategyLossLimit,
         " | strongLossTrades=", StrategyMaxLossTradesStrong,
         " | dxy=", (StringLen(g_activeDXYSymbol) > 0 ? g_activeDXYSymbol : "none"));
   Print("=====================================");
}

void OnDeinit(const int reason)
{
   Comment("");
   PrintTestSummary(reason);
   Print("LTS Prop Engine v6 removed. Reason: ", reason);
   Print("State: ", CampaignStateName(),
         " | Start gate opened=", g_startGateOpened,
         " | score=", g_startGateScore, "/8",
         " | direction=", DirectionName(g_startGateDirection),
         " | reason=", g_startGateReason);
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
         " weakGuardActive=", g_checkpointWeakGuardActive,
         " weakGuardBlocks=", g_checkpointWeakGuardBlocks,
         " return=", DoubleToString(CurrentReturnPct(), 2), "%");
   Print("Rejects: risk=", g_rejectRisk,
         " regime=", g_rejectRegime,
         " startGate=", g_rejectStartGate,
         " dxy=", g_rejectDXY,
         " spread=", g_rejectSpread);
   Print("RiskRejectDetail: openCap=", g_rejectRiskOpenCap,
         " dailySoft=", g_rejectRiskDailySoft,
         " propRoom=", g_rejectRiskPropRoom,
         " strategyPL=", g_rejectRiskStrategyPL,
         " strategyLosses=", g_rejectRiskStrategyLosses);
   Print("AdaptiveLossLimit: enabled=", UseAdaptiveStrategyLossLimit,
         " base=", StrategyMaxLossTrades,
         " strong=", StrategyMaxLossTradesStrong,
         " effective=", EffectiveStrategyMaxLossTrades());
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
   ManageStartGate();
   UpdateChartDisplay();

   if(g_haltedPermanent || g_targetHit || g_campaignState == WAITING_FOR_START)
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
//| v6 start gate                                                     |
//+------------------------------------------------------------------+
void ManageStartGate()
{
   if(!PropMode || !UseStartGate || g_campaignState != WAITING_FOR_START)
      return;

   if(g_haltedPermanent || g_targetHit)
      return;

   if(!IsNewBar(PERIOD_H1, g_lastStartGateBarTime))
      return;

   string reason = "";
   int direction = 0;
   int score = StartGateScore(direction, reason);

   g_startGateScore = score;
   g_startGateDirection = direction;
   g_startGateReason = reason;

   if(score >= StartGateMinScore && direction != 0)
   {
      g_startGateOpened = true;
      g_startGateOpenTime = TimeCurrent();
      SetCampaignState(ACTIVE_CHALLENGE, "start gate opened");
      Print("V6 START GATE OPEN: score ", score, "/8 | ",
            DirectionName(direction), " | ", reason);
      return;
   }

   g_rejectStartGate++;
   if(EnableDiagnostics)
   {
      Print("V6 START GATE WAIT: score ", score, "/8 | ",
            DirectionName(direction), " | ", reason);
   }
}

int StartGateScore(int &direction, string &reason)
{
   int score = 0;
   reason = "";
   direction = StartGateDirection();

   if(direction == 0)
   {
      reason = "no clear D1 bias";
      return 0;
   }

   double h1Close = iClose(Symbol(), PERIOD_H1, 1);
   double h1Ema20 = iMA(Symbol(), PERIOD_H1, FastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double h1Ema50 = iMA(Symbol(), PERIOD_H1, MidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double h1Ema200 = iMA(Symbol(), PERIOD_H1, SlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double h1Adx = iADX(Symbol(), PERIOD_H1, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   double h1AtrFast = iATR(Symbol(), PERIOD_H1, StartGateATRFastPeriod, 1);
   double h1AtrSlow = iATR(Symbol(), PERIOD_H1, StartGateATRSlowPeriod, 1);

   double h4Close = iClose(Symbol(), PERIOD_H4, 1);
   double h4Ema50 = iMA(Symbol(), PERIOD_H4, MidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double h4Ema200 = iMA(Symbol(), PERIOD_H4, SlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double h4Adx = iADX(Symbol(), PERIOD_H4, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);

   double d1Close = iClose(Symbol(), PERIOD_D1, 1);
   double d1Ema50 = iMA(Symbol(), PERIOD_D1, MidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double d1Ema200 = iMA(Symbol(), PERIOD_D1, SlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double d1Atr = iATR(Symbol(), PERIOD_D1, ATRPeriod, 1);

   if(h1Close <= 0 || h1Ema20 <= 0 || h1Ema50 <= 0 || h1Ema200 <= 0 ||
      h4Close <= 0 || h4Ema50 <= 0 || h4Ema200 <= 0 ||
      d1Close <= 0 || d1Ema50 <= 0 || d1Ema200 <= 0 || d1Atr <= 0)
   {
      reason = "missing H1/H4/D1 indicator data";
      return 0;
   }

   bool wantBuy = direction > 0;
   bool d1Stack = wantBuy ? (d1Close > d1Ema50 && d1Ema50 > d1Ema200)
                          : (d1Close < d1Ema50 && d1Ema50 < d1Ema200);
   bool h4Stack = wantBuy ? (h4Close > h4Ema50 && h4Ema50 > h4Ema200)
                          : (h4Close < h4Ema50 && h4Ema50 < h4Ema200);
   bool h1Stack = wantBuy ? (h1Close > h1Ema20 && h1Ema20 > h1Ema50 && h1Ema50 > h1Ema200)
                          : (h1Close < h1Ema20 && h1Ema20 < h1Ema50 && h1Ema50 < h1Ema200);

   if(d1Stack) score++; else reason += "D1 trend weak; ";
   if(h4Stack) score++; else reason += "H4 not aligned; ";
   if(h1Stack) score++; else reason += "H1 not aligned; ";

   if(h4Adx >= StartGateH4ADXMin) score++; else reason += "H4 ADX low; ";
   if(h1Adx >= StartGateH1ADXMin) score++; else reason += "H1 ADX low; ";

   if(!StartGateRequireDXY || !DXYAppliesToThisSymbol() || DXYAllows(wantBuy))
      score++;
   else
      reason += "DXY not supportive; ";

   double d1ExtensionATR = MathAbs(d1Close - d1Ema50) / d1Atr;
   if(StartGateMaxD1ExtensionATR <= 0 || d1ExtensionATR <= StartGateMaxD1ExtensionATR)
      score++;
   else
      reason += "D1 overextended; ";

   double atrRatio = (h1AtrSlow > 0 ? h1AtrFast / h1AtrSlow : 0.0);
   if(StartGateMinATRRatio <= 0 || atrRatio >= StartGateMinATRRatio)
      score++;
   else
      reason += "volatility too quiet; ";

   if(StringLen(reason) == 0)
      reason = "all campaign filters aligned";
   else
      reason = "blocked: " + reason;

   return score;
}

int StartGateDirection()
{
   double d1Close = iClose(Symbol(), PERIOD_D1, 1);
   double d1Ema50 = iMA(Symbol(), PERIOD_D1, MidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);

   if(d1Close <= 0 || d1Ema50 <= 0)
      return 0;

   if(d1Close > d1Ema50)
      return 1;
   if(d1Close < d1Ema50)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Strategy A: squeeze release + DXY                                 |
//+------------------------------------------------------------------+
bool BuildSqueezeSetup(TradeSetup &setup)
{
   if(!IsNewBar(SqueezeTF, g_lastSqueezeBarTime))
      return false;

   if(!StrategyEnabled(1))
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
   setup.label      = "LTSv6 SQZ";
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
   if(!IsNewBar(MomentumTF, g_lastMomentumBarTime))
      return false;

   if(!StrategyEnabled(2))
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
   setup.label      = "LTSv6 EXP";
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
   if(!IsNewBar(PullbackTF, g_lastPullbackBarTime))
      return false;

   if(!StrategyEnabled(3))
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
   setup.label      = "LTSv6 PBK";
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
      return false;

   if(!PropRiskRoomAllows(setup.riskPct))
      return false;

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
   if(g_campaignState != ACTIVE_CHALLENGE && g_campaignState != PROTECTING_PROFIT)
      return false;

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
         SetCampaignState(FAILED_STANDDOWN, "overall loss buffer reached");
         Print("PROP HALT: overall loss buffer reached");
         CloseAllOpenTrades("Overall loss halt");
         return false;
      }

      if(CheckPreservationStop())
      {
         g_haltedPermanent = true;
         SetCampaignState(FAILED_STANDDOWN, "challenge preservation stop");
         Print("PROP PRESERVATION STOP: challenge drawdown reached ",
               DoubleToString(CurrentOverallLossPct(), 2), "%");
         CloseAllOpenTrades("Preservation stop");
         return false;
      }

      if(CheckPeakDrawdownStop())
      {
         g_haltedPermanent = true;
         SetCampaignState(FAILED_STANDDOWN, "peak drawdown stop");
         Print("PROP PEAK DD STOP: peak drawdown reached ",
               DoubleToString(CurrentPeakDrawdownPct(), 2), "%");
         CloseAllOpenTrades("Peak DD stop");
         return false;
      }

      if(UseCampaignMode && g_campaignCheckpointHit && CampaignHaltIfWeak && !CampaignAllowsPush())
      {
         g_haltedPermanent = true;
         g_campaignProtected = true;
         SetCampaignState(FAILED_STANDDOWN, "campaign protect");
         Print("CAMPAIGN PROTECT: checkpoint held, regime score ",
               g_campaignScore, "/", CampaignPushMinScore,
               ". Standing down at ", DoubleToString(CurrentReturnPct(), 2), "%");
         if(CampaignCloseOnWeak)
            CloseAllOpenTrades("Campaign protect");
         return false;
      }

      if(UseCampaignMode && g_campaignCheckpointHit && UseCheckpointWeakPushGuard && !CampaignAllowsPush())
      {
         g_checkpointWeakGuardBlocks++;
         if(!g_checkpointWeakGuardActive)
         {
            g_checkpointWeakGuardActive = true;
            Print("CHECKPOINT WEAK GUARD: blocking new trades, score ",
                  g_campaignScore, "/", CampaignPushMinScore,
                  " return=", DoubleToString(CurrentReturnPct(), 2), "%");
            if(CheckpointWeakGuardCloseTrades)
               CloseAllOpenTrades("Checkpoint weak guard");
         }
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
   {
      g_rejectRisk++;
      g_rejectRiskOpenCap++;
      if(EnableDiagnostics)
      {
         Print("Risk open-cap reject: openRisk=", DoubleToString(openRisk, 2),
               "% nextRisk=", DoubleToString(nextRiskPct, 2),
               "% cap=", DoubleToString(MaxTotalOpenRiskPct, 2), "%");
      }
      return false;
   }

   if(PropMode)
   {
      double dailyLossPct = CurrentDailyLossPct();
      if(dailyLossPct >= DailySoftStopPct && nextRiskPct > ReducedRiskPct + 0.01)
      {
         g_rejectRisk++;
         g_rejectRiskDailySoft++;
         if(EnableDiagnostics)
         {
            Print("Risk daily-soft reject: dailyLoss=", DoubleToString(dailyLossPct, 2),
                  "% nextRisk=", DoubleToString(nextRiskPct, 2),
                  "% reducedRisk=", DoubleToString(ReducedRiskPct, 2), "%");
         }
         return false;
      }
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
   {
      g_rejectRisk++;
      g_rejectRiskPropRoom++;
      if(EnableDiagnostics)
      {
         Print("Risk room exhausted: dailyRoom=", DoubleToString(dailyRoom, 2),
               "% overallRoom=", DoubleToString(overallRoom, 2), "%");
      }
      return false;
   }

   if(nextRiskPct > dailyRoom || nextRiskPct > overallRoom)
   {
      g_rejectRisk++;
      g_rejectRiskPropRoom++;
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
   g_targetHitTime = TimeCurrent();
   SetCampaignState(TARGET_HIT, "profit target reached");
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
      g_checkpointHitTime = TimeCurrent();
      SetCampaignState(PROTECTING_PROFIT, "campaign checkpoint reached");
      g_peakEquity = MathMax(g_peakEquity, AccountEquity());
      Print("CAMPAIGN CHECKPOINT HIT: ", DoubleToString(returnPct, 2),
            "% | regime score ", CampaignRegimeScore(), "/", CampaignPushMinScore);
   }

   if(!g_campaignCheckpointHit)
      return;

   if(UseCheckpointWeakPushGuard)
   {
      bool weakPush = !CampaignAllowsPush();
      if(!weakPush && g_checkpointWeakGuardActive)
      {
         g_checkpointWeakGuardActive = false;
         Print("CHECKPOINT WEAK GUARD CLEARED: score ",
               g_campaignScore, "/", CampaignPushMinScore,
               " return=", DoubleToString(returnPct, 2), "%");
      }
   }

   if(CampaignProfitFloorPct > 0 && returnPct <= CampaignProfitFloorPct)
   {
      g_haltedPermanent = true;
      g_campaignProtected = true;
      SetCampaignState(FAILED_STANDDOWN, "campaign profit floor stop");
      Print("CAMPAIGN PROFIT FLOOR STOP: return gave back to ",
            DoubleToString(returnPct, 2), "%");
      CloseAllOpenTrades("Campaign floor stop");
      return;
   }

   if(CampaignHaltIfWeak && !CampaignAllowsPush())
   {
      g_haltedPermanent = true;
      g_campaignProtected = true;
      SetCampaignState(FAILED_STANDDOWN, "weak campaign push score");
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
   double equity = AccountEquity();

   if(equity > g_peakEquity)
      g_peakEquity = equity;

   if(g_peakEquity <= 0)
      return;

   double ddMoney = MathMax(0.0, g_peakEquity - equity);
   double ddPct = ddMoney / g_peakEquity * 100.0;

   if(ddMoney > g_maxDrawdownMoney)
      g_maxDrawdownMoney = ddMoney;
   if(ddPct > g_maxDrawdownPct)
      g_maxDrawdownPct = ddPct;
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
   int lossTradeLimit = EffectiveStrategyMaxLossTrades();

   if(StrategyMaxLossPct <= 0 && lossTradeLimit <= 0)
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
      if(!g_strategyPLCounted[strategyId])
      {
         g_rejectRisk++;
         g_rejectRiskStrategyPL++;
         g_strategyPLCounted[strategyId] = true;
         if(EnableDiagnostics)
         {
            Print("Strategy disabled by P/L: id=", strategyId,
                  " pl=", DoubleToString(pl, 2),
                  " limit=-", DoubleToString(maxLossMoney, 2));
         }
      }
      return false;
   }

   if(lossTradeLimit > 0 && losses >= lossTradeLimit)
   {
      if(!g_strategyLossCounted[strategyId])
      {
         g_rejectRisk++;
         g_rejectRiskStrategyLosses++;
         g_strategyLossCounted[strategyId] = true;
         if(EnableDiagnostics)
         {
            Print("Strategy disabled by loss count: id=", strategyId,
                  " losses=", losses,
                  " limit=", lossTradeLimit,
                  " adaptive=", UseAdaptiveStrategyLossLimit,
                  " checkpoint=", g_campaignCheckpointHit);
         }
      }
      return false;
   }

   return true;
}

int EffectiveStrategyMaxLossTrades()
{
   int baseLimit = StrategyMaxLossTrades;

   if(!UseAdaptiveStrategyLossLimit)
      return baseLimit;

   if(StrategyMaxLossTradesStrong <= baseLimit)
      return baseLimit;

   if(g_campaignCheckpointHit)
      return StrategyMaxLossTradesStrong;

   return baseLimit;
}

void SetCampaignState(int newState, string reason)
{
   if(g_campaignState == newState)
      return;

   g_campaignStateReason = reason;
   g_campaignState = newState;
   Print("V6 STATE -> ", CampaignStateName(), " | ", reason);
}

string CampaignStateName()
{
   if(g_campaignState == WAITING_FOR_START) return "WAITING_FOR_START";
   if(g_campaignState == ACTIVE_CHALLENGE)  return "ACTIVE_CHALLENGE";
   if(g_campaignState == PROTECTING_PROFIT) return "PROTECTING_PROFIT";
   if(g_campaignState == TARGET_HIT)        return "TARGET_HIT";
   if(g_campaignState == FAILED_STANDDOWN)  return "FAILED_STANDDOWN";
   return "UNKNOWN";
}

string DirectionName(int direction)
{
   if(direction > 0) return "BUY_BIAS";
   if(direction < 0) return "SELL_BIAS";
   return "NO_BIAS";
}

bool IsXauSymbol()
{
   string symbol = Symbol();
   return (StringFind(symbol, "XAU") >= 0 ||
           StringFind(symbol, "GOLD") >= 0 ||
           StringFind(symbol, "Gold") >= 0);
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

   if(StringLen(DXYSymbol) == 0 && DXYInverseFallback)
   {
      double eurPrice = iClose("EURUSD", DXYTimeframe, 1);
      if(eurPrice > 0)
      {
         g_activeDXYSymbol = "EURUSD_INV";
         return;
      }
   }

   string candidates[] = {"DXY.cash", "USDX", "DXY", "DX", "USDollarIndex", "DXY.USD"};
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
   text += "=== LTS Prop Engine v6.1 ===\n";
   text += "Symbol: " + Symbol() + " | Spread: " + DoubleToString(spreadPips, 1) + " pips\n";
   text += "State: " + CampaignStateName() + "\n";
   if(UseStartGate)
   {
      text += "Start gate: " + IntegerToString(g_startGateScore) + "/8 " +
              DirectionName(g_startGateDirection) + "\n";
      if(g_campaignState == WAITING_FOR_START)
         text += "Waiting: " + g_startGateReason + "\n";
   }
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
