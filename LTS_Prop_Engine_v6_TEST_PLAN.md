# LTS Prop Engine v6 Test Plan

## Purpose

`LTS_Prop_Engine_v6.mq4` is the first XAUUSD-only FTMO 2-Step campaign engine.
It keeps v5 as the benchmark and adds a start gate before the EA begins trading.

Primary question:

```text
Can v6 improve FTMO pass probability by waiting for strong gold campaign regimes,
without damaging v5's strong-window upside?
```

## Fixed Tester Setup

| Setting | Value |
|---|---:|
| Expert | `LTS_Prop_Engine_v6` |
| Symbol | `XAUUSD` |
| Period | `H1` |
| Model | `Every tick` |
| Spread | `15` |
| Initial deposit | `70000` |
| Currency | GBP |

Do not use "Current" spread for comparison tests.

## Core Defaults

| Input | Value |
|---|---:|
| `PropMode` | `true` |
| `PropPhase` | `1` |
| `Phase1TargetPct` | `10.0` |
| `Phase2TargetPct` | `5.0` |
| `XAUUSDOnly` | `true` |
| `UseStartGate` | `true` |
| `StartGateMinScore` | `7` |
| `StartGateMaxD1ExtensionATR` | `2.50` |
| `StartGateMinATRRatio` | `0.85` |
| `StartGateRequireDXY` | `true` |
| `DXYSymbol` | blank, forcing the EURUSD inverse fallback |
| `DXYInverseFallback` | `true` |
| `UseDXYConfirmation` | `true` |
| `MomentumUseDXY` | `true` |
| `PullbackUseDXY` | `true` |
| `UseCampaignMode` | `true` |
| `CampaignProfitFloorPct` | `1.5` |
| `PeakDrawdownStopPct` | `7.0` |
| `StandardRiskPct` | `0.75` |
| `ReducedRiskPct` | `0.25` |
| `HighConvictionRiskPct` | `1.00` |
| `MaxTotalOpenRiskPct` | `1.00` |
| `UseSqueezeStrategy` | `false` |
| `UseMomentumStrategy` | `true` |
| `UsePullbackStrategy` | `true` |
| `SqueezeRiskMultiplier` | `0.50` |

## Benchmark Windows

Run v6 on these first, then compare directly against frozen v5:

| Window | Dates |
|---|---|
| Jan 2024 start | 2024.01.01 to 2024.04.01 |
| Feb 2024 start | 2024.02.01 to 2024.05.01 |
| Mar 2024 start | 2024.03.01 to 2024.06.01 |
| Apr 2024 start | 2024.04.01 to 2024.07.01 |
| May 2024 start | 2024.05.01 to 2024.08.01 |
| Aug 2024 start | 2024.08.01 to 2024.11.01 |
| Sep 2024 start | 2024.09.01 to 2024.12.01 |
| Oct 2024 start | 2024.10.01 to 2025.01.01 |
| Nov 2024 start | 2024.11.01 to 2025.02.01 |
| Q1 2025 | 2025.01.01 to 2025.04.01 |
| Q2 2025 | 2025.05.01 to 2025.08.01 |
| Q3 2025 | 2025.09.01 to 2025.12.01 |
| Q1 2026 | 2026.01.01 to 2026.04.01 |

## Result Fields To Record

For each run, paste the final `V6 TEST SUMMARY` journal block. It includes:

| Field |
|---|
| Pass / no pass |
| Target hit date |
| Final return % |
| Max drawdown % |
| Profit factor |
| Total trades |
| Win rate |
| Start gate opened? |
| Start gate score and direction |
| Start gate reason if it waited |
| Signals by module: SQZ / EXP / PBK |
| Closed P/L by module |
| Closed losses by module |
| Reject detail: risk open cap / daily soft stop / prop room / strategy P/L / strategy losses |

Record each completed run in:

`/Users/olatreche/Desktop/LTS Edge v1/LTS_Prop_Engine_v6_BENCHMARK_LEDGER.csv`

## Decision Rules

| Pattern | Decision |
|---|---|
| More passes than v5 with similar/lower DD | Keep v6 gate and refine entries |
| Same passes as v5 but lower bad-window loss | Keep v6 gate, tune scoring threshold |
| Fewer passes and no drawdown improvement | Gate is too strict; lower threshold or simplify |
| Strong windows blocked completely | Overextension or DXY rule is too restrictive |
| Bad windows still trade early and lose | Gate is too permissive; raise score or add freshness filter |

