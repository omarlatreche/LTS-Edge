# V8 Candidate 1 Phase 0.5

Candidate label: pre-event positioning-asymmetry velocity at scheduled macro catalysts

Date: 2026-05-12

Status: killed at free pre-audit viability screen. This file does not authorize EA code, simulator work, tester runs, or final instrument selection.

## Relationship To V8 Pre-Registration

This file sits under `V8_VELOCITY_POCKET_PREREG.md`.

The global V8 prereg remains unchanged:

- Velocity pocket must be defined numerically before implementation.
- Detection, trigger, and execution timescales must be separated.
- No funded/personal fallback is embedded in the Phase 1 research brief.
- Forbidden structural and evaluation patterns still apply.

This Phase 0.5 file records the first proposed velocity source, the corrections required before a full candidate brief, and the eventual free-screen kill decision. Candidate 1 did not advance to paid data audit or full candidate brief.

## Plain-Market Thesis

Scheduled high-impact macro catalysts can create concentrated post-release velocity when pre-event positioning is crowded and the data surprise forces that positioning to unwind.

The proposed edge is not prediction of the macro surprise. It is the asymmetric flow after a surprise lands against crowded positioning:

```text
Crowded positioning + opposing macro surprise -> forced de-risking -> stop-cascade / one-way flow.
```

The velocity source is microstructural and event-driven, not D1 regime persistence, H1 compression breakout, or v6.3 trend continuation.

## Candidate Status Against Pre-Candidate Gates

| Gate | Status | Required correction |
|---|---|---|
| Plain-market velocity source | Pass | None. |
| Measurement method | Partial pass | Magnitude threshold and data-source discipline must be locked. |
| Native timescales | Partial pass | Direction timing must be aligned so direction is assigned before the pocket opens. |
| Not v7 in disguise | Pass | Must preserve forbidden-list declaration in full candidate brief. |

Verdict: advance to Phase 0.5 lock, not yet to full candidate brief.

## Pocket Timing

The event release itself is not the pocket open.

Default timing:

```text
T              = scheduled release timestamp.
T to T+5m      = data-digestion window. Surprise sign is computed. No orders.
T+5m           = default pocket open.
T+5m to T+60m  = primary fast-resolution pocket window.
T+5m to session close = optional extended window for slower-resolution events.
```

Direction must be assigned during the digestion window and before pocket open.

Default direction rule:

```text
At T+5m:
  positioning_sign = crowded long / crowded short from the most recent valid CFTC percentile
  surprise_sign    = actual vs frozen consensus

  IF surprise_sign opposes positioning_sign:
      trade against positioning_sign
  ELSE:
      no trade
```

No orders are allowed before the pocket-open offset.

The full candidate brief may define event-class-specific offsets, such as a longer offset for FOMC press-conference events, but it must pre-register those offsets before measurement.

## Event Universe Lock For Data Audit

Core clean event set:

| Event | Status | Reason |
|---|---|---|
| US CPI | Included for data-feasibility audit | Scheduled, numeric actual/consensus, repeatable release time. |
| US NFP | Included for data-feasibility audit | Scheduled, numeric actual/consensus, repeatable release time. |

Conditional event set:

| Event | Status | Numeric surprise definition required |
|---|---|---|
| FOMC statement | Conditional | `actual federal funds target upper bound - consensus upper bound`, in basis points. |
| ECB rate decision | Conditional | `actual deposit facility rate - consensus deposit facility rate`, in basis points. |
| BOJ rate decision | Conditional | `actual policy rate - consensus policy rate`, in basis points. YCC or purchase-program changes are excluded unless separately defined from reproducible consensus data. |

Excluded from first pass:

| Event / asset class | Status | Reason |
|---|---|---|
| FOMC press conference | Excluded | No objective frozen numeric surprise definition; qualitative tone reads are post-hoc labeling risk. |
| ECB press conference | Excluded | Same issue as FOMC press conference. |
| BOE events | Excluded | Held out to keep the first audit tight. |
| XAUUSD | Excluded | Held out to avoid immediate drift back into the v6/v7 instrument. |
| Index futures / CFDs | Excluded | Held out because Path 1 already tested index-adjacent velocity ideas. |

The conditional events may advance only if the data-feasibility audit confirms reproducible release-time consensus and actual values for their numeric surprise definitions.

