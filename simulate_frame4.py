#!/usr/bin/env python3
"""Planning-time Frame 4 Iteration 2 abort-rule simulation.

Consumes parse_frame2a_logs.py outputs after the observational
LogAllClosedTrades MT4 regeneration. The locked rule is:

At the end of calendar day 30, if at least 3 trades have closed, equity is <=
start balance, and no +5% closed-equity checkpoint has been hit, block new
entries for the rest of the quarter. Trades already open continue to their
original natural close.
"""

from __future__ import annotations

import csv
import struct
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path


BASE_DIR = Path("/Users/olatreche/Desktop/LTS Edge v1/frame2a_log_extract")
OUT_PATH = BASE_DIR / "frame4_iteration2_simulation.csv"
HST_PATH = Path(
    "/Users/olatreche/Library/Application Support/net.metaquotes.wine.metatrader4/"
    "drive_c/Program Files (x86)/MetaTrader 4/history/FTMO-Demo2/XAUUSD60.hst"
)

START_BALANCE = 70000.0
CHECKPOINT_PCT = 5.0
TARGET_PCT = 10.0
DAY_N = 30


EXPECTED_QUARTERS = [
    ("2020Q1", "2020-01-01", "2020-04-01"),
    ("2020Q2", "2020-04-01", "2020-07-01"),
    ("2020Q3", "2020-07-01", "2020-10-01"),
    ("2020Q4", "2020-10-01", "2021-01-01"),
    ("2021Q1", "2021-01-01", "2021-04-01"),
    ("2021Q2", "2021-04-01", "2021-07-01"),
    ("2021Q3", "2021-07-01", "2021-10-01"),
    ("2021Q4", "2021-10-01", "2022-01-01"),
    ("2022Q1", "2022-01-01", "2022-04-01"),
    ("2022Q2", "2022-04-01", "2022-07-01"),
    ("2022Q3", "2022-07-01", "2022-10-01"),
    ("2022Q4", "2022-10-01", "2023-01-01"),
    ("2023Q1", "2023-01-01", "2023-04-01"),
    ("2023Q2", "2023-04-01", "2023-07-01"),
    ("2023Q3", "2023-07-01", "2023-10-01"),
    ("2023Q4", "2023-10-01", "2024-01-01"),
    ("2024Q1", "2024-01-01", "2024-04-01"),
    ("2024Q2", "2024-04-01", "2024-07-01"),
    ("2024Q3", "2024-07-01", "2024-10-01"),
    ("2024Q4", "2024-10-01", "2025-01-01"),
    ("2025Q1", "2025-01-01", "2025-04-01"),
    ("2025Q2", "2025-04-01", "2025-07-01"),
    ("2025Q3", "2025-07-01", "2025-10-01"),
    ("2025Q4", "2025-10-01", "2026-01-01"),
    ("2026Q1", "2026-01-01", "2026-04-01"),
]


@dataclass
class Trade:
    ticket: str
    module: str
    type: str
    open_time: datetime
    close_time: datetime
    lots: float
    open_price: float
    close_price: float
    pl: float
    checkpoint_hit_after_close: bool


@dataclass
class Bar:
    time: datetime
    open: float
    high: float
    low: float
    close: float


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def parse_dt(value: str) -> datetime:
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            pass
    raise ValueError(f"Unsupported datetime: {value}")


def pct(balance: float) -> float:
    return (balance - START_BALANCE) / START_BALANCE * 100.0


def parse_pct(value: str) -> float:
    return float(value.strip().rstrip("%"))


def load_h1_bars(path: Path = HST_PATH) -> list[Bar]:
    data = path.read_bytes()
    bars: list[Bar] = []
    header_size = 148
    record_size = 60
    fmt = "<qddddqiq"
    for off in range(header_size, len(data) - record_size + 1, record_size):
        ts, open_, high, low, close, _vol, _spread, _real_vol = struct.unpack_from(fmt, data, off)
        if ts <= 0 or high <= 0 or low <= 0:
            continue
        bars.append(Bar(datetime.utcfromtimestamp(ts), open_, high, low, close))
    return bars


def price_pl(trade: Trade, price: float) -> float:
    diff = trade.close_price - trade.open_price
    if trade.type.upper() == "SELL":
        diff = -diff
        live_diff = trade.open_price - price
    else:
        live_diff = price - trade.open_price

    denom = diff * trade.lots
    if abs(denom) < 1e-9:
        return trade.pl
    value_per_price_lot = trade.pl / denom
    return live_diff * trade.lots * value_per_price_lot


