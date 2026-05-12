# V8 Velocity Pocket Pre-Registration

Date: 2026-05-12

Status: pre-candidate rules of engagement. No instrument, timeframe, signal class, or direction bias is selected in this document.

## Purpose

V7 closed because v6.3 proved to be a controlled-risk XAUUSD campaign scaffold, not a reliable FTMO pass engine. The repeated failure pattern was not just weak signal quality; it was a velocity mismatch:

```text
Systems clean enough to respect drawdown were usually too slow to reach +10%.
Systems with enough pass velocity tended to breach the drawdown ceiling.
```

V8 begins from a different question:

```text
Where does the market naturally offer +10%-quarter velocity without requiring oversized risk?
```

This file locks the definition and evidence gates for "velocity pockets" before candidate sourcing begins.

## Path 1 Iteration 3 Disambiguation

Working interpretation: **(b)**.

Path 1 Iteration 3 killed H1 index NR-N compression breakout, not the whole velocity-pocket thesis.

What was killed:

- USA30 / USATECH H1 NR-N setup.
- No trend filter.
- Breakout on the immediately following H1 bar.
- ATR(14) stop at `K * ATR`.
- US cash-session trigger window.
- Flat by 20:00 UTC.
- One open position max.

The working read is that the tested implementation collapsed detection, trigger, and execution onto a generic H1 abstraction. A V8 candidate may proceed only if it defines the velocity source at its native timescale before choosing an instrument or signal.

Kill condition: **(c)**.

If native-timescale velocity cannot be defined numerically before candidate sourcing, the velocity-pocket thesis is killed before implementation.

## Velocity Pocket Definition

A candidate pocket must satisfy all five conditions below before any EA code or tester run.

| Condition | Requirement |
|---|---|
| Magnitude | Conditional expected realized move must be at least `2.0 * ATR(N)` over the pocket duration, where `N` is the detection timescale. |
| Direction assignment | A pre-specified rule must assign the pocket as long, short, or two-sided at detection time, before the pocket opens. Direction cannot be assigned from outcome labels. |
| Window | The pocket must have a defined start trigger and defined end, either time-based or condition-based. Open-ended "wait for it to play out" definitions are disallowed. |
| Frequency | The pocket must recur often enough to produce at least `30` independent occurrences in the `2020-2026` sample on the eventual instrument. Independence must be defined before measurement; by default, pockets in the same instrument/direction must be separated by at least `5` trading days, and no single calendar quarter may contribute more than `20%` of accepted occurrences. |
| Velocity | Median completion time must be short enough that `+10%` cumulative return over a 60-trading-day quarter is reachable at `0.75-1.00%` risk per pocket. The candidate must demonstrate at least `50%` directional hit rate and at least `1.5R` median payoff on the pre-candidate pocket sample before tester runs. |

The velocity condition is the core gate. A clean edge that cannot plausibly reach the FTMO Phase 1 target at v6.3-equivalent risk is not a V8 candidate under this brief.

The `50%` hit-rate and `1.5R` payoff requirements imply a minimum gross expectancy of `+0.25R` per pocket before costs. They are gates, not optimistic assumptions.

## Native Timescale Requirement

Every future candidate brief must state three timescales separately:

| Timescale | Meaning |
|---|---|
| Detection timescale | The scale where the velocity source is measured or becomes visible. |
| Trigger timescale | The scale where the entry decision is made. This may equal the detection timescale or be one step coarser. |
| Execution timescale | The scale where stops, exits, and invalidation operate. |

The candidate must explain why those timescales match the proposed velocity source.

Known failure patterns:

- v6.3 mixed D1 detection with H1 execution and did not reliably convert the middle.
- Path 1 Iteration 3 collapsed detection, trigger, and execution onto H1 and failed the locked gates.

A candidate that cannot articulate detection, trigger, and execution timescales separately is incomplete.

## Scope Guards

This pre-registration does not lock:

- Instrument.
- Timeframe.
- Signal class.
- Direction bias.
- Broker symbol.
- Specific entry or exit rule.

Those belong in a later candidate brief after the velocity source is numerically defined.

This pre-registration does lock:

- The definition of a velocity pocket.
- The requirement to prove the pocket exists before implementation.
- The native-timescale decomposition.
- The forbidden-list review.
- The role split and gate ownership.

## Forbidden List

The following structural patterns are closed unless a future candidate explicitly justifies why reuse is not a v7 revival:

| Forbidden or restricted pattern | Reason |
|---|---|
| H1 NR-N compression breakout on USA30 / USATECH | Directly killed in Path 1 Iteration 3. |
| Generic H1 close breakout | Too close to Path 1 index momentum and Iteration 3 abstractions. |
| Session filter plus ATR stop as the main thesis | Session and ATR can support a thesis, but they are not a velocity source by themselves. |
| XAUUSD H1 trend-continuation | v6.3 already tested this family extensively. |
| D1-regime-gated rewrite of v6.3 | Path 2 rejected the D1 feature family as a checkpoint discriminator. |
| "v6.3 plus one more filter" | Closed by v7 structural diagnosis. |
| Selectivity as the mechanism | Selectivity is allowed only when tied to a measurable velocity source. It cannot be the thesis. |

Evaluation-side anti-patterns are also forbidden:

| Forbidden evaluation pattern | Reason |
|---|---|
| Rolling-window-optimized "best parameter" presentation | Rolling windows may be secondary stress references, but not the headline proof or parameter source. |
| Post-hoc instrument filtering | A candidate may not test a basket and then keep only the instruments that worked unless that selection rule was pre-registered. |
| Parameter ensembles as failure smoothing | Combining weak or failed parameter sets into an ensemble is not allowed unless ensemble construction was part of the candidate brief before results. |
| Threshold relaxation after seeing results | Existing v7 discipline carries forward: a near miss is still a miss unless a new brief is opened before more testing. |

Every future candidate brief must include a forbidden-list declaration:

```text
This candidate reuses / does not reuse the following restricted patterns: ...
Justification: ...
```

## Evidence Protocol Before Candidate Sourcing

Before selecting an instrument or signal, the thesis driver must describe a measurable velocity source in plain market terms.

Required pre-candidate evidence:

1. A proposed pocket definition using the five conditions above.
2. A proposed measurement method for realized move, direction assignment, and completion time.
3. A statement of the detection, trigger, and execution timescale candidates, without yet choosing a trading instrument.
4. A reason the proposed source is not merely H1 compression breakout or v6.3 trend-continuation in disguise.

Only after this exists may the team source candidate instruments that plausibly contain the pocket.

## Phase 1 Gate Discipline

FTMO Phase 1 remains the primary research frame:

- `+10%` target.
- Controlled drawdown.
- v6.3-equivalent risk per pocket: `0.75-1.00%`.

There is no built-in funded/personal fallback track in this brief. If a thesis misses Phase 1 gates but looks useful for another account type, that becomes a separate research question with a separate pre-registration.

## Roles

Claude role:

- Propose thesis inputs.
- Challenge whether the market mechanism is independently motivated.
- Surface ambiguity before lock.

Codex role:

- Own the pre-registration files.
- Lock validation gates and kill criteria in repo-visible documents.
- Challenge reproducibility, hidden fitting, and candidate shopping.
- Refuse implementation until the pre-candidate gates are satisfied.

The proposer and gatekeeper should remain distinct whenever practical.

## Candidate Brief Requirements

The first V8 candidate brief must include:

- Velocity pocket definition with numeric thresholds.
- Native-timescale declaration.
- Instrument selection rationale after, not before, velocity-source definition.
- Validation windows.
- Pass/DD gates.
- Robust-cost protocol.
- Kill criteria.
- Forbidden-list declaration.

No EA source fork, simulator build, or tester run is authorized by this file.
