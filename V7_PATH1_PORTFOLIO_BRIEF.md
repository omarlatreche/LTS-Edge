# LTS Path 1 Multi-Edge Portfolio Brief

Last updated: 2026-05-09

Status: planning only. No code, no parameter selection, no tester runs. This document defines the candidate, the regime it should target, validation rules, and kill criteria — all pre-registered before any implementation.

**Lock state as of 2026-05-09:** Research data confirmed (Dukascopy H1 CSV for `USA30.IDX/USD`, `USATECH.IDX/USD`, `DOLLAR.IDX/USD` from 2018-01-01 in UTC, integrity-checked at 94.2% / 94.2% / 86.2% audit-period coverage). Acceptance thresholds locked, including the losing-window overlap definition. Symbol protocol locked: USA30 and USATECH compared in research; ONE primary frozen before validation. Research begins only on explicit authorization.

**Step 1 outcome:** USA30 / USATECH H1 momentum research-split feasibility comparison was completed under the locked signal family and grid. No combination met both `>=15%` pass rate and `<=6.48%` worst DD. Index H1 momentum is killed for this phase.

**Step 2 outcome:** EURUSD H4/D1 trend-continuation research-split comparison was completed under its locked signal family and grid. No combination met both gates. EURUSD H4/D1 trend-continuation is killed for this phase.

**Current status:** 2 of 3 allowed research iterations have been used, both on trend-continuation premises. Pause for brief-level review before spending iteration 3.

**Iteration cap reached:** Iteration 3, NR-N volatility-squeeze breakout on USA30 / USATECH, was completed under locked rules and killed. All 3 allowed research iterations have now failed to meet the pass/DD gates. Mandatory brief-level review is triggered. No iteration 4 is authorized.

## Why this brief exists

Path 2 (regime-first XAUUSD v7 audit) was rejected on 2026-05-09. The frozen rule `ADX14(D1) >= 20 OR |close - EMA50|/ATR14 >= 1.5` fired on 7/8 checkpoint quarters AND 7/8 non-checkpoint quarters. The pre-registered fallback `ADX14 >= 18` also failed (6/8 vs 6/8). No D1 pre-trade regime signature separates v6.3 checkpoint quarters from non-checkpoint quarters using the planned feature set.

Per V7_PORTFOLIO_PLANNING.md decision tree, Path 2 Rejected mandates: do not redesign the XAUUSD start gate; pivot to a multi-edge portfolio with the second edge in a **non-XAUUSD instrument or different signal class**.

## Diagnostic from the audit data (informs target regime)

The comparison set isn't what the planning doc originally assumed. Looking at the 8 non-checkpoint quarters at their start:

| Window | XAUUSD D1 picture at quarter open |
|---|---|
| 2020-01-01 | Strong bull trend (ADX 26, dist +3.4 ATR) |
| 2020-07-01 | Slow bull trend (ADX 13, dist +2.7) |
| 2021-04-01 | Strong bear trend (ADX 36, dist −2.2) |
| 2022-04-01 | Strong bull trend (ADX 34) |
| 2023-04-01 | Strong bull trend (ADX 32, dist +2.4) |
| 2024-04-01 | Very strong bull trend (ADX 46, dist +4.6) |
| 2024-10-01 | Strong bull trend (ADX 28, dist +3.5) |
| 2025-07-01 | Flat / chop (ADX 13, dist +0.2) |

6 of 8 non-checkpoint quarters opened with what D1 measures call a strong trend. v6.3 still failed to reach checkpoint. This refines the v6.3 weakness diagnosis: it is **not** primarily a "stuck in chop" engine. The dominant failure mode is **"D1 looks tradable, H1 execution does not get traction."**

Implication for the second edge: the most valuable candidate is one that earns when **D1 trend conditions look healthy on XAUUSD but the H1 trend-continuation premise stalls**. That points to either:

- A **different instrument** under the same broad macro regime (so D1 trend conditions exist somewhere else and can be captured), or
- A **different signal class** on XAUUSD itself that does not depend on H1 trend continuation.

