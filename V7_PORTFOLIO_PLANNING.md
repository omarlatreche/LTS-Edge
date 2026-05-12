# LTS Prop Engine v7 / Portfolio Planning Document

Last updated: 2026-05-10

Status: planning only. No v7 trading logic has been implemented.

## Executive Decision

v6.3 is frozen as a benchmark/control. It should not be micro-tuned further unless a genuinely new, independent hypothesis appears.

The chronological validation result is the controlling evidence:

| Metric | Result |
|---|---:|
| Clean calendar-quarter windows | `25` |
| Passes | `2 / 25` |
| Raw pass rate | `8.0%` |
| Checkpoints | `8 / 25` |
| Checkpoint conversion | `2 / 8 = 25.0%` |
| Positive returns | `10 / 25` |
| Average return | `-0.04%` |
| Average max DD | `3.95%` |
| Worst return | `-4.66%` |
| Worst max DD | `6.48%` |

Both clean chronological passes survived robust-cost checks at spread `20` and slippage `8`:

| Window | Result | Return | PF | Max DD |
|---|---|---:|---:|---:|
| `2024.01.01 -> 2024.04.01` | pass | `+10.00%` | `10.40` | `3.10%` |
| `2026.01.01 -> 2026.04.01` | pass | `+10.00%` | `3.99` | `4.04%` |

Interpretation:

- v6.3's risk control generalized better than its pass generation.
- The weak point is upstream: regime/start-date selection and low checkpoint reach.
- The two surviving passes are credible, but the raw pass base rate is too low for v6.3 to be treated as a standalone FTMO pass engine.
- v7 should begin with research design, not code.

## Strategic Sequence

The v7 planning phase has two primary paths, but they should not start in parallel. Path 2 comes first because it is cheap, analysis-only, and its answer changes how Path 1 should be framed.

| Rank | Path | Purpose | Current priority |
|---:|---|---|---|
| 1 | Path 2: regime-first XAUUSD v7 audit | Decide whether XAUUSD campaign regimes are detectable before code. | First move. Cheap binary analysis. |
| 2 | Path 1: multi-edge prop portfolio | Improve effective pass probability by combining controlled, weakly correlated edges. | Next, informed by Path 2 outcome. |
| 3 | Different instrument/class search | Explore uncorrelated markets if Path 1 needs broader candidates. | Later, unless portfolio work requires it. |
| 4 | Directional/bull-only audit | Test whether direction is the main issue. | Low priority; evidence does not justify overreacting into bull-only logic. |

Decision discipline:

- Path 2 asks whether XAUUSD campaign regimes can be detected more reliably.
- Path 1 asks whether diversification can create acceptable prop challenge odds even if any single edge is modest.
- If Path 2 finds a clear signature, v7 can advance to a redesigned XAUUSD start gate.
- If Path 2 finds no signature, Path 1 should favor a different instrument or different signal class, not another XAUUSD variant.
- Neither path should begin with EA code.

## Path 2: Regime-First XAUUSD v7 Audit

### Research Question

What regime signature distinguishes checkpoint-reaching XAUUSD quarters from non-checkpoint quarters, beyond what the current v6.3 `0-8` start gate score captures?

If a clear signature exists, it becomes the candidate basis for a redesigned v7 start gate. If no clear signature exists, the project should prioritize portfolio construction over another XAUUSD-only redesign.

### Primary Hypothesis

v6.3's start gate is too coarse. It can open into regimes that look directionally aligned but lack enough expansion freshness, volatility structure, or macro confirmation to reach checkpoint. A better v7 gate may improve checkpoint reach without materially increasing drawdown.

This hypothesis is falsifiable:

- It is supported if checkpoint quarters share a measurable pre-trade regime signature that non-checkpoint quarters lack.
- It is rejected or weakened if checkpoint and non-checkpoint quarters are not separable using reasonable pre-trade features.

### Checkpoint-Reaching Quarter Set

Use the 8 clean chronological quarters that reached checkpoint:

| Window | Result |
|---|---|
| `2020.04.01 -> 2020.07.01` | checkpoint, no pass |
| `2022.07.01 -> 2022.10.01` | checkpoint, no pass |
| `2023.07.01 -> 2023.10.01` | checkpoint, no pass |
| `2023.10.01 -> 2024.01.01` | checkpoint, no pass |
| `2024.01.01 -> 2024.04.01` | pass |
| `2025.01.01 -> 2025.04.01` | checkpoint, no pass |
| `2025.10.01 -> 2026.01.01` | checkpoint, no pass |
| `2026.01.01 -> 2026.04.01` | pass |

### Comparison Set

Compare against at least 8 clean chronological non-checkpoint quarters. The first comparison set should include a balanced mix of losing, flat, and low-damage windows:

| Window | Reason to include |
|---|---|
| `2020.01.01 -> 2020.04.01` | no checkpoint, large controlled loss |
| `2020.07.01 -> 2020.10.01` | no checkpoint, weak follow-through |
| `2021.04.01 -> 2021.07.01` | no checkpoint, worst return |
| `2022.04.01 -> 2022.07.01` | no checkpoint, near-flat positive |
| `2023.04.01 -> 2023.07.01` | no checkpoint, worst DD |
| `2024.04.01 -> 2024.07.01` | no checkpoint, controlled weak window |
| `2024.10.01 -> 2025.01.01` | no checkpoint, near-flat controlled loss |
| `2025.07.01 -> 2025.10.01` | no checkpoint, clean failure |

Do not use rolling starts such as `2024.08 -> 2024.11` or `2025.09 -> 2025.12` as the primary audit set. They remain useful regression references, but clean quarter starts are closer to real challenge activation behavior.

### First-Pass Regime Features

The audit sample is small: 8 checkpoint quarters and 8 non-checkpoint quarters. Too many features create a multiple-testing problem, where a false "signature" can appear by chance. The first pass is therefore capped at 5 primary features plus one cheap structural label.

Capture these values at the first tradable day of each quarter, before EA behavior:

| Feature | Purpose |
|---|---|
| D1 ADX | Detect trend strength versus stale alignment. |
| ATR14 / ATR50 | Separate active expansion from compressed or exhausted volatility. |
| Distance from D1 EMA50 in ATR units | Identify early expansion versus overextension. |
| DXY / EURUSD inverse 20-day slope | Test whether macro alignment adds signal beyond current scoring. |
| Bars since last D1 close-to-close swing greater than X * ATR | Approximate freshness of trend impulse. |
| D1 EMA stack: EMA20 / EMA50 / EMA200 | Cheap regime label: clean stack versus tangled stack. |
| Start score and start direction | Establish what the existing gate already believed. |

Drop from the first pass:

- H4 trend state.
- H1/H4 alignment.
- Prior 10/20-day range location.

