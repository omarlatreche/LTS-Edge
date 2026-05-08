# V6 Handover Summary

## End Goal

Build a maintainable MT4 EA for prop-firm use, starting with FTMO 2-Step, that can pass accounts reliably and later be used on funded accounts.

Target:

- 10% Phase 1 / month where possible
- 5% is still useful if consistency is better
- Main priority: pass probability, drawdown control, repeatability, and maintainability

## Current Direction

v5 is frozen as the benchmark. v6 is the new active direction.

v6 target:

- Instrument: XAUUSD only
- Timeframe: H1 execution
- Account: 70000 GBP
- Tester setup: Every tick, fixed spread 15
- First prop model: FTMO 2-Step
- Strategy shape: regime-gated gold campaign engine
- Not multi-instrument yet
- Not ML/AI yet
- Not scalping or pure mean reversion

Reasoning:

- XAUUSD has shown the strongest tested edge so far.
- Gold suits trend expansion / volatility campaigns.
- Indices, silver, and other markets can come later only if XAUUSD v6 beats v5.

## Important Decision Points

### v5 Is The Control Benchmark

Do not keep endlessly tweaking v5. Use it to compare pass count, average return, drawdown, and bad-window behaviour.

### v6 Must Wait For Good Regimes

The issue with v5 is not just entries; it trades bad regimes too often.

v6 adds a start gate before attempting a challenge. If conditions are poor, it waits instead of forcing trades.

### DXY Should Not Be A Hard Dependency

FTMO has `DXY.cash`, but history is limited. IC Markets has no DXY.

Therefore v6 defaults to EURUSD inverse fallback:

- In MT4 inputs, leave `DXYSymbol` blank.
- Keep `DXYInverseFallback=true`.
- Expected journal line: `DXY proxy: EURUSD_INV`.

### Campaign Mode Exists, But Keep It Light

Campaign mode is on, but weak-checkpoint halt/close should not be aggressive. Early testing showed the original 3% checkpoint floor choked strong windows, so the active candidate uses a 1.5% floor and a 7% peak giveback stop.

## What Has Been Built

Main EA:

`/Users/olatreche/Desktop/LTS Edge v1/LTS_Prop_Engine_v6.mq4`

Test plan:

`/Users/olatreche/Desktop/LTS Edge v1/LTS_Prop_Engine_v6_TEST_PLAN.md`

Session log:

`/Users/olatreche/Desktop/LTS Edge v1/SESSION_LOG.md`

Key v6 features added:

- New v6 metadata/version.
- XAUUSD-only guard.
- Start gate system.
- Campaign state machine:
  - `WAITING_FOR_START`
  - `ACTIVE_CHALLENGE`
  - `PROTECTING_PROFIT`
  - `TARGET_HIT`
  - `FAILED_STANDDOWN`
- Start gate scoring based on:
  - D1/H4/H1 trend alignment
  - H1 and H4 ADX strength
  - EURUSD inverse / DXY support
  - D1 overextension filter
  - ATR expansion
- Chart display now shows v6 state, gate score, direction, return, campaign status, and signal counts.
- Journal now reports start gate waits/opens and DXY proxy.
- Journal now prints a pasteable `V6 TEST SUMMARY` block at the end of each run with return, PF, max DD, trade stats, module P/L, rejects, campaign state, and active settings.
- Module labels changed to:
  - `LTSv6 SQZ`
  - `LTSv6 EXP`
  - `LTSv6 PBK`
- Magic number changed to `89000`.

## Current Important v6 Defaults

Use these for the current candidate baseline:

| Input | Value |
|---|---:|
| `PropMode` | `true` |
| `PropPhase` | `1` |
| `Phase1TargetPct` | `10.0` |
| `XAUUSDOnly` | `true` |
| `UseStartGate` | `true` |
| `StartGateMinScore` | `7` |
| `StartGateRequireDXY` | `true` |
| `DXYSymbol` | blank |
| `DXYInverseFallback` | `true` |
| `UseDXYConfirmation` | `true` |
| `UseCampaignMode` | `true` |
| `CampaignProfitFloorPct` | `1.5` |
| `PeakDrawdownStopPct` | `7.0` |
| `StandardRiskPct` | `0.75` |
| `ReducedRiskPct` | `0.25` |
| `HighConvictionRiskPct` | `1.00` |
| `MaxTotalOpenRiskPct` | `1.00` |
| `SqueezeRiskMultiplier` | `0.50` |
| `UseSqueezeStrategy` | `false` |
| `UseMomentumStrategy` | `true` |
| `UsePullbackStrategy` | `true` |
| `MomentumADXMin` | `28` |
| `PullbackADXMin` | `26` |
| Strategy Tester spread | `15` |

