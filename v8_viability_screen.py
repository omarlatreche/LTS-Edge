"""
V8 Candidate 1 — Free Pre-Audit Viability Screen
=================================================

Bounded purpose per Codex Phase 0.5 lock:
    Does extreme CFTC positioning correlate with larger / against-the-crowd
    post-event moves on EUR/USD around FOMC, NFP, and CPI releases?

Output is a viability read only. The question it answers is:

    "Does the positioning/event velocity premise deserve a paid data audit?"

It does NOT test a trade rule, produce an equity curve, or pass/kill Candidate 1.

IN BOUNDS:
    - CFTC data acquisition + parsing
    - Public event-date table
    - Price move / ATR measurement on H4 EUR/USD (labeled degraded)
    - Exploratory grouped statistics

OUT OF BOUNDS:
    - Trade rules
    - Backtest equity curves
    - EA / simulator work
    - Pass/DD conclusions
    - Any use of consensus-vs-actual surprise data (we do not have it yet;
      this screen tests the unfiltered positioning vs realized-move relationship)
"""

from __future__ import annotations

import io
import os
import sys
import zipfile
import urllib.request
import urllib.error
from datetime import date, datetime, timedelta
from typing import List, Optional, Tuple

import numpy as np
import pandas as pd


# ---------------------------------------------------------------------------
# Paths and configuration
# ---------------------------------------------------------------------------

REPO = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(REPO, "v8_viability_data")
os.makedirs(DATA_DIR, exist_ok=True)

# Instrument configuration. Pick via CLI arg: python3 v8_viability_screen.py [eurusd|usdjpy]
INSTRUMENTS = {
    "eurusd": {
        "label": "EURUSD",
        "ask_csv": "EURUSD_4 Hours_Ask_2018.01.01_2026.05.09.csv",
        "bid_csv": "EURUSD_4 Hours_Bid_2018.01.01_2026.05.09.csv",
        "cftc_market_names": ["EURO FX - CHICAGO MERCANTILE EXCHANGE", "EURO FX"],
        "cftc_market_contains": "EURO FX",
        "invert_positioning": False,
    },
    "usdjpy": {
        "label": "USDJPY",
        "ask_csv": "USDJPY_4 Hours_Ask_2018.01.01_2026.05.12.csv",
        "bid_csv": "USDJPY_4 Hours_Bid_2018.01.01_2026.05.12.csv",
        "cftc_market_names": ["JAPANESE YEN - CHICAGO MERCANTILE EXCHANGE", "JAPANESE YEN"],
        "cftc_market_contains": "JAPANESE YEN",
        # Long JPY futures = bullish JPY = bearish USD/JPY. Invert so the bucket
        # label refers to positioning in the spot instrument (USD/JPY).
        "invert_positioning": True,
    },
}

START_YEAR = 2020
END_YEAR = 2026

# Percentile thresholds for positioning buckets.
CROWDED_LONG_PCT = 80.0
CROWDED_SHORT_PCT = 20.0

# ATR period on H4 bars.
ATR_PERIOD = 20

# Post-event measurement window: H4 bars after release.
# Bar 0 = the H4 bar containing the release.
# Bar 1 = the next H4 bar.
# We report on Bar 0 alone and the combined 2-bar (~8 hour) window.


# ---------------------------------------------------------------------------
# Event dates (2020 - 2026)
# ---------------------------------------------------------------------------

# FOMC statement releases, 14:00 ET (19:00 UTC standard / 18:00 UTC during DST).
# Source: federalreserve.gov calendars.
FOMC_DATES = [
    "2020-01-29", "2020-03-03", "2020-03-15", "2020-04-29", "2020-06-10",
    "2020-07-29", "2020-09-16", "2020-11-05", "2020-12-16",
    "2021-01-27", "2021-03-17", "2021-04-28", "2021-06-16", "2021-07-28",
    "2021-09-22", "2021-11-03", "2021-12-15",
    "2022-01-26", "2022-03-16", "2022-05-04", "2022-06-15", "2022-07-27",
    "2022-09-21", "2022-11-02", "2022-12-14",
    "2023-02-01", "2023-03-22", "2023-05-03", "2023-06-14", "2023-07-26",
    "2023-09-20", "2023-11-01", "2023-12-13",
    "2024-01-31", "2024-03-20", "2024-05-01", "2024-06-12", "2024-07-31",
    "2024-09-18", "2024-11-07", "2024-12-18",
    "2025-01-29", "2025-03-19", "2025-05-07", "2025-06-18", "2025-07-30",
    "2025-09-17", "2025-10-29", "2025-12-10",
    "2026-01-28", "2026-03-18", "2026-04-29",
]
FOMC_RELEASE_HOUR_UTC = 19  # 14:00 ET in standard time; 18 UTC during DST.
FOMC_RELEASE_HOUR_UTC_DST = 18