These can be revisited only if the primary audit is inconclusive and there is a specific reason to believe they add non-duplicative information.

Important constraint:

Only features knowable at the start of the window may be used for start-gate design. Later quarter outcomes are labels, not inputs.

### Collection Protocol

Use a checkpoint-first protocol to reduce data dredging:

1. Collect the 8 checkpoint-reaching quarters first.
2. Before looking at the 8 comparison non-checkpoint rows, write down which feature or feature pair looks promising and the proposed cutoff(s).
3. Freeze that candidate signature in the notes.
4. Collect the 8 comparison rows and test the frozen signature against the pre-registered separation threshold.

This converts the comparison set from another search surface into a test. If the signature is changed after comparison values are visible, label the result exploratory and do not treat it as promotion-grade evidence.

Interpretation cautions:

- Distance from D1 EMA50 and EMA stack are partially redundant. They may be useful together, but they should not be counted as two independent confirmations.
- The comparison set is deliberately balanced across losing, flat, and low-damage failures. It tests whether a signature separates checkpoint windows from typical non-checkpoint failures; it does not prove drawdown protection by itself.

### Data Pull Requirements

For each window, use the first tradable XAUUSD trading day on or after the window start date. Indicator values should reference the most recent completed D1 bar as of that window open.

Required values:

| Source | Values |
|---|---|
| XAUUSD D1 | ADX(14), ATR(14), ATR(50), EMA20, EMA50, EMA200, prior D1 close. |
| XAUUSD D1 freshness | Bars back to the most recent D1 close-to-close move greater than `1.0 * ATR(14)`. |
| v6.3 run output | Start gate score and direction at window start. |
| DXY or EURUSD fallback | Prior D1 close and close 20 D1 bars earlier, so 20-day slope can be computed. |

Collect one quarter at a time during manual MT4 work so bad indicator references can be caught early.

### v6.3 Start-Score Recovery

The existing v6.3 ledger/test-plan records start direction for the 25 clean chronological quarters, but it does not reliably record start score and sub-check contributions for all 16 audit windows.

Use Option C:

1. Collect the 6 regime features for the 8 checkpoint windows first once MT4 history availability is confirmed.
2. In parallel, queue a logging-only v6.3 tester rerun across the 16 audit windows.
3. The rerun must leave v6.3 trading behavior unchanged.
4. At the first tradable bar of each window, log one parseable line with:
   - window start/end
   - start score `0-8`
   - start direction
   - contributing start-gate sub-checks
5. If score logging cannot be added without touching strategy behavior, stop and flag it.

Start score is not required to collect checkpoint rows or freeze candidate regime cutoffs. It is required before final Strong / Weak / Rejected classification, because the audit must check whether the proposed signature adds information beyond the existing v6.3 start gate. If the candidate signature is merely a proxy for the existing `0-8` gate, the v7 redesign case collapses.

### Frozen Candidate Signature

Frozen after the 8 checkpoint rows were computed and before any comparison-set rows were viewed.

Primary candidate rule:

```text
D1 ADX(14) >= 20
OR
abs(D1 close - D1 EMA50) / D1 ATR(14) >= 1.5
```

Reference: most recent completed D1 bar strictly before the first tradable XAUUSD bar on or after the window start.

Pre-comparison checkpoint read:

| Property | Value |
|---|---|
| Checkpoint hits | `7 / 8` |
| Missed checkpoint | `2025.01.01 -> 2025.04.01` |
| Concepts | 2: D1 trend strength and D1 EMA50 displacement. |
| Direction-neutral | Yes, uses absolute EMA50 distance. |
| Market rationale | v6.3 needs either established trend strength or meaningful directional displacement; flat low-ADX chop near EMA50 is less likely to reach checkpoint. |
| Strong threshold | Rule must fire on `<=3 / 8` comparison windows, excluding at least `5 / 8`. |

Exploratory-only fallback:

```text
D1 ADX(14) >= 18
```

This fallback may be reported for transparency only. It is not promotion-grade because it was identified after reviewing checkpoint rows and should not be used to rescue the primary rule after comparison data is visible.

### Path 2 Audit Result

Result after applying the frozen candidate rule to the 8 comparison non-checkpoint windows:

| Set | Rule fires | Rule excludes |
|---|---:|---:|
| Checkpoint set | `7 / 8` | `1 / 8` |
| Comparison non-checkpoint set | `7 / 8` | `1 / 8` |

Classification: **Rejected**.

Reason:

- Strong required the rule to fire on `<=3 / 8` comparison windows.
- The rule fired on `7 / 8` comparison windows.
- The rule fired on `14 / 16` total audit windows, so it did not discriminate between checkpoint-reaching and non-checkpoint quarters.

Exploratory fallback:

- `D1 ADX(14) >= 18` also failed.
- It fired on `6 / 8` comparison windows and did not meet the `6 / 8 + 6 / 8` threshold.

Interpretation:

The selected first-pass D1 regime features do not separate XAUUSD checkpoint quarters from non-checkpoint quarters. Several non-checkpoint windows looked more trend-aligned at the start than several checkpoint windows. Per the anti-overfitting rule, the correct response is not to add more features or rescue the audit with H4/H1 alignment; it is to accept that no useful pre-trade D1 signature was found.

Decision:

- Do not draft a v7 XAUUSD start-gate redesign brief from this audit.
- Pivot to Path 1 multi-edge portfolio research.
- Path 1 should favor non-XAUUSD or a materially different signal class, not another XAUUSD trend-continuation variant.
- The v6.3 start-score logging rerun is no longer on the critical path. It can be parked unless later portfolio analysis needs it.

Path 1 follow-up:

- `V7_PATH1_PORTFOLIO_BRIEF.md` is the canonical brief for the multi-edge portfolio candidate.
- Lead candidate: US30 / NAS100 H1 momentum.
- Refined failure diagnosis: many non-checkpoint XAUUSD quarters began with strong D1 trend readings, so the second edge should target cases where XAUUSD D1 looks tradable but v6.3 H1 execution fails to gain traction.

### Analysis Output

The Path 2 audit should produce a simple table:

| Window | Label | Direction | D1 ADX | ATR ratio | EMA50 distance ATR | DXY 20-day slope | Freshness | EMA stack | Notes |
|---|---|---|---:|---:|---:|---:|---|---|---|

Then classify candidate signatures as:

| Classification | Meaning |
|---|---|
| Strong | Separates most checkpoint windows from most non-checkpoint windows and has a market rationale. |
| Weak | Some signal, but many exceptions or likely fitted. |
| Rejected | No meaningful separation. |

### Path 2 Promotion Thresholds

A regime-first v7 start-gate hypothesis may move to implementation only if it meets all conditions below:

| Gate | Threshold |
|---|---|
| Separation quality | Candidate signature identifies either at least `7 / 8` checkpoint quarters while excluding at least `5 / 8` comparison non-checkpoint quarters, or at least `6 / 8` checkpoint quarters while excluding at least `6 / 8` comparison non-checkpoint quarters. |
| Market rationale | Rule can be explained as trend freshness, volatility expansion, macro alignment, or non-overextension. |
| Simplicity | No more than 2 new gate concepts for first implementation. |
| Direction neutrality | Does not become bull-only unless SELL_BIAS failure is proven separately. |
| Anti-overfit check | Does not exist only to explain one remembered window. |

After implementation, use the validation protocol below before promotion.

## Path 1: Multi-Edge Portfolio Brief

### Research Question

Can the project improve prop challenge pass odds by combining v6.3 with one or more controlled, weakly correlated edges that perform when v6.3 fails to reach checkpoint?

### Portfolio Hypothesis

v6.3 is not strong enough alone, but it may be useful as one component in a portfolio because:

- Its true passes survived robust-cost checks.
- Its drawdown profile was mostly contained across clean chronological quarters.
- Its failures are often low-traction, non-checkpoint starts rather than catastrophic blowups.

A second edge should be selected by anti-correlation to v6.3, not by standalone excitement.

### v6.3 Failure Regimes To Target

The second edge should prefer conditions where v6.3 tends to lose or stagnate:

| v6.3 weakness | Desired second-edge behavior |
|---|---|
| Choppy/low-traction starts | Earns modestly or stays flat in range conditions. |
| Gate opens but no checkpoint | Uses different participation logic or market structure. |
| Calendar-quarter start sensitivity | Less dependent on perfect activation timing. |
| XAUUSD trend continuation drought | Performs in another instrument, timeframe, or regime. |
| Momentum and pullback both negative | Uses a non-trend-continuation premise. |

### Candidate Edge Families

These are research briefs, not implementation decisions:

| Rank | Candidate | Why it may diversify | Main risk |
|---:|---|---|---|
| 1 | US30 or NAS100 H1 momentum | Strongest a-priori anti-correlation case; same broad trend-continuation infrastructure, different macro cycle. | Index gaps, session behavior, and prop symbol costs need careful validation. |
| 2 | EURUSD H4/D1 trend continuation | Cheapest spread and different behavior from gold; may earn when XAUUSD chops. | Slower path to a 10% Phase 1 target. |
| 3 | XAUUSD H4 pullback with D1 trend filter | Same instrument but different timeframe; may reduce H1 noise. | Still exposed to gold-specific regime droughts. |

Lower-priority or rejected for first portfolio brief:

| Candidate | Reason |
|---|---|
| XAUUSD range/mean-reversion | Spread economics and spike risk are unattractive for prop challenge targeting. |
| Carry/swing component | Likely too slow for Phase 1 velocity. |
| Crypto | Prop-firm rules and execution constraints make it a poor first candidate. |

### Portfolio Evaluation

The portfolio should be judged as a prop attempt system, not just as separate EA results.

Track:

| Metric | Reason |
|---|---|
| Raw pass rate per component | Determines whether each edge earns its place. |
| Combined pass rate | Main practical goal. |
| Worst combined DD | Must remain inside prop-firm safety limits. |
| Overlap of losing windows | Measures whether diversification is real. |
| Overlap of checkpoint windows | Shows whether edges are redundant. |
| Time-to-target distribution | Important for challenge planning. |
| Robust-cost survival | Filters fragile wins. |

### Second-Edge Acceptance Thresholds

A second edge is worth implementing only if the pre-code brief can specify:

| Requirement | Minimum standard |
|---|---|
| Target regime | Clear statement of when it should trade and why v6.3 struggles there. |
| Validation windows | Chronological windows defined before tuning. |
| Expected correlation | Explicit expectation about which v6.3 bad windows it should improve. |
| Risk budget | How it shares or replaces v6.3 risk under prop constraints. |
| Kill criteria | Conditions under which the idea is abandoned. |

After implementation, a candidate second edge should show at least one of:

- `>=15%` raw pass rate on clean chronological windows with controlled DD.
- Clear positive contribution in v6.3 non-checkpoint windows without making v6.3 pass windows materially worse.
- Combined portfolio pass rate meaningfully above v6.3's `8%` baseline while preserving average/worst DD discipline.

## v6.3 Infrastructure To Reuse

Reuse infrastructure because it generalized better than signal generation.

| Asset | Reuse recommendation |
|---|---|
| Prop-firm risk scaffold | Reuse. Keep daily/overall room checks, target handling, account-size assumptions, and safety buffers. |
| Campaign state machine | Reuse conceptually. It gives clear lifecycle states for challenge attempts. |
| Dynamic campaign floor | Reuse as protective layer after enough profit is earned. Do not tune it to force passes. |
| Adaptive post-checkpoint loss tolerance | Reuse cautiously. It helped known passes, but should remain tied to checkpoint reach. |
| End-of-test summary block | Reuse and extend. It is essential for manual MT4 research. |
| Module P/L and reject counters | Reuse. They made failure modes visible. |
| Post-checkpoint trace logging | Keep as diagnostic tooling, not default strategy logic. |
| Anti-overfitting workflow | Reuse as a hard process rule. |

Do not blindly reuse:

| Asset | Reason |
|---|---|
| Current 0-8 start gate | It is the suspected weak point. Treat it as a baseline to beat. |
| Current momentum/pullback mix | It may remain useful, but should not define v7 before regime audit. |
| Weak-push close guard | It improved some failures but killed a known pass. Keep as rejected/default-off research history. |
| Rolling-window benchmark as proof | It is a regression set, not a generalization test. |

### Safest Reuse Method

When implementation begins, fork rather than mode-flag v6.3:

1. Copy `LTS_Prop_Engine_v6.mq4` to `LTS_Prop_Engine_v7.mq4`.
2. Immediately stub the start gate so it always returns `score=0` and `NEUTRAL`.
3. Add a placeholder `CampaignRegimeScore`.
4. Keep the prop risk scaffold, campaign state machine, dynamic floor, instrumentation, and summary block intact.
5. Keep momentum and pullback code present, but treat them as placeholders pending the regime audit.

The expected first v7 build should compile, run, and obviously take no trades. Development then replaces stubs deliberately. This makes accidental drift into "v6.3 with tweaks" visible.

Avoid building v7 as a set of mode flags inside v6.3. That is easier to corrupt and harder to reason about.

## Validation Design Before Code

### Data Splits

Use clean calendar quarters as the primary validation unit. Rolling starts may be secondary stress tests, but they should not be the headline estimate.

Recommended split:

| Split | Windows | Purpose |
|---|---|---|
| Research/train | `2020 Q1 -> 2023 Q4` | Discover regime signatures and define second-edge briefs. |
| Validation | `2024 Q1 -> 2026 Q1` | Evaluate candidate rules after design; includes both known clean v6.3 chronological passes. |
| Final holdout | Pre-2020 quarters not used during v6 development, if MT4 history supports them. | Final promotion check only. |

Holdout integrity note:

- `2024 Q1` and `2026 Q1` are both known v6.3 clean chronological passes, so they belong in validation, not final holdout.
- `2018 Q4 -> 2019 Q1` was already used once, so it is not pristine, but it remains cleaner than recent windows that shaped v6 thinking.
- Genuine holdout integrity requires older data that was never run during v6 development. If MT4 history supports `2014 -> 2017` quarters, reserve them for final holdout.

### Baseline Comparisons

Every v7 or portfolio candidate must be compared against:

| Baseline | Required comparison |
|---|---|
| v6.3 clean chronological baseline | Must beat `2 / 25` raw passes or materially improve checkpoint reach without worse DD. |
| v6.3 selected/rolling benchmark | Must not obviously destroy known strong-window behavior. |
| Robust-cost v6.3 winners | Candidate wins should survive spread `20`, slippage `8` before promotion. |

### Metrics

Record these for every candidate:

| Metric | Formula / read |
|---|---|
| Raw pass rate | `passes / total windows` |
| Checkpoint reach rate | `checkpoint windows / total windows` |
| Checkpoint conversion rate | `passes / checkpoint windows` |
| Controlled-fail rate | Non-pass windows with DD under roughly `4-5%` and no prop danger. |
| Positive-return rate | Positive windows / total windows. |
| Average return | Mean window return. |
| Worst return | Largest losing return. |
| Average max DD | Mean max DD. |
| Worst max DD | Largest max DD. |
| PF / trades / win rate | Supporting diagnostics, not primary promotion criteria. |
| Module/instrument contribution | Required for multi-edge analysis. |
| Robust-cost survival | Passes rerun at spread `20`, slippage `8`. |

### Promotion Thresholds

Pre-register thresholds before coding:

| Result band | Meaning | Action |
|---:|---|---|
| Raw pass rate `>=25%` and DD no worse than v6.3 | Strong candidate. | Consider demo/live validation after robust-cost checks. |
| Raw pass rate `15-25%` with improved checkpoint reach and controlled DD | Useful component. | Consider portfolio inclusion, not standalone scale. |
| Raw pass rate `5-15%` | Marginal. | Only keep if it is strongly diversifying versus v6.3. |
| Raw pass rate `<5%` | Not enough pass edge. | Reject or redesign. |

Additional hard gates:

- Worst max DD should not exceed v6.3's chronological worst DD of `6.48%` unless pass-rate improvement is large and explainable.
- Average max DD should stay near or below v6.3's `3.95%`.
- No candidate should be promoted from selected rolling windows alone.
- Robust-cost checks are required on all candidate pass windows before production/demo promotion.

### Kill Criteria

Pre-register these limits before v7 implementation:

| Rule | Threshold |
|---|---|
| Parameter budget | No more than 15 new strategy-related inputs, excluding reused risk/state-machine inputs. |
| Iteration cap | Maximum 3 iteration cycles on any research item before forced session-level review. |
| Demo trigger | Once a candidate reaches `>=15%` raw pass rate, survives robust-cost checks, and passes holdout, the next step is 60-day demo deployment, not another optimization round. |
| XAUUSD v7 negative kill | If the regime-redesigned XAUUSD gate does not move raw pass rate above `10%`, freeze that XAUUSD path and pivot to Path 1. |

These rules exist to prevent v7 from becoming another parameter-fitting loop.

## Collaboration Model

The operating model for v7 should be principle-based, not a fixed role split.

The strongest decisions in v6 came from both agents doing research, analytics, implementation thinking, and challenge. Codex ran important validation and planning work; Claude produced important research framing, including the start-date sensitivity diagnosis, second-edge anti-correlation framing, pre-registration thresholds, and robust-cost check suggestion. Locking one agent into "research" and the other into "coding" would misrepresent how the project actually improved.

Use a driver/challenger model:

| Phase | Driver | Other agent's role |
|---|---|---|
| Strategic decisions: freeze, scope, what to build | Whoever has the most current context | Active challenge before lock-in |
| Validation design, hypothesis, thresholds | Whoever proposes the change | Adversarial review before any test runs |
| Implementation | Whoever picks it up | Review afterward; flag any mismatch with the agreed hypothesis |
| Result interpretation | Shared | Required to disagree early if the reads diverge |

Practical rules:

- Either agent can drive any phase if they have context and the handoff is clear.
- The current driver owns the next decision until they hand it off or ask for review.
- No surprise trading-logic changes: strategic direction and validation design must be agreed before implementation.
- Implementation can surface new research facts. If code structure, instrumentation, or edge cases change the hypothesis, pause and revise the plan rather than quietly expanding scope.
- The other agent's job is not passive review; it is active challenge against overfitting, weak evidence, and implementation drift.

## Resolved Challenge Notes

Claude's first challenge pass changed the plan in these ways:

| Challenge | Resolution |
|---|---|
| Path 2 feature list was too long for `n=16`. | First-pass audit reduced to 5 primary features plus EMA stack label. |
| `6 / 8` plus `5 / 8` threshold was too loose. | Tightened to `7 / 8 + 5 / 8` or `6 / 8 + 6 / 8`. |
| Path 1 and Path 2 should not run in parallel immediately. | Path 2 ran first and was rejected; Path 1 brief is now next. |
| v7 should not be v6.3 with mode flags. | Implementation plan now says fork to `LTS_Prop_Engine_v7.mq4` and stub the start gate. |
| Second-edge family needed ranking. | First portfolio candidate is US30/NAS100 H1 momentum. |
| Holdout split had known-pass contamination. | `2026 Q1` moved into validation; final holdout should use older pre-2020 data if available. |
| Kill criteria were missing. | Added parameter budget, iteration cap, demo trigger, and XAUUSD negative kill. |
| Path 2 audit needed a binary outcome. | Frozen candidate and fallback were both rejected; do not rescue with more XAUUSD gate features. |
| Path 1 iteration cap reached. | USA30/USATECH momentum, EURUSD H4/D1 pullback, and USA30/USATECH NR breakout all failed locked pass/DD gates. No iteration 4; conduct planning-frame review. |
| Planning-frame review after iteration cap. | `+10%` per quarter remains non-negotiable. Lead frame selected: v7 conversion architecture via post-checkpoint risk escalation. v6.3 remains frozen as control; any test must be a v7 fork/design proposal first. |

## Frame 2A Iteration Record

### Iteration 1: KILL (recorded 2026-05-10)

