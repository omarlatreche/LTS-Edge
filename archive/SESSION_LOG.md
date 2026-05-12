# LTS Edge — Master Session Log

**Last updated:** 2026-05-07
**Current EA:** `LTS_Prop_Engine_v6.mq4` (v6.00 start-gated XAUUSD FTMO campaign engine)
**Status:** v5 is frozen as the benchmark. v6 is now a separate XAUUSD-only FTMO 2-Step campaign EA with a start gate, campaign state machine, and fixed rolling-window test plan. Next step is MT4 compile plus the v6 benchmark test matrix.

## STRATEGIC PIVOT (2026-04-30)

### The Problem We Identified
Live CAGR for v4.5 (~7-10%) does NOT beat S&P 500 ISA (10-13% tax-free, zero effort). Trading a £1K account compounds too slowly to obliterate passive index returns. The math:

| Strategy | Year 10 Balance (£800/mo deposits) |
|----------|-------------------------------------|
| S&P 500 ISA (10% tax-free) | £174,500 |
| LTS Edge v4.5 + DXY (8% live, after tax) | £155,000 |
| **ISA wins by £19,500 with zero effort** | |

### The New Path: PROP FIRM FUNDED TRADING

Instead of compounding personal capital, **rent institutional capital** by passing prop firm evaluations:
- Pay £500-2000 evaluation fee
- Trade demo to prove skill
- Pass → access $100K-$500K live capital
- Keep 80-90% of profits
- **Effective return on YOUR £500: thousands of percent annually if skilled**

Realistic outcome: 3-5% monthly on $200K funded account = $6-10K/month profit, $4.8-8K to trader.
- That's £45-75K/year on initial £500 fee
- **Genuinely obliterates index investing**

### What Changes for LTS Edge

1. **Goal shift:** Not maximizing absolute returns — maximizing prop firm rule compliance
2. **Risk per trade:** 1.5% → **0.5-1.0%** (FTMO compliant)
3. **Max DD target:** Currently 17.77% backtest → must be **<8% backtest** for prop rules
4. **Profit target:** Hit 8-10% in 30-day window
5. **Daily loss limit:** Code in protection for ~4% daily limit
6. **Track record:** 60-90 days of disciplined demo execution

### Personal Wealth Strategy (Updated)

**1. Max ISA every year (£20K) into VWRP/VUSA** — this is the bedrock
**2. Use LTS Edge to pass prop firm evaluations** — the income engine
**3. Allocate prop trading profits to:**
   - More ISA contributions (compound tax-free)
   - Crypto trading account (separate edge)
   - Eventually scale to multiple funded accounts

### 10-Year Math (Optimistic Prop Path)

If skilled enough to hit 3% monthly on $200K funded account:
- Year 1: £45K trading income + £20K ISA = £65K saved
- Year 5: £225K trading + £100K ISA returns = £325K
- Year 10: £450K cumulative trading + £250K ISA = **£700K-£1M**

**This obliterates index investing.** But requires actual skill validation through evaluations.

---

## Table of Contents