The plan's ranked candidate list (US30/NAS100 H1 momentum first) is consistent with the first option, and the audit data reinforces that ranking rather than overturning it. The brief leads with index momentum.

## Lead candidate: US30 / NAS100 H1 momentum

### Target regime

The candidate is intended to trade when:

- A US equity index shows a multi-bar H1 momentum impulse aligned with its D1 trend.
- Market session is the US cash session, where index momentum is most persistent.
- v6.3 on XAUUSD is in a non-checkpoint state — particularly the "D1 trend present, H1 stalled" mode identified above.

It is **not** intended to trade range or mean-reversion conditions, and it is **not** intended to trade overnight gap-risk windows.

### Why this should diversify v6.3

| Source of diversification | Mechanism |
|---|---|
| Different macro driver | Equity indices price growth/risk-on; gold prices real rates and risk-off. Their dominant beta differs even when both trend up. |
| Different participation logic | Index H1 momentum often runs in clean continuation legs during US cash hours; gold H1 frequently noise-traps continuation systems. |
| Different session structure | US index sessions concentrate signal in a narrow window; XAUUSD signal is spread across London + NY. Reduces same-clock failure correlation. |
| Different start-date sensitivity | Index regimes do not align with quarter boundaries the way XAUUSD trend droughts have in the audit set. |

### What would invalidate the diversification claim

- If index momentum's losing windows overlap with v6.3's losing windows by more than 50% on the validation split, the candidate fails the diversification premise even if it trades profitably in isolation.
- If the candidate's positive windows are concentrated in the same calendar quarters as v6.3's positive windows (2024 Q1, 2026 Q1), it is redundant rather than additive.
- If the candidate requires being on during XAUUSD risk-off shocks (e.g. 2020 Q1 COVID crash, where indices crashed and gold initially sold then ran), the candidate is anti-correlated in a bad way and should be sized smaller or gated.

These are the explicit anti-correlation checks the validation step must verify before accepting the candidate.

### Risk budget

Pre-register before any tester run:

- Maximum simultaneous risk per trade: same per-trade percent risk envelope as v6.3, not additive on top.
- Maximum simultaneous open exposure across both edges: capped so that worst-case correlated drawdown stays within prop-firm daily loss limit with the same buffer v6.3 uses.
- Per-edge daily-loss soft cap: each edge stops trading for the day at its own threshold; the portfolio-level daily kill switch remains the prop-firm daily limit minus buffer.
- No martingale, no averaging-in, no symbol scaling tied to PnL.

The candidate must not weaken v6.3's existing risk scaffold. The campaign state machine, dynamic floor, and daily/overall room checks from v6.3 are reused unchanged.

### Validation windows (pre-registered)

| Split | Windows | Purpose |
|---|---|---|
| Research / design | 2020 Q1 → 2023 Q4 (16 clean quarters) | Choose entry/exit logic, not parameter values. Parameter selection happens in this split too, but only one set is carried forward. |
| Validation | 2024 Q1 → 2026 Q1 (9 clean quarters) | Evaluate the chosen rules. Includes both v6.3 chronological passes (2024 Q1, 2026 Q1) — the candidate must not ruin those. |
| Final holdout | Pre-2020 quarters never used in v6 development, if MT4 history supports them | Promotion check only. No tuning. |

XAUUSD MT4 history available locally extends to 2004-06-11, so several pre-2020 quarters are accessible for holdout. Index H1 history is confirmed via Dukascopy CSV from 2018-01-01 — see "Research Data Source" section below.

Rolling-start windows remain regression references only, not headline validation, per V7_PORTFOLIO_PLANNING.md.

### Acceptance thresholds (pre-registered, locked 2026-05-09)

The candidate is promoted to the portfolio only if **all** of the following hold on the validation split. These thresholds are now formally locked. Any change after this date is a plan deviation and must be raised before validation begins, not after seeing validation results.