Hypothesis tested: Uniform `2.0×` post-checkpoint sizing on all post-`+5%` trades converts research checkpoint quarters from `0/4` to `≥2/4` without breaking pass preservation, DD ceiling, or daily-kill budget. Trigger was checkpoint reached (`+5%` closed equity).

Tooling: planning-time Python simulation against MT4 tester `POST-CHECKPOINT CLOSED TRADE` traces, with H1 OHLC reconstruction for intra-bar adverse and favorable excursion, cost-per-lot rescaling, day-attributed daily-kill, and halt-rest-of-day enforcement. v6.3 EA untouched.

Mechanical result:

| Multiplier | Conversion | Pass preservation | Worst DD-from-peak | Daily kills | Verdict |
|---|---|---|---:|---:|---|
| `1.5×` | `0/4` (peak-DD-stop in 2022Q3) | preserved | n/a | 0 | KILL |
| `2.0×` | `2/4` mechanical (2022Q3, 2023Q3) | preserved (10.00% / 10.00%) | 5.66% | 0 | mechanical pass |

Robust read (decisive): 2023Q3's "conversion" is built on `1` post-checkpoint trace row — a single trade whose intra-bar favorable excursion happened to clear `+10%`. One bar's swing is not a meaningful test of a post-checkpoint sizing architecture. Counting it as the second conversion would bend the gate after seeing the data, which is the failure mode pre-registration is designed to prevent. Effective robust conversion = `1/4` → KILL.

What was learned:

1. Pass preservation works at `2.0×` — 2024Q1 and 2026Q1 both clear cleanly under elevated post-checkpoint sizing.
2. DD ceiling is comfortably inside budget at `2.0×` under this trigger.
3. Binding constraint is conversion quality, not capacity. Uniform activation at `+5%` closed takes the elevated risk before the quarter has confirmed it can carry it.

Iteration counter post iteration 1: `1/3` consumed. `2/3` remain.

### Iteration 2: Locked (pre-registered 2026-05-10)

Hypothesis: Tier 2 sizing applied only after the quarter has produced both a realized post-checkpoint winner AND simulator-reconstructed floating peak evidence of campaign velocity converts `≥2/4` research checkpoint quarters with each conversion built on `≥3` post-checkpoint trace rows, while preserving known passes and respecting DD/kill budgets.

Activation rule:

```text
Tier 2 activates after BOTH:
  1. At least one post-checkpoint trade has closed with realized P/L > 0
  2. Simulator-reconstructed H1 floating peak equity since checkpoint
     has reached >= +7.0%
     (this is reconstructed from H1 OHLC inside the simulator;
     it is not MT4 tick-perfect peak)

Activation time = close-time of the first post-checkpoint winning trade
                  that satisfies BOTH conditions.

Pre-activation trades remain 1.0x.
The activating trade itself is NOT retroactively resized; it stays at the
sizing it was opened with (1.0x).
Subsequent eligible trades are sized at 2.0x.
Activation is sticky for the quarter, subject to the demote rules below.
```

Pre-checkpoint logic untouched (Frame 2A is post-checkpoint only).

Sizing:

- Tier 1 (pre-activation): `1.0×` baseline.
- Tier 2 (post-activation): `2.0×` baseline.

Multiplier deliberately unchanged from iteration 1. The lever under test is activation timing, not aggression.

Guardrails (unchanged from iteration 1):

- Demote-to-1× floor: closed equity `< +3%` → sticky demote rest of quarter.
- Daily-kill: floating intraday loss `≤ −4%` → flat-all, halt rest of day.
- Peak-DD safety stop: floating peak-DD `> 8%` → permanent demote to 1× rest of quarter.

Module application: uniform across momentum / expansion / pullback.

Splits (unchanged):

- Research: 2020 Q1 – 2023 Q4 (4 checkpoint quarters: 2020Q2, 2022Q3, 2023Q3, 2023Q4).
- Validation: 2024 Q1 – 2026 Q1 (4 checkpoint quarters incl. 2 known passes 2024Q1, 2026Q1).
- Holdout: pre-2020 (untouched).

Acceptance gates (all four required):

| Gate | Threshold |
|---|---|
| Research conversion | `≥2/4` AND each conversion has `≥3` post-checkpoint trace rows |
| Pass preservation | both 2024Q1 and 2026Q1 `≥ +9.0%` final return |
| Worst DD-from-peak | `≤ 8.5%` across all 8 quarters |
| Daily kills | `≤ 5` total across all 8 quarters |

The `≥3` trace rows clause is tightening, not relaxation — it directly addresses iteration 1's failure mode (1-trade quarter masquerading as conversion) without altering the original `≥2/4` count.

Mid-research kill triggers:

- `0/4` research conversion (counting only `≥3`-trace-row conversions) → immediate KILL.
- `> 12%` single-quarter DD-from-peak → immediate KILL.
- This consumes iteration `2/3`.

Honest-read confirmation: results that fall short are KILL with no relaxation. `1/4` robust conversion → KILL. `2/4` robust with worst DD `8.6%` → KILL.

What changed vs iteration 1:

| Item | Iteration 1 | Iteration 2 |
|---|---|---|
| Trigger | Checkpoint reached (`+5%` closed) | Checkpoint reached AND first post-checkpoint winner closed AND simulator-reconstructed H1 floating peak `≥ +7%` since checkpoint |
| Sizing post-activation | `2.0×` | `2.0×` (unchanged) |
| Conversion gate | `≥2/4` | `≥2/4` with `≥3` trace rows per conversion |
| Pre-activation sizing | `1.0×` until checkpoint | `1.0×` until activation (longer 1× period) |
| Guardrails | as defined | unchanged |
| Splits | as defined | unchanged |

Simulator changes required (Codex):

1. Trigger state machine in `simulate_frame2a.py`:
   - Track `first_post_checkpoint_winner_closed` (bool, post-checkpoint).
   - Track `peak_floating_equity_since_checkpoint` (simulator-reconstructed H1 peak).
   - Activation gate evaluated only at realized-close events, not on every bar.
   - Sticky-on once activated, subject to existing demote rules.
2. No retroactive resize: the activating trade remains at the sizing it was opened with (`1.0×`). `2.0×` applies only to subsequent eligible trades.
3. Coverage report enhancement: mark conversion eligibility per the `≥3`-trace-row rule.
4. Everything else unchanged.

Existing trace data is reusable; no MT4 regen needed unless v6.3 baselines change.

### Iteration 2: KILL (executed 2026-05-10)

Codex implemented the locked activation state machine in `simulate_frame2a.py` and executed against the existing full 8/8 checkpoint-quarter trace set. No EA/MQL4 changes were made.

Mechanical result:

| Quarter | Baseline | Sim | Target | Gate-eligible conversion | Activated | Worst DD | Daily kills | Trace rows | Notes |
|---|---:|---:|---|---|---|---:|---:|---:|---|
| 2020Q2 | 1.50% | 1.50% | false | false | false | 4.88% | 0 | 5 | Demoted |
| 2022Q3 | 4.01% | 4.28% | false | false | true | 9.80% | 0 | 9 | Peak-DD stop |
| 2023Q3 | 6.18% | 6.18% | false | false | true | 1.18% | 0 | 1 | Single trace row remains non-evidence |
| 2023Q4 | 1.50% | 1.50% | false | false | false | 4.65% | 0 | 3 | Demoted |
| 2024Q1 | 10.00% | 10.00% | true | true | false | 3.30% | 0 | 5 | Pass preserved |
| 2025Q1 | 4.04% | 4.04% | false | false | false | 3.36% | 0 | 3 | No conversion |
| 2025Q4 | 2.76% | 2.76% | false | false | false | 4.13% | 0 | 7 | Demoted |
| 2026Q1 | 10.00% | 10.00% | true | true | true | 4.86% | 0 | 6 | Pass preserved |

Acceptance gate read:

| Gate | Threshold | Actual | Verdict |
|---|---:|---:|---|
| Research conversion | `>=2/4`, each conversion `>=3` trace rows | `0/4` | FAIL |
| Pass preservation | both known passes `>= +9.0%` | `10.00% / 10.00%` | OK |
| Worst DD-from-peak | `<= 8.5%` across all 8 quarters | `9.80%` | FAIL |
| Daily kills | `<= 5` total | `0` | OK |

Decision: **Frame 2A iteration 2 = KILL.** The stricter confirmation trigger preserved known passes but did not convert any research checkpoint quarter, and 2022Q3 breached the peak-DD gate.

Iteration counter post iteration 2: `2/3` consumed. `1/3` remains.

### Iteration counter status

| Counter | Used | Remaining |
|---|---:|---:|
| Path 1 signal-search | 3/3 | 0 (closed) |
| Frame 2A architecture | 2/3 | 1 |
| Frame 4 activation timing | 0/3 | 3 (untouched) |
| Path 2 regime audit | 1/1 | 0 (single-shot, rejected) |

## Frame 4 Iteration Record

### Iteration 1: Locked (pre-registered 2026-05-10)

Frame 4 is "activation timing / campaign selection." Different lever from Frame 2A: instead of modifying sizing inside an active quarter, it modifies whether v6.3 trades at all, or continues to trade, in a given window.

Sub-lever space:

| Sub-lever | Description | Status |
|---|---|---|
| 4a — pre-quarter skip filter | Decide at quarter open whether to activate v6.3 at all | Already explored via Path 2 (rejected). D1 features don't separate. Don't repeat. |
| 4b — mid-quarter abort on early weakness | If v6.3 fails to reach an early milestone by day N, halt rest of quarter | **Locked iteration 1.** |
| 4c — session/time-of-day gating | Restrict v6.3 trading to specific session windows | Iteration 2/3 candidate. |
| 4d — equity-self-throttling | Stop entering after consecutive losing days/weeks beyond v6.3's existing limits | Iteration 2/3 candidate. Risks duplication with v6.3 adaptive loss-tolerance. |

Hypothesis (iteration 1): A mid-quarter abort rule that halts v6.3 trading after a fixed early window if no checkpoint has been reached preserves the two known passes (2024Q1, 2026Q1) AND reduces total drawdown in non-checkpoint losing quarters AND does not cost any additional pass.

Locked rule:

```text
If by end of calendar day 30 of the quarter:
  - v6.3 equity is <= START_BALANCE (i.e., 0% return or worse), AND
  - No campaign checkpoint has been hit (i.e., no closed equity excursion >= +5%)
Then:
  - No new entries are allowed for the rest of the quarter.
  - Existing open positions continue under normal v6.3 management until natural close.
  - After the final open position closes, equity becomes fixed for the rest of the quarter.
```

Locked design parameters:

| Parameter | Locked value |
|---|---|
| Day N | 30 calendar days |
| Equity threshold | `<= 0%` from start balance |
| Checkpoint definition | same v6.3 `+5%` closed-equity checkpoint |
| Open-position handling | manage to natural close, no forced close |

Splits (unchanged):

- Research: 2020 Q1 – 2023 Q4 (12 clean chronological quarters).
- Validation: 2024 Q1 – 2026 Q1 (8 clean chronological quarters; 2 known passes).
- Holdout: pre-2020 (untouched).

Acceptance gates (all four required):

| Gate | Threshold |
|---|---|
| Pass preservation | Both 2024Q1 and 2026Q1 final return `≥ +9.0%` |
| False-abort budget | `≤ 1` baseline-positive non-checkpoint quarter aborted into worse final return |
| DD reduction | `≥ 30%` reduction in average max DD across non-checkpoint quarters with baseline negative return, vs. baseline |
| Aggregate effect | Average return across all 25 quarters does not decrease vs. baseline |

Mid-research kill triggers:

- Aborts 2024Q1 or 2026Q1 before checkpoint → immediate KILL.
- Aborts `> 2` baseline-positive quarters into worse outcomes → KILL.
- Aggregate return decreases vs. baseline → KILL.
- This consumes Frame 4 iteration `1/3`.

Honest-read discipline:

- A 25%-DD-reduction (below 30% gate) → KILL, no narrative rescue.
- A pass aborted but "would have hit anyway under a slightly different N" → KILL, no parameter retuning after seeing results.
- The aggregate-return gate is strict by design: even if DD reduction passes, a marginal aggregate-return drop is still a KILL. This is acknowledged at lock time.
- Iteration 2 may revisit `N` or `equity threshold` only as a fresh pre-reg, not a rescue of iteration 1.

Data dependency (verified 2026-05-10):

Frame 4 needs full v6.3 trade-by-trade or daily equity-curve data across all 25 chronological quarters at `Slippage=5`. The existing `POST-CHECKPOINT CLOSED TRADE` traces are insufficient because aborts can fire before any checkpoint is reached.

Verified data state:

- MT4 tester does NOT auto-save per-run reports to disk. `tester/caches` and `tester/files` are empty.
- Tester logs only contain post-checkpoint trade rows; pre-checkpoint trades are not journaled in any current EA build.
- No `*.htm`, `*.csv`, or `*.xml` report files exist in the tester tree.

Recovery options:

1. Re-run all 25 quarters and manually save HTML report per run (no EA change, ~25 manual save dialogs, brittle HTML parsing).
2. Add observational `LogAllClosedTrades` flag to v6.3 EA — pure logging, no behavior change. Single set of reruns regenerates everything in the journal format the existing parser already understands.

