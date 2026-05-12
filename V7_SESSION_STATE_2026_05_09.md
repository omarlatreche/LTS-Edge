# V7 Session State — 2026-05-09 (updated 2026-05-10)

Resume point for next session. Most-recent update at top; prior content preserved below.

## Update 2026-05-10: v7 Research Closed

After Frame 4 iteration 2 KILL, the strategic decision was made to close v7 research with the structural diagnosis rather than spend the remaining `1/3` iteration in Frame 2A or Frame 4 on lower-quality hypotheses than the evidence already in hand.

This is a discipline decision, not an exhaustion decision. Iterations remain available but their probability of clearing locked gates is low given the structural pattern across `5` KILL outcomes.

### Structural diagnosis (locked)

**v6.3 is a controlled-risk XAUUSD campaign engine, not a reliable FTMO pass engine.**

- Risk plumbing works: passes survive robust-cost checks, DD contained, no catastrophic blowups.
- Pass generation is too sparse (`8%` raw) and too regime-lucky.
- Path 2 ruled out start-gate redesign within v6.3's feature set.
- Path 1 ruled out diversification via structurally different signal classes at the locked pass/DD gate.
- Frame 2A ruled out post-checkpoint sizing schedules as a conversion lever.
- Frame 4 ruled out day-30 abort timing as a DD-reduction lever (damage is mostly realized before day 30).

Pattern across architecturally different attempts is structural, not iterative.

### What is preserved

- v6.3 EA frozen at current default state.
- Observational `LogAllClosedTrades=false` flag remains in source; no behavior change.
- Frame 2A iteration 3 reserved (module-specific application) — only with a genuinely new motivating thesis.
- Frame 4 iteration 3 reserved (session/time-of-day gating) — same condition.
- All planning, simulation, parser code, and CSV outputs remain available.

### What is closed

- No further sub-lever tuning of v6.3 within v7's frame structure.
- No v7 EA fork.
- No additional MT4 reruns within current frames.
- No threshold relaxation of any locked gate.
- No retroactive rescoring of any KILL.

### Higher-altitude decision pending

Not subject to v7's iteration-counter discipline. Two options at the project-direction level:

1. **Deploy v6.3** as a controlled low-pass-rate attempt machine. Accept `~8%` pass rate; lean on the proven risk plumbing. Gives the project a deployment outcome.
2. **Start a new EA family / portfolio thesis from scratch.** Different instrument, mechanism, or premise. Longer horizon; no inherited overfitting risk.

Both open. Neither defaults to a v7 sub-lever revival.

### Final iteration counter

| Counter | Used | Remaining |
|---|---:|---|
| Path 1 signal-search | 3/3 | 0 (closed) |
| Frame 2A architecture | 2/3 | 1 (reserved, not spent without new thesis) |
| Frame 4 activation timing | 2/3 | 1 (reserved, not spent without new thesis) |
| Path 2 regime audit | 1/1 | 0 (single-shot, rejected) |

### Immediate next move

Make the higher-altitude decision: deploy v6.3 (option 1) or start a new EA family (option 2). v7 research is otherwise closed.

### Next-session headline

```text
v7 research is closed: after full 25-quarter all-trades regen, Frame 4 Iteration 2 KILL confirmed; v6.3 is preserved as a controlled-risk XAUUSD scaffold but not a reliable FTMO pass engine; next decision is deploy v6.3 as a low-pass-rate attempt machine vs start a new EA family/portfolio thesis.
```

---

## Update 2026-05-10: Frame 4 Iteration 2 Executed — KILL

Frame 4 Iteration 2 added the locked activity precondition to the Iteration 1 abort rule:

```text
At end of calendar day 30:
  abort only if closed_trades_by_abort >= 3
  AND equity <= start balance
  AND no +5% closed-equity checkpoint has been hit.
```

Implementation:

- Updated `simulate_frame4.py`.
- Output file: `frame2a_log_extract/frame4_iteration2_simulation.csv`.
- Added audit column `closed_trades_by_abort`.
- No EA changes and no new MT4 runs.

Mechanical result:

| Gate | Threshold | Actual | Verdict |
|---|---:|---:|---|
| Pass preservation | 2024Q1 and 2026Q1 both `>= +9.0%` | 2024Q1 `10.00%`, 2026Q1 `10.00%` | OK |
| False-abort budget | `<= 1` baseline-positive non-checkpoint quarter aborted into worse final | `0` | OK |
| DD reduction | `>= 30%` avg max-DD reduction across baseline-negative non-checkpoint quarters | `3.22%` | FAIL |
| Aggregate effect | average return across 25 quarters does not decrease | baseline `-0.04%`, simulated `-0.20%` | FAIL |

Decision: **Frame 4 Iteration 2 = KILL.**

Read:

- The activity precondition fixed the structural Iteration 1 failure: 2024Q1 had `0` closed trades by day 30, so it was spared and preserved the `+10.00%` pass.
- It also spared 2022Q2 (`2` closed trades by day 30), removing the Iteration 1 false-abort-worse case.
- The main hypothesis still failed: average max-DD reduction across baseline-negative non-checkpoint quarters fell to only `3.22%`, far below the locked `30%` gate.
- Aggregate return still decreased from `-0.04%` to `-0.20%`.

Discipline notes:

- No relaxation of the DD gate.
- Do not retune `closed_trades_by_abort` from `3` after seeing the result.
- Frame 4 activation timing has now consumed iteration `2/3`; only `1/3` remains.
- Frame 2A iteration 3 remains held in reserve, not active.

Current counter status:

| Counter | Used | Remaining |
|---|---:|---:|
| Path 1 signal-search | 3/3 | 0 (closed) |
| Frame 2A architecture | 2/3 | 1 (held in reserve) |
| Frame 4 activation timing | 2/3 | 1 |
| Path 2 regime audit | 1/1 | 0 |

Immediate next move:

Claude/user review the Iteration 2 result. If continuing Frame 4, the final iteration needs a fresh pre-registration and likely a different mechanism; the day-30 abort family has now failed mainly because DD damage is already realized before the abort can help.

---

## Update 2026-05-10: Frame 4 Iteration 2 Locked

Following Frame 4 iteration 1 KILL, iteration 2 is pre-registered and locked. It addresses a structural category error revealed by iter 1, not a threshold rescue. The locked iteration 1 thresholds (`N=30`, equity `≤ 0%`) are explicitly preserved.

### Frame 4 — Iteration 2 (locked, awaiting execution)

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

What changed vs iteration 1:

| Item | Iteration 1 | Iteration 2 |
|---|---|---|
| Day N | 30 | 30 (unchanged) |
| Equity threshold | `<= 0%` | `<= 0%` (unchanged) |
| Checkpoint definition | v6.3 +5% closed | unchanged |
| **Activity precondition** | none | **`>= 3` closed trades by day-30** |
| Acceptance gates | as defined | unchanged |
| Splits | as defined | unchanged |

Rationale for `X = 3` closed trades: mirrors v6.3's existing `MaxConsecutiveLosses=3` and `StrategyMaxLossTrades=3`, mirrors Frame 2A iter 2's `≥3 trace rows` rule, and is the lowest count where outcomes are not dominated by single-trade luck. Closed trades chosen over entries opened: rule is about evidence of failed campaign expression; closed trades give realized information.

Acceptance gates (unchanged from iter 1):

| Gate | Threshold |
|---|---|
| Pass preservation | both 2024Q1 and 2026Q1 final return `≥ +9.0%` |
| False-abort budget | `≤ 1` baseline-positive non-checkpoint quarter aborted into worse outcome |
| DD reduction | `≥ 30%` reduction in average max DD across baseline-negative non-checkpoint quarters |
| Aggregate effect | average return across 25 quarters does not decrease vs baseline |

Honest-read confirmation (acknowledged at lock):

- DD gate may be structurally unreachable in this frame. Iter 1 hit only `13.81%` reduction with maximum-aggressive aborts. Damage in losing quarters is mostly taken before day 30. The frame may pass pass-preservation and aggregate, then KILL on DD. **Still a KILL** — no relaxation.
- Aggregate-return gate is the most likely binding constraint. Saving 2024Q1 alone moves aggregate by `~+0.40pp`.

Simulator changes required (minimal):

1. Before evaluating the abort condition, count `closed_trades_by_abort_time` from `all_trades.csv`.
2. New gate clause: `if closed_trades_count < 3: skip abort`.
3. All other logic unchanged. Existing data fully covers iter 2 — no MT4 reruns needed.

### Iteration counter status

| Counter | Used | Remaining |
|---|---|---|
| Path 1 signal-search | 3/3 | 0 (closed) |
| Frame 2A architecture | 2/3 | 1 (held in reserve) |
| Frame 4 activation timing | 1/3 used; iteration 2 locked, not yet executed | 2 remaining |
| Path 2 regime audit | 1/1 | 0 |

### Immediate next move

Codex implements the activity precondition in `simulate_frame4.py` and runs. Reports mechanical result against the four gates. No EA changes. No new MT4 runs.

---

## Update 2026-05-10: Frame 4 Iteration 1 Executed — KILL

Full 25-quarter `LogAllClosedTrades=true` regeneration was completed and parsed.

Verification:

- `python3 parse_frame2a_logs.py` parsed `123` runs from `4` MT4 tester log files.
- Clean Frame 4 set selected exactly `25` quarter-aligned Slippage=5 v6.3 runs.
- `frame2a_log_extract/all_trades.csv` contains `182` closed-trade rows across the selected 25 quarters.
- Each selected run has `ALL CLOSED TRADE` row count equal to the MT4 summary `total_trades`.
- Added `simulate_frame4.py` and wrote `frame2a_log_extract/frame4_iteration1_simulation.csv`.

Locked rule tested:

```text
At end of calendar day 30:
  abort if equity <= start balance
  AND no +5% closed-equity checkpoint has been hit.
Existing open positions continue to natural close; no new entries after abort.
```

Mechanical result:

| Gate | Threshold | Actual | Verdict |
|---|---:|---:|---|
| Pass preservation | 2024Q1 and 2026Q1 both `>= +9.0%` | 2024Q1 `0.00%`, 2026Q1 `10.00%` | FAIL |
| False-abort budget | `<= 1` baseline-positive non-checkpoint quarter aborted into worse final | `1` (`2022Q2`) | OK |
| DD reduction | `>= 30%` avg max-DD reduction across baseline-negative non-checkpoint quarters | `13.81%` | FAIL |
| Aggregate effect | average return across 25 quarters does not decrease | baseline `-0.04%`, simulated `-0.44%` | FAIL |

Immediate kill trigger:

- 2024Q1 aborts before checkpoint. At the day-30 check (`2024.01.31 00:00`), equity is exactly flat (`0.00%`) and no checkpoint has been hit. The first 2024Q1 trade opens later that day at `2024.01.31 16:00`, so the locked rule blocks all `7` trades and converts a `+10.00%` pass into `0.00%`.

Decision: **Frame 4 Iteration 1 = KILL.**

Discipline notes:

- Do not rescue by changing `N=30`, changing `<= 0%` to `< 0%`, adding "must have traded first", or exempting quiet pass windows after seeing this result.
- Frame 4 activation timing has now consumed iteration `1/3`; `2/3` remain only for a fresh pre-registered rule.
- Frame 2A iteration 3 remains held in reserve, not active.

