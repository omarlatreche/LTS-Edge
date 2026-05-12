#!/usr/bin/env python3
"""Extract v6.3 post-checkpoint trade traces from MT4 tester logs.

Frame 2A only changes sizing after the +5% checkpoint, so this parser focuses
on run attribution plus POST-CHECKPOINT trace rows. It does not infer missing
pre-checkpoint trades.
"""

from __future__ import annotations

import csv
import hashlib
import re
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Iterable


LOG_DIR = Path(
    "/Users/olatreche/Library/Application Support/net.metaquotes.wine.metatrader4/"
    "drive_c/Program Files (x86)/MetaTrader 4/tester/logs"
)
OUT_DIR = Path("/Users/olatreche/Desktop/LTS Edge v1/frame2a_log_extract")

CHECKPOINT_QUARTERS = {
    "2020Q2": ("2020-04-01", "2020-07-01"),
    "2022Q3": ("2022-07-01", "2022-10-01"),
    "2023Q3": ("2023-07-01", "2023-10-01"),
    "2023Q4": ("2023-10-01", "2024-01-01"),
    "2024Q1": ("2024-01-01", "2024-04-01"),
    "2025Q1": ("2025-01-01", "2025-04-01"),
    "2025Q4": ("2025-10-01", "2026-01-01"),
    "2026Q1": ("2026-01-01", "2026-04-01"),
}


LOG_RE = re.compile(
    r"^(?P<level>\d+)\s+(?P<wall>\d\d:\d\d:\d\d\.\d+)\s+"
    r"(?P<sim>\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+"
    r"(?P<rest>.*)$"
)
INPUT_RE = re.compile(r"LTS_Prop_Engine_v6 inputs: (?P<inputs>.*)$")
KV_RE = re.compile(r"(?P<key>[A-Za-z][A-Za-z0-9_]*)=(?P<value>[^;]*);")


def parse_sim_time(value: str) -> str:
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S").isoformat(sep=" ")


def norm_date(value: str) -> str:
    return value.replace(".", "-")


def parse_kv_semicolon(text: str) -> dict[str, str]:
    return {m.group("key"): m.group("value").strip() for m in KV_RE.finditer(text)}


def log_message(rest: str) -> str:
    if "LTS_Prop_Engine_v6 inputs:" in rest:
        return rest.strip()
    if ": " in rest:
        return rest.split(": ", 1)[1].strip()
    return rest.strip()