## Current v5 vs v6 Read

Latest v5 benchmark results are recorded in:

`/Users/olatreche/Desktop/LTS Edge v1/LTS_Prop_Engine_v5_LATEST_RESULTS.md`

On the 10 matching latest benchmark windows:

| Metric | v5 | v6 candidate |
|---|---:|---:|
| Passes | 2 / 10 | 2 / 10 |
| Total return | +32.16% | +34.61% |
| Average return | +3.22% | +3.46% |
| Median return | +3.73% | +3.04% |
| Average max DD | 3.99% | 3.74% |
| Average PF | 1.79 | 2.47 |

Current conclusion:

- v6 is a modest overall improvement and safer prop-firm foundation.
- v6 improves bad-window containment, especially `2024.05 -> 2024.08`.
- v6 does not yet improve pass count.
- v6 gives up too much upside in `2024.08 -> 2024.11` and `2024.09 -> 2024.12`.

Next work item:

Recover more late-2024 upside without losing the v6 bad-window protection. First inspect the source of very high `risk` rejects after checkpoint / during active campaigns before changing entries.

## 2026-05-08 Test Session Notes

Code/test workflow changes made:

- Added final `V6 TEST SUMMARY` journal block to `LTS_Prop_Engine_v6.mq4`.
- Fixed DXY resolution so blank `DXYSymbol` uses `EURUSD_INV` before broker-specific DXY symbols.
- Updated EA defaults to current candidate settings:
  - `StartGateMinScore=7`
  - `UseSqueezeStrategy=false`
  - `PeakDrawdownStopPct=7.0`
  - `CampaignProfitFloorPct=1.5`

Candidate v6 matrix from this session:

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

Key lesson:

v6 is now safer than v5 in bad windows and modestly better overall, but it still has the same pass count. Next work should focus on converting +5% to +10% campaigns, especially by investigating high `risk` rejects, while avoiding any change that reopens the May-Aug 2024 drawdown problem.

## 2026-05-08 Diagnostic Follow-Up

The `2024.08 -> 2024.11` retest showed `risk=11471` with `momentum=3` losses and `pullback=3` losses. That indicates the active modules hit `StrategyMaxLossTrades=3` and then repeatedly reported disabled-module rejects for the rest of the run.

v6.1 code hygiene change:

- Moved strategy-disable checks after the relevant new-bar check.
- Count strategy P/L and strategy loss-count disables once per module instead of once per evaluation loop.
- Kept the aggregate `risk` reject total for compatibility, but `RiskRejectDetail` is now the decision field.

Next targeted test:

- Recompile v6.1 in MetaEditor.
- Re-run `2024.08.01 -> 2024.11.01`.
- Confirm the summary includes `RiskRejectDetail`.
- If `strategyLosses` is still the dominant blocker, test `StrategyMaxLossTrades=4` before changing entries or start-gate logic.

Diagnostic result:

| Window | Return | PF | Max DD | Trades | Risk detail | Read |
|---|---:|---:|---:|---:|---|---|
| `2024.08 -> 2024.11` | +2.97% | 1.45 | 3.69% | 11 | `openCap=0 dailySoft=0 propRoom=0 strategyPL=0 strategyLosses=2` | Both active modules hit the 3-loss shutoff; risk room is not the blocker. |

Next controlled setting:

`StrategyMaxLossTrades=4`, with all other v6.1 baseline settings unchanged.

Controlled test result:

| Window | Setting | Return | PF | Max DD | Trades | Target | Read |
|---|---|---:|---:|---:|---:|---|---|
| `2024.08 -> 2024.11` | `StrategyMaxLossTrades=4` | +10.00% | 4.10 | 3.20% | 10 | 2024.08.20 11:01 | Converted from non-pass to pass with no risk rejects. |

Candidate conclusion:

`StrategyMaxLossTrades=4` is now the leading v6.1 change. It must be re-tested against bad windows, especially `2024.05 -> 2024.08`, before becoming the new default.

Bad-window check:

| Window | Setting | Return | PF | Max DD | Trades | Risk detail | Read |
|---|---|---:|---:|---:|---:|---|---|
| `2024.05 -> 2024.08` | `StrategyMaxLossTrades=4` | -1.90% | 0.64 | 3.78% | 8 | `strategyPL=1 strategyLosses=1` | Worse than baseline -0.83%, but drawdown did not expand beyond the prior 3.78% area. |