def selected_runs() -> list[dict[str, str]]:
    runs = read_csv(BASE_DIR / "runs.csv")
    all_rows = read_csv(BASE_DIR / "all_trades.csv")
    all_counts: dict[str, int] = {}
    for row in all_rows:
        all_counts[row["run_id"]] = all_counts.get(row["run_id"], 0) + 1

    selected: list[dict[str, str]] = []
    problems: list[str] = []
    for quarter, start, _end in EXPECTED_QUARTERS:
        candidates = [
            row
            for row in runs
            if row["input_start_date"] == start
            and row["slippage"] == "5"
            and row["dyn_floor"] == "true"
            and str(row["gate_min"]) == "7"
            and row["adaptive_loss"] == "true"
        ]
        candidates.sort(
            key=lambda row: (
                all_counts.get(row["run_id"], 0),
                row["summary_end_date"],
                row["run_id"],
            ),
            reverse=True,
        )
        if not candidates:
            problems.append(f"{quarter}: no candidate run")
            continue
        best = candidates[0]
        all_count = all_counts.get(best["run_id"], 0)
        total_trades = int(best["total_trades"])
        if all_count != total_trades:
            problems.append(
                f"{quarter}: run {best['run_id']} all_rows={all_count} total_trades={total_trades}"
            )
            continue
        selected.append({"quarter": quarter, **best})

    if problems:
        raise SystemExit("Frame 4 simulation blocked:\n" + "\n".join(problems))
    if len(selected) != 25:
        raise SystemExit(f"Frame 4 simulation blocked: selected {len(selected)} runs, expected 25")
    return selected


def trades_by_run() -> dict[str, list[Trade]]:
    out: dict[str, list[Trade]] = {}
    for row in read_csv(BASE_DIR / "all_trades.csv"):
        run_id = row["run_id"]
        out.setdefault(run_id, []).append(
            Trade(
                ticket=row["ticket"],
                module=row["module"],
                type=row["type"],
                open_time=parse_dt(row["open"]),
                close_time=parse_dt(row["close"]),
                lots=float(row["lots"]),
                open_price=float(row["openPrice"]),
                close_price=float(row["closePrice"]),
                pl=float(row["pl"]),
                checkpoint_hit_after_close=row["checkpoint_hit"].lower() == "true",
            )
        )
    for rows in out.values():
        rows.sort(key=lambda trade: (trade.close_time, int(trade.ticket) if trade.ticket.isdigit() else 0))
    return out


def equity_at_time(balance: float, trades: list[Trade], when: datetime, price: float) -> float:
    floating = 0.0
    for trade in trades:
        if trade.open_time <= when < trade.close_time:
            floating += price_pl(trade, price)
    return balance + floating


def simulate_quarter(run: dict[str, str], trades: list[Trade], bars: list[Bar]) -> dict[str, object]:
    start_dt = datetime.strptime(run["input_start_date"], "%Y-%m-%d")
    abort_time = start_dt + timedelta(days=DAY_N)
    end_dt = datetime.strptime(run["summary_end_date"], "%Y-%m-%d") + timedelta(days=1)

    balance_at_abort = START_BALANCE
    checkpoint_by_abort = False
    abort_bar: Bar | None = None
    closed_trades_by_abort = sum(1 for trade in trades if trade.close_time <= abort_time)
    for trade in trades:
        if trade.close_time <= abort_time:
            balance_at_abort += trade.pl
            if pct(balance_at_abort) >= CHECKPOINT_PCT or trade.checkpoint_hit_after_close:
                checkpoint_by_abort = True

    quarter_bars = [bar for bar in bars if start_dt <= bar.time < end_dt]
    for bar in quarter_bars:
        if bar.time < abort_time:
            abort_bar = bar
        else:
            break
    if abort_bar is None:
        raise SystemExit(f"No H1 bar found before abort time for {run['quarter']}")

    abort_equity = equity_at_time(balance_at_abort, trades, abort_bar.time + timedelta(hours=1), abort_bar.close)
    abort = (
        closed_trades_by_abort >= 3
        and abort_equity <= START_BALANCE
        and not checkpoint_by_abort
    )

    allowed_trades = [
        trade
        for trade in trades
        if (not abort) or trade.open_time < abort_time
    ]
    blocked_trades = len(trades) - len(allowed_trades)

    final_balance = START_BALANCE + sum(trade.pl for trade in allowed_trades)
    sim_return_pct = pct(final_balance)
    sim_target_hit = sim_return_pct >= TARGET_PCT

    closed_pl = 0.0
    closed: set[str] = set()
    peak_equity = START_BALANCE
    min_equity = START_BALANCE
    max_dd_pct = 0.0
    freeze_time = max((trade.close_time for trade in allowed_trades), default=start_dt)
    path_end = freeze_time if abort else end_dt

    relevant_bars = [bar for bar in quarter_bars if bar.time <= path_end]
    for bar in relevant_bars:
        for trade in allowed_trades:
            if trade.ticket in closed:
                continue
            if trade.close_time <= bar.time:
                closed_pl += trade.pl
                closed.add(trade.ticket)

        floating = 0.0
        for trade in allowed_trades:
            if trade.ticket in closed:
                continue
            if trade.open_time <= bar.time < trade.close_time:
                floating += price_pl(trade, bar.close)

        equity = START_BALANCE + closed_pl + floating
        peak_equity = max(peak_equity, equity)
        min_equity = min(min_equity, equity)
        max_dd_pct = max(max_dd_pct, (peak_equity - equity) / START_BALANCE * 100.0)

    baseline_return = parse_pct(run["return_balance_pct"])
    baseline_dd = parse_pct(run["max_dd_pct"])
    checkpoint_value = run["checkpoint"].strip()
    baseline_checkpoint = (
        checkpoint_value not in {"", "-"}
        or any(trade.checkpoint_hit_after_close for trade in trades)
    )
    baseline_negative_non_checkpoint = baseline_return < 0 and not baseline_checkpoint
    baseline_positive_non_checkpoint = baseline_return > 0 and not baseline_checkpoint
    false_abort_worse = abort and baseline_positive_non_checkpoint and sim_return_pct < baseline_return
    pass_window_aborted = abort and run["quarter"] in {"2024Q1", "2026Q1"}

    return {
        "quarter": run["quarter"],
        "run_id": run["run_id"],
        "start": run["input_start_date"],
        "end": run["summary_end_date"],
        "baseline_return_pct": f"{baseline_return:.2f}",
        "baseline_max_dd_pct": f"{baseline_dd:.2f}",
        "baseline_checkpoint": str(baseline_checkpoint).lower(),
        "baseline_target_hit": run["target_hit"],
        "baseline_state": run["state"],
        "baseline_trades": len(trades),
        "abort_time": abort_time.strftime("%Y-%m-%d %H:%M:%S"),
        "closed_trades_by_abort": closed_trades_by_abort,
        "checkpoint_by_abort": str(checkpoint_by_abort).lower(),
        "abort_equity_pct": f"{pct(abort_equity):.2f}",
        "aborted": str(abort).lower(),
        "blocked_trades": blocked_trades,
        "sim_return_pct": f"{sim_return_pct:.2f}",
        "sim_target_hit": str(sim_target_hit).lower(),
        "sim_max_dd_pct": f"{max_dd_pct:.2f}",
        "sim_trades": len(allowed_trades),
        "baseline_negative_non_checkpoint": str(baseline_negative_non_checkpoint).lower(),
        "baseline_positive_non_checkpoint": str(baseline_positive_non_checkpoint).lower(),
        "false_abort_worse": str(false_abort_worse).lower(),
        "pass_window_aborted": str(pass_window_aborted).lower(),
    }