def parse_pipe_fields(text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for part in text.split("|"):
        part = part.strip()
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        fields[key.strip()] = value.strip()
    return fields


def parse_bool(value: str | None) -> str:
    if value is None:
        return ""
    lowered = value.strip().lower()
    if lowered in {"1", "true"}:
        return "true"
    if lowered in {"0", "false"}:
        return "false"
    return value


def run_version(inputs: dict[str, str], settings: dict[str, str]) -> str:
    dyn = parse_bool(inputs.get("UseDynamicCampaignFloor") or settings.get("dynFloor"))
    adaptive = parse_bool(inputs.get("UseAdaptiveStrategyLossLimit") or settings.get("adaptiveLoss"))
    weak_guard = parse_bool(inputs.get("UseCheckpointWeakPushGuard") or settings.get("weakGuard"))

    if dyn == "true":
        return "v6.3"
    if weak_guard == "true":
        return "v6.2"
    if adaptive == "true" or inputs.get("StrategyMaxLossTradesStrong"):
        return "v6.1"
    return "v6.0_or_early"


def quarter_from_start(start: str) -> str:
    dt = datetime.strptime(start[:10], "%Y-%m-%d")
    q = ((dt.month - 1) // 3) + 1
    return f"{dt.year}Q{q}"


def stable_hash(parts: Iterable[str]) -> str:
    h = hashlib.sha1()
    for part in parts:
        h.update(part.encode("utf-8", errors="replace"))
        h.update(b"\0")
    return h.hexdigest()[:12]


@dataclass
class Trade:
    source: str
    fields: dict[str, str]


@dataclass
class Run:
    log_path: Path
    start_line: int
    end_line: int = 0
    input_sim_time: str = ""
    inputs: dict[str, str] = field(default_factory=dict)
    summary_sim_time: str = ""
    result: dict[str, str] = field(default_factory=dict)
    dates: dict[str, str] = field(default_factory=dict)
    account: dict[str, str] = field(default_factory=dict)
    report: dict[str, str] = field(default_factory=dict)
    trades_summary: dict[str, str] = field(default_factory=dict)
    campaign: dict[str, str] = field(default_factory=dict)
    settings: dict[str, str] = field(default_factory=dict)
    trace_summary: dict[str, str] = field(default_factory=dict)
    all_closed_rows: list[Trade] = field(default_factory=list)
    closed_rows: list[Trade] = field(default_factory=list)
    trace_rows: list[Trade] = field(default_factory=list)

    @property
    def run_id(self) -> str:
        return stable_hash([str(self.log_path), str(self.start_line), self.input_sim_time])

    @property
    def input_start_date(self) -> str:
        return norm_date(self.input_sim_time[:10]) if self.input_sim_time else ""

    @property
    def summary_end_date(self) -> str:
        return norm_date(self.summary_sim_time[:10]) if self.summary_sim_time else ""

    @property
    def quarter(self) -> str:
        return quarter_from_start(self.input_start_date) if self.input_start_date else ""

    @property
    def selected_trades(self) -> list[Trade]:
        rows = self.trace_rows if self.trace_rows else self.closed_rows
        seen: set[tuple[str, str, str]] = set()
        out: list[Trade] = []
        for row in rows:
            key = (
                row.fields.get("ticket", ""),
                row.fields.get("open", ""),
                row.fields.get("close", ""),
            )
            if key in seen:
                continue
            seen.add(key)
            out.append(row)
        return out


def parse_log(path: Path) -> list[Run]:
    runs: list[Run] = []
    current: Run | None = None

    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for lineno, line in enumerate(fh, start=1):
            line = line.rstrip("\n")
            m = LOG_RE.match(line)
            if not m:
                continue

            msg = log_message(m.group("rest"))
            input_match = INPUT_RE.search(msg)
            if input_match:
                if current is not None:
                    current.end_line = lineno - 1
                    runs.append(current)
                current = Run(log_path=path, start_line=lineno, input_sim_time=parse_sim_time(m.group("sim")))
                current.inputs = parse_kv_semicolon(input_match.group("inputs"))
                continue

            if current is None:
                continue

            current.end_line = lineno
            if msg == "========== V6 TEST SUMMARY ==========":
                current.summary_sim_time = parse_sim_time(m.group("sim"))
            elif msg.startswith("Result: "):
                current.result = parse_pipe_fields(msg.removeprefix("Result: "))
            elif msg.startswith("Dates: "):
                current.dates = parse_pipe_fields(msg.removeprefix("Dates: "))
            elif msg.startswith("Account: "):
                current.account = parse_pipe_fields(msg.removeprefix("Account: "))
            elif msg.startswith("Report: "):
                current.report = parse_pipe_fields(msg.removeprefix("Report: "))
            elif msg.startswith("Trades: "):
                current.trades_summary = parse_pipe_fields(msg.removeprefix("Trades: "))
            elif msg.startswith("Campaign: ") and "|" in msg:
                current.campaign = parse_pipe_fields(msg.removeprefix("Campaign: "))
            elif msg.startswith("Settings: "):
                current.settings = parse_pipe_fields(msg.removeprefix("Settings: "))
            elif msg.startswith("POST-CHECKPOINT TRACE SUMMARY: "):
                current.trace_summary = parse_pipe_fields(msg.removeprefix("POST-CHECKPOINT TRACE SUMMARY: "))
            elif msg.startswith("ALL CLOSED TRADE: "):
                fields = parse_pipe_fields(msg.removeprefix("ALL CLOSED TRADE: "))
                current.all_closed_rows.append(Trade(source="all_closed", fields=fields))
            elif msg.startswith("POST-CHECKPOINT CLOSED TRADE: "):
                fields = parse_pipe_fields(msg.removeprefix("POST-CHECKPOINT CLOSED TRADE: "))
                current.closed_rows.append(Trade(source="closed", fields=fields))
            elif "POST-CHECKPOINT TRACE ROW" in msg:
                _, payload = msg.split(":", 1)
                fields = parse_pipe_fields(payload.strip())
                current.trace_rows.append(Trade(source="trace", fields=fields))

    if current is not None:
        runs.append(current)
    return runs


def write_csv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    log_paths = sorted(LOG_DIR.glob("*.log"))
    runs: list[Run] = []
    for path in log_paths:
        runs.extend(parse_log(path))

    run_rows: list[dict[str, object]] = []
    trade_rows: list[dict[str, object]] = []
    all_trade_rows: list[dict[str, object]] = []
    for run in runs:
        version = run_version(run.inputs, run.settings)
        settings_blob = ";".join(f"{k}={v}" for k, v in sorted(run.inputs.items()))
        settings_hash = stable_hash([settings_blob])
        selected_trades = run.selected_trades

        run_rows.append(
            {
                "run_id": run.run_id,
                "log_file": str(run.log_path),
                "start_line": run.start_line,
                "end_line": run.end_line,
                "version": version,
                "quarter": run.quarter,
                "input_start_date": run.input_start_date,
                "summary_end_date": run.summary_end_date,
                "tester_start": run.dates.get("testerStart", ""),
                "gate_open": run.dates.get("gateOpen", ""),
                "checkpoint": run.dates.get("checkpoint", ""),
                "target": run.dates.get("target", ""),
                "state": run.result.get("state", ""),
                "target_hit": run.result.get("targetHit", ""),
                "return_balance_pct": run.account.get("returnBalance", "").rstrip("%"),
                "return_equity_pct": run.account.get("returnEquity", "").rstrip("%"),
                "peak_equity": run.campaign.get("peakEquity", ""),
                "max_dd_pct": (run.report.get("maxDD", "").split("(")[-1].rstrip(")") if "(" in run.report.get("maxDD", "") else ""),
                "total_trades": run.trades_summary.get("total", ""),
                "post_checkpoint_rows": len(selected_trades),
                "trace_rows_reported": run.trace_summary.get("rows", ""),
                "trace_overflow": run.trace_summary.get("overflow", ""),
                "settings_hash": settings_hash,
                "gate_min": run.settings.get("gateMin", run.inputs.get("StartGateMinScore", "")),
                "dyn_floor": run.settings.get("dynFloor", parse_bool(run.inputs.get("UseDynamicCampaignFloor"))),
                "dyn_trigger": run.settings.get("dynTrigger", run.inputs.get("DynamicFloorTriggerPct", "")),
                "dyn_floor_pct": run.settings.get("dynFloorPct", run.inputs.get("DynamicFloorPct", "")),
                "adaptive_loss": run.settings.get("adaptiveLoss", parse_bool(run.inputs.get("UseAdaptiveStrategyLossLimit"))),
                "strong_loss_trades": run.settings.get("strongLossTrades", run.inputs.get("StrategyMaxLossTradesStrong", "")),
                "slippage": run.inputs.get("Slippage", ""),
            }
        )

        for idx, trade in enumerate(selected_trades, start=1):
            f = trade.fields
            trade_rows.append(
                {
                    "run_id": run.run_id,
                    "trade_index": idx,
                    "source": trade.source,
                    "ticket": f.get("ticket", ""),
                    "module": f.get("module", ""),
                    "type": f.get("type", ""),
                    "open": f.get("open", ""),
                    "close": f.get("close", ""),
                    "lots": f.get("lots", ""),
                    "openPrice": f.get("openPrice", ""),
                    "closePrice": f.get("closePrice", ""),
                    "pl": f.get("pl", ""),
                    "equity": f.get("equity", ""),
                    "return_pct": f.get("return", "").rstrip("%"),
                    "peak_return_pct": f.get("peakReturn", "").rstrip("%"),
                    "dyn_peak_pct": f.get("dynPeak", "").rstrip("%"),
                    "campaign_score": f.get("campaignScore", ""),
                    "state": f.get("state", ""),
                }
            )

        for idx, trade in enumerate(run.all_closed_rows, start=1):
            f = trade.fields
            all_trade_rows.append(
                {
                    "run_id": run.run_id,
                    "trade_index": idx,
                    "source": trade.source,
                    "ticket": f.get("ticket", ""),
                    "module": f.get("module", ""),
                    "type": f.get("type", ""),
                    "open": f.get("open", ""),
                    "close": f.get("close", ""),
                    "lots": f.get("lots", ""),
                    "openPrice": f.get("openPrice", ""),
                    "closePrice": f.get("closePrice", ""),
                    "pl": f.get("pl", ""),
                    "equity": f.get("equity", ""),
                    "return_pct": f.get("return", "").rstrip("%"),
                    "peak_return_pct": f.get("peakReturn", "").rstrip("%"),
                    "dyn_peak_pct": f.get("dynPeak", "").rstrip("%"),
                    "campaign_score": f.get("campaignScore", ""),
                    "checkpoint_hit": f.get("checkpointHit", ""),
                    "state": f.get("state", ""),
                }
            )

    run_fields = [
        "run_id",
        "log_file",
        "start_line",
        "end_line",
        "version",
        "quarter",
        "input_start_date",
        "summary_end_date",
        "tester_start",
        "gate_open",
        "checkpoint",
        "target",
        "state",
        "target_hit",
        "return_balance_pct",
        "return_equity_pct",
        "peak_equity",
        "max_dd_pct",
        "total_trades",
        "post_checkpoint_rows",
        "trace_rows_reported",
        "trace_overflow",
        "settings_hash",
        "gate_min",
        "dyn_floor",
        "dyn_trigger",
        "dyn_floor_pct",
        "adaptive_loss",
        "strong_loss_trades",
        "slippage",
    ]
    trade_fields = [
        "run_id",
        "trade_index",
        "source",
        "ticket",
        "module",
        "type",
        "open",
        "close",
        "lots",
        "openPrice",
        "closePrice",
        "pl",
        "equity",
        "return_pct",
        "peak_return_pct",
        "dyn_peak_pct",
        "campaign_score",
        "state",
    ]
    all_trade_fields = [
        "run_id",
        "trade_index",
        "source",
        "ticket",
        "module",
        "type",
        "open",
        "close",
        "lots",
        "openPrice",
        "closePrice",
        "pl",
        "equity",
        "return_pct",
        "peak_return_pct",
        "dyn_peak_pct",
        "campaign_score",
        "checkpoint_hit",
        "state",
    ]

    write_csv(OUT_DIR / "runs.csv", run_rows, run_fields)
    write_csv(OUT_DIR / "trades.csv", trade_rows, trade_fields)
    write_csv(OUT_DIR / "all_trades.csv", all_trade_rows, all_trade_fields)

    coverage_rows: list[dict[str, object]] = []
    for quarter, (start, end) in CHECKPOINT_QUARTERS.items():
        base_filter = [
            row
            for row in run_rows
            if row["version"] == "v6.3"
            and row["quarter"] == quarter
            and row["input_start_date"] == start
            and row["dyn_floor"] == "true"
            and str(row["gate_min"]) == "7"
            and str(row["adaptive_loss"]) == "true"
        ]
        baseline_candidates = [row for row in base_filter if str(row["slippage"]) == "5"]
        trace_candidates = [row for row in base_filter if int(row["post_checkpoint_rows"]) > 0]

        baseline_candidates.sort(
            key=lambda row: (
                int(row["post_checkpoint_rows"]),
                str(row["summary_end_date"]),
                str(row["run_id"]),
            ),
            reverse=True,
        )
        trace_candidates.sort(
            key=lambda row: (
                int(row["post_checkpoint_rows"]),
                str(row["slippage"]) == "5",
                str(row["summary_end_date"]),
                str(row["run_id"]),
            ),
            reverse=True,
        )

        best = baseline_candidates[0] if baseline_candidates else {}
        trace_best = trace_candidates[0] if trace_candidates else {}
        if best and int(best.get("post_checkpoint_rows", 0)) > 0:
            status = "usable_baseline_trace"
        elif best and trace_best:
            status = "baseline_missing_trace_alt_available"
        elif best:
            status = "baseline_missing_trace"
        elif trace_best:
            status = "no_baseline_alt_trace_available"
        else:
            status = "missing"

        coverage_rows.append(
            {
                "quarter": quarter,
                "expected_start": start,
                "expected_end": end,
                "baseline_candidate_runs": len(baseline_candidates),
                "baseline_run_id": best.get("run_id", ""),
                "baseline_summary_end_date": best.get("summary_end_date", ""),
                "baseline_return_pct": best.get("return_balance_pct", ""),
                "baseline_state": best.get("state", ""),
                "baseline_target_hit": best.get("target_hit", ""),
                "baseline_post_checkpoint_rows": best.get("post_checkpoint_rows", ""),
                "baseline_trace_overflow": best.get("trace_overflow", ""),
                "best_trace_run_id": trace_best.get("run_id", ""),
                "best_trace_slippage": trace_best.get("slippage", ""),
                "best_trace_return_pct": trace_best.get("return_balance_pct", ""),
                "best_trace_state": trace_best.get("state", ""),
                "best_trace_rows": trace_best.get("post_checkpoint_rows", ""),
                "status": status,
            }
        )

    coverage_fields = [
        "quarter",
        "expected_start",
        "expected_end",
        "baseline_candidate_runs",
        "baseline_run_id",
        "baseline_summary_end_date",
        "baseline_return_pct",
        "baseline_state",
        "baseline_target_hit",
        "baseline_post_checkpoint_rows",
        "baseline_trace_overflow",
        "best_trace_run_id",
        "best_trace_slippage",
        "best_trace_return_pct",
        "best_trace_state",
        "best_trace_rows",
        "status",
    ]
    write_csv(OUT_DIR / "coverage.csv", coverage_rows, coverage_fields)

    print(f"Parsed {len(runs)} runs from {len(log_paths)} log files")
    print(f"Wrote {OUT_DIR / 'runs.csv'}")
    print(f"Wrote {OUT_DIR / 'trades.csv'}")
    print(f"Wrote {OUT_DIR / 'all_trades.csv'}")
    print(f"Wrote {OUT_DIR / 'coverage.csv'}")
    print("Frame 2A checkpoint coverage:")
    for row in coverage_rows:
        print(
            f"  {row['quarter']}: {row['status']} "
            f"baseline_runs={row['baseline_candidate_runs']} "
            f"baseline_trades={row['baseline_post_checkpoint_rows']} "
            f"baseline_return={row['baseline_return_pct']} "
            f"trace_alt={row['best_trace_rows']}@slip{row['best_trace_slippage']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
