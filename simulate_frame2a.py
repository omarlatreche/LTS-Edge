#!/usr/bin/env python3
"""Planning-time Frame 2A post-checkpoint sizing simulation.

This consumes parse_frame2a_logs.py outputs. It intentionally fails closed if
any primary baseline checkpoint quarter lacks usable Slippage=5 trace rows.
"""

from __future__ import annotations

import csv
import struct
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path


BASE_DIR = Path("/Users/olatreche/Desktop/LTS Edge v1/frame2a_log_extract")
OUT_PATH = BASE_DIR / "frame2a_simulation.csv"
HST_PATH = Path(
    "/Users/olatreche/Library/Application Support/net.metaquotes.wine.metatrader4/"
    "drive_c/Program Files (x86)/MetaTrader 4/history/FTMO-Demo2/XAUUSD60.hst"
)
START_BALANCE = 70000.0
TARGET_PCT = 10.0
TRIGGER_PCT = 5.0
DEMOTE_FLOOR_PCT = 3.0
PEAK_DD_STOP_PCT = 8.0
DAILY_KILL_PCT = 4.0
ACTIVATION_PCT = 7.0
MULTIPLIERS = (2.0,)


@dataclass
class Trade:
    ticket: str
    module: str
    type: str
    open: str
    close: str
    lots: float
    open_price: float
    close_price: float
    pl: float
    baseline_return_pct: float
    baseline_peak_pct: float
    state: str


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


def pct(balance: float) -> float:
    return (balance - START_BALANCE) / START_BALANCE * 100.0


def parse_dt(value: str) -> datetime:
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S" if "." in value[:10] else "%Y-%m-%d %H:%M:%S")


def parse_trade_dt(value: str) -> datetime:
    return datetime.strptime(value, "%Y.%m.%d %H:%M" if "." in value[:10] else "%Y-%m-%d %H:%M")


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


def price_pl(trade: Trade, price: float, multiplier: float) -> float:
    # Baseline trade PL is already net of spread/slippage/FX conversion. Inferring
    # value per price unit from the realized trade makes costs scale per lot too.
    diff = trade.close_price - trade.open_price
    if trade.type.upper() == "SELL":
        diff = -diff
        live_diff = trade.open_price - price
    else:
        live_diff = price - trade.open_price

    denom = diff * trade.lots
    if abs(denom) < 1e-9:
        return trade.pl * multiplier
    value_per_price_lot = trade.pl / denom
    return live_diff * trade.lots * multiplier * value_per_price_lot


def adverse_price(trade: Trade, bar: Bar) -> float:
    if trade.type.upper() == "SELL":
        return bar.high
    return bar.low


def favorable_price(trade: Trade, bar: Bar) -> float:
    if trade.type.upper() == "SELL":
        return bar.low
    return bar.high


def selected_baseline_runs() -> list[dict[str, str]]:
    coverage = read_csv(BASE_DIR / "coverage.csv")
    selected: list[dict[str, str]] = []
    missing: list[str] = []
    for row in coverage:
        if row["status"] != "usable_baseline_trace":
            missing.append(f"{row['quarter']} ({row['status']})")
            continue
        selected.append(row)
    if missing:
        joined = ", ".join(missing)
        raise SystemExit(
            "Primary Frame 2A simulation blocked: missing usable Slippage=5 "
            f"baseline trace for {joined}. Regenerate those baseline runs first."
        )
    return selected


def trades_by_run() -> dict[str, list[Trade]]:
    out: dict[str, list[Trade]] = {}
    for row in read_csv(BASE_DIR / "trades.csv"):
        run_id = row["run_id"]
        out.setdefault(run_id, []).append(
            Trade(
                ticket=row["ticket"],
                module=row["module"],
                type=row["type"],
                open=row["open"],
                close=row["close"],
                lots=float(row["lots"]),
                open_price=float(row["openPrice"]),
                close_price=float(row["closePrice"]),
                pl=float(row["pl"]),
                baseline_return_pct=float(row["return_pct"]),
                baseline_peak_pct=float(row["peak_return_pct"]),
                state=row["state"],
            )
        )
    return out