# NFP: First Friday of each month, 08:30 ET (13:30 UTC standard / 12:30 UTC DST).
NFP_RELEASE_HOUR_UTC = 13  # 13:30 UTC standard; 12:30 UTC DST.
NFP_RELEASE_HOUR_UTC_DST = 12

# CPI: Mid-month release, 08:30 ET. We approximate using BLS historical schedule.
# Approximation rule: 10th-14th of the month for the prior month's data.
# Below is a list compiled from BLS historical releases.
CPI_DATES = [
    "2020-01-14", "2020-02-13", "2020-03-11", "2020-04-10", "2020-05-12",
    "2020-06-10", "2020-07-14", "2020-08-12", "2020-09-11", "2020-10-13",
    "2020-11-12", "2020-12-10",
    "2021-01-13", "2021-02-10", "2021-03-10", "2021-04-13", "2021-05-12",
    "2021-06-10", "2021-07-13", "2021-08-11", "2021-09-14", "2021-10-13",
    "2021-11-10", "2021-12-10",
    "2022-01-12", "2022-02-10", "2022-03-10", "2022-04-12", "2022-05-11",
    "2022-06-10", "2022-07-13", "2022-08-10", "2022-09-13", "2022-10-13",
    "2022-11-10", "2022-12-13",
    "2023-01-12", "2023-02-14", "2023-03-14", "2023-04-12", "2023-05-10",
    "2023-06-13", "2023-07-12", "2023-08-10", "2023-09-13", "2023-10-12",
    "2023-11-14", "2023-12-12",
    "2024-01-11", "2024-02-13", "2024-03-12", "2024-04-10", "2024-05-15",
    "2024-06-12", "2024-07-11", "2024-08-14", "2024-09-11", "2024-10-10",
    "2024-11-13", "2024-12-11",
    "2025-01-15", "2025-02-12", "2025-03-12", "2025-04-10", "2025-05-13",
    "2025-06-11", "2025-07-15", "2025-08-12", "2025-09-11", "2025-10-15",
    "2025-11-13", "2025-12-10",
    "2026-01-14", "2026-02-11", "2026-03-12", "2026-04-10",
]
CPI_RELEASE_HOUR_UTC = 13
CPI_RELEASE_HOUR_UTC_DST = 12


def is_us_dst(d: date) -> bool:
    """Rough US DST check: 2nd Sunday March to 1st Sunday November."""
    year = d.year
    # 2nd Sunday of March
    march_first = date(year, 3, 1)
    days_to_sun = (6 - march_first.weekday()) % 7
    dst_start = march_first + timedelta(days=days_to_sun + 7)
    # 1st Sunday of November
    nov_first = date(year, 11, 1)
    days_to_sun = (6 - nov_first.weekday()) % 7
    dst_end = nov_first + timedelta(days=days_to_sun)
    return dst_start <= d < dst_end


def first_friday_dates(start_year: int, end_year: int) -> List[str]:
    out = []
    for y in range(start_year, end_year + 1):
        for m in range(1, 13):
            d = date(y, m, 1)
            offset = (4 - d.weekday()) % 7  # 4 = Friday
            out.append((d + timedelta(days=offset)).isoformat())
    return out


NFP_DATES = first_friday_dates(START_YEAR, END_YEAR)


def event_datetime_utc(date_str: str, event_type: str) -> datetime:
    """Return a UTC datetime for an event, accounting for US DST."""
    d = datetime.strptime(date_str, "%Y-%m-%d").date()
    dst = is_us_dst(d)
    if event_type == "FOMC":
        hour = FOMC_RELEASE_HOUR_UTC_DST if dst else FOMC_RELEASE_HOUR_UTC
    elif event_type == "NFP":
        hour = NFP_RELEASE_HOUR_UTC_DST if dst else NFP_RELEASE_HOUR_UTC
    elif event_type == "CPI":
        hour = CPI_RELEASE_HOUR_UTC_DST if dst else CPI_RELEASE_HOUR_UTC
    else:
        raise ValueError(f"Unknown event_type {event_type}")
    # NFP/CPI at 13:30 / 12:30 UTC; FOMC at 19:00 / 18:00 UTC.
    minute = 30 if event_type in ("NFP", "CPI") else 0
    return datetime(d.year, d.month, d.day, hour, minute)