## Verification Already Done

- Checked v6 file for leftover v5 strings/magic.
- Brace balance was clean.
- Confirmed DXY fallback code exists.
- Added and compiled end-of-test `V6 TEST SUMMARY` journal reporting.
- Fixed blank `DXYSymbol` handling so it truly prefers `EURUSD_INV` before broker-specific DXY symbols.
- Could not compile from shell; compile changes in MetaEditor/MT4 after edits.

## Next Immediate Step

1. Compile `LTS_Prop_Engine_v6.mq4` in MetaEditor.
2. If compile errors appear, paste them and fix those first.
3. If it compiles, run the first v6 benchmark:

Strategy Tester:

- Expert: `LTS_Prop_Engine_v6`
- Symbol: `XAUUSD`
- Period: `H1`
- Model: `Every tick`
- Spread: `15`
- Deposit: `70000`
- Date: `2024.01.01` to `2024.04.01`

Check journal for:

- `DXY proxy: EURUSD_INV`
- `V6 START GATE OPEN`
- or `V6 START GATE WAIT`

Record:

- pass/no pass
- target hit date
- final return %
- max drawdown %
- profit factor
- total trades
- signal counts
- closed P/L by module
- start gate score/reason

## Important Test Windows

Run these after compile:

| Window | Dates |
|---|---|
| Jan 2024 start | `2024.01.01 -> 2024.04.01` |
| Feb 2024 start | `2024.02.01 -> 2024.05.01` |
| Mar 2024 start | `2024.03.01 -> 2024.06.01` |
| Apr 2024 start | `2024.04.01 -> 2024.07.01` |
| May 2024 start | `2024.05.01 -> 2024.08.01` |
| Aug 2024 start | `2024.08.01 -> 2024.11.01` |
| Sep 2024 start | `2024.09.01 -> 2024.12.01` |
| Oct 2024 start | `2024.10.01 -> 2025.01.01` |
| Nov 2024 start | `2024.11.01 -> 2025.02.01` |
| Q1 2025 | `2025.01.01 -> 2025.04.01` |
| Q2 2025 | `2025.05.01 -> 2025.08.01` |
| Q3 2025 | `2025.09.01 -> 2025.12.01` |
| Q1 2026 | `2026.01.01 -> 2026.04.01` |

## How To Judge v6

v6 is worth keeping if it:

- beats v5 pass count, or
- matches v5 pass count but reduces bad-window losses, and
- does not increase hard-risk events, and
- preserves strong-window upside.

## Latest v5 vs v6 Comparison

Latest v5 benchmark file:

`/Users/olatreche/Desktop/LTS Edge v1/LTS_Prop_Engine_v5_LATEST_RESULTS.md`

Current v6 candidate:

- `StartGateMinScore=7`
- `UseSqueezeStrategy=false`
- `UseMomentumStrategy=true`
- `UsePullbackStrategy=true`
- `PeakDrawdownStopPct=7.0`
- `CampaignProfitFloorPct=1.5`
- `DXYSymbol` blank with `EURUSD_INV`

Side-by-side on 10 matching windows:

| Metric | v5 | v6 |
|---|---:|---:|
| Passes | 2 / 10 | 2 / 10 |
| Total return across windows | +32.16% | +34.61% |
| Average return | +3.22% | +3.46% |
| Median return | +3.73% | +3.04% |
| Average max DD | 3.99% | 3.74% |
| Average PF | 1.79 | 2.47 |

Key window differences:

| Window | v5 | v6 | Read |
|---|---:|---:|---|
| `2024.05 -> 2024.08` | -4.17% | -0.83% | v6 much better bad-window containment |
| `2025.01 -> 2025.04` | -0.85% | +4.34% | v6 much better |
| `2024.08 -> 2024.11` | +7.54% | +2.96% | v6 sacrifices too much upside |
| `2024.09 -> 2024.12` | +4.31% | +2.18% | v5 better upside |

Verdict:

- v6 is a modest overall improvement and a better prop-firm engine foundation.
- v6 does not yet improve pass count: both v5 and v6 passed 2 of the 10 matching windows.
- v6 improves average return, average PF, and average max DD.
- v6's main weakness is over-filtering / under-participating in strong late-2024 expansion windows.