Current counter status:

| Counter | Used | Remaining |
|---|---:|---:|
| Path 1 signal-search | 3/3 | 0 (closed) |
| Frame 2A architecture | 2/3 | 1 (held in reserve) |
| Frame 4 activation timing | 1/3 | 2 |
| Path 2 regime audit | 1/1 | 0 |

Immediate next move:

Claude/user review the Frame 4 Iteration 1 result. If continuing Frame 4, draft a fresh Iteration 2 pre-registration before any simulation. No threshold tuning against the just-seen failure.

---

## Update 2026-05-10: Frame 4 Iteration 1 Locked + Data Path Verified

Pivoted from Frame 2A to Frame 4 after iteration 2 KILL. Frame 4 iteration 1 is pre-registered and locked. Frame 2A iteration 3 held in reserve, not active.

### Frame 4 — Iteration 1 (locked, awaiting data)

Sub-lever: **4b — mid-quarter abort on early weakness**.

Locked rule:

```text
If by end of calendar day 30 of the quarter:
  - v6.3 equity is <= START_BALANCE (i.e., 0% return or worse), AND
  - No campaign checkpoint has been hit (closed equity excursion >= +5%)
Then:
  - No new entries are allowed for the rest of the quarter.
  - Existing open positions continue under normal v6.3 management until natural close.
  - After the final open position closes, equity becomes fixed for the rest of the quarter.
```

Locked params: `N=30`, equity threshold `<= 0%`, checkpoint `+5%` closed, open positions to natural close.

Acceptance gates (all four required):

| Gate | Threshold |
|---|---|
| Pass preservation | both 2024Q1 and 2026Q1 final return `≥ +9.0%` |
| False-abort budget | `≤ 1` baseline-positive non-checkpoint quarter aborted into worse outcome |
| DD reduction | `≥ 30%` reduction in average max DD across non-checkpoint losing quarters vs. baseline |
| Aggregate effect | average return across 25 quarters does not decrease vs. baseline |

Mid-research kill: aborts 2024Q1 or 2026Q1 before checkpoint → KILL; aborts `> 2` baseline-positive quarters into worse outcomes → KILL; aggregate return decreases vs. baseline → KILL.

Honest-read: aggregate-return gate is strict by design (acknowledged at lock). No relaxation after seeing results. No `N`/threshold retuning to rescue iteration 1.

### Data path verification (2026-05-10)

Frame 4 needs full v6.3 trade-by-trade or daily equity-curve data across all 25 chronological quarters at `Slippage=5`. Existing `POST-CHECKPOINT CLOSED TRADE` traces are insufficient because aborts can fire before any checkpoint.

Verified state:

- MT4 tester does NOT auto-save per-run reports to disk. `tester/caches` and `tester/files` are empty.
- Tester journal logs only contain post-checkpoint trade rows; pre-checkpoint trades are not journaled.
- No `*.htm` / `*.csv` / `*.xml` report files exist anywhere under `tester/`.

Recovery options (authorization resolved):

1. Re-run all 25 quarters in MT4 with manual `Save as Report` per run. ~25 manual save dialogs, HTML parsing required.
2. Add observational `LogAllClosedTrades` flag to v6.3 EA. Pure logging, no behavior change. One set of reruns regenerates everything in the journal format the existing parser already understands.

Decision: option 2 authorized. Add an observational `LogAllClosedTrades` flag to v6.3 EA, scoped to logging only.

Prepared changes:

- `LTS_Prop_Engine_v6.mq4`: added `LogAllClosedTrades=false` input, one gated `ALL CLOSED TRADE:` print helper, and one call from the existing closed-trade handler before the existing post-checkpoint trace call.
- `parse_frame2a_logs.py`: added parsing for `ALL CLOSED TRADE:` rows and emits `frame2a_log_extract/all_trades.csv` with `checkpoint_hit`.

Scope constraints preserved:

- No entry, exit, sizing, filter, stop, campaign-state, daily-loss, or overall-loss logic changed.
- New logging flag defaults to `false`.
- Existing `LogPostCheckpointTrades` behavior is unchanged.

Verification so far:

- Python parser compile/check passed.
- Parser re-run completed and wrote `all_trades.csv`; it contains only the header until a new `LogAllClosedTrades=true` smoke run is generated.
- MQL compile and MT4 smoke test are still pending. CLI Wine is not available in the shell; compile/smoke likely needs MT4/MetaEditor from the desktop app.

### Iteration counter status

| Counter | Used | Remaining |
|---|---:|---:|
| Path 1 signal-search | 3/3 | 0 (closed) |
| Frame 2A architecture | 2/3 | 1 (held in reserve) |
| Frame 4 activation timing | 0/3 (iter 1 locked, not yet executed) | 3 |
| Path 2 regime audit | 1/1 | 0 |

### Immediate next move

Claude/user review the scoped EA diff. Then compile in MetaEditor and run one 2026Q1 smoke test with `LogAllClosedTrades=true` and `LogPostCheckpointTrades=true`. Confirm no behavior drift (`10.00%` final), all closed tickets logged, post-checkpoint rows unchanged, and module trade counts match `ALL CLOSED TRADE` rows before any 25-quarter regen.

### Codex working log (2026-05-10)