# ---------------------------------------------------------------------------
# Load EUR/USD H4 (mid) and compute ATR
# ---------------------------------------------------------------------------

def load_h4_mid(ask_csv: str, bid_csv: str) -> pd.DataFrame:
    ask_path = os.path.join(REPO, ask_csv)
    bid_path = os.path.join(REPO, bid_csv)
    if not os.path.exists(ask_path) or not os.path.exists(bid_path):
        sys.exit(f"Missing H4 CSVs at:\n  {ask_path}\n  {bid_path}")
    ask = pd.read_csv(ask_path)
    bid = pd.read_csv(bid_path)
    for df in (ask, bid):
        df.columns = [c.strip() for c in df.columns]
        df["Time (UTC)"] = pd.to_datetime(df["Time (UTC)"])
    merged = ask.merge(
        bid, on="Time (UTC)", suffixes=("_ask", "_bid")
    )
    merged["Open"] = (merged["Open_ask"] + merged["Open_bid"]) / 2.0
    merged["High"] = (merged["High_ask"] + merged["High_bid"]) / 2.0
    merged["Low"] = (merged["Low_ask"] + merged["Low_bid"]) / 2.0
    merged["Close"] = (merged["Close_ask"] + merged["Close_bid"]) / 2.0
    out = merged[["Time (UTC)", "Open", "High", "Low", "Close"]].copy()
    out = out.sort_values("Time (UTC)").reset_index(drop=True)
    return out


def add_atr(df: pd.DataFrame, period: int = 20) -> pd.DataFrame:
    df = df.copy()
    prev_close = df["Close"].shift(1)
    tr = pd.concat(
        [
            df["High"] - df["Low"],
            (df["High"] - prev_close).abs(),
            (df["Low"] - prev_close).abs(),
        ],
        axis=1,
    ).max(axis=1)
    df["ATR"] = tr.rolling(period, min_periods=period).mean()
    return df


def bar_at_or_after(df: pd.DataFrame, ts: datetime) -> Optional[int]:
    """Index of the first H4 bar whose start time covers ts.
    H4 bars are 4 hours long; the bar that contains ts has start <= ts < start+4h."""
    times = df["Time (UTC)"]
    idx = times.searchsorted(pd.Timestamp(ts), side="right") - 1
    if idx < 0 or idx >= len(df):
        return None
    bar_start = times.iloc[idx]
    if bar_start <= pd.Timestamp(ts) < bar_start + pd.Timedelta(hours=4):
        return idx
    return None


# ---------------------------------------------------------------------------
# CFTC COT data acquisition
# ---------------------------------------------------------------------------

CFTC_URL_CANDIDATES = [
    # Annual futures-only "Commitments of Traders" historical compressed files.
    "https://www.cftc.gov/files/dea/history/dea_fut_xls_{year}.zip",
    "https://www.cftc.gov/files/dea/history/deahistfo{year}.zip",
]