Decision note:

The `4` setting adds enough runway to pass Aug-Oct 2024, but costs about 1.07 percentage points in the May-Aug 2024 bad window. Continue testing on `2024.09 -> 2024.12` and `2025.09 -> 2025.12` before deciding whether the trade-off is worth making default.

Follow-up strong-window check:

| Window | Setting | Return | PF | Max DD | Trades | Read |
|---|---|---:|---:|---:|---:|---|
| `2024.09 -> 2024.12` | `StrategyMaxLossTrades=4` | +1.15% | 1.21 | 4.26% | 10 | Worse than the +2.18% baseline; not a universal improvement. |
| `2025.09 -> 2025.12` | `StrategyMaxLossTrades=4` | +10.00% | 3.55 | 2.59% | 13 | Converted the +7.45% baseline into a pass; campaign score finished at 5. |

Emerging design:

`StrategyMaxLossTrades=4` is powerful in genuine strong campaigns, but too permissive in weaker/non-checkpoint windows. The likely v6.1 implementation should keep the base module shutoff at 3 and allow one extra loss only after the campaign has reached checkpoint.

## v6.1 Adaptive Loss-Limit Candidate

Implementation added:

| Input | Value | Purpose |
|---|---:|---|
| `StrategyMaxLossTrades` | `3` | Base module loss-count shutoff. |
| `UseAdaptiveStrategyLossLimit` | `true` | Enable adaptive checkpoint runway. |
| `StrategyMaxLossTradesStrong` | `4` | Module loss-count shutoff after checkpoint. |

Effective rule:

- Use `3` by default.
- Use `4` if the campaign checkpoint has been reached.

Validation order:

1. `2024.08 -> 2024.11`: should retain the pass.
2. `2025.09 -> 2025.12`: should retain the pass.
3. `2024.05 -> 2024.08`: should move closer to baseline bad-window containment than global `4`.
4. `2024.09 -> 2024.12`: should improve versus global `4`.

Adaptive validation results:

| Window | Return | PF | Max DD | Trades | Effective limit | Read |
|---|---:|---:|---:|---:|---|---|
| `2024.08 -> 2024.11` | +10.00% | 4.10 | 3.20% | 10 | `4` after checkpoint | Retained the global-4 pass. |
| `2025.09 -> 2025.12` | +10.00% | 3.55 | 2.59% | 13 | `4` after checkpoint | Retained the global-4 pass. |
| `2024.05 -> 2024.08` | -1.90% | 0.64 | 3.78% | 8 | `4` from score before checkpoint | Failed containment test; score-based pre-checkpoint unlock is too permissive. |
| `2024.05 -> 2024.08` | -0.83% | 0.81 | 3.78% | 7 | `3`, no checkpoint | Corrected checkpoint-only adaptive restored baseline containment. |
| `2024.09 -> 2024.12` | +2.17% | 1.48 | 4.26% | 9 | `3`, no checkpoint | Avoided global-4 degradation and returned to baseline-like behavior. |
| `2024.01 -> 2024.04` | +10.00% | 10.39 | 3.10% | 7 | `4` after checkpoint | Original pass preserved. |
| `2026.01 -> 2026.04` | +10.00% | 3.98 | 4.05% | 11 | `4` after checkpoint | Original pass preserved. |

Current checkpoint-only adaptive read:

- Confirmed passes: 4 windows (`2024.01`, `2024.08`, `2025.09`, `2026.01`).
- Preserved bad-window containment on `2024.05 -> 2024.08`.
- Avoided the global-4 degradation on `2024.09 -> 2024.12`.
- This is the current v6.1 candidate baseline.

Remaining matrix results:

| Window | Return | PF | Max DD | Trades | State | Read |
|---|---:|---:|---:|---:|---|---|
| `2024.02 -> 2024.05` | +3.04% | 1.36 | 5.57% | 14 | `PROTECTING_PROFIT` | Checkpoint reached but did not convert; both active modules hit the strong 4-loss limit. |
| `2024.03 -> 2024.06` | +1.49% | 1.18 | 7.06% | 13 | `FAILED_STANDDOWN` | Checkpoint hit early then gave back to campaign floor; drawdown is a caution. |
| `2024.04 -> 2024.07` | -1.08% | 0.69 | 3.07% | 6 | `ACTIVE_CHALLENGE` | No checkpoint, effective limit stayed 3, controlled weak-window loss. |
| `2024.10 -> 2025.01` | -0.57% | 0.87 | 3.28% | 7 | `ACTIVE_CHALLENGE` | No checkpoint, effective limit stayed 3, near-flat controlled loss. |
| `2025.01 -> 2025.04` | +4.06% | 1.72 | 2.90% | 11 | `PROTECTING_PROFIT` | Checkpoint reached; pullback carried, momentum hurt, no pass. |
| `2025.05 -> 2025.08` | -2.44% | 0.44 | 4.11% | 6 | `ACTIVE_CHALLENGE` | No checkpoint, effective limit stayed 3, worst remaining controlled-loss window. |

Full v6.1 checkpoint-only adaptive snapshot:

| Metric | Result |
|---|---:|
| Confirmed passes | 4 |
| Tested benchmark windows | 12 |
| Pass rate | 33.3% |
| Worst return | -2.44% |
| Worst max DD | 7.06% |
| Passed windows | `2024.01`, `2024.08`, `2025.09`, `2026.01` |

Conclusion:

v6.1 checkpoint-only adaptive improves pass count from 2 to 4 while preserving controlled losses in no-checkpoint weak windows. The main remaining risk is checkpoint giveback, especially `2024.03 -> 2024.06`, where max DD reached 7.06% after an early checkpoint.

## v6.2 Checkpoint Weak-Push Guard

Purpose:

Reduce checkpoint giveback after +5% without killing strong campaigns.

Implementation added:

| Input | Value | Purpose |
|---|---:|---|
| `UseCheckpointWeakPushGuard` | `true` | After checkpoint, block new trades when campaign push score is weak. |
| `CheckpointWeakGuardCloseTrades` | `false` | Keep open trades managed normally; do not force close on first guard trigger. |

Rule:

- Before checkpoint: no effect.
- After checkpoint: if `CampaignRegimeScore < CampaignPushMinScore`, block new entries.
- If the score recovers, new entries are allowed again.

Validation order:

1. `2024.03 -> 2024.06`: should improve from +1.49% and reduce 7.06% DD.
2. `2024.02 -> 2024.05`: should improve from +3.04%.
3. `2025.01 -> 2025.04`: should preserve more than +4.06%.
4. Recheck pass windows `2024.08 -> 2024.11` and `2025.09 -> 2025.12`.

Initial result:

| Window | Setting | Return | PF | Max DD | Trades | Weak guard blocks | Read |
|---|---|---:|---:|---:|---:|---:|---|
| `2024.03 -> 2024.06` | close trades `false` | +1.48% | 1.18 | 7.06% | 13 | 3900 | No improvement; giveback likely came from already-open trades rather than new entries after the weak guard. |
| `2024.03 -> 2024.06` | close trades `true` | +1.58% | 1.26 | 4.41% | 12 | 5244 | Meaningfully reduced drawdown and avoided campaign-floor failure, but did not recover much return. |
| `2024.02 -> 2024.05` | close trades `true` | +3.17% | 1.50 | 4.07% | 13 | 3216 | Reduced drawdown from 5.57% to 4.07% with slight return improvement. |
| `2025.01 -> 2025.04` | close trades `true` | +4.25% | 1.79 | 2.74% | 11 | 3336 | Slightly improved return/PF and reduced drawdown from 2.90% to 2.74%. |
| `2024.08 -> 2024.11` | close trades `true` | +5.43% | 1.80 | 3.28% | 18 | 4536 | Failed pass-preservation check; prior v6.1 pass dropped to non-pass. |

Next controlled test:

Close-on-weak guard is not suitable as a default because it killed the `2024.08 -> 2024.11` pass. Revert `UseCheckpointWeakPushGuard=false` and `CheckpointWeakGuardCloseTrades=false` for baseline, or explore a softer profit-lock guard rather than immediate close.

v6.2 verdict:

- Keep the weak-push guard code as optional research tooling.
- Default `UseCheckpointWeakPushGuard=false`.
- Default `CheckpointWeakGuardCloseTrades=false`.
- Current baseline remains v6.1 checkpoint-only adaptive module loss limits.

Revision:

Remove the pre-checkpoint `CampaignRegimeScore >= CampaignPushMinScore` unlock. v6.1 adaptive should grant `StrategyMaxLossTradesStrong=4` only after the checkpoint has been reached.