| Gate | Threshold |
|---|---|
| Standalone pass rate | Raw pass rate ≥ 15% on validation clean chronological windows, OR clear positive contribution in v6.3 non-checkpoint windows without making 2024 Q1 or 2026 Q1 materially worse. |
| Combined pass rate | Combined v6.3 + candidate pass rate is meaningfully above v6.3's 8% baseline. "Meaningfully" means ≥ 16% raw or ≥ 4 of 25 chronological windows passing in the combined system. |
| Drawdown discipline | Worst max DD does not exceed v6.3's 6.48%. Average max DD remains near or below v6.3's 3.95%. |
| Diversification | Losing-window overlap ≤ 50% on the validation split. **Definition (locked):** `overlap = |v6_lose ∩ cand_lose| / |cand_lose|` where `v6_lose` and `cand_lose` are the sets of validation chronological windows in which v6.3 and the candidate, respectively, return < 0%. Asymmetric by design — measures whether the candidate's losses coincide with v6.3's losses, which is the relevant diversification question. Edge case: if `|cand_lose| = 0`, set overlap to 0. |
| Robust-cost survival | Candidate pass windows survive rerun at the spread/slippage levels appropriate for the chosen index symbol on the prop-firm broker. Specific levels to be set when broker symbol is selected; the principle is the same as v6.3's spread 20 / slippage 8 stress test. |
| Direction balance | Candidate is not effectively long-only by mechanism. If it is, that must be justified by the chosen instrument's structural drift (e.g. equity-index drift), not by parameter choice. |
| Parameter budget | ≤ 10 strategy-related inputs for the candidate alone (within the project-wide ≤ 15 cap when combined with reused infrastructure). |

### Kill criteria

The candidate is abandoned if any of the following occurs during research:

| Trigger | Action |
|---|---|
| Three iteration cycles on the candidate's core rules without converging on the validation thresholds | Stop. Move to the next-ranked candidate (EURUSD H4/D1 trend continuation, then XAUUSD H4 pullback). |
| Validation pass rate < 5% standalone AND no demonstrable lift on v6.3 non-checkpoint windows | Reject the candidate. |
| Diversification overlap > 50% on losing windows | Reject as not additive, regardless of standalone numbers. |
| Worst max DD on validation > 6.48% | Reject unless pass-rate improvement is large and explainable, per the plan's hard gate. |
| Implementation requires breaking v6.3's risk scaffold or campaign state machine | Stop and revisit at planning level — this is a plan deviation, not an implementation detail. |
| Index broker spreads / overnight financing on the prop-firm symbol make robust-cost checks unreachable | Reject; reroute to EURUSD candidate. |

### What is explicitly out of scope for this brief

- Specific entry/exit signal definitions (RSI vs MACD vs raw close-break, etc.). These are research decisions, not planning decisions.
- Specific lookback parameters. Choosing them is part of the research split, with the iteration cap applying.
- Multi-edge orchestration code. The portfolio currently has one edge (v6.3); adding a second is a single-edge addition, not a routing-engine project.

### Symbol protocol (locked 2026-05-09)

USA30 and USATECH form the lead candidate family during research/design. Validation runs on **one** symbol/rule set, not both.

- Treat `USA30.IDX/USD` and `USATECH.IDX/USD` as the lead candidate family during research/design only.
- Use the research split (2020 Q1 → 2023 Q4) to compare feasibility and choose ONE primary symbol/rule set.
- Freeze that choice before running validation.
- Do **not** run validation on both and pick the winner — that re-introduces the multiple-comparison overfit the validation step is designed to prevent.
- FTMO `US30.cash` / `US100.cash` remain reserved for final cost-realism checks, not research data sources. Whichever symbol survives research is later stress-tested against FTMO's spread / financing on its corresponding `.cash` symbol.

### Step 1 Result: USA30 / USATECH H1 Momentum

Signal family tested:

