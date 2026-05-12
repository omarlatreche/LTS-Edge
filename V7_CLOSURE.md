# V7 Research Closure

Date: 2026-05-12

## Decision

V7 research is closed.

The project direction is now:

1. Preserve `LTS_Prop_Engine_v6.mq4` / v6.3 as a controlled-risk XAUUSD infrastructure scaffold and benchmark.
2. Do not deploy v6.3 as a paid FTMO pass engine.
3. Do not revive v7 by spending the remaining reserved Frame 2A or Frame 4 iterations without a genuinely new thesis.
4. Start a new EA family / portfolio thesis from first principles in a separate research phase.

This document is the repo-level handoff marker. `V7_SESSION_STATE_2026_05_09.md`, `V7_PORTFOLIO_PLANNING.md`, and `V7_PATH1_PORTFOLIO_BRIEF.md` contain the full supporting record.

## Evidence Summary

Clean chronological v6.3 validation from `2020 Q1` through `2026 Q1`:

| Metric | Result |
|---|---:|
| Windows | `25` |
| Passes | `2 / 25` |
| Raw pass rate | `8.0%` |
| Checkpoints | `8 / 25` |
| Checkpoint conversion | `2 / 8 = 25.0%` |
| Positive returns | `10 / 25` |
| Average return | `-0.04%` |
| Average max DD | `3.95%` |
| Worst return | `-4.66%` |
| Worst max DD | `6.48%` |

The two clean chronological passes, `2024 Q1` and `2026 Q1`, survived robust-cost checks at spread `20` and slippage `8`. That supports the risk/infrastructure quality of v6.3, but it does not overcome the low base-rate pass problem.

## Closed Research Paths

| Path / frame | Outcome |
|---|---|
| Path 2: XAUUSD regime-first audit | Rejected. The frozen D1 signature fired on `7 / 8` checkpoint quarters and `7 / 8` comparison non-checkpoint quarters. |
| Path 1: multi-edge signal search | Closed after `3 / 3` KILL outcomes: index H1 momentum, EURUSD H4/D1 trend continuation, and index NR-N volatility breakout. |
| Frame 2A: post-checkpoint risk escalation | Closed after `2 / 3` KILL outcomes. Uniform and confirmation-gated escalation did not create robust conversion under locked gates. |
| Frame 4: mid-quarter abort / activation timing | Closed after `2 / 3` KILL outcomes. Day-30 abort timing did not materially reduce DD and reduced aggregate return. |

Remaining Frame 2A and Frame 4 iterations are reserved only. They are not active next steps.

## Structural Diagnosis

v6.3 is a controlled-risk XAUUSD campaign engine, not a reliable FTMO pass engine.

What worked:

- Prop-firm risk plumbing generalized better than the signal logic.
- Dynamic campaign floor contained failed campaigns without damaging known passes.
- The two real pass windows survived modestly worse execution assumptions.
- Drawdown stayed controlled across the 25 clean chronological quarters.

What did not work:

- Pass generation was too sparse.
- Checkpoint reach was low.
- Checkpoint-to-pass conversion was weak.
- Pre-trade D1 regime features did not separate checkpoint from non-checkpoint quarters.
- Adjacent fixes either arrived too late, increased risk without robust conversion, or failed to add pass-rate lift.

The pattern across the failed paths is structural rather than a near-miss parameter problem.

## What Is Preserved

Preserve these assets for the next family:

- v6.3 prop-risk scaffold.
- Campaign state machine concept.
- Dynamic floor concept.
- End-of-test summary and diagnostic logging.
- `parse_frame2a_logs.py`, `simulate_frame2a.py`, `simulate_frame4.py`.
- `frame2a_log_extract/` generated outputs as the reproducible v7 research record.
- The anti-overfitting workflow: pre-registration, locked gates, mechanical KILL decisions, and no threshold relaxation after results.

Do not treat the following as proven foundations for the next family:

- Current XAUUSD H1 trend-continuation signal logic.
- Current v6.3 start gate.
- Rolling/selected benchmark windows as proof of generalization.
- v7 sub-lever tuning as the default continuation path.

## New-Family Constraints

The next EA family should be pre-registered before any tester run.

Minimum constraints:

- Not XAUUSD-only unless the signal is not H1 trend-continuation.
- Not a D1-regime-gated rewrite of v6.3.
- Not "v6.3 plus one more filter."
- Signal premise must be independently motivated before implementation.
- Validation windows, pass/DD gates, robust-cost checks, and kill criteria must be locked before execution.

The campaign/risk scaffold may be reused, but the signal thesis must stand on its own.

## Deployment Position

No paid v6.3 FTMO deployment is recommended as the main business path.

Acceptable v6.3 use:

- Demo telemetry.
- Paper/live shadow observation.
- A tiny bounded paid experiment only if separately pre-registered with a strict challenge-fee budget and no scaling assumptions.

Default position:

```text
New EA family first. v6.3 is infrastructure and benchmark, not the business engine.
```

## Repo Packaging Recommendation

Before starting new-family work, create a closure commit or reviewed closure bundle.

Recommended commit contents:

- `V7_CLOSURE.md`
- `V7_SESSION_STATE_2026_05_09.md`
- `V7_PORTFOLIO_PLANNING.md`
- `V7_PATH1_PORTFOLIO_BRIEF.md`
- `parse_frame2a_logs.py`
- `simulate_frame2a.py`
- `simulate_frame4.py`
- `frame2a_log_extract/`
- v6.3 source/docs/ledger changes after Claude/Codex review confirms the source diff is intended.

Data files:

- The Dukascopy and MT4 market CSVs are useful but bulky source data.
- Prefer keeping them out of the main repo unless the project intentionally wants data versioning.
- If excluded, record their filenames, date ranges, and source in the research docs so the analysis remains reproducible.

## Team Handoff

Claude challenge result: no fresh motivating thesis is present for the reserved v7 iterations. Closure stands.

Recommendation: review and package the closure state, then open a separate session for the new-family thesis with a clean decision surface.
