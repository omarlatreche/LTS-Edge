# LTS Prop Engine v5 Latest Test Results

## Purpose

This file records the latest known v5 benchmark results before moving primary development to v6.

v5 is now frozen as the benchmark/control EA. v6 should be judged against these results, especially on:

- pass count
- average return
- max drawdown
- bad-window damage
- strong-window upside preservation

## Fixed Test Setup

Unless noted otherwise, results use:

| Setting | Value |
|---|---:|
| EA | `LTS_Prop_Engine_v5` |
| Symbol | `XAUUSD` |
| Timeframe | `H1` |
| Model | `Every tick` |
| Spread | `15` |
| Initial deposit | `70000` |
| Prop mode | `true` |
| Phase | `1` |
| Phase 1 target | `10%` |
| Campaign mode | Best benchmark is `UseCampaignMode=false` |

Important note: earlier tests on small deposits were distorted by lot rounding. The useful benchmark is the fixed-spread 70000 account testing.

## Current v5 Benchmark Summary

The latest v5 conclusion:

- v5 can pass in strong gold expansion windows.
- v5 does not pass consistently across rolling windows.
- v5 preserves capital reasonably in some weak windows, but still suffers in bad regimes.
- v5 is not the final answer; it is the benchmark that v6 must beat.

## Latest Manual v5 Results

These are the latest known manually reported MT4 results from the v5 testing sequence.

| Window | Result | Target hit | Net profit | Return | Profit factor | Max DD | Trades | Win rate | Notes |
|---|---:|---|---:|---:|---:|---:|---:|---:|---|
| `2024.01.01 -> 2024.04.01` | Pass | 2024.03.07 | 7005.59 | 10.01% | 4.21 | 4.31% | 13 | 61.54% | Strong Q1 2024 expansion window. |
| `2024.02.01 -> 2024.05.01` | No pass | n/a | 2600.42 | 3.71% | 1.48 | 4.32% | 15 | 40.00% | Profitable but below FTMO Phase 1 target. |
| `2024.03.01 -> 2024.06.01` | No pass | n/a | 2627.65 | 3.75% | 1.64 | 5.02% | 12 | 41.67% | Good gross profit but drawdown reached the protection area. |
| `2024.04.01 -> 2024.07.01` | Loss | n/a | -1140.69 | -1.63% | 0.66 | 3.69% | 11 | 27.27% | Weak transition/chop window. |
| `2024.05.01 -> 2024.08.01` | Loss | n/a | -2915.87 | -4.17% | 0.10 | 4.84% | 9 | 11.11% | Bad window. This is a major v6 improvement target. |
| `2024.08.01 -> 2024.11.01` | No pass | n/a | 5277.10 | 7.54% | 2.07 | 3.21% | 17 | 58.82% | Strong non-pass. v6 should preserve this upside. |
| `2024.09.01 -> 2024.12.01` | No pass | n/a | 3017.38 | 4.31% | 1.87 | 3.15% | 13 | 53.85% | Profitable, but not enough to pass. |
| `2024.10.01 -> 2025.01.01` | Slight loss | n/a | -359.54 | -0.51% | 0.90 | 3.29% | 10 | 30.00% | Near-flat controlled loss. |
| `2025.01.01 -> 2025.04.01` | Slight loss | n/a | -596.85 | -0.85% | 0.83 | 4.45% | 11 | 36.36% | Earlier versions showed profit; latest setting/test showed small loss. Needs v6 filtering. |
| `2026.01.01 -> 2026.04.01` | Pass | 2026.02.20 | 7000.47 | 10.00% | 4.17 | 3.64% | 12 | 75.00% | Strong gold expansion window. v6 must preserve this behaviour. |

## Module P/L Snapshots From Latest Logs

These are useful for understanding which modules carried or hurt each period.

| Window | SQZ P/L | MOM P/L | PBK P/L | Notes |
|---|---:|---:|---:|---|
| `2024.01.01 -> 2024.04.01` | -341.52 | 2022.92 | 5324.18 | Pullback module carried the pass. |
| `2024.05.01 -> 2024.08.01` | -806.31 | -1386.85 | -722.71 | All modules lost. Bad regime. |
| `2024.08.01 -> 2024.11.01` | 1886.26 | 1459.98 | 1930.85 | All modules contributed positively. |
| `2024.09.01 -> 2024.12.01` | 1279.31 | 2657.64 | -919.57 | Momentum strong, pullback hurt. |
| `2024.10.01 -> 2025.01.01` | -7.45 | -1400.63 | 1048.54 | Pullback helped offset momentum losses. |
| `2025.01.01 -> 2025.04.01` | 1009.08 | -1414.86 | -191.08 | Squeeze helped, momentum/pullback hurt. |
| `2026.01.01 -> 2026.04.01` | 1169.48 | 3056.28 | 2774.71 | All modules contributed positively. |

## Older 70000 Benchmark Results From Session Log

These are earlier validated rolling-window results preserved for context. They helped reveal that small-account tests were misleading because of lot rounding.

| Window | Pass? | Trades | Net % | Max DD | Notes |
|---|---:|---:|---:|---:|---|
| `2025.01 -> 2025.04` | No | 12 | 4.24% | 3.40% | Realistic 70000 test. Did not reach 10%. |
| `2025.05 -> 2025.08` | No | 4 | 3.70% | 1.36% | Too few trades to compound. |
| `2025.09 -> 2025.12` | No | 12 | 1.99% | 1.99% | Earlier 10000/1000 result was inflated by rounding. |
| `2026.01 -> 2026.04` | No | 7 | 3.55% | 2.47% | Earlier "miracle" result was a lot-rounding artifact. |
| `2024.01 -> 2024.04` | Loss | 9 | -2.62% | 4.92% | Older v4.5/v5-path result, before later v5 improvements. |
| `2024.05 -> 2024.08` | Loss | 7 | -0.77% | 3.23% | Bad 2024 H1 regime. |
| `2024.09 -> 2024.12` | No | 5 | 2.80% | 2.18% | Recovered but no pass. |
| `2023.10 -> 2024.01` | No | 10 | 5.91% | 3.16% | Stronger than expected. |
| `2018.10 -> 2019.01` | Loss | 10 | -1.03% | 3.23% | Chop hurts the strategy. |
| `2014.01 -> 2014.04` | Pass | 8 | 10.01% | 2.48% | Directional bear regime worked well. |

## Key Decision From v5 Testing

v5 has a real but inconsistent edge. It is strongest when gold is already in a clean expansion/trend regime and weakest in chop, transitions, or stale continuation phases.

Therefore, the correct next direction is v6:

- Keep v5 frozen as the benchmark.
- Add a start gate before the EA begins a campaign.
- Require strong enough XAUUSD regime conditions before attacking the FTMO challenge.
- Use EURUSD inverse fallback instead of relying on broker-specific DXY history.
- Measure whether v6 improves pass probability and reduces bad-window losses without killing Q1 2024, Q3 2024, and Q1 2026 upside.

## v6 Must Beat This

Minimum v6 acceptance standard:

- More passes than v5, or same passes with lower drawdown/losses.
- Better behaviour in `2024.05 -> 2024.08`.
- Better behaviour in `2024.10 -> 2025.04`.
- Preserve pass behaviour in `2024.01 -> 2024.04` and `2026.01 -> 2026.04`.
- Preserve most of the upside in `2024.08 -> 2024.11`.