def fetch_cftc_year(year: int) -> Optional[pd.DataFrame]:
    cache = os.path.join(DATA_DIR, f"cftc_{year}.csv")
    if os.path.exists(cache):
        return pd.read_csv(cache, parse_dates=["Report_Date_as_YYYY-MM-DD"])
    last_err = None
    for url_tpl in CFTC_URL_CANDIDATES:
        url = url_tpl.format(year=year)
        try:
            print(f"  fetching {url}", flush=True)
            req = urllib.request.Request(
                url, headers={"User-Agent": "Mozilla/5.0 (research)"}
            )
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = resp.read()
        except (urllib.error.URLError, urllib.error.HTTPError) as e:
            last_err = e
            continue
        try:
            zf = zipfile.ZipFile(io.BytesIO(data))
        except zipfile.BadZipFile as e:
            last_err = e
            continue
        # Find the .xls or .txt inside.
        names = zf.namelist()
        # Prefer the financial / annual file.
        target = None
        for n in names:
            if n.lower().endswith((".xls", ".xlsx")):
                target = n
                break
        if target is None:
            for n in names:
                if n.lower().endswith(".txt") or n.lower().endswith(".csv"):
                    target = n
                    break
        if target is None:
            last_err = RuntimeError(f"no parseable file in {url}: {names}")
            continue
        raw = zf.read(target)
        try:
            if target.lower().endswith((".xls", ".xlsx")):
                df = pd.read_excel(io.BytesIO(raw))
            else:
                df = pd.read_csv(io.BytesIO(raw))
        except Exception as e:
            last_err = e
            continue
        # Locate the date column robustly. Prefer the MM_DD_YYYY variant since
        # the YYYY-MM-DD one is sometimes stored as a corrupted datetime in xls.
        date_col = None
        for c in df.columns:
            if "Report_Date_as_MM_DD_YYYY" in str(c):
                date_col = c
                break
        if date_col is None:
            for c in df.columns:
                if "Report_Date_as_YYYY-MM-DD" in str(c) or "As_of_Date_In_Form_YYMMDD" in str(c) or "Report_Date" in str(c):
                    date_col = c
                    break
        if date_col is None:
            for c in df.columns:
                if "date" in str(c).lower():
                    date_col = c
                    break
        if date_col is None:
            last_err = RuntimeError(f"no date col in {target}")
            continue
        df = df.rename(columns={date_col: "Report_Date_as_YYYY-MM-DD"})
        df["Report_Date_as_YYYY-MM-DD"] = pd.to_datetime(
            df["Report_Date_as_YYYY-MM-DD"], errors="coerce"
        )
        df.to_csv(cache, index=False)
        return df
    print(f"  failed year {year}: {last_err}", flush=True)
    return None


def build_positioning(market_names: List[str], market_contains: str, invert: bool = False) -> pd.DataFrame:
    """Return a weekly DataFrame with date, net_noncomm, oi, net_pct (percentile over trailing 52 weeks).
    If invert=True, the percentile is flipped (100 - pct) so that bucket labels refer to
    positioning in the spot instrument rather than the underlying futures contract."""
    print("CFTC: acquiring annual COT files...", flush=True)
    frames = []
    for year in range(START_YEAR - 2, END_YEAR + 1):  # extra history for percentile rolling
        df = fetch_cftc_year(year)
        if df is None:
            continue
        name_col = None
        for c in df.columns:
            if "Market_and_Exchange_Names" in str(c) or "Market_and_Exchange_Name" in str(c):
                name_col = c
                break
        if name_col is None:
            for c in df.columns:
                if "market" in str(c).lower() and "exchange" in str(c).lower():
                    name_col = c
                    break
        if name_col is None:
            print(f"  year {year}: no market name column; columns: {list(df.columns)[:8]}", flush=True)
            continue
        eur = df[df[name_col].astype(str).str.strip().str.upper().isin(
            [n.upper() for n in market_names]
        )]
        if eur.empty:
            eur = df[df[name_col].astype(str).str.upper().str.contains(market_contains.upper(), na=False)]
        if eur.empty:
            print(f"  year {year}: no {market_contains} rows found", flush=True)
            continue
        # Find positioning columns.
        long_col = None
        short_col = None
        oi_col = None
        for c in eur.columns:
            cs = str(c)
            if long_col is None and "NonComm" in cs and "Positions_Long" in cs and "All" in cs:
                long_col = c
            if short_col is None and "NonComm" in cs and "Positions_Short" in cs and "All" in cs:
                short_col = c
            if oi_col is None and "Open_Interest" in cs and "All" in cs:
                oi_col = c
        if not all([long_col, short_col, oi_col]):
            # fallback: try without "All"
            for c in eur.columns:
                cs = str(c)
                if long_col is None and "NonComm" in cs and "Long" in cs:
                    long_col = c
                if short_col is None and "NonComm" in cs and "Short" in cs:
                    short_col = c
                if oi_col is None and "Open_Interest" in cs:
                    oi_col = c
        if not all([long_col, short_col, oi_col]):
            print(f"  year {year}: missing pos columns; sample cols: {list(eur.columns)[:20]}", flush=True)
            continue
        sub = eur[["Report_Date_as_YYYY-MM-DD", long_col, short_col, oi_col]].copy()
        sub.columns = ["date", "noncomm_long", "noncomm_short", "oi"]
        sub["date"] = pd.to_datetime(sub["date"])
        for c in ("noncomm_long", "noncomm_short", "oi"):
            sub[c] = pd.to_numeric(sub[c], errors="coerce")
        frames.append(sub)
    if not frames:
        sys.exit("CFTC: no data acquired. Check network access and URL patterns.")
    all_df = pd.concat(frames, ignore_index=True).dropna(subset=["date"])
    all_df = all_df.sort_values("date").drop_duplicates(subset=["date"]).reset_index(drop=True)
    all_df["net_noncomm"] = all_df["noncomm_long"] - all_df["noncomm_short"]
    all_df["net_over_oi"] = all_df["net_noncomm"] / all_df["oi"].replace(0, np.nan)
    # Trailing 52-week percentile of net_over_oi.
    pct = []
    for i in range(len(all_df)):
        window_lo = max(0, i - 52 + 1)
        window = all_df["net_over_oi"].iloc[window_lo : i + 1]
        v = all_df["net_over_oi"].iloc[i]
        if np.isnan(v) or window.dropna().empty:
            pct.append(np.nan)
        else:
            pct.append(100.0 * (window <= v).sum() / window.dropna().shape[0])
    all_df["net_pct_52w"] = pct
    if invert:
        all_df["net_pct_52w"] = all_df["net_pct_52w"].apply(
            lambda v: 100.0 - v if pd.notna(v) else v
        )
    return all_df