def main() -> int:
    runs = selected_runs()
    by_run = trades_by_run()
    bars = load_h1_bars()
    rows: list[dict[str, object]] = []
    for run in runs:
        trades = by_run.get(run["run_id"], [])
        if not trades:
            raise SystemExit(f"Selected run {run['run_id']} has no all-trade rows")
        rows.append(simulate_quarter(run, trades, bars))

    fields = [
        "quarter",
        "run_id",
        "start",
        "end",
        "baseline_return_pct",
        "baseline_max_dd_pct",
        "baseline_checkpoint",
        "baseline_target_hit",
        "baseline_state",
        "baseline_trades",
        "abort_time",
        "closed_trades_by_abort",
        "checkpoint_by_abort",
        "abort_equity_pct",
        "aborted",
        "blocked_trades",
        "sim_return_pct",
        "sim_target_hit",
        "sim_max_dd_pct",
        "sim_trades",
        "baseline_negative_non_checkpoint",
        "baseline_positive_non_checkpoint",
        "false_abort_worse",
        "pass_window_aborted",
    ]
    with OUT_PATH.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    baseline_avg_return = sum(float(row["baseline_return_pct"]) for row in rows) / len(rows)
    sim_avg_return = sum(float(row["sim_return_pct"]) for row in rows) / len(rows)
    neg_nc = [row for row in rows if row["baseline_negative_non_checkpoint"] == "true"]
    baseline_avg_dd = sum(float(row["baseline_max_dd_pct"]) for row in neg_nc) / len(neg_nc)
    sim_avg_dd = sum(float(row["sim_max_dd_pct"]) for row in neg_nc) / len(neg_nc)
    dd_reduction_pct = (baseline_avg_dd - sim_avg_dd) / baseline_avg_dd * 100.0
    false_aborts = [row for row in rows if row["false_abort_worse"] == "true"]
    pass_2024 = next(row for row in rows if row["quarter"] == "2024Q1")
    pass_2026 = next(row for row in rows if row["quarter"] == "2026Q1")

    print(f"Wrote {OUT_PATH}")
    print(f"Rows: {len(rows)} | Aborted: {sum(row['aborted'] == 'true' for row in rows)}")
    print(f"Pass preservation: 2024Q1={pass_2024['sim_return_pct']} 2026Q1={pass_2026['sim_return_pct']}")
    print(f"False-abort worse count: {len(false_aborts)}")
    print(f"Baseline negative non-checkpoint avg DD: {baseline_avg_dd:.2f}%")
    print(f"Sim negative non-checkpoint avg DD: {sim_avg_dd:.2f}%")
    print(f"DD reduction: {dd_reduction_pct:.2f}%")
    print(f"Average return: baseline={baseline_avg_return:.2f}% sim={sim_avg_return:.2f}%")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