## Magnitude Structure

The proposal uses a two-tier magnitude structure.

Tier 1: event-volatility pre-screen.

```text
60-minute realized move / 20-day daily ATR >= 1.5
```

This identifies events worth studying as possible velocity-pocket candidates. It is not the V8 magnitude gate.

Tier 2: V8 magnitude gate.

```text
Realized move from pocket open to pocket close >= 2.0 * daily ATR(14)
```

The final candidate must clear Tier 2. Routine events that clear the pre-screen but fail the V8 magnitude gate do not count as accepted pockets.

Important implication:

The earlier rough frequency estimate was based on the looser pre-screen. The full candidate brief must redo the frequency check against the locked `2.0 * daily ATR(14)` magnitude gate and the V8 independence rule. Frequency is not assumed to pass.

## Native Timescales

Current candidate-specific timescale proposal:

| Timescale | Proposed value | Reason |
|---|---|---|
| Detection | Days to weeks | Crowded positioning develops over the rate/macro cycle and is measured by weekly CFTC COT data. |
| Trigger | Minutes post-release | Surprise sign and first reaction become knowable only after the release. |
| Execution | Hours to one trading session | Forced de-risking should resolve within the event session or fail quickly. |

The full candidate brief must name exact detection, trigger, and execution timescales per event class before measurement.

## Data Source Discipline

Consensus and actual-release data:

- Use one named source per event class.
- Consensus values must be frozen as of release time.
- Post-hoc revised consensus values are not allowed.
- Candidate brief must state how archived release-time values are reproduced.

Preferred source order:

1. Bloomberg historical economic calendar.
2. Refinitiv historical economic data.
3. Investing.com calendar archive, only if archive reproducibility is sufficient.

CFTC positioning data:

- Use the most recent COT report that was publicly available at the event date.
- Treat the signal as lagged, typically by about three trading days.
- Do not use later COT revisions or reports unavailable at the event time.

If release-time consensus snapshots cannot be obtained reproducibly, this candidate cannot advance to implementation.

## Data-Feasibility Audit

The next required deliverable is a data-feasibility audit.

Audit goal:

```text
Confirm that release-time consensus and actual values can be reproduced for the core and conditional event sets from 2020-2026.
```

Step 1: premium-source access check.

- Ask whether Bloomberg or Refinitiv historical economic calendar data is available by any route.
- If yes, audit scope is limited to confirming queryability and frozen-at-release reproducibility.
- If no, proceed to the fallback audit below.

Fallback audit:

1. Select `5` random events per audited event class across `2020-2026`.
2. Retrieve release-time consensus from archived pages dated before the release, with Investing.com + Wayback as the practical default.
3. Retrieve actual values from official sources where possible, including BLS for US CPI/NFP and central-bank releases for policy decisions.
4. Cross-check reconstructed consensus values against a second contemporaneous source when available.
5. Record irreproducible events explicitly.

Fallback pass criterion:

```text
At least 90% of sampled events produce reproducible consensus + actual values
within event-appropriate tolerance:
  - rates: 1 bp
  - payroll jobs: 1k jobs
  - CPI-style percentage releases: 0.1 percentage points
```

If an event class fails the audit, that class is excluded from Candidate 1. If the core clean set fails, Candidate 1 is killed before measurement.

In-bounds audit code:

- Data acquisition scripts for archived consensus and official actual values.
- Parsing scripts for audit evidence tables.

Out of bounds:

- EA source changes.
- Trading simulator work.
- Tester runs.
- Strategy optimization.
- Any trading-logic implementation.

## FTMO Account-Mode Stance

Official FTMO news-rule reality check, as of 2026-05-12:

- During FTMO Evaluation / Verification, macro news trading restrictions do not apply.
- On funded FTMO Standard accounts, selected news restrictions apply to targeted instruments around restricted releases.
- FTMO Swing accounts have no news-trading restriction.

Source: `https://ftmo.com/en/faq/can-i-trade-news/`

Primary target for this candidate:

```text
FTMO 2-Step Evaluation / Verification only.
```

Funded-account deployment is out of scope for this brief. If this candidate clears Evaluation-phase gates, funded-account viability must be opened as a separate research question covering FTMO Standard, FTMO Swing, or alternative prop/account structures.

## Frequency Recheck Requirement