def positioning_at_event(cot: pd.DataFrame, event_dt: datetime) -> Tuple[Optional[float], Optional[str]]:
    """Most recent COT report strictly before the event."""
    mask = cot["date"] < pd.Timestamp(event_dt.date())
    sub = cot[mask]
    if sub.empty:
        return None, None
    row = sub.iloc[-1]
    pct = row["net_pct_52w"]
    if np.isnan(pct):
        return None, None
    if pct >= CROWDED_LONG_PCT:
        bucket = "CROWDED_LONG"
    elif pct <= CROWDED_SHORT_PCT:
        bucket = "CROWDED_SHORT"
    else:
        bucket = "NEUTRAL"
    return float(pct), bucket


# ---------------------------------------------------------------------------
# Main screen
# ---------------------------------------------------------------------------

def run_screen(instrument_key: str = "eurusd") -> None:
    cfg = INSTRUMENTS[instrument_key]
    label = cfg["label"]
    print(f"=== INSTRUMENT: {label} ===\n", flush=True)
    print(f"Loading {label} H4 (mid)...", flush=True)
    px = load_h4_mid(cfg["ask_csv"], cfg["bid_csv"])
    px = add_atr(px, ATR_PERIOD)
    print(f"  rows: {len(px)}, range: {px['Time (UTC)'].iloc[0]} -> {px['Time (UTC)'].iloc[-1]}", flush=True)

    print(f"Building {label} positioning percentile series...", flush=True)
    cot = build_positioning(
        market_names=cfg["cftc_market_names"],
        market_contains=cfg["cftc_market_contains"],
        invert=cfg["invert_positioning"],
    )
    print(f"  weeks: {len(cot)}, range: {cot['date'].iloc[0].date()} -> {cot['date'].iloc[-1].date()}", flush=True)
    if cfg["invert_positioning"]:
        print(f"  (positioning percentile inverted: bucket labels refer to {label} spot)", flush=True)

    # Assemble events.
    events = (
        [("FOMC", d) for d in FOMC_DATES]
        + [("NFP", d) for d in NFP_DATES]
        + [("CPI", d) for d in CPI_DATES]
    )
    events.sort(key=lambda x: x[1])

    rows = []
    for ev_type, ev_date in events:
        ev_dt = event_datetime_utc(ev_date, ev_type)
        if ev_dt.year < START_YEAR or ev_dt.year > END_YEAR:
            continue
        # Skip future events past available data.
        if pd.Timestamp(ev_dt) > px["Time (UTC)"].iloc[-1]:
            continue
        idx0 = bar_at_or_after(px, ev_dt)
        if idx0 is None or idx0 + 1 >= len(px):
            continue
        bar0 = px.iloc[idx0]
        bar1 = px.iloc[idx0 + 1]
        atr0 = bar0["ATR"]
        if np.isnan(atr0) or atr0 <= 0:
            continue
        # Bar 0 metrics.
        bar0_range = bar0["High"] - bar0["Low"]
        bar0_dir = np.sign(bar0["Close"] - bar0["Open"])
        # Combined 8h window (bar 0 + bar 1).
        combined_high = max(bar0["High"], bar1["High"])
        combined_low = min(bar0["Low"], bar1["Low"])
        combined_range = combined_high - combined_low
        combined_close_open = bar1["Close"] - bar0["Open"]
        combined_dir = np.sign(combined_close_open)

        pct, bucket = positioning_at_event(cot, ev_dt)
        if bucket is None:
            continue

        rows.append({
            "date": ev_date,
            "event": ev_type,
            "event_utc": ev_dt.isoformat(),
            "pos_pct_52w": round(pct, 1),
            "bucket": bucket,
            "bar0_range_atr": round(bar0_range / atr0, 3),
            "bar0_dir": int(bar0_dir),
            "combined_range_atr": round(combined_range / atr0, 3),
            "combined_dir": int(combined_dir),
            "combined_signed_atr": round(combined_close_open / atr0, 3),
        })

    df = pd.DataFrame(rows)
    out_csv = os.path.join(DATA_DIR, f"viability_screen_events_{label.lower()}.csv")
    df.to_csv(out_csv, index=False)
    print(f"\nWrote per-event table: {out_csv}  ({len(df)} events)\n", flush=True)

    # Summary by bucket.
    def summarize(group: pd.DataFrame) -> dict:
        n = len(group)
        med_bar0 = group["bar0_range_atr"].median()
        med_comb = group["combined_range_atr"].median()
        pct_gt15 = (group["combined_range_atr"] >= 1.5).mean() * 100
        pct_gt20 = (group["combined_range_atr"] >= 2.0).mean() * 100
        return {
            "n": n,
            "med_bar0_range_atr": round(med_bar0, 2),
            "med_combined_range_atr": round(med_comb, 2),
            "pct_combined_ge_1.5_atr": round(pct_gt15, 1),
            "pct_combined_ge_2.0_atr": round(pct_gt20, 1),
        }

    print("=== SUMMARY: ALL EVENTS ===")
    overall = pd.DataFrame([summarize(df)])
    print(overall.to_string(index=False))
    print()

    print("=== SUMMARY BY POSITIONING BUCKET ===")
    bucket_rows = []
    for b in ["CROWDED_LONG", "NEUTRAL", "CROWDED_SHORT"]:
        sub = df[df["bucket"] == b]
        if sub.empty:
            continue
        row = {"bucket": b, **summarize(sub)}
        # "Against the crowd": negative combined_dir when crowded long, positive when crowded short.
        if b == "CROWDED_LONG":
            against = (sub["combined_dir"] < 0).mean() * 100
        elif b == "CROWDED_SHORT":
            against = (sub["combined_dir"] > 0).mean() * 100
        else:
            against = np.nan
        row["pct_against_crowd"] = round(against, 1) if not np.isnan(against) else None
        bucket_rows.append(row)
    print(pd.DataFrame(bucket_rows).to_string(index=False))
    print()

    print("=== SUMMARY BY EVENT × BUCKET ===")
    event_bucket_rows = []
    for ev in ["FOMC", "NFP", "CPI"]:
        for b in ["CROWDED_LONG", "NEUTRAL", "CROWDED_SHORT"]:
            sub = df[(df["event"] == ev) & (df["bucket"] == b)]
            if sub.empty:
                continue
            row = {"event": ev, "bucket": b, **summarize(sub)}
            if b == "CROWDED_LONG":
                against = (sub["combined_dir"] < 0).mean() * 100
            elif b == "CROWDED_SHORT":
                against = (sub["combined_dir"] > 0).mean() * 100
            else:
                against = np.nan
            row["pct_against_crowd"] = round(against, 1) if not np.isnan(against) else None
            event_bucket_rows.append(row)
    print(pd.DataFrame(event_bucket_rows).to_string(index=False))
    print()

    print("=== READ KEY ===")
    print("If CROWDED buckets show higher median combined_range_atr vs NEUTRAL,")
    print("AND pct_against_crowd > 50% in crowded buckets,")
    print("the positioning/event velocity premise has signs of life.")
    print()
    print("If neither pattern shows, thesis is probably dead and consensus data")
    print("is not worth paying for.")
    print()
    print("REMINDER: H4 data is a DEGRADED proxy. Negative results are suggestive,")
    print("not conclusive. Positive results justify chasing finer data.")


if __name__ == "__main__":
    instrument = sys.argv[1].lower() if len(sys.argv) > 1 else "eurusd"
    if instrument not in INSTRUMENTS:
        sys.exit(f"Unknown instrument {instrument}. Valid: {list(INSTRUMENTS.keys())}")
    run_screen(instrument)
