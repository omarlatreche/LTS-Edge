# V8 Session State — 2026-05-12

Resume point for the next session.

## Current State

V7 is formally closed and anchored in:

- `V7_CLOSURE.md`

V8 Phase 0 is active and anchored in:

- `V8_VELOCITY_POCKET_PREREG.md`

V8's working axis remains:

```text
Find market-native velocity pockets that can plausibly reach FTMO Phase 1 velocity
without manufacturing the move through oversized risk.
```

No EA source fork, simulator build, tester run, or trading-logic implementation is currently authorized by V8.

## V8 Candidate 1

Candidate:

```text
Pre-event positioning-asymmetry velocity at scheduled macro catalysts.
```

Status:

```text
KILLED at free pre-audit viability screen.
```

Canonical file:

- `V8_CANDIDATE1_PRE_EVENT_PHASE0_5.md`

Reason:

- The free screen did not show enough underlying positioning/event signal to justify paid consensus-data acquisition.
- EUR/USD contradicted the directional forced-unwind thesis.
- USD/JPY showed only a weak thesis-consistent hint, statistically indistinguishable from noise at the available sample size.
- Magnitude patterns were inconsistent across instruments and did not cleanly separate crowded from neutral regimes.

Outcome discipline:

- `$0` spent.
- No paid data.
- No third instrument.
- No XAUUSD extension.
- No index extension.
- No thesis rewrite.
- No EA, simulator, tester, or trading logic.

## Candidate 1 Artifacts

Scripts and data retained for inspection / future non-rescue event probes:

- `v8_viability_screen.py`
- `v8_viability_data/viability_screen_events.csv`
- `v8_viability_data/viability_screen_events_usdjpy.csv`
- `v8_viability_data/cftc_2018.csv` through `v8_viability_data/cftc_2026.csv`

Downloaded/added market data:

- `USDJPY_4 Hours_Ask_2018.01.01_2026.05.12.csv`
- `USDJPY_4 Hours_Bid_2018.01.01_2026.05.12.csv`

Note:

The screen used degraded H4 event bars, enough for a free viability read but not for trade-rule validation.

## Secret Hygiene

`.gitignore` was updated to exclude local secret/key files:

- `.env`
- `.env.local`
- `.env.*.local`
- `*.key`
- `secrets/`

Keep this change.

## Current Repo Packaging State

No commit was made this session.

There are many uncommitted tracked and untracked artifacts from v6/v7/v8 research. Before new implementation work, review and package the closure/research state deliberately.

Suggested future packaging:

1. Commit closure/planning/research docs and small reproducibility artifacts.
2. Decide whether bulky raw market CSVs belong in git or in an external data directory.
3. Preserve generated research outputs that support recorded KILL decisions.

## Next Session

Do not start by reacting to Candidate 1.

Next session opens cold with:

```text
Propose Candidate 2 only if there is an independently motivated velocity source.
```

Candidate 2 must satisfy `V8_VELOCITY_POCKET_PREREG.md` before any candidate brief, code, data pull, simulator, or tester work.

Do not use Candidate 1's failure as the thesis generator. Avoid "not event-driven" or "not positioning-based" as the main motivation. The new candidate must stand on its own market mechanism.