1. [Project Goal & Vision](#1-project-goal--vision)
2. [Strategy Evolution: v1 → v4.5](#2-strategy-evolution-v1--v45)
3. [Current Strategy: v4.5 Detailed Spec](#3-current-strategy-v45-detailed-spec)
4. [Failed Optimizations (DON'T RETRY)](#4-failed-optimizations-dont-retry)
5. [Instrument Testing](#5-instrument-testing)
6. [Path 1 Filter Testing — Current Phase](#6-path-1-filter-testing--current-phase)
7. [Code Changes Made](#7-code-changes-made)
8. [DXY Symbol Investigation](#8-dxy-symbol-investigation)
9. [AI Filter System (Python Daemon)](#9-ai-filter-system-python-daemon)
10. [Trade Management Mechanics](#10-trade-management-mechanics)
11. [Backtest Mechanics & Caveats](#11-backtest-mechanics--caveats)
12. [Compounding Projections (£800/month)](#12-compounding-projections-800month)
13. [v5 Ensemble Roadmap](#13-v5-ensemble-roadmap)
14. [Friend's Critique & Response](#14-friends-critique--response)
15. [Live Degradation Expectations](#15-live-degradation-expectations)
16. [VPS & Deployment](#16-vps--deployment)
17. [Files in Project](#17-files-in-project)
18. [Quick Resume Instructions](#18-quick-resume-instructions)

---

## 1. Project Goal & Vision

### Primary Objectives
- Build a profitable MQL4 Expert Advisor for MetaTrader 4
- Double £1,000 GBP account in year 1 (~100% return)
- Trade both longs and shorts (TradeBias=0)
- Test over multi-year periods to confirm robustness
- Deploy to VPS for live demo trading before real money
- Target: at least 1 trade per day average

### Long-term Aspiration
- Backtest PF 1.5+ with Max DD ≤25%
- Live PF 1.30-1.40 (after typical 30% degradation)
- Life-changing returns with £800/month additional deposits
- Eventually: multi-strategy AI ensemble (v5)

### User's Risk Tolerance
- Accepts live performance will be 30-50% worse than backtest
- Willing to deploy to demo first for 60-90 days minimum
- Comfortable with up to ~25% drawdown live
- Wants something "far better" than PF 1.25 with 42% DD (which friend called "good but not game changing")

---

## 2. Strategy Evolution: v1 → v4.5

| Version | Strategy Type | Status | Key Result |
|---------|--------------|--------|------------|
| **v1** | NY Session Breakout | Legacy | Initial baseline |
| **v2** | London Session Breakout | Legacy | Improved on v1 |
| **v3** | London Mean Reversion | **Deprecated** | Failed — equity downtrending £1,000 → £966 |
| **v4** | Volatility Squeeze (TTM-style) | **Winning core** | PF 1.25-1.30 baseline over 16 years |
| **v4.5** | v4 + Path 1 Quality Filters | **Current** | Testing in progress |
| v5 | Multi-strategy AI Ensemble | Planned | Target: PF 1.40-1.60 backtest |

### v3 (Mean Reversion) Failure Details
- Strategy: London session range fade
- Issue 1: `MinRangePips=8` was too high for gold in 2012 (ranges were only 3-6 pips that year)
- Fix attempt: Lowered to `MinRangePips=3` — didn't help
- Issue 2: Widened to `MaxRangePips=100` — equity curve still downtrending
- User stopped test early, strategy abandoned
- **Lesson learned:** Mean reversion doesn't work on XAUUSD in this configuration

### v4 (Squeeze Breakout) Discovery
- Hypothesis: TTM-style volatility squeeze (BB inside KC)
- Initial test: PF 1.25, 221 trades, -£190 net (10-month IC Markets test)
- Adding D1 EMA50 trend filter: PF 1.08 → 1.24 (massive improvement)
- 16-year backtest confirmed edge: PF 1.25-1.30 sustained
- **This is THE core edge** — all subsequent work builds on this

---

## 3. Current Strategy: v4.5 Detailed Spec

### File
`LTS_Edge_v4_5.mq4` — located at `/Users/olatreche/Desktop/LTS Edge v1/`

### Core Mechanics

| Component | Setting | Notes |
|-----------|---------|-------|
| **Squeeze detection** | BB(20, 2.0) inside KC(20, ATR 10, x1.5) | TTM-style |
| **Min squeeze bars** | 3 | Bars in compression before breakout |
| **Signal timeframe** | H1 (60 min) | Primary |
| **Trend filter** | D1 EMA50 | Longs above only, shorts below only |
| **Stop loss** | ATR(14) × 1.5 | Volatility-adapted |
| **Risk:Reward** | 1:2 | TP at 2× SL distance |
| **Risk per trade** | 1.5% | Lowered from 2.5% (better DD) |
| **Session** | 8:00-16:00 UK | London + NY overlap |
| **Days** | Mon-Fri all enabled | (was Tue-Thu in v4 originally) |
| **Daily DD cap** | 3% | Stops trading if exceeded |
| **Magic number** | 77777 | (v4 used 66666) |
| **Broker UTC offset** | 3 | IC Markets |

### Path 1 Quality Filters (testing in isolation)

| Filter | Input Name | Purpose |
|--------|-----------|---------|
| MTF Squeeze | `UseMultiTFSqueeze` | Require squeeze on H1 AND H4 |
| ATR Percentile | `UseVolatilityRegime` | Only trade when ATR is 30-80th percentile |
| DXY Confirmation | `UseDXYFilter` | Gold long only when USD weak, short only when USD strong |
| Prime Session | `UsePrimeSessionOnly` | First 2 hrs London (8:00-10:00 UK) only |
| AI Filter | `UseAIFilter` | Read ai_signal.txt before each trade |

### Why These Specific Filters Were Chosen
1. **MTF Squeeze** — H4 confirmation reduces false breakouts (institutional alignment)
2. **ATR Percentile** — Avoid extreme volatility regimes (chaotic news days)
3. **DXY** — Gold is fundamentally inverse to USD (~85% correlation historically)
4. **Prime Session** — First 2 hours London = highest liquidity, cleanest moves

### Pip Size Handling
- XAUUSD: 2 digits, Point = 0.01
- 1 pip on gold = $1 movement (different from forex)
- Lot calculation accounts for this via `MarketInfo(MODE_TICKVALUE)`

---

## 4. Failed Optimizations (DON'T RETRY)

These were tested on v4 and **all failed** — do NOT retry these as "improvements":

| Setting Tested | Result | Verdict |
|----------------|--------|---------|
| MinSqueezeBars=6 | PF 1.07 | ❌ Worse than 3 |
| No session filter | PF 1.04, 58.92% DD | ❌ Disaster |
| RR=3.0 | PF 1.08, 51% DD | ❌ Wider TP rarely hit |
| ATR x2.0 SL | PF 1.22 | ❌ Wider stops = lower profit |
| H4 timeframe | PF 1.20, 226 trades | ❌ Too few trades |
| KC x2.0 | PF 1.11, 62% DD | ❌ Squeezes too rare |
| EMA 200 trend filter | PF 1.23 | ❌ Marginally worse than EMA 50 |
| Session 7-18 (12 hrs) | PF 1.04, 79% DD | ❌ Too much choppy time |
| Tue-Thu only | Lower trade count | 🟡 Reduced volume, kept off |

**Conclusion:** Original v4 settings are optimal. Don't optimize parameters — improve via filters.

---

## 5. Instrument Testing

| Symbol | Result | Notes |
|--------|--------|-------|
| **XAUUSD (Gold)** | ✅ WORKS | PF 1.25-1.30, the core edge |
| EURUSD | ❌ FAILED | Tight spreads, smooth volatility — squeezes don't expand reliably |
| GBPUSD | ❌ FAILED | Similar issue to EURUSD |

**Conclusion:** The squeeze breakout edge is **XAUUSD-specific**. Gold's:
- Higher volatility profile
- Larger range moves post-news
- Strong directional follow-through after compression
- Clean trend persistence (driven by macro/safe-haven flows)

...all combine to make squeeze breakouts profitable on gold but not on majors. **Don't waste time testing other instruments without major redesign.**

For v5 ensemble, additional strategies will be needed for diversification — but the v4 squeeze stays gold-only.

---

## 6. Path 1 Filter Testing — Current Phase

### Test Methodology
- Each test isolates ONE filter (others stay OFF)
- Strategy Tester: XAUUSD H1, 2010.01.01 → 2026.04.01, Every Tick mode
- Starting balance: £1,000
- All other settings constant (see Section 3)

### Results So Far

| Test | Filter | Trades | PF | Max DD | Net £ | Win % | CAGR | Verdict |
|------|--------|--------|-----|--------|-------|-------|------|---------|
| **1** | None (baseline) | 973 | 1.25 | 21.05% | +£7,086 | 39.88% | 13.9% | ✅ Baseline |
| **2** | MTF Squeeze | 177 | **1.52** | 13.16% | +£920 | 44.07% | 4.2% | 🟡 Best PF, too few trades |
| **3** | ATR Percentile | 291 | 1.12 | 31.52% | +£399 | 37.11% | 2.1% | ❌ DROPPED — hurts strategy |
| **4** (bug) | DXY (broken) | 973 | 1.25 | 21.05% | +£7,086 | 39.88% | 13.9% | 🐛 Filter never fired |
| **4** (fixed) | DXY | 648 | **1.31** | 17.77% | +£4,187 | 40.90% | 11.0% | ✅ KEEP — modest but real |
| **5** | Prime Session (8-10 UK) | 945 | 1.23 | **33.95%** | +£4,213 | 39.05% | 9.7% | ❌ DROPPED — cherry-picks out winners |
| **6** | DXY + MTF-soft (planned) | TBD | TBD | TBD | TBD | TBD | TBD | ⏳ Pending code change |
| **7** | Final v4.5 config | TBD | TBD | TBD | TBD | TBD | TBD | ⏳ |

### Detailed Verdicts

#### Test 2: MTF Squeeze — Too Restrictive
- Required H1 + H4 squeeze simultaneously (rare event)
- 82% trade reduction was too aggressive
- 11 trades/year insufficient for compounding
- **Future plan:** Re-implement as *soft filter* (1.5x size when aligned, 1.0x when not)

#### Test 3: ATR Percentile — DROPPED
- Filtered out trades when ATR was below 30th or above 80th percentile
- **Why it failed:** The strategy's edge IS volatility transitions (low ATR squeeze → high ATR expansion). Filtering ATR extremes fights the core mechanism.
- Equity curve showed peak then decay — classic sign of removing winners
- **Removed from consideration permanently**

#### Test 4: DXY — KEEP
- Only allow gold longs when USD weak (EURUSD inverse > EMA20)
- Only allow gold shorts when USD strong (EURUSD inverse < EMA20)
- 33% trade reduction, modest PF improvement (1.25 → 1.31)
- DD reduced from 21% → 17.77%
- Equity curve much smoother
- Risk-adjusted returns roughly flat — but psychological survivability improved

#### Test 5: Prime Session — DROPPED ❌
- Hypothesis was: trades drop ~75%, PF improves to 1.30+
- **Actual result:** trades only dropped 3% (973 → 945), but profit dropped 41% and DD jumped to 33.95%
- **Why:** Strategy already concentrates entries at session open (08:00 UK = 11:00 server). Almost ALL trades open in the first hour anyway. Prime Session filter only blocked the rare ~28 trades that fired in hours 3-8.
- **The 28 filtered trades were ~14× more profitable than average** — they were the strategy's outlier wins (squeezes that broke later in session and ran for full multi-hour trends).
- **Lesson learned:** Filters that look reasonable can cherry-pick out the strategy's biggest winners. Always check if the filter's "removed" trades have above-average expectancy.
- Journal confirmed filter was correctly active: `Prime Session: ON (8-10 UK)`, `UsePrimeSessionOnly=1`
- **Permanently removed from consideration.**

---

### Path 1 Final Scoreboard

| Filter | Standalone PF | DD | Trades | Verdict | Reason |
|--------|---------------|-----|--------|---------|--------|
| MTF Squeeze (H1+H4) | 1.52 | 13.16% | 177 | 🟡 Too restrictive as binary gate | 11 trades/year too few for compounding |
| ATR Percentile | 1.12 | 31.52% | 291 | ❌ Permanently dropped | Fights core edge (squeezes need ATR transitions) |
| DXY Confirmation | **1.31** | 17.77% | 648 | ✅ **KEEP** — only winner | Modest but real improvement, smoother curve |
| Prime Session (8-10 UK) | 1.23 | 33.95% | 945 | ❌ Permanently dropped | Cherry-picks out outlier winners |

**Conclusion:** Only DXY filter survives binary testing. MTF has signal value but needs to be re-implemented as soft filter (position size scaler) to be useful.

### Critical Lessons Learned

1. **Trade count alone isn't a reliable filter quality signal.** Prime Session removed only 3% of trades but hurt profitability dramatically — those were outsized winners.
2. **Always check filter selectivity ALIGNS with strategy nature.** ATR Percentile filtered out exactly the conditions where squeezes work (volatility transitions).
3. **MTF as binary gate is too aggressive.** Use as soft signal (size multiplier) instead.
4. **Init journal logs are essential for filter validation.** Confirm settings actually applied via `Print()` statements before trusting results.
5. **`MarketInfo(MODE_BID)` returns 0 in Strategy Tester for non-chart symbols.** Always use `iClose()` for cross-symbol checks.

### Decision Point (END OF PATH 1)

Three options going forward:

#### Option A — Deploy v4.5 + DXY only to Demo NOW
- Settings: only `UseDXYFilter = true`, all others false
- Expected: PF 1.31 backtest → ~1.10-1.20 live (after degradation)
- Pros: Fast, gets real-world data
- Cons: Modest gain over v4 baseline

#### Option B — Build MTF as Soft Filter (Code Change) ⭐ Recommended
- Re-implement MTF squeeze as position size scaler:
  - MTF aligned (H1+H4 squeeze) → 2.0% risk
  - MTF not aligned (H1 only squeeze) → 1.0% risk
- Expected: ~700-800 trades, PF 1.40-1.50, DD 15-18%
- Pros: Captures MTF's PF 1.52 quality without losing volume
- Cons: Requires ~2-4 hours code work, then re-test
- **Then test MTF-soft + DXY combined → expected PF 1.45-1.55**

#### Option C — Continue Adding New Filter Ideas
Beyond Path 1, ideas mentioned but not implemented:
- VIX filter (skip when VIX > 30) — IC Markets only has VIX futures (same DXY problem)
- Day-of-week analysis
- Hour-of-day micro-analysis
- Pullback depth filter (squeeze must pullback to BB middle)
- COT alignment (Commitments of Traders)

**Each is a new dev cycle.**

---

## 7. Code Changes Made

### Fix 1: DXY Fallback Bug (THIS SESSION)

**File:** `LTS_Edge_v4_5.mq4`
**Function:** `ResolveDXYSymbol()` at line 171

**Problem:**
- Code used `MarketInfo(symbol, MODE_BID)` to test if a symbol was available
- In Strategy Tester, `MarketInfo(MODE_BID)` returns 0 for any symbol that isn't the chart symbol — even when historical data exists
- This caused the EURUSD inverse fallback to silently fail
- Filter would default to "always pass" → no actual filtering happened
- Test 4 (initial) produced bit-for-bit identical results to Test 1 (baseline)

**Fix:**
- Replaced `MarketInfo(symbol, MODE_BID) > 0` checks with `iClose(symbol, DXYTimeframe, 1) > 0`
- `iClose()` reads from history and works in both live and tester modes
- This is the same pattern the actual filter logic uses elsewhere in the code

**Verification:**
Journal now shows on init:
```
DXY filter: symbol 'USDX' not available (no history)
DXY filter: falling back to EURUSD inverse (EUR price=1.43153)
```

Test 4 re-run produced different results (648 trades vs 973), confirming the filter is now genuinely active.

### Previous Fixes (from v1.4 → v4 evolution, before this session)

These bugs were fixed in earlier versions and shouldn't recur in v4.5:

1. **Trailing stop on every tick** → Now only updates on new M5 bars
2. **Error 4108 after partial close** → `continue` after partial close to skip BE/trailing on dead ticket
3. **`MarketInfo(MODE_MINLOT)` returning 9999999** → Hardcoded 0.01 min check
4. **Trailing stop becoming 1-pip tight after BE** → Store original SL distance globally
5. **No `RefreshRates()` before OrderSend** → Added to ensure fresh Ask/Bid

---

## 8. DXY Symbol Investigation

### IC Markets Offering
- DXY is **only available as Futures CFDs** on IC Markets
- Symbols: `DXY_M6`, `DXY_U5`, `DXY_Z5` (June 2026, Sept 2025, Dec 2025 contracts)
- **NOT** available as continuous spot symbol
- Confirmed by checking Market Watch and Indices CFDs folder

### Why We Can't Use DXY Futures
1. **Contracts expire every 3 months** — would need rollover logic
2. **Fragmented historical data** — each contract only has ~3 months of data
3. **Contango/backwardation** — futures price differs from spot
4. **Rollover gaps** — price jumps when switching contracts
5. **Complex engineering** for a simple trend confirmation filter

### Solution: EURUSD Inverse Fallback
- EURUSD = 57.6% of DXY basket (largest weight)
- Correlation with DXY: ~-0.95 (very strong inverse)
- Available on every broker, continuous data, no rollovers
- 16+ years of history in MT4
- **~95% as accurate as real DXY** for trend confirmation purposes

### Logic
```
If EURUSD > EMA20 → EUR strengthening → DXY proxy "falling"
If EURUSD < EMA20 → EUR weakening → DXY proxy "rising"

For BUY gold: require DXY proxy falling
For SELL gold: require DXY proxy rising
```

### Future: VIX Filter for v5
- IC Markets has VIX as futures (`VIX_F6`, `VIX_K6`, `VIX_U5`)
- VIX = S&P 500 volatility / "fear gauge"
- Gold often spikes during VIX spikes (both risk-off)
- **Future v5 idea:** Skip trades when VIX above 30 (extreme risk-off causes whipsaws)

---

## 9. AI Filter System (Python Daemon)

### File
`/Users/olatreche/Desktop/LTS Edge v1/ai_filter.py`

### Purpose
Python daemon runs alongside the EA on VPS. Uses Claude API to assess macro/news risk every 30 minutes. Writes signal file the EA reads before each trade.

### Architecture

```
┌─────────────────┐         ┌──────────────────┐
│  ai_filter.py   │         │  LTS_Edge_v4.5   │
│  (every 30 min) │         │       EA         │
│                 │         │                  │
│  1. Fetch news  │         │  Before trade:   │
│  2. Check cal   │         │  Read signal     │
│  3. Ask Claude  │  writes │  file            │
│  4. Write sig   │ ──────> │                  │
└─────────────────┘ai_signal│  If SKIP → skip  │
                    .txt    │  If TRADE → go   │
                            └──────────────────┘
```

### Claude Model
`claude-sonnet-4-20250514`

### Signal File Format
`ai_signal.txt` contains:
```
TRADE|reason|timestamp
```
or
```
SKIP|reason|timestamp
```

### EA Reading Logic (already in v4.5)
```mql4
if(UseAIFilter)
{
   string aiSignal = ReadAISignal();
   if(StringFind(aiSignal, "SKIP") == 0)
   {
      // Parse reason after pipe
      // Log and skip trade
      return;
   }
}
```

### Stale Signal Handling
- Signal timestamp checked
- If >60 minutes old → ignored, defaults to TRADE
- Prevents EA being blocked if Python daemon dies

### What Claude Analyzes
- **News headlines** (Google News RSS for "gold price XAUUSD")
- **Economic calendar** (NFP, CPI, FOMC, GDP, PCE within 2 hours)
- **Central bank speakers** (Fed chair etc. within 2 hours)
- **Geopolitical events** (war escalation, sanctions, flash crashes)
- **Major US holidays** (thin/closed markets)

### SKIP conditions
- Major data release in next 2 hours
- Fed chair / central banker speaking soon
- Extreme geopolitical crisis breaking
- Flash crash / circuit breaker active
- Major US holiday
- Multiple conflicting whipsaw signals

### TRADE conditions (default — be conservative with SKIP)
- Normal market conditions
- Routine news (analyst opinions, forecasts, minor data)
- Stable or already-priced-in geopolitics
- No major releases imminent

### Operating Cost
- ~48 API calls per day @ ~$0.01-0.02 each
- **~$1/month** for full coverage

### Failure Handling
- API key missing → defaults to TRADE
- API error → defaults to TRADE
- Network failure → defaults to TRADE
- Daemon crash → file gets stale → EA defaults to TRADE
- **Philosophy:** Never block trades unnecessarily, fail open

### Run Modes
```bash
python ai_filter.py              # Run once
python ai_filter.py --daemon     # Continuous, every 30 min
python ai_filter.py --test       # Test with sample data
```

### Environment
- Requires `ANTHROPIC_API_KEY` env var
- Requires `pip install anthropic requests`

---

## 10. Trade Management Mechanics

### Partial Close at 1R
- When trade reaches 1R profit, close 50% of position
- Tracked via global ticket array (not order comments — those can't be modified)
- **Bug fix history:** Originally checked `OrderComment()` for "P" flag — but MT4 creates new ticket on partial close with comment "from #ticket" (no "P"). Now uses `g_partialTickets[]` array.

### Break-Even After Partial
- Once partial closed, move SL to entry + 1 pip
- Locks in 0R minimum on remaining 50%
- Lets remaining position run to 2R TP

### Trailing Stop Options
- **Default in v4.5:** OFF
- Reasoning: After partial close + BE, trailing chokes the remaining 50% before it reaches 2R TP
- Math: Avg win £4.43 vs avg loss £9.17 — trailing was killing winners

### ATR-Based Trailing (when enabled)
- Trail at: `current_price - ATR(14) × 1.5` (for buys)
- Only updates on new M5 bars (not every tick) — prevents OrderModify spam
- Uses original SL distance, not recalculated from current SL

### Daily Drawdown Cap
- Tracks `DayPL` (closed P&L today + floating P&L)
- If loss > `AccountBalance × 3%` → stops trading for the day
- Resets at midnight server time

### One Trade Per Symbol
- `HasOpenTrade()` check prevents stacking
- Magic number 77777 isolates this EA's trades

---

## 11. Backtest Mechanics & Caveats

### Strategy Tester Configuration
- Expert: `LTS_Edge_v4_5.ex4` (compiled output)
- Symbol: XAUUSD
- Period: H1
- Model: **Every tick** (most precise — uses smallest TF available)
- Spread: Current (typically 5 on IC Markets)
- From: 2010.01.01
- To: 2026.04.01
- Use date: ✓ checked
- Visual mode: ☐ unchecked (slows down massively)

### Known Backtest Caveats

#### "Modeling quality: n/a"
- Appears in IC Markets backtests
- Means: tick data quality couldn't be calculated
- **Not necessarily a problem** — Every Tick still uses M1 data interpolated
- Live results may differ slightly from backtest

#### "Mismatched charts errors: 238"
- D1 trend filter and H4 squeeze TF don't have perfectly synced bars
- Some bars evaluated on slightly stale higher-TF data
- Effect: ~minimal, but worth noting
- Could be reduced by ensuring all required timeframes are pre-loaded

#### Spread Effects
- Backtest uses "Current" spread (today's value)
- Live spread varies hourly (wider during news, weekends)
- Live execution will see wider spreads at times → ~5-10% performance hit

### What to Watch For
- **Modeling quality < 90%** would be concerning
- **Mismatched chart errors growing over time** would mean data drift
- **Final equity matching report exactly** = no off-by-one bugs

---

## 12. Compounding Projections (£800/month)

### v4.5 Realistic (DXY filter, ~11% live CAGR)

| Year | Balance | Total Deposited | Trading Profit |
|------|---------|-----------------|----------------|
| 1 | £11,400 | £10,600 | +£800 |
| 3 | ~£35,000 | £29,800 | +£5,200 |
| 5 | ~£70,000 | £49,000 | +£21,000 |
| 10 | ~£250,000 | £97,000 | +£153,000 |

### v4.5 Conservative (no live degradation, 14% CAGR)

| Year | Balance |
|------|---------|
| 3 | £37,800 |
| 5 | £72,700 |
| 10 | £252,000 |

### v5 Ensemble Conservative (25% live CAGR)

| Year | Balance | Profit |
|------|---------|--------|
| 1 | £12,105 | +£1,505 |
| 3 | £43,339 | +£13,539 |
| 5 | ~£70,000 | +£21,000 |

### v5 Ensemble Realistic (35% live CAGR)

| Year | Balance | Profit |
|------|---------|--------|
| 1 | £12,732 | +£2,132 |
| 3 | £49,954 | +£20,154 |
| 5 | £116,211 | +£67,211 |

### v5 Optimistic (50% live CAGR)

| Year | Balance | Profit |
|------|---------|--------|
| 1 | £13,542 | +£2,942 |
| 3 | £60,572 | +£30,772 |
| 5 | ~£195,000 | +£146,000 |

### v5 Realistic with Edge Decay (years 1-3: 35%, 4-6: 20%, 7-10: 12%)

| Year | Balance |
|------|---------|
| 3 | £49,954 |
| 6 | £124,943 |
| 10 | **£245,415** |

This is the most realistic 10-year scenario.

### Comparison Table (3-Year End Balance)

| Strategy | End Balance | Profit vs Cash |
|----------|-------------|----------------|
| Cash savings (2%) | £30,720 | +£920 |
| S&P 500 (~8%) | £33,747 | +£3,947 |
| LTS Edge v4.5 (12%) | £35,868 | +£6,068 |
| LTS Edge v5 (25-35%) | £43-50K | +£13-20K |
| LTS Edge v5 (50%) | £60,572 | +£30,772 |

---

## 13. v5 Ensemble Roadmap

### Goal
Build PF 1.5+ system through diversification rather than parameter tuning.

### Why Ensemble Works
- Single strategy = single point of failure
- Multiple uncorrelated edges = lower variance
- AI regime detection avoids worst conditions
- Compound effect: PF 1.25 × diversification = effective PF 1.40+

### Phase 1: Build H4 Momentum Strategy (2-4 weeks)
**Requirements:**
- Genuinely different from v4 (NOT just parameter tweaks)
- 10-year backtest PF > 1.20 standalone
- <0.3 correlation with v4 trades
- ADX-filtered breakouts on H4

**Without this phase, everything else is just v4 with extra complexity.**

### Phase 2: AI Regime Classifier (2-3 weeks)
- Claude API analyzes:
  - Volatility regime (LOW/NORMAL/HIGH/EXTREME)
  - Trend strength (strong/weak)
  - News environment (calm/active/crisis)
- Outputs: TRENDING / RANGING / VOLATILE / CRISIS
- Plus confidence %
- Updates every 4 hours

### Phase 3: Ensemble Coordinator (2-3 weeks)
- Allocates risk dynamically:
  - Trending regime → favor momentum
  - Ranging regime → favor squeeze breakout
  - Crisis regime → halt all trading
- Master daily DD cap across all strategies
- Confidence-weighted position sizing

### Targets
- Backtest PF: 1.40-1.60
- Live PF: 1.25-1.35
- Max DD: 20-25%
- Build time: 8-12 weeks total
- Deployment: Mid-2026

### Three Realistic Paths to PF 1.5+

#### Path 1: Quality Over Quantity ← CURRENT
- Add 4-5 conviction filters to v4
- Reduce trades 60-70%, improve quality
- Target backtest PF: 1.50-1.70
- Target live PF: 1.30-1.40

#### Path 2: Multi-Strategy Ensemble (described above)
- Diversification reduces variance
- More trades from multiple strategies
- Target live PF: 1.25-1.35

#### Path 3: ML Entry Scoring (highest risk)
- XGBoost on 50+ features
- Walk-forward validation required
- Target backtest PF: 1.80-2.20 (overfit risk)
- Target live PF: 1.20-1.45 (high variance)

### Recommended Sequence
1. **Now (2 weeks):** Path 1 — finish testing v4.5 filters
2. **After demo (60-90 days):** Path 2 Phase 1 — momentum strategy
3. **Mid-2026:** Path 2 Phase 2-3 — AI layer
4. **Late 2026+:** Consider Path 3 if Phase 2 hits ceiling

---

## 14. Friend's Critique & Response

### Friend (Omar from Royal Mansour) — WhatsApp critique
**Valid concerns raised:**
1. **Regime dependency** — strategy may break when market regime shifts
2. **Overfitting risk** — 16-year backtest doesn't guarantee future performance
3. **42% DD is brutal** — psychologically hard to stick with
4. **Recovery math** — 42% DD requires 72% gain to recover
5. **PF 1.30 with 42% DD** = "good but not game changing"

### Friend's Recommendations
- Deploy to demo first, see actual results
- His friend built AI EA that "allowed him to buy 3 houses"
- Consider AI integration

### Our Response
1. Lowered risk to 1.5% → cut DD to 21% (much more survivable)
2. Building Path 1 quality filters → improve PF without parameter overfit
3. Planned v5 ensemble with AI regime detection
4. Will deploy to demo for 60-90 days minimum before real money
5. Building robustness through diversification, not curve-fitting

---

## 15. Live Degradation Expectations

### Why Live ≠ Backtest

| Factor | Backtest Assumption | Live Reality | Impact |
|--------|---------------------|--------------|--------|
| Spread | Fixed "Current" | Variable (wider during news) | -5 to -10% |
| Slippage | None | 1-3 pips per trade on gold | -10 to -20% |
| Commission | None | ~$3-7 per round-trip | -5 to -10% |
| Requotes | None | Common during volatility | -5% |
| Weekend gaps | Smooth | Can skip stops by 20+ pips | -5% |
| News spikes | Modeled | Stop hunts, slippage | -5 to -10% |
| Execution speed | Instant | 50-200ms latency | -2 to -5% |

### Total Expected Degradation
- **Conservative estimate:** 30% worse than backtest
- **Realistic estimate:** 35-40% worse
- **Pessimistic estimate:** 50% worse

### Why We Target Backtest PF 1.5+
- 30% degradation: 1.5 → 1.05 (barely profitable, risky)
- 40% degradation: 1.5 → 0.90 (loss-making)
- **Need backtest PF 1.7+ to safely target live PF 1.20**
- That's why ensemble approach is critical

---

## 16. VPS & Deployment

### VPS Details
- **IP:** 194.37.82.16
- **Purpose:** Run MT4 + EA + AI filter daemon 24/5
- **Status:** Active

### Broker (for live demo)
- **IC Markets** (chosen for backtest consistency)
- **UTC offset:** 3
- **Leverage:** 1:200
- **Account type:** Demo (£1,000 simulated)
- **Status:** Being set up

### Deployment Plan
1. ✅ Path 1 backtest validation (in progress)
2. ⏳ Pick best filter combination from Tests 5-7
3. ⏳ Compile final v4.5 → upload to VPS
4. ⏳ Set up Python venv + install requirements + Anthropic API key
5. ⏳ Start `ai_filter.py --daemon` in screen/tmux session
6. ⏳ Start MT4 with EA attached to XAUUSD H1
7. ⏳ Run for 60-90 days minimum
8. ⏳ Analyze: live PF vs backtest, regime behavior, slippage impact
9. ⏳ Decision point:
   - Live PF > 1.10 → start v5 development
   - Live PF < 1.00 → debug/recalibrate v4.5

### What to Monitor on Demo
- Daily P&L vs backtest equivalent days
- Trade count (should be 60/year average)
- DD progression
- AI filter SKIP frequency
- Slippage per trade
- Correlation between AI SKIP days and what would have been losing trades

---

## 17. Files in Project

### Project root: `/Users/olatreche/Desktop/LTS Edge v1/`

| File | Purpose | Status |
|------|---------|--------|
| `LTS_Edge_v1.mq4` | NY Session Breakout | Legacy |
| `LTS_Edge_v2.mq4` | London Session Breakout | Legacy |
| `LTS_Edge_v3.mq4` | London Mean Reversion | Deprecated (failed) |
| `LTS_Edge_v4.mq4` | Volatility Squeeze (baseline PF 1.25) | Reference |
| `LTS_Edge_v4_5.mq4` | **CURRENT** — v4 + Path 1 filters | Active |
| `ai_filter.py` | Python Claude API news filter daemon | Ready, untested live |
| `ai_signal.txt` | Signal file written by ai_filter.py | Auto-generated |
| `ai_filter.log` | Python daemon log | Auto-generated |
| `SESSION_LOG.md` | **THIS FILE** — master reference | Active |

### GitHub Repository
- **URL:** https://github.com/omarlatreche/LTS-Edge
- **All files pushed** as of session start
- Recommended: `git add SESSION_LOG.md && git commit && git push` after each major update

---

## 18. Quick Resume Instructions

### If session is lost or context wiped, give a new Claude this prompt:

> I'm continuing work on my MQL4 EA `LTS_Edge_v4_5.mq4` (v4.55 with FTMO mode). Read `SESSION_LOG.md` in `/Users/olatreche/Desktop/LTS Edge v1/` for full context.
>
> **Current state (April 2026):**
> - **Strategic pivot complete:** Project goal is now "use EA to pass FTMO prop firm evaluations to access $100K-$2M capital", not "compound £1K personal account"
> - **Phase 2 complete:** v4.5 has FTMO compliance mode (250+ lines added)
>   - 0.75% risk, 4% daily DD limit, 8% max DD limit, news filter, consecutive loss halt, profit target tracking
> - **Phase 3 (Test FTMO-1) complete:** Strategy SURVIVES FTMO rules but takes 2 YEARS to pass Phase 1
>   - Final return: 10.08%, Max DD: 7.10%, 85 trades, PF 1.32
>   - Real FTMO traders pass in 1-3 months → too slow
> - User has signed up for FTMO Free Trial (14-day demo, £70K, GBP, MT4)
>
> **Next action:** Build v5 ensemble (momentum strategy + ensemble coordinator) to add trade volume needed for realistic FTMO pass timeline.
>
> Read SESSION_LOG.md sections "FTMO Prop Firm Research" and "Test FTMO-1 Results" and "Strategic Implications & Decision Points" before proposing next steps.

### Working Style Preferences (for new Claude)
- User wants concise, structured responses
- Prefers tables for data comparison
- Verifies test settings via screenshots before each run
- Wants honest assessment, not cheerleading
- Targets profitability through quality filters, NOT parameter tuning
- Strict on filter testing methodology (one filter at a time)

### Critical Rules
1. **DO NOT** retry failed optimizations from Section 4
2. **DO NOT** test other instruments (Section 5 — gold-specific)
3. **DO NOT** use `MarketInfo(MODE_BID)` for non-chart symbol checks (use `iClose`)
4. **DO NOT** enable trailing stop by default (Section 10)
5. **DO** test filters one at a time, then combine winners
6. **DO** ask user to verify Strategy Tester settings via screenshot before runs
7. **DO** update this SESSION_LOG.md as each test completes

---

## FTMO Prop Firm Research (Comprehensive)

### Industry Snapshot 2026
- $1.5B+ collectively paid to traders by major firms
- **FTMO:** $450M+ paid since 2015 (gold standard)
- **TopStep:** $1.1B paid since 2012 (futures specialist)
- **FundedNext:** $261M paid since 2022 (rapidly growing)
- **MyFundedFX:** SHUT DOWN February 2026 — left funded traders unpaid
- **Lesson:** Choose established firms with long payout histories

### Top 5 Prop Firms Compared

| Firm | Profit Split | Max Account | Payout Speed | Drawdown | EA-Friendly | Best For |
|------|--------------|-------------|--------------|----------|-------------|----------|
| **FTMO** | 80% → 90% | $2M scaled | 5-10 days | 5%/10% | ✅ Yes | Forex/CFD safest |
| **FundedNext** | Up to 95% | $400K | 1-3 days | 5%/10% | ✅ Yes | Best value, news allowed |
| **The5ers** | Up to 100% | $4M scaled | 5-7 days | 4%/10% | ✅ Yes | Long-term forex scaling |
| **TopStep** | 90% | $300K | 5-10 days | Trailing | ⚠️ Limited | Futures only |
| **Apex** | Up to 100% | $300K | 8 days | Trailing | ✅ Yes | Higher pass rates (15-20%) |

### Why FTMO is Default Pick
- Longest track record (since 2015)
- Allows EAs explicitly on MT4/MT5
- $2M max account through scaling
- Unlimited time to pass evaluation
- 80% → 90% split as you scale
- Most respected reputation

### Pass Rate Reality
| Stage | Success Rate |
|-------|--------------|
| Pass first evaluation | **5-10%** |
| Receive any payout | **~7%** |
| Stay funded + profitable long-term | **1-3%** |

90-95% of paid evaluations END IN LOSS for the trader.

### Average Trader Spend Before First Pass
$4,270 in evaluation fees. 60% lose all of this.

### Realistic Earnings (For Those Who Pass)
- Industry avg return per cycle: **4% of allocated funds**
- $100K account × 4% = $4K profit
- 80% split = $3.2K to trader
- Per quarter pace: $12-15K/year per account
- **For skilled trader, multiple accounts: £20-50K/year achievable**

### FTMO Two-Step Structure (Recommended Path)

#### Phase 1: Challenge
- Profit target: 10%
- Daily loss limit: 5%
- Max overall loss: 10%
- Min trading days: 4
- Time limit: NONE
- Fee: ~£155 GBP for £70K account

#### Phase 2: Verification
- Profit target: 5% (lower)
- Same drawdown rules
- Min trading days: 4
- No time limit

#### Phase 3: Funded (LIVE)
- Real capital
- 80% profit split (rises to 90%)
- Bi-weekly payouts after 14 days
- Same 5%/10% drawdown rules forever

### FTMO Account Sizes
$10K, $25K, $50K, $100K, $200K, $400K start max → scales to **$2M cap**

### Scaling Plan (How $400K → $2M)
- Trade 4+ months minimum
- Hit 10%+ total profit
- Receive 2+ processed payouts
- Have positive balance
- → +25% account size every cycle

### FTMO EA Rules
- ✅ EAs explicitly allowed (MT4 and MT5)
- ✅ Both Challenge and funded accounts
- ❌ NO HFT/scalping with sub-second trade duration
- ❌ NO arbitrage between brokers
- ❌ NO copy trading from third parties
- ❌ NO grid/martingale (most firms ban)

### UK Tax Implications (Critical)

**HMRC treats prop profits as SELF-EMPLOYMENT INCOME (not capital gains).**

| Income Source | UK Tax Rate |
|---------------|-------------|
| ISA capital gains | 0% |
| Regular brokerage capital gains | 18-24% |
| **Prop firm payouts** | **20-45% income tax + NIC** |

| Income Bracket | Effective Tax |
|----------------|---------------|
| £12,571-£50,270 | 20% income tax + 8% NIC = **28%** |
| £50,271-£125,140 | 40% income tax + 2% NIC = **42%** |
| Above £125,140 | 45% income tax + 2% NIC = **47%** |

### Tax Mitigation
- ✅ Evaluation fees deductible
- ✅ VPS, software, equipment deductible
- ✅ Trade through Limited Company (corp tax 19-25%)
- ✅ Pension contributions reduce taxable income

### Example: £40K Prop Profit
- Income tax: ~£5,486
- Class 4 NIC: ~£2,194
- Take-home: ~£32,320 (effective 19% tax)

### Comparison: Prop vs ISA After Tax
- £40K prop profit → £32K take-home
- £40K ISA growth → £40K (tax-free)
- **For equal pre-tax returns, ISA wins by 20%**
- For prop trading to beat ISA, need ~25% more pre-tax returns

---

## Test FTMO-1 Results (16-Year Backtest with FTMO Mode)

**Date run:** 2026-04-30
**Settings:** FTMO Mode ON, Phase 1, DXY filter ON, all other filters OFF
**Risk:** 0.75% per trade, 4% daily DD limit, 8% max overall DD limit

### Results

| Metric | Value | FTMO Compliance |
|--------|-------|-----------------|
| **Final return** | **10.08%** | ✅ Hit Phase 1 target |
| **Time to pass** | **~2 years** (Jan 2010 → Feb 2012) | 🚨 Way too slow |
| Profit factor | 1.32 | ✅ Maintained |
| Max DD | 7.10% (£72.74) | ✅ Under 8% buffer |
| Total trades | 85 | ⚠️ Only 42/year |
| Win rate | 41.18% | ✅ Healthy |
| Avg win / loss | £12.01 / -£6.39 | ✅ 1.88:1 ratio |
| Largest profit | £35.07 | — |
| Largest loss | -£11.34 | — |
| Daily loss halts | 0 | ✅ Never triggered |
| Consecutive loss halts | 0 | ✅ Never triggered |
| News filter halts | 90 | ✅ Working as designed |
| Permanent halt | NO | ✅ Strategy survived |

### What Worked
- ✅ FTMO mode code works correctly (one bug found and fixed — counter overflow)
- ✅ Strategy survives 16 years without permanent halt
- ✅ Max DD stays well under 8% buffer (7.10%)
- ✅ News filter triggers correctly (CPI, FOMC windows)
- ✅ DXY filter still functioning
- ✅ Profit target hit successfully

### What's Wrong
- 🚨 **2-YEAR pass time** (real FTMO traders pass in 1-3 months)
- 🚨 At 0.75% risk, strategy is too conservative for realistic prop trading
- 🚨 Only 42 trades/year = ~3.5/month — too few signals to compound aggressively
- 🚨 0.4% per month average return = vastly below FTMO viable pace (3-10%/month needed)

### Math: Why 2 Years
- 10% in 24 months = 0.4% per month average
- v4.5 expectancy at 0.75% risk: ~0.5% per trade × 3.5 trades = ~1.75% per month gross
- After news filter halts (90 over 2 years = ~4/month) = ~1% per month effective
- Slight outperformance compounds to 10% over 24 months

### Bug Fixed
`g_ftmoHaltsTarget` counter was incrementing on every tick after target hit. Fixed by adding `if(!g_ftmoTargetHit)` guard to only increment once.

---

## Test FTMO-1B: Recent Period Quick Test (Q1 2026)

**Date run:** 2026-04-30
**Settings:** Same as FTMO-1 (FTMO Mode ON, Phase 1, DXY ON)
**Period:** 2026.01.01 → 2026.04.01 (3 months)

### Results

| Metric | Value |
|--------|-------|
| **Final return** | **18.14%** |
| **Time to pass** | **18 trading days** (Jan 19 → Feb 6) |
| Total trades | 2 (both wins) |
| Win rate | 100% |
| Max DD | 4.92% |
| Daily/consecutive halts | 0 |
| News filter halts | 6 |

### Trade Detail
- Trade 1: 19 Jan → 20 Jan (1 day) — BUY @ 4663.68 → TP 4723.68, +£44 (+4.4%)
- Trade 2: 6 Feb → 9 Feb (3 days) — BUY @ 4861.98 → TP 5047.56, +£137 (+13%)

### Key Insight: 2026 Gold Conditions Massively Favor Strategy
- Gold price 4x higher than 2010 (~£4,700 vs ~£1,100)
- ATR 10-15x larger (20-60+ pips vs 2-4 pips)
- Same % SL = much bigger absolute moves
- Strong bull trend = trend filter rarely blocks
- TPs are 92-185 pips → bigger absolute wins

### Caveat: Sample of 2 Trades is Statistically Meaningless
Could be lucky. Need to validate with multiple recent quarter backtests.

---

## Test FTMO-2 Series: Recent Quarter Validation

**Purpose:** Confirm 2026 result isn't a fluke. Test 9 different historical windows.

| Window | Period | Pass? | Days to Pass | Trades | Net % | Max DD | Notes |
|--------|--------|-------|--------------|--------|-------|--------|-------|
| Q1 2025 | 2025.01-2025.04 | ❌ | n/a | 12 | 3.71% | 2.29% | INVALID (£1K rounding). Re-run @£70K below |
| Q1 2025 @£70K | 2025.01-2025.04 | ❌ | n/a | 12 | **4.24%** | **3.40%** | Realistic. 0.51 lots, 0.79% real risk. Doesn't reach 10% |
| Q2 2025 | 2025.05-2025.08 | ❌ | n/a | 4 | 5.00% | 1.43% | INVALID (£1K rounding). Re-run @£70K below |
| Q2 2025 @£70K | 2025.05-2025.08 | ❌ | n/a | 4 | **3.70%** | **1.36%** | Realistic. Lower than £1K (5%) — only 4 trades, can't compound |
| Q3 2025 | 2025.09-2025.12 | ✅ | Nov 26 (~57 days) | 11 | 10.00% | 2.92% | INVALID (£1K rounding). Re-run @£70K below |
| Q3 2025 @£70K | 2025.09-2025.12 | ❌ | n/a | 12 | **1.99%** | **1.99%** | **HUGE drop from "10%". £1K result was 5x inflated by lot rounding** |
| Q1 2026 @£70K | 2026.01-2026.04 | ❌ | n/a | 7 | **3.55%** | **2.47%** | The "miracle 18%" was 100% lot rounding artifact. Real return matches other quarters |
| Q1 2024 @£70K | 2024.01-2024.04 | ❌ LOSS | n/a | 9 | **-2.62%** | **4.92%** | First losing quarter. Strategy not consistently profitable across all periods |
| Q2 2024 @£70K | 2024.05-2024.08 | ❌ LOSS | n/a | 7 | **-0.77%** | **3.23%** | Second consecutive losing quarter. 2024 H1 was bad regime |
| Q3 2024 @£70K | 2024.09-2024.12 | ❌ | n/a | 5 | **2.80%** | **2.18%** | Recovered from H1 2024 losses but only 2.80% — still no pass |
| Slow period @£70K | 2023.10-2024.01 | ❌ | n/a | 10 | **5.91%** | **3.16%** | Best £70K result. "Slow" period actually produced strongest return — counter-intuitive |
| Chop period @£70K | 2018.10-2019.01 | ❌ LOSS | n/a | 10 | **-1.03%** | **3.23%** | Sideways gold = small loss. Strategy struggles in chop |
| Bear 2014 @£70K | 2014.01-2014.04 | ✅ PASS | within 3mo | 8 | **10.01%** | **2.48%** | Bear trends produce strong squeeze→breakout patterns. Strategy LIKES directional regimes |

### Decision Matrix
- 7-9 passes → Strategy genuinely works in modern conditions, no v5 needed
- 4-6 passes → Mixed reliability, deploy carefully with multi-instrument
- 0-3 passes → 2026 was a fluke, need v5 or different approach

### Q1 2026 Result Comparison (Most Striking Example)

| Test | Return | Trades | Insight |
|------|--------|--------|---------|
| Q1 2026 @£1K | **18.14%** | 2 (both wins, locked in) | Fake — lot rounding inflated 5x |
| Q1 2026 @£70K | **3.55%** | 7 (mixed results) | Real — same as other quarters |

The 2-trade "miracle pass" at £1K was an artifact of lot rounding making each trade ~5x bigger than intended. At realistic FTMO sizing, even Q1 2026's strong gold conditions only produced ~3.5% return.

### ⚠️ CRITICAL CAVEAT: Initial Deposit Must Match FTMO Account Size

**Tests 1-4 above were run at £1,000 starting balance.** This caused **lot size rounding artifacts** that over-stated returns:
- 0.75% risk on £1,000 = £7.50 target risk
- Required lots: ~0.003 (below 0.01 minimum)
- Rounded UP to 0.01 lots
- Actual risk: £22+ (~2.2% per trade — 3x intended)
- Result: Returns ~3x higher than realistic FTMO simulation

**MUST re-run all tests with £70,000 initial deposit (matching planned FTMO account size).**
At £70K, lot sizes have proper granularity (0.20-0.30 lots typical) and risk is accurately 0.75%.

User identified this issue mid-testing on 2026-04-30. All Q1-Q3 2025 + Q1 2026 results above are INVALID for FTMO planning purposes — to be re-run.

To be filled in as user runs each test (now at £70K).

---

## Strategic Implications & Decision Points

### The Honest Truth After Test FTMO-1
**v4.5 with DXY filter alone is NOT VIABLE for FTMO trading despite passing the technical rules.**

Why:
- 2 years to pass = unworkable in real terms
- Need to be earning consistently within months, not years
- FTMO charges fee per Challenge — can't afford 2-year cycles
- Real funded traders need 3-10% monthly pace to scale

### Three Paths Forward

#### Path A: Increase Risk to 1.0% (Quick Fix)
- Roughly halves pass time to ~12 months (still too slow)
- Max DD likely doubles to ~14% (BREACHES FTMO 10% limit)
- ❌ Not viable — would breach overall DD rule

#### Path B: Build v5 Ensemble (Medium Term)
- Add momentum strategy + others = 3-5x trade volume
- Multiple uncorrelated strategies = lower variance
- Target: 200-300 trades/year vs current 42
- Could realistically pass FTMO Phase 1 in 3-6 months
- Build time: 2-3 months
- **Recommended path**

#### Path C: Try Different Strategy Type Entirely
- Higher-frequency strategy (M15 or M5)
- More trade volume from start
- Risk: lower edge per trade, may not survive FTMO rules
- Build time: 1-2 months

### Recommendation
**Build v5 ensemble (Path B).** v4.5 has proven the system works under FTMO rules — it just needs more trade volume from additional uncorrelated strategies.

### Updated 5-Year Plan

#### Year 1 (Months 1-12)
- ✅ Phase 1: v4.5 + FTMO mode tested (DONE)
- ⏳ Phase 2: Build v5 momentum strategy (2-3 months)
- ⏳ Phase 3: Add 1-2 more strategies (1-2 months each)
- ⏳ Phase 4: Build ensemble coordinator (1 month)
- ⏳ Phase 5: 30-60 day demo on FTMO Free Trial
- ⏳ Phase 6: Pay for FTMO Challenge (£155 for £70K account)
- ⏳ Realistic pass rate: 20-40% on first attempt with v5
- ⏳ Income if pass: £5-15K (after taxes, partial year)

#### Year 2-3
- Pass scaling milestones, multiple accounts
- Realistic income: £20-50K/year (after taxes)

#### Year 4-5
- $1M+ funded capital across firms
- Limited Company structure for tax efficiency
- Realistic income: £60-120K/year (after taxes)

#### 5-Year Cumulative Realistic
- £200-300K total prop income (after tax)
- Plus £100K+ ISA growth
- **Genuinely beats ISA-only path** if v5 works as designed

---

## FTMO Free Trial Setup (User Action)

User has signed up for FTMO Free Trial:
- **14-day demo** — shortened version of Challenge
- £70K balance, GBP, FTMO Standard 1:100, MT4
- ⚠️ User selected 1-Step initially — recommended switching to **2-Step** (more forgiving)

### What the Free Trial Tests
- ✅ Can EA connect to FTMO MT4 server
- ✅ Does FTMO broker spread/slippage match expectations
- ✅ User comfort with FTMO dashboard
- ❌ NOT a strategy validation (14 days too short for ~3.5 trades/month)

### When to Pay for Real Challenge
- After v5 ensemble built (more trade volume)
- After 30-60 day successful demo run
- When confidence in pass probability >50%

---

## Session History

### 2026-05-07 (Codex v6 start-gated campaign engine)
- Decision: freeze v5 as the benchmark and begin v6 separately.
- Current best benchmark remains base v5 with `UseCampaignMode=false`.
- Built `LTS_Prop_Engine_v6.mq4` as an XAUUSD-only FTMO 2-Step campaign EA.
- v6 keeps the v5 risk governor and three modules, but renames the main momentum label to `LTSv6 EXP` to reflect expansion-breakout mode.
- Added a start gate before trading:
  - State machine: `WAITING_FOR_START`, `ACTIVE_CHALLENGE`, `PROTECTING_PROFIT`, `TARGET_HIT`, `FAILED_STANDDOWN`.
  - Scores gold conditions 0-8 using D1/H4/H1 trend alignment, H1/H4 ADX, DXY support, D1 overextension, and H1 ATR expansion.
  - Default start threshold is `StartGateMinScore=6`.
  - Once the gate opens, it stays open for that attempt.
  - Tester/journal output now prints gate score, direction, and wait reason.
- Added `LTS_Prop_Engine_v6_TEST_PLAN.md` with fixed-spread XAUUSD rolling-window tests.
- Strategic hypothesis: v6 should improve pass probability by waiting for strong gold campaign regimes instead of forcing every 3-month window to trade immediately.

### 2026-05-05 (Codex v5.1 campaign layer)
- Built `LTS_Prop_Engine_v5.mq4` up to v5.1 after rolling XAUUSD H1 tests showed v5 was survivable but not consistently FTMO-efficient.
- Continuous fixed-spread XAUUSD test read before v5.1:
  - Q1 2024: passed +10%
  - Q2 2024: controlled fail around -4%
  - Q3 2024: strong non-pass around +7.5%
  - Q4 2024: near-flat controlled loss
  - Q1 2025: profitable but below target
  - Q2 2025: controlled fail
  - Q3/Q4 2025: small positives
  - Q1 2026: passed +10%
- Conclusion: current edge captures strong gold expansion windows and preserves capital in bad windows, but needs a higher-level decision layer to know when to press.
- v5.1 additions:
  - `UseCampaignMode`
  - `CampaignCheckpointPct`
  - `CampaignProfitFloorPct`
  - `CampaignPushMinScore`
  - `CampaignMaxRiskPct`
  - `CampaignHaltIfWeak`
  - `CampaignCloseOnWeak`
  - 0-5 campaign regime score using H1/H4 ADX, EMA stack, and DXY alignment
  - checkpoint protection: after +5%, either stand down or continue toward +10% only if regime score is strong
- Follow-up campaign tests showed the first campaign throttle was too restrictive and underperformed base v5 on Q3 2024.
- Current best default is base v5 behaviour with `UseCampaignMode=false`.
- Next test: run a long stability pass from 2024.01.01 to 2026.04.01 with XAUUSD H1, fixed spread 15, £70K, campaign off.

### 2026-04-30 (afternoon — STRATEGIC PIVOT + FTMO TESTING)
- **Big realization:** v4.5 + DXY only CAGR (8-10% live) is barely better than S&P 500 ISA (10-12% tax-free)
- **Strategic pivot:** From "compound £1K account" to "use EA to access prop firm capital"
- Researched FTMO, FundedNext, Apex, TopStep, The5ers in depth
- Established UK tax reality (income tax 20-45%, NOT CGT)
- Decided to use v4.5 first (validate path) before v5 ensemble (optimize)
- **Phase 2 complete:** Implemented FTMO mode in v4.5 (250+ lines new code)
  - `FTMOMode` toggle, profit target tracking, daily/max DD halts, news filter, consecutive loss halt
  - Fixed counter overflow bug after first run
- **Phase 3 (Test FTMO-1):** v4.5 + FTMO mode + DXY backtested over 16 years
  - PASSED Phase 1 with 10.08% return, max DD 7.10%
  - But took 2 YEARS — too slow for realistic prop trading
  - Strategy is technically viable but needs more trade volume
- **Decision:** Build v5 ensemble next to add trade volume + survive FTMO rules
- User started FTMO Free Trial signup process

### 2026-04-30 (morning)
- Test 5 (Prime Session): completed — DROPPED (cherry-picks out outlier winners)
- Path 1 testing concluded — only DXY filter survives
- Updated SESSION_LOG with final Path 1 scoreboard, lessons learned, decision point

### 2026-04-29
- Test 4 (DXY filter, post-fix): completed — KEEP verdict
- Created comprehensive SESSION_LOG.md

### Earlier this session
- Discovered DXY fallback bug (filter never fired)
- Investigated IC Markets DXY availability (futures only — not usable)
- Implemented `iClose()` fix for symbol resolution
- Built compounding projections for £800/month over 3-10 years
- Discussed v5 ensemble roadmap and three paths to PF 1.5+

### Previous sessions (summarized)
- Built v4 squeeze strategy (PF 1.25 baseline established)
- Tested ~8 parameter optimizations on v4 (all failed)
- Tested EURUSD and GBPUSD (both failed — XAUUSD-specific edge)
- Built `ai_filter.py` Python daemon for Claude API news filter
- Discussed friend's WhatsApp critique
- Decided risk = 1.5% optimal balance
- Set up VPS at 194.37.82.16 for IC Markets demo
- Pushed all files to GitHub

---

**End of Master Session Log**