Next chat window priority:

1. Preserve v6 bad-window containment.
2. Recover more of v5's `2024.08 -> 2024.11` and `2024.09 -> 2024.12` upside.
3. Inspect why post-checkpoint or active-campaign `risk` rejects often exceed 10,000.
4. Consider a targeted post-checkpoint participation fix before changing entry rules.

## 2026-05-08 Session Addendum

Significant work completed in this chat:

- Confirmed `LTS_Prop_Engine_v6.mq4` compiled in MetaEditor.
- Ran the initial v6 benchmark matrix manually in MT4 Strategy Tester.
- Added a pasteable end-of-test `V6 TEST SUMMARY` journal block so future tests do not need report screenshots.
- Fixed blank `DXYSymbol` behaviour so it truly prefers `EURUSD_INV` before broker-specific symbols such as `DXY.cash`.
- Updated v6 code defaults to the current candidate baseline:
  - `StartGateMinScore=7`
  - `UseSqueezeStrategy=false`
  - `UseMomentumStrategy=true`
  - `UsePullbackStrategy=true`
  - `PeakDrawdownStopPct=7.0`
  - `CampaignProfitFloorPct=1.5`
  - `DXYSymbol=""`, `DXYInverseFallback=true`
- Confirmed Q1 2026 still passes after the `EURUSD_INV` fix.
- Updated this handover and the v6 test plan with the v5-v6 comparison.

Important v6 candidate test results from this chat:

| Window | Return | PF | Max DD | Trades | Result |
|---|---:|---:|---:|---:|---|
| `2024.01 -> 2024.04` | +10.00% | 10.48 | 3.08% | 7 | Pass |
| `2024.02 -> 2024.05` | +4.48% | 1.63 | 4.05% | 12 | No pass |
| `2024.03 -> 2024.06` | +3.12% | 1.48 | 5.57% | 11 | No pass |
| `2024.04 -> 2024.07` | -1.08% | 0.69 | 3.07% | 6 | Controlled loss |
| `2024.05 -> 2024.08` | -0.83% | 0.81 | 3.78% | 7 | Controlled loss |
| `2024.08 -> 2024.11` | +2.96% | 1.44 | 3.69% | 11 | No pass |
| `2024.09 -> 2024.12` | +2.18% | 1.48 | 4.26% | 9 | No pass |
| `2024.10 -> 2025.01` | -0.56% | 0.87 | 3.29% | 7 | Controlled loss |
| `2025.01 -> 2025.04` | +4.34% | 1.81 | 2.65% | 10 | No pass |
| `2025.05 -> 2025.08` | -2.44% | 0.44 | 4.11% | 6 | Controlled loss |
| `2025.09 -> 2025.12` | +7.45% | 2.29 | 2.60% | 13 | Strong non-pass |
| `2026.01 -> 2026.04` | +10.00% | 4.01 | 3.97% | 10 | Pass |

What we learned:

- Disabling squeeze improved quality. Squeeze was repeatedly negative in early tests, while momentum and pullback carried most profitable windows.
- Raising `StartGateMinScore` from 6 to 7 preserved the Q1 2024 pass and improved the May-Aug 2024 bad window from around -3% to below -1%.
- Lowering `CampaignProfitFloorPct` from 3.0 to 1.5 allowed Q1 2024 to pass instead of stopping around +3%.
- v6 repeatedly reaches the +3% to +7% zone but often fails to convert to +10%.
- Very large `risk` reject counts are a recurring clue and should be investigated before major strategy changes.

Bad windows to improve:

- `2024.04 -> 2024.08`
- `2024.10 -> 2025.02`
- early/mid 2025 weak patches

Strong windows to preserve:

- Q1 2024
- Q3 2024
- Q1 2026

## Likely Next Tuning Decisions

If v6 blocks strong windows:

- lower `StartGateMinScore` from `6` to `5`
- loosen overextension or DXY requirement

If v6 still trades bad windows:

- raise `StartGateMinScore`
- add a freshness filter
- require stronger H4/D1 alignment
- make module disabling more selective

If EURUSD fallback causes too many rejects:

- test `StartGateRequireDXY=false`
- keep entry-level DXY confirmation on/off separately

## Most Important Principle

Do not chase one amazing month. The aim is to build a bot that can repeatedly identify when conditions are good enough to attempt a prop challenge, attack during those windows, and stand down when the market is not suitable.