- H1 close breakout over prior `N` H1 closes.
- D1 EMA20 / EMA50 trend filter.
- ATR(14) stop at `K * ATR`.
- US cash-session entries only.
- Flat by 20:00 UTC.
- Bid/ask execution and zero-volume bar filtering.

Locked grid:

| Parameter | Values |
|---|---|
| `N` | `12`, `24`, `48` |
| `K` | `1.5`, `3.0` |

Research split:

`2020 Q1 -> 2023 Q4`, 16 clean quarters.

Result table:

| Symbol | N | K | Pass% | CP% | Worst Ret% | Worst DD% | Avg Ret% | Trades/Q | Win% |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| USA30 | 12 | 1.5 | 0.0 | 18.8 | -8.99 | 10.19 | +0.62 | 35.0 | 48.0 |
| USA30 | 12 | 3.0 | 0.0 | 0.0 | -6.19 | 7.47 | +0.21 | 32.9 | 53.9 |
| USA30 | 24 | 1.5 | 0.0 | 6.2 | -6.83 | 8.55 | -0.43 | 27.8 | 45.8 |
| USA30 | 24 | 3.0 | 0.0 | 0.0 | -3.69 | 5.02 | -0.20 | 26.1 | 51.7 |
| USA30 | 48 | 1.5 | 0.0 | 18.8 | -7.48 | 7.66 | -0.87 | 19.7 | 44.1 |
| USA30 | 48 | 3.0 | 0.0 | 6.2 | -4.16 | 5.37 | -0.14 | 18.2 | 51.7 |
| USATECH | 12 | 1.5 | 12.5 | 31.2 | -8.25 | 8.90 | +3.08 | 36.9 | 50.3 |
| USATECH | 12 | 3.0 | 0.0 | 6.2 | -4.56 | 4.65 | +1.43 | 35.2 | 56.8 |
| USATECH | 24 | 1.5 | 6.2 | 43.8 | -11.87 | 11.87 | +2.43 | 30.2 | 51.2 |
| USATECH | 24 | 3.0 | 0.0 | 12.5 | -6.48 | 6.48 | +1.31 | 28.8 | 58.5 |
| USATECH | 48 | 1.5 | 0.0 | 31.2 | -5.37 | 6.30 | +2.34 | 21.9 | 51.3 |
| USATECH | 48 | 3.0 | 0.0 | 0.0 | -4.33 | 4.58 | +1.37 | 20.9 | 58.1 |

Decision:

- Required: pass rate `>=15%` and worst DD `<=6.48%`.
- USA30: no pass-producing combination.
- USATECH: showed some positive expectancy, but the only pass-producing combination reached only `12.5%` pass rate and breached DD at `8.90%`.
- No combination met both gates.

Outcome: **KILL / REROUTE**.

Per the locked process, do not rescue this result with a wider grid, different breakout parameters, or another index H1 signal family without a new brief-level review.

## Implementation order (when implementation is authorized)

This order applies only after the brief is reviewed and the user explicitly authorizes implementation. None of these steps begin yet.

1. Research-split feasibility comparison of `USA30.IDX/USD` vs `USATECH.IDX/USD` H1 momentum on Dukascopy CSV (2020 Q1 → 2023 Q4). Output: one chosen primary symbol + one frozen rule set. This is the symbol-protocol step.
2. Fork `LTS_Prop_Engine_v6.mq4` to a new file dedicated to the index momentum candidate, targeting the chosen primary symbol. Do not embed it inside v6.3 as a mode flag, per V7_PORTFOLIO_PLANNING.md "safest reuse method."
3. Stub the strategy logic so the new file compiles and obviously takes no trades.
4. Reuse v6.3's prop-firm risk scaffold, campaign state machine, dynamic floor, instrumentation, and end-of-test summary. These are the v6 assets that generalized.
5. Implement the frozen H1 momentum logic. Do not look at the validation split during this step.
6. Run the validation split (2024 Q1 → 2026 Q1) once on the chosen primary symbol only. Apply the locked acceptance thresholds mechanically. No threshold changes.
7. Apply robust-cost stress test to any pass windows. The cost-realism step uses FTMO's `US30.cash` or `US100.cash` (whichever matches the chosen primary symbol), not Dukascopy data.
8. If thresholds are met, run the final holdout once and report.
9. If holdout passes, the next step is 60-day demo deployment, not another optimization round.