- Re-read project state files and confirmed the active resume point: Frame 4 Iteration 1 is locked; Frame 2A Iteration 3 remains held in reserve, not active.
- Reviewed the prepared observability/parser scope. `git diff` against `HEAD` includes older v6.3 dynamic-floor changes as well as the new logging patch, so Claude/user diff review should focus on the incremental `LogAllClosedTrades` addition and parser extension.
- Re-ran `python3 -m py_compile parse_frame2a_logs.py && python3 parse_frame2a_logs.py`: parser still succeeds, parsed `98` runs from `4` MT4 tester log files, and rewrote `runs.csv`, `trades.csv`, `all_trades.csv`, and `coverage.csv`.
- Confirmed `frame2a_log_extract/all_trades.csv` is header-only until a fresh MT4 smoke run is generated with `LogAllClosedTrades=true`.
- Claude/user diff review identified that `git diff` includes pre-existing uncommitted v6.3 dynamic-floor work because `HEAD` is still at v6.2. The actual authorized observability addition remains `LogAllClosedTrades`, its gated print helper, parser support for `ALL CLOSED TRADE:`, and related CSV output.
- Reverted the out-of-scope `#property version` bump back to `"6.20"` so the current patch does not mix a version-label decision with the logging-only change. A separate "sync version string to v6.3 baseline" commit can be made later if desired.
- MetaEditor/MT4 2026Q1 smoke test passed with `LogAllClosedTrades=true` and `LogPostCheckpointTrades=true`: final return `10.00%`, max DD `4.04%`, `11` total trades, `TARGET_HIT`, checkpoint `2026.01.23 18:20`, `11` `ALL CLOSED TRADE` rows, `6` `POST-CHECKPOINT CLOSED TRADE` rows. No behavior drift; patch is observational.
- Re-ran parser after smoke: parsed `99` runs from `4` MT4 tester log files; `frame2a_log_extract/all_trades.csv` now contains the smoke run's `11` closed-trade rows.
- Full 25-quarter regen is authorized at `Slippage=5`, `LogAllClosedTrades=true`, `LogPostCheckpointTrades=true`.

### Frame 4 regen run list (confirmed 25 clean quarters)

Use the clean quarter-aligned chronological validation table from `LTS_Prop_Engine_v6_TEST_PLAN.md`, not rolling benchmark windows from the ledger. Ledger rows such as `2025.05 -> 2025.08` and `2025.09 -> 2025.12` are benchmark/regression windows, not part of the 25 clean-quarter Frame 4 set.

| # | Quarter | Tester start | Tester end |
|---:|---|---|---|
| 1 | 2020 Q1 | `2020.01.01` | `2020.04.01` |
| 2 | 2020 Q2 | `2020.04.01` | `2020.07.01` |
| 3 | 2020 Q3 | `2020.07.01` | `2020.10.01` |
| 4 | 2020 Q4 | `2020.10.01` | `2021.01.01` |
| 5 | 2021 Q1 | `2021.01.01` | `2021.04.01` |
| 6 | 2021 Q2 | `2021.04.01` | `2021.07.01` |
| 7 | 2021 Q3 | `2021.07.01` | `2021.10.01` |
| 8 | 2021 Q4 | `2021.10.01` | `2022.01.01` |
| 9 | 2022 Q1 | `2022.01.01` | `2022.04.01` |
| 10 | 2022 Q2 | `2022.04.01` | `2022.07.01` |
| 11 | 2022 Q3 | `2022.07.01` | `2022.10.01` |
| 12 | 2022 Q4 | `2022.10.01` | `2023.01.01` |
| 13 | 2023 Q1 | `2023.01.01` | `2023.04.01` |
| 14 | 2023 Q2 | `2023.04.01` | `2023.07.01` |
| 15 | 2023 Q3 | `2023.07.01` | `2023.10.01` |
| 16 | 2023 Q4 | `2023.10.01` | `2024.01.01` |
| 17 | 2024 Q1 | `2024.01.01` | `2024.04.01` |
| 18 | 2024 Q2 | `2024.04.01` | `2024.07.01` |
| 19 | 2024 Q3 | `2024.07.01` | `2024.10.01` |
| 20 | 2024 Q4 | `2024.10.01` | `2025.01.01` |
| 21 | 2025 Q1 | `2025.01.01` | `2025.04.01` |
| 22 | 2025 Q2 | `2025.04.01` | `2025.07.01` |
| 23 | 2025 Q3 | `2025.07.01` | `2025.10.01` |
| 24 | 2025 Q4 | `2025.10.01` | `2026.01.01` |
| 25 | 2026 Q1 | `2026.01.01` | `2026.04.01` |

Operational note: MT4 Strategy Tester driving is manual/user-side. The 2026Q1 smoke run already exists in `tester/logs/20260510.log` with the correct logging inputs and can count as the 2026Q1 row unless intentionally rerun. Practically, that leaves 24 manual reruns. For every run: `XAUUSD`, `H1`, `Every tick`, initial deposit `70000 GBP`, `Slippage=5`, `LogAllClosedTrades=true`, `LogPostCheckpointTrades=true`, all other v6.3 defaults unchanged. Wait for `========== V6 TEST SUMMARY ==========` in the Journal before moving to the next quarter. Tester logs accumulate automatically; no manual HTML saves are needed.

After user completes the MT4 reruns:

1. Verify all 25 clean-quarter runs landed in tester logs with one complete `V6 TEST SUMMARY` per quarter and no truncation.
2. Re-run/extend `parse_frame2a_logs.py` so `frame2a_log_extract/all_trades.csv` covers all 25 clean quarters.
3. Build Frame 4 simulator for the locked Iteration 1 abort rule and report against all four acceptance gates.

---

## Update 2026-05-10: Frame 2A Iteration 2 KILL

Frame 2A iteration 2 was implemented in `simulate_frame2a.py` and executed against the existing full 8/8 checkpoint-quarter trace set. No EA/MQL4 changes were made.

### Iteration 2 — KILL

