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