Authorization resolved 2026-05-10: option 2 (observational `LogAllClosedTrades` flag) chosen. EA patch landed, smoke test passed (no behavior drift), 25-quarter regen at Slippage=5 completed.

### Iteration 1: KILL (executed 2026-05-10)

Implementation: `simulate_frame4.py` built against parsed `all_trades.csv`. Applies the locked day-30 abort rule per quarter, then computes the four acceptance gates.

Acceptance gate read:

| Gate | Threshold | Actual | Verdict |
|---|---:|---:|---|
| Pass preservation | both 2024Q1 and 2026Q1 `≥ +9.0%` | `2024Q1 = 0.00%`, `2026Q1 = 10.00%` | FAIL |
| False-abort budget | `≤ 1` baseline-positive non-checkpoint quarter aborted into worse outcome | `1` (2022Q2: `+0.31% → -1.99%`) | OK |
| DD reduction | `≥ 30%` reduction in average max DD across baseline-negative non-checkpoint quarters | `13.81%` | FAIL |
| Aggregate effect | average return across 25 quarters does not decrease vs baseline (`-0.04%`) | `-0.44%` | FAIL |

Decision: **Frame 4 iteration 1 = KILL.** No threshold relaxation applied.

Critical structural finding (informs iteration 2):

The 2024Q1 abort fired at day-30 (2024-01-31 00:00) when v6.3 had **closed zero trades** for the quarter. The first 2024Q1 trade opened later that same day at 16:00. The locked rule treated "day 30 + flat equity" as evidence of failed campaign expression, when in reality v6.3 had not yet expressed itself at all.

This is a category error in the rule, not a threshold-tuning issue. "Day 30 and flat" is not the same as "30 days of failed campaign evidence." The full +10% pass quarter was converted into a 0% null trade because the abort blocked all 7 trades before the EA had a chance to run.

Secondary findings:

- DD reduction ceiling at day-30 abort timing is structurally limited to ~14% — most drawdown damage in losing quarters is already taken before day 30. Aborts at this timing prevent additional entries but do not undo the existing damage. Even with maximum-aggressive aborts (24/25 quarters aborted), the 30% DD-reduction gate is unreachable.
- Aggregate-return gate is binding. The rule blocked recovery in some baseline-positive recovering quarters (notably 2022Q2).

### Iteration 2: Locked (pre-registered 2026-05-10)

Hypothesis: A mid-quarter abort rule that fires only when v6.3 has had meaningful expression opportunity AND has failed to convert preserves passes that start late while still cutting drawdown in genuinely failing quarters.

Framing: this is **not** a rescue of iteration 1. It addresses a structural category error revealed by iteration 1. The locked iteration 1 thresholds (`N=30`, equity `≤ 0%`) are explicitly preserved.

Locked rule:

```text
At end of calendar day 30 of the quarter:
  IF v6.3 has closed >= 3 trades since quarter start, AND
     v6.3 equity is <= START_BALANCE (i.e., 0% return or worse), AND
     No campaign checkpoint has been hit (closed equity excursion >= +5%)
  THEN:
     - No new entries are allowed for the rest of the quarter.
     - Existing open positions continue under normal v6.3 management
       until natural close.
     - After the final open position closes, equity becomes fixed for
       the rest of the quarter.
```

Locked design parameters:

| Parameter | Locked value | Change vs iter 1 |
|---|---|---|
| Day N | 30 calendar days | unchanged |
| Equity threshold | `<= 0%` from start balance | unchanged |
| Checkpoint definition | v6.3 `+5%` closed-equity checkpoint | unchanged |
| Activity precondition | `>= 3` closed trades since quarter start | **new** |
| Open-position handling | manage to natural close | unchanged |

Rationale for activity precondition (`X = 3`):

- Mirrors v6.3's existing `MaxConsecutiveLosses=3` and `StrategyMaxLossTrades=3` thresholds — internal project consistency.
- Mirrors the `≥3` trace rows evidence-quality rule adopted in Frame 2A iteration 2 — same project-wide "≥3 = meaningful sample" pattern.
- Lowest count where outcomes are not dominated by single-trade luck.
- Closed trades chosen over entries opened: rule is about evidence of failed campaign expression; closed trades give realized information, entries opened would let open risk count as "evidence" before the system has produced an outcome.

Splits unchanged: research 2020Q1-2023Q4 (12 q), validation 2024Q1-2026Q1 (8 q, 2 known passes), holdout pre-2020.

Acceptance gates unchanged from iteration 1:

| Gate | Threshold |
|---|---|
| Pass preservation | both 2024Q1 and 2026Q1 `≥ +9.0%` |
| False-abort budget | `≤ 1` baseline-positive non-checkpoint quarter aborted into worse outcome |
| DD reduction | `≥ 30%` reduction in average max DD across baseline-negative non-checkpoint quarters |
| Aggregate effect | average return across 25 quarters does not decrease vs baseline |

Mid-research kill triggers unchanged: aborts 2024Q1 or 2026Q1 before checkpoint → KILL; aborts `> 2` baseline-positive quarters → KILL; aggregate decreases → KILL. This consumes Frame 4 iteration `2/3`.

Honest-read confirmation (acknowledged at lock):

- The DD gate may be structurally unreachable in this frame. Iteration 1 hit only `13.81%` DD reduction with maximum-aggressive aborts. Even with the activity precondition functioning perfectly, DD damage is mostly taken before day 30. The frame may pass pass-preservation and aggregate, then KILL on DD. **That outcome is still a KILL** — no relaxation.
- The aggregate-return gate is the most likely binding constraint. Saving 2024Q1's `+10%` pass alone moves aggregate by `~+0.40pp`. If the precondition spares 2024Q1 only, aggregate sits near baseline; if it spares additional quarters, aggregate may go above baseline.

What changed vs iteration 1:

| Item | Iteration 1 | Iteration 2 |
|---|---|---|
| Day N | 30 | 30 (unchanged) |
| Equity threshold | `<= 0%` | `<= 0%` (unchanged) |
| Checkpoint definition | v6.3 +5% closed | unchanged |
| **Activity precondition** | none | **`>= 3` closed trades by day-30** |
| Acceptance gates | as defined | unchanged |
| Splits | as defined | unchanged |

Simulator changes required (minimal):

1. Before evaluating the abort condition, count `closed_trades_by_abort_time` from `all_trades.csv`.
2. New gate clause: `if closed_trades_count < 3: skip abort`.
3. All other logic unchanged.

Existing data fully covers iter 2 — no MT4 reruns needed.

### Iteration 2: KILL (executed 2026-05-10)

Activity precondition (`>= 3` closed trades by day-30) was added to the iteration 1 abort rule. Data unchanged — same 25-quarter `all_trades.csv`.

Acceptance gate read:

| Gate | Threshold | Actual | Verdict |
|---|---:|---:|---|
| Pass preservation | both 2024Q1 and 2026Q1 `≥ +9.0%` | `2024Q1 = 10.00%`, `2026Q1 = 10.00%` | OK |
| False-abort budget | `≤ 1` baseline-positive non-checkpoint quarter aborted into worse outcome | `0` | OK |
| DD reduction | `≥ 30%` reduction in average max DD across baseline-negative non-checkpoint quarters | `3.22%` | FAIL |
| Aggregate effect | average return across 25 quarters does not decrease vs baseline (`-0.04%`) | `-0.20%` | FAIL |

Decision: **Frame 4 iteration 2 = KILL.** No threshold relaxation applied.

Read:

- The activity precondition fixed both structural failures from iteration 1: 2024Q1 had `0` closed trades by day 30, so it was spared and preserved the `+10.00%` pass; 2022Q2 had `2` closed trades by day 30, so it was also spared and the false-abort-worse case disappeared.
- The frame's core promise (meaningful DD reduction) still did not appear. DD reduction collapsed to `3.22%` because the precondition spared two baseline-negative quarters that had been contributing to iter 1's already-modest reduction. The locked `30%` gate is structurally unreachable at this abort timing.
- Aggregate return still decreased (`-0.04% → -0.20%`).

Empirical finding consolidated across iter 1 and iter 2:

The day-30 abort family cannot deliver meaningful DD reduction. By day 30, most drawdown damage in baseline-negative non-checkpoint quarters is already realized — the abort prevents further entries but does not undo earlier damage. This is a structural finding about v6.3's quarter-level loss profile, not a rule-design issue.

### Iteration counter status

| Counter | Used | Remaining |
|---|---|---|
| Path 1 signal-search | 3/3 | 0 (closed) |
| Frame 2A architecture | 2/3 | 1 (held in reserve) |
| Frame 4 activation timing | 2/3 | 1 |
| Path 2 regime audit | 1/1 | 0 |

## v7 Research Closure (recorded 2026-05-10)

### Decision

v7 research is closed. v6.3 is frozen as benchmark/control and reusable risk scaffold. No further sub-lever tuning authorized inside v7's frame structure without a genuinely new motivating thesis.

This is a discipline decision, not an exhaustion decision. Remaining iterations exist (Frame 2A `1/3`, Frame 4 `1/3`) but the data has shown the pattern: the ideas left to spend on are now lower quality than the evidence already in hand.

### Outcomes summary

| Path / Frame | Iterations | Outcome |
|---|---:|---|
| Path 1: multi-edge portfolio (signal search) | 3/3 | All KILL |
| Path 2: regime-first XAUUSD audit | 1/1 | Rejected |
| Frame 2A: post-checkpoint risk escalation | 2/3 | Both KILL (`1/3` reserved, not spent) |
| Frame 4: activation timing / mid-quarter abort | 2/3 | Both KILL (`1/3` reserved, not spent) |

### Structural diagnosis

**v6.3 is a controlled-risk XAUUSD campaign engine, not a reliable FTMO pass engine.**

What works:

- Risk plumbing generalized cleanly. Both surviving passes (2024Q1, 2026Q1) cleared robust-cost checks at spread `20` and slippage `8`.
- DD profile is contained across 25 chronological quarters (worst max DD `6.48%`, average max DD `3.95%`).
- No catastrophic blowups in any tested window.

What does not:

- Pass generation is too sparse (`8.0%` raw pass rate, `2/8` checkpoint conversion).
- Pass quality is too regime-lucky: the two surviving passes were not predicted by any pre-trade D1 feature in scope.
- Adjacent levers cannot fix it within v6.3's architecture:
  - Path 2 found no D1 regime feature separating checkpoint from non-checkpoint quarters → start-gate redesign blocked.
  - Path 1 found no structurally different signal class clearing the `+15%` pass / `≤6.48%` DD gate at `1%` per-trade risk on 16-quarter samples.
  - Frame 2A found no post-checkpoint sizing schedule that converts checkpoint quarters: uniform escalation magnifies losing tails (iter 1, robust `1/4` conversion); confirmation-gated escalation fires too late on weak quarters and magnifies losers when it does fire (iter 2, `0/4` + DD breach in 2022Q3).
  - Frame 4 found that day-30 abort timing is structurally too late to reduce DD: by day 30 most damage is realized; even maximum-aggressive aborts only achieved `13.81%` reduction (iter 1), and with the activity precondition properly fixing pass preservation, reduction collapsed to `3.22%` (iter 2).

The pattern across `5` KILL outcomes in architecturally different attempts is structural, not iterative.

### What is preserved

- v6.3 EA frozen at current default state.
- Observational `LogAllClosedTrades=false` flag remains in source; no behavior change.
- Frame 2A iteration 3 reserved (module-specific application hypothesis) — usable only with a genuinely new motivating thesis, not as a default next step.
- Frame 4 iteration 3 reserved (session/time-of-day gating, sub-lever 4c) — same condition.
- All planning, simulation, and parser code remains in place: `parse_frame2a_logs.py`, `simulate_frame2a.py`, `simulate_frame4.py`, `frame2a_log_extract/` outputs.
- v6.3 trade traces (`all_trades.csv`, `trades.csv`, `coverage.csv`, simulation CSVs) remain available for any future analysis without rerunning MT4.

### What is closed

- No further sub-lever tuning of v6.3 within this frame structure.
- No v7 EA fork.
- No additional MT4 reruns within current frames.
- No threshold relaxation of any locked gate.
- No retroactive rescoring of any KILL.

### Higher-altitude decision pending

Two options at the level above sub-lever choice. This decision is not subject to v7's iteration-counter discipline — it is a project-direction decision.

| Option | Description | Practical |
|---|---|---|
| 1. Demo v6.3 as a controlled low-pass-rate attempt machine | Run live or in a staged demo. Accept ~8% raw pass rate. Lean on proven risk plumbing. | Gives the project a deployment outcome rather than another research cycle. |
| 2. Start a new EA family / portfolio thesis from scratch | Different instrument, different mechanism, or genuinely different premise. | Longer horizon, no inherited overfitting risk, but resets the calendar. |

Both options are open. Neither defaults to a v7 sub-lever revival.

## Immediate Next Actions

Resume from `V7_SESSION_STATE_2026_05_09.md`.

1. Higher-altitude decision: pick between deployment of v6.3 (option 1) and new EA family (option 2). v7 research is otherwise closed.
2. v6.3 EA trading behavior remains frozen. The observational `LogAllClosedTrades` flag is the only EA touch authorized.
3. Frame 2A iter 3 and Frame 4 iter 3 remain reserved but require a genuinely new thesis to spend — not the next default.
4. No new MT4 reruns, no new simulator code, no parameter exploration without explicit authorization.