- Hypothesis tested: wait until the quarter has both a realized post-checkpoint winner and simulator-reconstructed H1 floating peak `>= +7.0%`, then size subsequent eligible trades at `2.0x`.
- Implementation: sticky activation state machine, no retroactive resize of the activating trade, per-trade sizing assigned when a trade becomes live, `conversion_eligible_for_gate = sim_target_hit AND trace_rows >= 3`, and max observed floating DD-from-peak used for the DD gate.
- Result: robust research conversion `0/4` (2020Q2, 2022Q3, 2023Q3, 2023Q4 all failed target under the locked gate).
- Pass preservation: preserved (`2024Q1 = 10.00%`, `2026Q1 = 10.00%`).
- Worst DD-from-peak: `9.80%` in 2022Q3, with peak-DD stop fired.
- Daily kills: `0`.

Acceptance gate read:

| Gate | Threshold | Actual | Verdict |
|---|---:|---:|---|
| Research conversion | `>=2/4`, each conversion `>=3` trace rows | `0/4` | FAIL |
| Pass preservation | both known passes `>= +9.0%` | `10.00% / 10.00%` | OK |
| Worst DD-from-peak | `<= 8.5%` | `9.80%` | FAIL |
| Daily kills | `<= 5` | `0` | OK |

Decision: **Frame 2A iteration 2 = KILL.** This consumes iteration `2/3`. Frame 2A has `1/3` iteration remaining.

Current active next-decision state:

- Do not rescue iteration 2 with threshold relaxation.
- Do not change v6.3.
- Either draft Frame 2A iteration 3 as the final allowed architecture iteration, or surface Frame 4 activation timing as the next review frame.

### Iteration counter status

| Counter | Used | Remaining |
|---|---:|---:|
| Path 1 signal-search | 3/3 | 0 (closed) |
| Frame 2A architecture | 2/3 | 1 |
| Frame 4 activation timing | 0/3 | 3 (untouched) |
| Path 2 regime audit | 1/1 | 0 (single-shot, rejected) |

---

## Update 2026-05-10: Frame 2A Iteration 1 KILL + Iteration 2 Locked

The "Pending: Frame 2A design proposal" section near the bottom is now superseded. The 8 design decisions have been answered, iteration 1 was executed and killed, and iteration 2 is pre-registered and locked.

### Iteration 1 — KILL

- Hypothesis: uniform `2.0×` post-checkpoint sizing on all post-`+5%` trades.
- Tooling: planning-time Python simulation against MT4 tester `POST-CHECKPOINT CLOSED TRADE` traces; H1 OHLC reconstruction for adverse and favorable intra-bar excursion; cost-per-lot rescaling; day-attributed daily-kill with halt-rest-of-day. v6.3 EA untouched.
- Mechanical: `2.0×` got `2/4` research conversions (2022Q3, 2023Q3), pass preservation intact (`10.00%` / `10.00%`), worst DD-from-peak `5.66%`, `0` daily kills. `1.5×` killed mechanically (peak-DD-stop in 2022Q3, `0/4`).
- Robust: 2023Q3's "conversion" is built on `1` post-checkpoint trace row. One bar's intra-bar favorable excursion is not a meaningful test of a sizing architecture. Counting it as the second conversion would bend the gate after seeing the data. Effective robust conversion `1/4` → KILL.
- Learned: pass preservation works at `2.0×`, DD ceiling is well inside budget at `2.0×`, binding constraint is conversion quality not capacity, `+5%` closed activation is too early on weak checkpoint quarters.

### Iteration 2 — Locked, ready to execute

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

- Multiplier: `2.0×` post-activation (deliberately unchanged from iteration 1; lever under test is timing, not aggression).
- Guardrails unchanged: `+3%` demote floor (sticky), `−4%` daily-kill (halt rest of day), `8%` peak-DD safety stop.
- Module application uniform.
- Splits unchanged: research 2020Q1-2023Q4 (4 cp), validation 2024Q1-2026Q1 (4 cp), holdout pre-2020.
- Acceptance gates: `≥2/4` research conversion AND each conversion has `≥3` post-checkpoint trace rows; both 2024Q1 and 2026Q1 `≥ +9.0%`; worst DD-from-peak `≤ 8.5%`; daily kills `≤ 5` total.
- Mid-research kill: `0/4` robust conversion → KILL; `> 12%` single-quarter DD → KILL.
- Honest-read: `1/4` robust conversion → KILL, `2/4` robust with `8.6%` DD → KILL, no relaxation.

The `≥3 trace rows` clause is tightening (directly addresses iter 1 failure mode), not relaxation.

### Simulator change spec for Codex

1. Trigger state machine in `simulate_frame2a.py`:
   - `first_post_checkpoint_winner_closed` (bool, post-checkpoint).
   - `peak_floating_equity_since_checkpoint` (simulator-reconstructed H1 peak).
   - Activation gate evaluated at realized-close events only.
   - Sticky-on once activated, subject to existing demote rules.
2. No retroactive resize of the activating trade.
3. Coverage report enhancement: mark conversion eligibility per `≥3`-trace-row rule.
4. Everything else unchanged. Existing trace data reusable; no MT4 regen needed.

### Iteration counter status (post lock, pre execution)

| Counter | Used | Remaining |
|---|---:|---:|
| Path 1 signal-search | 3/3 | 0 (closed) |
| Frame 2A architecture | 1/3 (iter 2 locked, not yet executed) | 2 |
| Frame 4 activation timing | 0/3 | 3 (untouched) |
| Path 2 regime audit | 1/1 | 0 (single-shot, rejected) |

### Immediate next move