The full candidate brief must recompute frequency after all of the following are locked:

- Event universe.
- Instrument universe.
- Pocket-open offset.
- Pocket-close rule.
- Direction assignment rule.
- `2.0 * daily ATR(14)` magnitude gate.
- V8 independence rule.
- Quarter concentration cap.

The rough event-count estimate from the thesis proposal is not accepted as evidence.

Minimum frequency still follows the V8 prereg:

```text
At least 30 independent accepted pockets in the 2020-2026 sample.
Same instrument/direction pockets separated by at least 5 trading days by default.
No single calendar quarter contributes more than 20% of accepted pockets.
```

## Forbidden-List Declaration

Current declaration:

| Restricted pattern | Reused? | Status |
|---|---|---|
| H1 NR-N compression breakout on USA30 / USATECH | No | Catalyst-driven, not compression-derived. |
| Generic H1 close breakout | No | Trigger is event-release/digestion, not bar-close. |
| Session filter plus ATR stop as main thesis | No | Catalyst defines the window; session may only be an execution boundary. |
| XAUUSD H1 trend-continuation | No | No shared signal logic with v6.3. |
| D1-regime-gated rewrite | No | CFTC positioning is not a D1 OHLC regime feature. |
| "v6.3 plus one more filter" | No | No v6.3 entry logic is reused. |
| Selectivity as mechanism | No | Selectivity is tied to measured positioning asymmetry plus macro surprise. |

The full candidate brief must repeat this declaration and include the evaluation-side forbidden patterns from `V8_VELOCITY_POCKET_PREREG.md`.

## Conditions To Advance To Full Candidate Brief

Before a full candidate brief is written, the thesis driver must provide:

1. Data-feasibility audit result by event class.
2. Proposed event universe after audit exclusions.
3. Proposed instrument universe.
4. Exact event-class pocket-open offsets.
5. Exact pocket-close rule.
6. Exact source for actual/consensus data.
7. Exact CFTC positioning mapping to each instrument/event.
8. Measurement plan for `2.0 * daily ATR(14)` magnitude, hit rate, payoff ratio, and completion time.

The prior seven-condition list is superseded by the audit-first sequence above.

No implementation or tester work is authorized until the full candidate brief locks validation windows, pass/DD gates, robust-cost protocol, and kill criteria.

## Free Pre-Audit Viability Screen

After Trading Economics pricing showed that Economic Calendar API access was Enterprise-only and outside the bounded research budget, Candidate 1 ran a free pre-audit viability screen before any paid data acquisition.

Scope:

- EUR/USD first pass, then one final USD/JPY probe.
- Events: US CPI, US NFP, FOMC statement dates.
- Positioning: CFTC futures positioning percentile.
- Price: degraded H4 post-event movement from free Dukascopy data.
- No consensus/surprise data.
- No trading rule, equity curve, pass/DD read, simulator, or EA work.

Artifacts:

- `v8_viability_screen.py`
- `v8_viability_data/viability_screen_events.csv`
- `v8_viability_data/viability_screen_events_usdjpy.csv`

Headline results:

| Instrument | Bucket | n | Against-crowd % | Median move / ATR | Move >= 2 ATR |
|---|---|---:|---:|---:|---:|
| EUR/USD | Crowded long | 68 | `38.2%` | `2.08` | `60.3%` |
| EUR/USD | Crowded short | 69 | `50.7%` | `2.84` | `79.7%` |
| USD/JPY | Crowded long | 53 | `56.6%` | `2.40` | `62.3%` |
| USD/JPY | Crowded short | 52 | `51.9%` | `2.10` | `53.8%` |

Read:

- EUR/USD did not support the directional forced-unwind component.
- USD/JPY showed a weak thesis-consistent directional hint, but the effect was small and statistically indistinguishable from noise at the available sample size.
- Magnitude patterns were inconsistent across instruments and did not cleanly separate crowded from neutral regimes.
- The H4 data is degraded and cannot resolve true event-window path, but the free screen was sufficient to decide whether paid consensus data was justified.

Decision: **Candidate 1 KILL.**

Reason:

The free screen did not show enough underlying positioning/event signal to justify paid consensus-data acquisition. Per the V8 discipline, no third instrument, XAUUSD extension, index extension, or thesis redefinition is authorized as a rescue.