## Lower-priority candidates (held for later)

Per V7_PORTFOLIO_PLANNING.md, the second and third candidates are EURUSD H4/D1 trend continuation and XAUUSD H4 pullback with D1 filter. These are not started in parallel. They are reserved for the case where the index candidate hits its kill criteria.

The audit data informs this reserve list as well: a XAUUSD H4 pullback variant is the weakest reserve, because the audit confirmed XAUUSD-specific failures aren't a chop-vs-trend problem. Demoting it to last-resort.

Current next candidate after Step 1 kill:

`EURUSD H4/D1 trend continuation` was tested as iteration 2 and killed.

### Step 2 Result: EURUSD H4/D1 Trend Continuation

Signal family tested:

- D1 EMA20 / EMA50 trend filter.
- H4 pullback into D1 EMA20.
- H4 resumption close back beyond D1 EMA20.
- ATR(14) stop at `K * ATR`.
- Exit on D1 trend flip, stop, or 10-D1-bar time stop.
- Bid/ask execution.

Locked grid:

| Parameter | Values |
|---|---|
| `X` pullback lookback | `3`, `6` |
| `K` ATR stop multiplier | `1.5`, `3.0` |

Research split:

`2020 Q1 -> 2023 Q4`, 16 clean quarters.

Result table:

| X | K | Pass% | CP% | Worst Ret% | Worst DD% | Avg Ret% | Trades/Q | Win% |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 3 | 1.5 | 6.2 | 12.5 | -3.54 | 6.79 | +1.44 | 7.6 | 24.8 |
| 3 | 3.0 | 0.0 | 0.0 | -3.91 | 4.90 | +0.22 | 5.4 | 33.7 |
| 6 | 1.5 | 6.2 | 12.5 | -4.04 | 7.73 | +1.18 | 7.8 | 24.0 |
| 6 | 3.0 | 0.0 | 0.0 | -3.91 | 5.85 | -0.00 | 5.6 | 32.2 |

Decision:

- Required: pass rate `>=15%` and worst DD `<=6.48%`.
- Best pass rate was `6.2%`.
- DD-compliant combinations had `0%` pass rate.
- No combination met both gates.

Outcome: **KILL**.

Read:

EURUSD produced the expected failure mode: some controlled positive expectancy, but not enough signal density or quarterly velocity to reach the FTMO Phase 1 pass bar. This is not a parameter-grid rescue case under the locked rules.

Iteration discipline:

Two research iterations have now killed under the same broad trend-continuation premise:

1. USA30 / USATECH H1 momentum.
2. EURUSD H4/D1 trend continuation.

The third listed reserve, XAUUSD H4 pullback with D1 filter, is also trend-continuation-adjacent. Do not spend iteration 3 automatically. Pause for brief-level review before deciding whether iteration 3 should follow the original list or switch to a genuinely different signal class.

### Brief-Level Review Decision After Two Kills

The two non-trivial candidates failed for different reasons:

| Candidate | Research read |
|---|---|
| USATECH H1 momentum | Some velocity and positive expectancy, but DD breached the ceiling. |
| EURUSD H4/D1 pullback | Controlled positive expectancy, but insufficient velocity for standalone pass rate. |

The locked research gate tested standalone candidate quality. It did not test the portfolio-additivity branch from the validation brief: whether a controlled, lower-velocity candidate can materially improve v6.3's non-checkpoint quarters without damaging v6.3's pass quarters.

Decision:

- Run a portfolio-additivity sanity check before spending iteration 3.
- This does not consume iteration budget because it reuses already-collected research-split data.
- Do not touch validation data.
- Do not change strategy parameters.
- Do not authorize EA implementation.