Hand the simulator change spec to Codex. Codex updates `simulate_frame2a.py`, runs, reports mechanical result against the four acceptance gates. No EA changes. No new MT4 runs.

### What is now superseded in the prior content below

- "Pending: Frame 2A design proposal" — all 8 decisions answered. Decisions 1, 4, 5, 6, 8 confirmed as proposed. Decision 2 narrowed: only `2.0×` survives iteration 1, `1.5×` killed. Decision 3 confirmed as proposed and proven safe at `2.0×` in iteration 1. Decision 7 cleared (trade-log scan authorized, parser written by Codex, full coverage achieved including 2026Q1 baseline regen at Slippage=5).
- "Frame 2A proposal — short summary for re-entry" — superseded by iteration 2 lock above.

---

## (prior content from 2026-05-09 below — preserved for history)

## Where we are

Path 1 signal-search closed (3/3 iterations consumed, all KILL). Frame 2A (post-checkpoint risk escalation) selected as lead architecture frame. Pre-registered design proposal drafted and waiting on user lock-in.

## Locked constraints (do not re-litigate)

- **+10% per quarter pass bar: NON-NEGOTIABLE.** Not in scope for any review.
- v6.3 stays frozen as benchmark/control. No micro-tuning. Implementation, when later authorized, must fork to v7.
- Anti-overfit discipline carries forward: pre-register before execute, no rescue grids, no threshold relaxation after seeing results.
- Driver/challenger model active. Decisions surfaced before execution.

## Today's chronology

| Step | Outcome | Key result |
|---|---|---|
| Path 2: XAUUSD regime audit | **REJECTED** | Frozen rule `ADX14≥20 OR \|close-EMA50\|/ATR14≥1.5` fired 7/8 on checkpoint AND 7/8 on comparison — no separation. Fallback ADX14≥18 also failed (6/8 vs 6/8). |
| Path 1 step 1: USA30/USATECH H1 momentum + D1 EMA filter | **KILL** | Best USATECH N=12 K=1.5: 12.5% pass / 8.90% DD. Closest near-miss; DD ceiling binding. |
| Path 1 step 1-rerouted: EURUSD H4/D1 pullback | **KILL** | Best X=3 K=1.5: 6.2% pass / 6.79% DD / +1.44% avg. Clean small edge, no velocity. |
| Option A: portfolio additivity sanity check | **WEAK on operational metric** | v6.3 + EURUSD 50/50: avg ret +1.34pp, worst quarter +1.10pp, but 0 incremental passes. Loss overlap 66.7% vs 68.75% expected under independence (artifact, not correlation). |
| Path 1 iteration 3: NR-N squeeze breakout (no trend filter) on USA30/USATECH | **KILL** | Best 6.2% pass; DD-compliant combos all 0% pass. Iteration cap reached. |
| Planning-frame review | Frame 2A selected | Post-checkpoint risk escalation. Hypothesis: lift conversion 2/8 → ≥4/8, raw pass 8% → ~16%. |
| Frame 2A design proposal | **Delivered, waiting on user lock-in** | See "Pending" below. |

## Key meta-finding to preserve

3 structurally different signal classes (H1 momentum, H4 pullback, NR squeeze breakout) all failed the locked +15% pass / ≤6.48% DD gate at 1% per-trade risk on 16-quarter samples. The binding constraint pattern is **DD ceiling, not pass capacity**: candidates that have edge to clear pass blow DD; candidates that comply with DD have no edge. This is why Frame 2A targets conversion rather than fresh signal search.

## Locked items inside V7_PATH1_PORTFOLIO_BRIEF.md