def simulate_quarter(
    run: dict[str, str],
    trades: list[Trade],
    multiplier: float,
    h1_bars: list[Bar],
) -> dict[str, object]:
    # We start at the first logged post-checkpoint close. Its baseline return
    # already includes pre-checkpoint P/L, which Frame 2A leaves unchanged.
    balance = START_BALANCE
    peak_balance = START_BALANCE
    max_peak_dd_from_peak_pct = 0.0
    checkpoint_balance = START_BALANCE * (1.0 + TRIGGER_PCT / 100.0)
    active = True
    demoted = False
    activated = False
    activation_time = ""
    first_post_checkpoint_winner_closed = False
    activation_balance = START_BALANCE * (1.0 + ACTIVATION_PCT / 100.0)
    peak_floating_since_checkpoint = checkpoint_balance
    target_hit = False
    peak_dd_stop = False
    daily_kill_days: set[str] = set()
    halted_day: str | None = None
    daily_pl: dict[str, float] = {}

    first = min(trades, key=lambda t: parse_trade_dt(t.close))
    first_equity_after = START_BALANCE * (1.0 + first.baseline_return_pct / 100.0)
    # Pre-trigger/pre-first-close P/L is not changed by Frame 2A. Do not floor it
    # upward; if trace starts after checkpoint, the first close reconstructs it.
    balance = first_equity_after - first.pl
    peak_balance = max(START_BALANCE, balance, checkpoint_balance)
    peak_floating_since_checkpoint = max(peak_floating_since_checkpoint, balance)

    trade_state = {trade.ticket: {"closed": False, "realized": 0.0} for trade in trades}
    trade_multiplier: dict[str, float] = {}
    open_times = {trade.ticket: parse_trade_dt(trade.open) for trade in trades}
    close_times = {trade.ticket: parse_trade_dt(trade.close) for trade in trades}
    start_time = min(open_times.values()).replace(minute=0, second=0, microsecond=0)
    end_time = max(close_times.values()).replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)
    bars = [bar for bar in h1_bars if start_time <= bar.time <= end_time]

    def assigned_multiplier(trade: Trade) -> float:
        if trade.ticket not in trade_multiplier:
            trade_multiplier[trade.ticket] = multiplier if active and activated else 1.0
        return trade_multiplier[trade.ticket]

    for bar in bars:
        day = bar.time.strftime("%Y-%m-%d")
        if halted_day != day:
            halted_day = None

        floating = 0.0
        for trade in trades:
            if trade_state[trade.ticket]["closed"]:
                continue
            if not (open_times[trade.ticket] <= bar.time <= close_times[trade.ticket]):
                continue
            eff = assigned_multiplier(trade)
            floating += price_pl(trade, adverse_price(trade, bar), eff)

        floating_equity = balance + floating
        peak_balance = max(peak_balance, floating_equity)
        current_pct = pct(floating_equity)
        peak_dd_pct = (peak_balance - floating_equity) / START_BALANCE * 100.0
        max_peak_dd_from_peak_pct = max(max_peak_dd_from_peak_pct, peak_dd_pct)

        if current_pct < DEMOTE_FLOOR_PCT and active:
            active = False
            demoted = True
        if peak_dd_pct > PEAK_DD_STOP_PCT:
            active = False
            peak_dd_stop = True
            demoted = True
            break
        if day not in daily_kill_days and daily_pl.get(day, 0.0) + min(0.0, floating) <= -START_BALANCE * DAILY_KILL_PCT / 100.0:
            daily_kill_days.add(day)
            halted_day = day

        favorable_floating = 0.0
        for trade in trades:
            if trade_state[trade.ticket]["closed"]:
                continue
            if not (open_times[trade.ticket] <= bar.time <= close_times[trade.ticket]):
                continue
            eff = assigned_multiplier(trade)
            favorable_floating += price_pl(trade, favorable_price(trade, bar), eff)
        favorable_equity = balance + favorable_floating
        peak_balance = max(peak_balance, favorable_equity)
        peak_floating_since_checkpoint = max(peak_floating_since_checkpoint, favorable_equity)
        if pct(balance + favorable_floating) >= TARGET_PCT:
            target_hit = True
            balance = START_BALANCE * (1.0 + TARGET_PCT / 100.0)
            peak_balance = max(peak_balance, balance)
            peak_floating_since_checkpoint = max(peak_floating_since_checkpoint, balance)
            break

        for trade in sorted(trades, key=lambda t: close_times[t.ticket]):
            if trade_state[trade.ticket]["closed"]:
                continue
            if close_times[trade.ticket].replace(minute=0, second=0, microsecond=0) != bar.time:
                continue
            if halted_day == day:
                trade_state[trade.ticket]["closed"] = True
                continue
            eff = assigned_multiplier(trade)
            adjusted_pl = trade.pl * eff
            balance += adjusted_pl
            daily_pl[day] = daily_pl.get(day, 0.0) + adjusted_pl
            trade_state[trade.ticket]["closed"] = True
            trade_state[trade.ticket]["realized"] = adjusted_pl
            peak_balance = max(peak_balance, balance)
            peak_floating_since_checkpoint = max(peak_floating_since_checkpoint, balance)
            if adjusted_pl > 0:
                first_post_checkpoint_winner_closed = True
                if (
                    not activated
                    and active
                    and first_post_checkpoint_winner_closed
                    and peak_floating_since_checkpoint >= activation_balance
                ):
                    activated = True
                    activation_time = trade.close
            if pct(balance) >= TARGET_PCT:
                target_hit = True
                break
        if target_hit:
            break

    final_pct = pct(balance)
    return {
        "quarter": run["quarter"],
        "run_id": run["baseline_run_id"],
        "multiplier": multiplier,
        "baseline_return_pct": run["baseline_return_pct"],
        "baseline_target_hit": run["baseline_target_hit"],
        "sim_return_pct": f"{final_pct:.2f}",
        "sim_target_hit": str(target_hit).lower(),
        "sim_peak_return_pct": f"{pct(peak_balance):.2f}",
        "sim_peak_dd_from_peak_pct": f"{max_peak_dd_from_peak_pct:.2f}",
        "activated": str(activated).lower(),
        "activation_time": activation_time,
        "peak_floating_since_checkpoint_pct": f"{pct(peak_floating_since_checkpoint):.2f}",
        "demoted": str(demoted).lower(),
        "peak_dd_stop": str(peak_dd_stop).lower(),
        "daily_kills": len(daily_kill_days),
        "trace_rows": len(trades),
        "conversion_eligible_for_gate": str(target_hit and len(trades) >= 3).lower(),
    }


def main() -> int:
    selected = selected_baseline_runs()
    by_run = trades_by_run()
    h1_bars = load_h1_bars()
    rows: list[dict[str, object]] = []
    for run in selected:
        trades = by_run.get(run["baseline_run_id"], [])
        if not trades:
            raise SystemExit(f"Run {run['baseline_run_id']} has no trade rows")
        for multiplier in MULTIPLIERS:
            rows.append(simulate_quarter(run, trades, multiplier, h1_bars))

    fields = [
        "quarter",
        "run_id",
        "multiplier",
        "baseline_return_pct",
        "baseline_target_hit",
        "sim_return_pct",
        "sim_target_hit",
        "sim_peak_return_pct",
        "sim_peak_dd_from_peak_pct",
        "activated",
        "activation_time",
        "peak_floating_since_checkpoint_pct",
        "demoted",
        "peak_dd_stop",
        "daily_kills",
        "trace_rows",
        "conversion_eligible_for_gate",
    ]
    with OUT_PATH.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {OUT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
