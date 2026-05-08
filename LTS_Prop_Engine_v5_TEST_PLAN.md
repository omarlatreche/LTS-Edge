# LTS Prop Engine v5.1 Test Plan

## Purpose

This EA is a separate prop-firm engine, not a replacement for the v4.5 research file.

Primary objective:

```text
Reach +10% before breaching the daily or overall loss buffers.
Stretch target: +10% in 1 month.
Acceptable target: +10% in 2-3 months.
```

The key metric is rolling-window FTMO pass probability, not CAGR alone.

v5.1 includes campaign mode as a research layer, but current best testing uses
campaign mode off. The validated base-v5 behaviour is stronger than the first
campaign throttles.

## Default Strategy Modules

| Module | Label | Purpose |
|---|---|---|
| Strategy A | `LTSv5 SQZ` | v4.5-style H1 squeeze breakout with DXY confirmation |
| Strategy B | `LTSv5 MOM` | Directional momentum breakout in strong regimes |
| Strategy C | `LTSv5 PBK` | Pullback-continuation entry during established trends |

## Core Inputs For First Tests

Use these for first-pass testing:

| Input | Value |
|---|---:|
| `PropMode` | `true` |
| `PropPhase` | `1` |
| `Phase1TargetPct` | `10.0` |
| `MaxDailyLossPct` | `4.0` |
| `MaxOverallLossPct` | `8.0` |
| `RiskBufferPct` | `0.5` |
| `ChallengePreserveLossPct` | `5.0` |
| `PeakDrawdownStopPct` | `5.0` |
| `StandardRiskPct` | `0.75` |
| `ReducedRiskPct` | `0.25` |
| `HighConvictionRiskPct` | `1.00` |
| `MaxTradesPerDay` | `3` |
| `MaxTotalOpenRiskPct` | `1.00` |
| `StrategyMaxLossPct` | `1.25` |
| `StrategyMaxLossTrades` | `3` |
| `UseNewsGuard` | `true` |
| `UseCampaignMode` | `false` |
| `CampaignCheckpointPct` | `5.0` |
| `CampaignProfitFloorPct` | `3.0` |
| `CampaignPushMinScore` | `4` |
| `CampaignMaxRiskPct` | `1.00` |
| `CampaignHaltIfWeak` | `false` |
| `CampaignCloseOnWeak` | `false` |
| `BlockChopRegime` | `true` |
| `RequireH4TrendAlignment` | `true` |
| `H4TrendADXMin` | `18.0` |
| `MomentumADXMin` | `28.0` |
| `MomentumRequireH4Trend` | `true` |
| `PullbackADXMin` | `26.0` |
| `PullbackRequireH4Trend` | `true` |
| `MinBarsBetweenTrades` | `4` |
| `SqueezeRiskMultiplier` | `0.50` |
| `UseDXYConfirmation` | `true` for XAU/XAG, test off for indices later |

## Fixed Spread Settings

Use fixed spread, not "Current", so results are comparable.

| Instrument | Spread |
|---|---:|
| XAUUSD | 15 |
| XAGUSD | 40 |
| US30 | 200 |
| NAS100 | 150 |
| SPX500 | 80 |

## First Test Windows

Start with the same realistic windows already used for v4.5:

| Window | Dates |
|---|---|
| Q1 2026 | 2026.01.01 to 2026.04.01 |
| Q1 2025 | 2025.01.01 to 2025.04.01 |
| Q2 2025 | 2025.05.01 to 2025.08.01 |
| Q3 2025 | 2025.09.01 to 2025.12.01 |
| Q1 2024 | 2024.01.01 to 2024.04.01 |
| Q2 2024 | 2024.05.01 to 2024.08.01 |
| Q3 2024 | 2024.09.01 to 2024.12.01 |
| Chop | 2018.10.01 to 2019.01.01 |
| Bear | 2014.01.01 to 2014.04.01 |

## Result Fields To Record

For every test, record:

| Field |
|---|
| Pass or no pass |
| Date target was hit |
| Final return % |
| Max drawdown % |
| Profit factor |
| Total trades |
| Win rate |
| Largest loss |
| Daily loss halt count |
| Permanent halt yes/no |
| Strategy label mix from journal/comments |
| Closed P/L by strategy from deinit journal |
| Closed losses by strategy from deinit journal |
| Campaign checkpoint/protection message |
| Campaign score at deinit |

## Decision Rules

| Result Pattern | Decision |
|---|---|
| Passes 5+ of the first 9 windows without breach | Continue tuning v5 risk and modules |
| 2-4 passes, low drawdown | Keep architecture, add another uncorrelated module |
| 0-1 passes | Momentum/pullback logic is not enough; redesign Strategy B/C |
| Any frequent permanent halts | Lower risk or tighten regime gating before adding modules |

## v5.1 Campaign Retest

Campaign mode is research-only for now. If testing it again, start with the
windows that taught us the most:

| Window | Dates | Reason |
|---|---|---|
| Q3 2024 | 2024.08.01 to 2024.11.01 | Previously hit +5% quickly and made +7.5% |
| Q1 2024 | 2024.01.01 to 2024.04.01 | Previously hit +10% |
| Q2 2024 | 2024.05.01 to 2024.08.01 | Bad regime, should protect damage |
| Q1 2026 | 2026.01.01 to 2026.04.01 | Previously hit +10% |

Keep `Phase1TargetPct=10.0`. Campaign mode should handle the 5% checkpoint
internally; do not lower the main target for these retests.