Option A sanity check:

1. Take v6.3 per-quarter returns on the research split: `2020 Q1 -> 2023 Q4`.
2. Take EURUSD's already-tested research combo per-quarter returns:
   - primary: `X=3`, `K=1.5`
   - defensive reference: `X=3`, `K=3.0`
3. Sum returns per quarter as a simple first-order portfolio approximation.
4. Report:
   - combined per-quarter returns
   - combined pass rate
   - combined checkpoint rate
   - combined worst return
   - combined worst DD if available from the existing run; otherwise label DD as approximate / unresolved
   - whether EURUSD gains land in v6.3 non-checkpoint quarters
   - losing-window overlap using the locked definition where applicable

Decision rule for this sanity check:

- If additivity is material and risk remains plausibly controlled, draft a brief amendment for portfolio-additivity-based promotion before validation.
- If additivity is weak, spend iteration 3 on a genuinely different signal class rather than XAUUSD H4 pullback by inertia.
- XAUUSD H4 pullback remains last-resort only.

### Option A Result: Portfolio Additivity Sanity Check

Primary test:

- v6.3 research-split quarterly returns: `2020 Q1 -> 2023 Q4`.
- EURUSD `X=3`, `K=1.5` research-split quarterly returns.
- Simple 50/50 combined return approximation.

Headline:

| Metric | v6.3 standalone | Combined | Read |
|---|---:|---:|---|
| Pass rate `>=10%` | `0 / 16` | `0 / 16` | No operational pass lift. |
| Checkpoint rate `>=5%` | `1 / 16` | `1 / 16` | No checkpoint lift. |
| Positive quarters | `5 / 16` | `6 / 16` | Small improvement. |
| Worst quarter | `-4.66%` | `-3.56%` | Risk smoothing. |
| Average quarter | `-1.25%` | `+0.09%` | Expected-value lift. |
| Worst DD | `6.48%` | `3.40% -> 5.45%` bounded estimate | Risk improvement. |

Read:

EURUSD adds some expected-value lift and risk smoothing, but it does not create new pass or checkpoint quarters. For the FTMO Phase 1 operating goal, the additivity is weak.

Defensive reference:

- EURUSD `X=3`, `K=3.0` did not help: `0` passes, `0` checkpoints, average combined quarter `-0.51%`.
- Drop this variant from consideration.

Overlap metric caveat:

- Observed losing-window overlap was `66.7%`, above the locked `<=50%` threshold.
- But v6.3 lost in `11 / 16 = 68.75%` of research-split quarters.
- Under independence, expected overlap would already be about `68.75%`.
- Therefore this research-split overlap result does not prove EURUSD losses are correlated with v6.3 losses; it shows the locked overlap metric is not very informative when the baseline loses in most quarters.
- Keep the locked overlap definition for validation, but qualify research-split interpretations against the base loss rate.

Decision:

- Do not draft a portfolio-additivity amendment for EURUSD.
- Do not spend iteration 3 on XAUUSD H4 pullback by inertia.
- Iteration 3 should be a genuinely different signal class.

Meta-flag:

If iteration 3 also fails, the forced brief-level review should examine whether the operating frame itself is too constrained: single-edge or simple two-edge liquid-instrument systems may not reliably clear a `+10%` quarterly Phase 1 target under v6.3-level DD discipline.

### Iteration 3 Result: NR-N Volatility-Squeeze Breakout

Signal family tested:

- NR-N setup on H1 indices.
- No trend filter.
- Breakout on the immediately following H1 bar.
- ATR(14) stop at `K * ATR`.
- US cash-session trigger window.
- Flat by 20:00 UTC.
- One open position max.

Locked grid:

| Parameter | Values |
|---|---|
| `N` NR lookback | `4`, `7` |
| `K` ATR stop multiplier | `1.5`, `3.0` |

Research split:

`2020 Q1 -> 2023 Q4`, 16 clean quarters.

Result table:

| Symbol | N | K | Pass% | CP% | Worst Ret% | Worst DD% | Avg Ret% | Trades/Q | Win% |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| USA30 | 4 | 1.5 | 6.2 | 12.5 | -7.83 | 7.85 | -0.76 | 42.8 | 45.3 |
| USA30 | 4 | 3.0 | 0.0 | 6.2 | -4.13 | 5.09 | -0.22 | 42.4 | 46.4 |
| USA30 | 7 | 1.5 | 6.2 | 6.2 | -5.62 | 5.63 | -0.09 | 13.9 | 44.6 |
| USA30 | 7 | 3.0 | 0.0 | 0.0 | -3.47 | 3.47 | +0.19 | 13.9 | 46.4 |
| USATECH | 4 | 1.5 | 6.2 | 18.8 | -12.95 | 13.57 | -0.90 | 42.5 | 45.9 |
| USATECH | 4 | 3.0 | 6.2 | 6.2 | -6.81 | 7.14 | -0.23 | 42.1 | 47.0 |
| USATECH | 7 | 1.5 | 0.0 | 6.2 | -5.38 | 5.64 | +0.13 | 11.7 | 42.2 |
| USATECH | 7 | 3.0 | 0.0 | 0.0 | -2.03 | 2.57 | +0.21 | 11.6 | 44.6 |

Decision:

- Required: pass rate `>=15%` and worst DD `<=6.48%`.
- Best pass rate was `6.2%`.
- DD-compliant combinations had `0%` or `6.2%` pass with approximately flat average returns.
- No combination met both gates.

Outcome: **KILL**.

Iteration cap:

- 3 of 3 research iterations consumed.
- Iteration 4 is not authorized.
- Mandatory brief-level review of the planning frame is triggered.

Pattern:

| Iteration | Premise | Best pass rate | DD-compliant read | Outcome |
|---|---|---:|---|---|
| 1 | H1 index momentum trend-continuation breakout | `12.5%` | DD-compliant combos had `0%` pass. | KILL |
| 2 | EURUSD H4/D1 trend-continuation pullback | `6.2%` | DD-compliant combos had `0%` pass. | KILL |
| 3 | H1 index volatility-regime breakout | `6.2%` | DD-compliant combos had `0%` or `6.2%` pass with flat average return. | KILL |

Review question:

The repeated failure shape suggests the bottleneck may be structural rather than signal-specific: simple liquid-instrument single-edge systems at `1%` per-trade risk may not reliably clear `+10%` per quarter while staying under v6.3's `6.48%` worst-DD discipline.

The next decision should be a planning-frame review, not a new signal proposal.

## Planning-Frame Review Outcome

Constraint:

- `+10%` per quarter / FTMO Phase 1 target is non-negotiable.

Rejected next moves:

- No iteration 4 in the original signal-search sequence.
- No XAUUSD H4 pullback by inertia.
- No DD-threshold relaxation by itself.
- No portfolio-insurance amendment for EURUSD, because it did not add pass or checkpoint quarters.

Selected lead frame:

**Conversion architecture: post-checkpoint risk escalation in a v7 fork.**

Rationale:

- v6.3 reached checkpoint in `8 / 25` clean chronological quarters but passed only `2 / 8` checkpoint quarters.
- Improving checkpoint conversion from `25%` to `50%` would mechanically lift raw pass rate from `8%` to about `16%`.
- This targets the known bottleneck more directly than another signal search.

Guardrail:

This is not v6.3 micro-tuning. v6.3 remains frozen as benchmark/control. Any implementation must be a v7 architecture experiment after a pre-registered design proposal is reviewed and locked.

Iteration-counter handling:

- Path 1 signal-search iteration cap remains reached.
- Post-checkpoint risk escalation is a fresh architecture research item with its own cap.
- It must still use the same anti-overfit discipline: one proposal, locked parameters, explicit validation design, explicit kill criteria.

Immediate next action:

Draft a design proposal for post-checkpoint risk escalation. The proposal must define:

- exact escalation trigger
- risk multiplier or schedule
- daily-loss and peak-DD guardrails
- interaction with dynamic campaign floor
- affected modules/trades
- train/validation/holdout treatment
- acceptance thresholds
- kill criteria

No tests or EA/MQL4 edits are authorized until that proposal is accepted.

Session resume pointer:

`V7_SESSION_STATE_2026_05_09.md` captures the end-of-session state, including the pending Frame 2A decisions, data dependency, active iteration counters, and what not to do on resume.

## Open items status

1. ~~Broker symbol availability for US30 / NAS100 on the prop-firm broker.~~ **Resolved 2026-05-09:** FTMO has `US30.cash` and `US100.cash`. Spread / financing / trading-hours specifics will be captured at step 7 (cost-realism), not before research.
2. ~~MT4 H1 history availability and depth for the chosen index symbol.~~ **Resolved 2026-05-09:** Dukascopy H1 CSV in hand for both symbols, integrity-checked. FTMO MT4 H1 depth is shallow (~2026.01 only); Dukascopy is the research source, FTMO is the cost-realism source.
3. ~~v6.3 start-score logging rerun.~~ **Resolved 2026-05-09:** De-prioritized. Off the critical path. Was needed only for interpreting a Strong Path 2 result; Path 2 was rejected.
4. ~~Acceptance thresholds lock-in.~~ **Resolved 2026-05-09:** Locked, including the losing-window overlap definition. Symbol protocol also locked: USA30 and USATECH compared in research, ONE primary frozen before validation.

All gating items resolved. Research begins only on explicit user authorization.

### Research Data Confirmation

Dukascopy H1 CSV research data is now available in the project folder:

| Symbol | Bid file | Ask file | Range | Real H1 bars | Audit coverage | Verdict |
|---|---|---|---|---:|---:|---|
| USA30 | `USA30IDXUSD_Hourly_Bid_2018.01.01_2026.05.09.csv` | `USA30IDXUSD_Hourly_Ask_2018.01.01_2026.05.09.csv` | `2018-01-02 -> 2026-05-08` | `48,607` | `94.2%` | Research-grade |
| USATECH | `USATECHIDXUSD_Hourly_Bid_2018.01.01_2026.05.09.csv` | `USATECHIDXUSD_Hourly_Ask_2018.01.01_2026.05.09.csv` | `2018-01-02 -> 2026-05-08` | `48,604` | `94.2%` | Research-grade |
| DOLLAR | `DOLLARIDXUSD_Hourly_Bid_2018.01.01_2026.05.09.csv` | `DOLLARIDXUSD_Hourly_Ask_2018.01.01_2026.05.09.csv` | `2018-01-02 -> 2026-05-08` | `44,751` | `86.1%` | Research-grade |

Codex integrity check:

- Bid/ask timestamps align exactly for each symbol.
- No duplicate timestamps.
- No OHLC violations.
- Around `98%` of rows are real bars with volume greater than zero.
- Flat/zero-volume filler bars are weekend/holiday filler and should be filtered from analysis.
- Largest gaps are weekend/holiday gaps, not suspicious mid-week holes.
- Close-spread medians: USA30 about `3.91`, USATECH about `3.07`, DOLLAR about `0.037`.

Read:

The index H1 data blocker is cleared for research. FTMO `US30.cash` / `US100.cash` remain required later for final cost-realism and broker-symbol sanity checks, because Dukascopy research prices are not identical to FTMO CFD execution.

## Driver/challenger notes

- This brief is the driver's output. The challenger should review the diagnostic claim ("D1 trend present, H1 stalled" is the dominant v6.3 failure mode) before research begins, since that claim shapes which candidates rank where.
- The brief intentionally avoids picking specific entry/exit logic. If that gap feels wrong, that is the right time to push back — at planning, not after a first implementation pass.
- Any disagreement with the kill criteria or acceptance thresholds should be raised before research begins. Re-tuning thresholds after seeing validation results would repeat the failure mode the plan was designed to prevent.