- Lock state header (top of doc).
- Symbol protocol (USA30 + USATECH in research, ONE frozen for validation).
- Acceptance thresholds with locked overlap definition (`|v6_lose ∩ cand_lose| / |cand_lose|`, threshold ≤50%).
- Implementation order pointing at Dukascopy CSV research.
- Research data confirmation block (Codex's integrity check).
- Open items all marked resolved.

## Files in play

| File | Purpose | Status |
|---|---|---|
| `V7_PORTFOLIO_PLANNING.md` | Master plan | Updated with Path 2 rejection, Path 1 kills, Frame 2A choice |
| `V7_PATH1_PORTFOLIO_BRIEF.md` | Path 1 brief | Fully marked up with all 3 kills + Option A + iteration cap reached |
| `V7_SESSION_STATE_2026_05_09.md` | This file | New |
| `LTS_Prop_Engine_v6_TEST_PLAN.md` | v6 history (chronological per-quarter results lines 308-323) | Reference only |
| `LTS_Prop_Engine_v6_BENCHMARK_LEDGER.csv` | v6 selected/rolling ledger | Reference only |
| `XAUUSD1440.csv` | XAUUSD D1 from MT4 (2004→2026) | Used for Path 2 audit |
| `EURUSD1440.csv` | EURUSD D1 from MT4 (1971→2026) | Used for Path 2 macro slope |
| `USA30IDXUSD_Hourly_{Bid,Ask}_*.csv` | Dukascopy USA30 H1 (2018→2026) | Used for step 1 + iteration 3 |
| `USATECHIDXUSD_Hourly_{Bid,Ask}_*.csv` | Dukascopy USATECH H1 (2018→2026) | Used for step 1 + iteration 3 |
| `DOLLARIDXUSD_Hourly_{Bid,Ask}_*.csv` | Dukascopy DXY H1 (2018→2026) | Available, lightly used |
| `EURUSD_4 Hours_{Bid,Ask}_*.csv` | Dukascopy EURUSD H4 (2018→2026) | Used for step 1 reroute + Option A |

## Research scripts (in worktree, not project root)

`/Users/olatreche/Desktop/LTS Edge v1/.claude/worktrees/intelligent-wilson-e4beff/`

| Script | Purpose | Re-runnable |
|---|---|---|
| `path2_audit.py` | Path 2 regime audit (16 windows, frozen rule applied) | Yes |
| `step1_research.py` | Path 1 step 1: USA30/USATECH H1 momentum (6 combos × 2 syms) | Yes |
| `step1_eurusd.py` | Path 1 step 1-rerouted: EURUSD H4/D1 pullback (4 combos) | Yes |
| `option_a_additivity.py` | v6.3 + EURUSD additivity sanity check | Yes |
| `iteration3_nr.py` | Path 1 iteration 3: NR-N squeeze (4 combos × 2 syms) | Yes |
| `h1_integrity_check.py` | Dukascopy CSV data integrity verifier | Yes |

These are research code, not production. v6.3 EA was not touched.

## Pending: Frame 2A design proposal

Proposal delivered in last response. **Eight decisions waiting on user**:

1. Trigger: closed-trade equity ≥ +5% first-touch in quarter — confirm.
2. Multiplier grid for iteration 1: `{1.5×, 2.0×}` — confirm.
3. Guardrails: floor demote at +3%, daily-kill at −4% intraday, peak-DD safety stop at 8% — confirm or push back.
4. Module application: uniform across all v6.3 modules (momentum / expansion / pullback) — confirm.
5. Acceptance gates: ≥2/4 research conversion AND ≥+9% on known passes AND ≤8.5% worst DD AND ≤5 daily-kills — confirm.
6. Iteration counter: fresh, separate from Path 1 — confirm.
7. **Authorize a scan of local files for v6.3 trade-level logs.** Frame 2A research needs per-trade entry/exit/size/P&L for the 25 chronological quarters. If logs exist, escalation simulation runs in Python at planning time, no v7 fork needed. If not, we're blocked at planning until v6.3 trade logs can be regenerated or v7 is forked (forbidden until research is locked).
8. Honest-read confirmation: a research result of e.g. 1/4 conversion + 8.6% DD is still a KILL — no relaxation after seeing results.

## Frame 2A proposal — short summary for re-entry

(Full text in last assistant turn of session transcript.)

- **Trigger:** closed-trade equity ≥ +5% first-touch.
- **Tier 1 active:** all post-trigger trades sized at multiplier × 1% baseline.
- **Demotion:** equity below +3% → back to 1× rest of quarter.
- **Daily-loss kill:** −4% intraday → flat all, halt for day.
- **Peak-DD safety:** total DD from peak > 8% → permanent demote to 1× for quarter.
- **Module application:** uniform.
- **Loss-tolerance interaction:** v6.3 adaptive loss-tolerance unchanged — Frame 2A is risk SIZE only, orthogonal lever.
- **Splits:** research 2020 Q1-2023 Q4 (4 cp, 0 passes), validation 2024 Q1-2026 Q1 (4 cp, 2 passes), holdout pre-2020.
- **Acceptance:** all 4 gates simultaneously (research conversion, validation pass preservation, worst DD, daily-kills).
- **Kill triggers during research:** 0/4 conversion → immediate KILL; >12% single-quarter DD → KILL; iter cap 3 → KILL.

## What NOT to do on resume

- Do not start Frame 2A execution before user answers the 8 decisions.
- Do not run any new signal-search candidates without explicit authorization.
- Do not modify v6.3 source.
- Do not fork v7 EA.
- Do not consider EURUSD portfolio amendment (rejected as insufficient on operational metric).
- Do not relax DD discipline by itself (rejected as overfit risk).
- Do not re-litigate the +10%/Q pass bar.

## What CAN happen on resume without further authorization

- User can answer the 8 Frame 2A decisions; if all confirmed AND trade logs are available, execute iteration 1 (Python simulation, 2 multipliers × 25 quarters).
- User can authorize the trade-log scan independently to clear the data dependency.
- User can override frame selection (e.g. switch to Frame 4 activation timing instead) — would require a new design proposal in the same discipline.

## Iteration cap status

| Counter | Used | Remaining |
|---|---:|---:|
| Path 1 signal-search | 3/3 | 0 (closed) |
| Frame 2A architecture | 1/3 | 2 |
| Frame 4 activation timing | 0/3 | 3 (untouched) |
| Path 2 regime audit | 1/1 | 0 (single-shot, rejected) |

Brief-level review consumed for the planning-frame question. Frame 2A is the active lead.

## 2026-05-10 Resume Addendum

This addendum records the resumed Codex/Claude team session through the Frame 2A iteration 1 kill. It supersedes the "Pending: Frame 2A design proposal" block above for current state, while preserving the original chronology.

### Team / process state

- User reminded Codex to work with Claude as a team.
- Driver/challenger model reaffirmed.
- Codex drove log parsing and simulation tooling.
- Claude challenged simulator assumptions and result interpretation.
- User delegated ongoing plan maintenance to Codex.

### Frame 2A lock-in

Frame 2A decisions 1-6 and 8 were confirmed as proposed:

1. Trigger: closed-trade equity >= +5% first-touch.
2. Iteration 1 multiplier grid: `1.5x`, `2.0x`.
3. Guardrails: floor demote at +3%, daily-kill at -4% intraday, peak-DD safety at 8%.
4. Uniform module application.
5. Acceptance gates: >=2/4 research conversion AND >=+9% on known passes AND <=8.5% DD AND <=5 daily-kills.
6. Fresh Frame 2A iteration counter.
7. Trade-log scan authorized.
8. Honest-read rule confirmed: near misses are KILLs; no relaxation after seeing results.

### Data dependency outcome

Trade-log scan found MT4 Strategy Tester logs under:

`/Users/olatreche/Library/Application Support/net.metaquotes.wine.metatrader4/drive_c/Program Files (x86)/MetaTrader 4/tester/logs/`

Key files:

- `20260508.log`
- `20260509.log`
- `20260510.log`

Saved HTML/XML reports were not found beyond templates, but tester logs contain `POST-CHECKPOINT CLOSED TRADE` and `POST-CHECKPOINT TRACE ROW` records. This is sufficient for Frame 2A because Frame 2A only changes sizing after checkpoint.

Codex added parser/output tooling:

| File | Purpose |
|---|---|
| `parse_frame2a_logs.py` | Parse MT4 tester logs into run/trade/coverage CSVs. |
| `simulate_frame2a.py` | Planning-time Frame 2A post-checkpoint sizing simulator. |
| `frame2a_log_extract/runs.csv` | Parsed run attribution and settings. |
| `frame2a_log_extract/trades.csv` | Parsed post-checkpoint trade rows. |
| `frame2a_log_extract/coverage.csv` | Coverage for 8 checkpoint quarters. |
| `frame2a_log_extract/frame2a_simulation.csv` | Iteration 1 simulation output. |

Initial parse found 7/8 baseline checkpoint traces. `2026Q1` baseline at slippage 5 lacked trace rows; only slippage 8 robust-cost trace existed. Claude/user agreed to regenerate `2026Q1` baseline at slippage 5 rather than mix cost regimes.

After user/Claude located `20260510.log`, parser coverage became 8/8 usable baseline traces:

| Quarter | Status |
|---|---|
| `2020Q2` | usable baseline trace |
| `2022Q3` | usable baseline trace |
| `2023Q3` | usable baseline trace |
| `2023Q4` | usable baseline trace |
| `2024Q1` | usable baseline trace |
| `2025Q1` | usable baseline trace |
| `2025Q4` | usable baseline trace |
| `2026Q1` | usable baseline trace |

### Simulator challenge/fixes

Claude challenged the first simulator skeleton on:

- Close-only path dependence.
- Daily-kill attribution/halt behavior.
- Cost scaling.
- HST source compatibility.
- Favorable intra-bar peak tracking.

Codex updated the simulator to:

- Load XAUUSD H1 `.hst` bars.
- Use H1 adverse excursion for floating equity guardrails.
- Use H1 favorable excursion for target checks.
- Track favorable intra-bar peaks before target checks.
- Rewrite daily-kill handling as one breach per day with same-day halt behavior.
- Scale trade economics from realized P/L per price-unit/lot rather than pure close-only P/L multiplication.

HST source check:

- `FTMO-Demo2/XAUUSD60.hst` and `ICMarketsSC-Demo01/XAUUSD60.hst` both contained all selected baseline trace open/close prices inside matching H1 bars.
- Current simulator uses `FTMO-Demo2/XAUUSD60.hst`.

### Frame 2A iteration 1 result

Iteration 1 tested:

- Trigger: closed-trade equity >= +5%.
- Multipliers: `1.5x`, `2.0x`.
- Uniform application to all post-trigger trades.
- Guardrails as locked above.

Final hardened simulator read:

| Multiplier | Mechanical result | Robust read |
|---|---|---|
| `1.5x` | 0/4 research conversions; 2022Q3 peak-DD stop | KILL |
| `2.0x` | 2/4 mechanical conversions: 2022Q3 and 2023Q3 | KILL on evidence quality |

Detailed interpretation:

- `2.0x` preserved known passes: `2024Q1` and `2026Q1` both stayed at `10.00%`.
- `2.0x` worst final DD-from-peak read was `5.66%`.
- `2.0x` daily-kills were `0`.
- However, `2023Q3` had only one post-checkpoint trace row. Counting that as the decisive second conversion would treat a single lever pull / intra-bar favorable high as a meaningful test of the Frame 2A architecture.
- User/Codex selected Claude's stricter read: `2023Q3` is structurally not-a-test for conversion quality. Effective robust conversion is therefore `1/4`.

Decision:

**Frame 2A iteration 1: KILL.**

Reason:

Iteration 1 showed pass preservation and controlled DD, but insufficient robust conversion. Only `2022Q3` converted on meaningful post-checkpoint activity.

### Current counter state

| Counter | Used | Remaining |
|---|---:|---:|
| Path 1 signal-search | 3/3 | 0 (closed) |
| Frame 2A architecture | 1/3 | 2 |
| Frame 4 activation timing | 0/3 | 3 (untouched) |
| Path 2 regime audit | 1/1 | 0 (single-shot, rejected) |

### Iteration 2 pre-reg direction

Do not run iteration 2 yet. It needs a new pre-registration first.

Codex's proposed iteration 2 design stance:

- Trigger should be `AND`, not `OR`: first post-checkpoint winner AND closed equity >= +7%.
- Multiplier should remain `2.0x` to isolate activation timing rather than size aggression.
- Acceptance gates should keep the original gates and add a conversion-quality requirement.
- Proposed conversion-quality requirement: converted quarters count only if they have >=3 post-checkpoint trace rows, or if target is hit by realized closed-trade equity rather than a single intra-bar favorable excursion. Codex currently prefers the `>=3 trace rows` rule because it directly addresses the revealed weakness.

Authorship:

- Claude should draft Frame 2A iteration 2 pre-registration.
- Codex should review/challenge before any simulator changes or execution.
- Batch doc updates with the iteration 2 pre-reg rather than creating another half-step after this addendum.

### Current plan

1. Claude drafts Frame 2A iteration 2 pre-registration.
2. Codex reviews/challenges the draft.
3. Once locked, Codex updates docs and simulator as needed.
4. Only then run iteration 2.

## End of session.
