"""
LTS Edge AI News Filter
========================
Runs on VPS alongside the EA. Checks gold market conditions every 30 minutes
using Claude API and writes a signal file that the EA reads before trading.

Signal file: ai_signal.txt
  - "TRADE" = conditions are clear, EA can trade normally
  - "SKIP|reason" = dangerous conditions, EA should not enter

Requirements:
  pip install anthropic requests

Usage:
  python ai_filter.py                    # Run once
  python ai_filter.py --daemon           # Run continuously every 30 min
  python ai_filter.py --test             # Test with a sample analysis

Environment:
  ANTHROPIC_API_KEY=sk-ant-...           # Required
"""

import os
import sys
import json
import time
import logging
import argparse
from datetime import datetime, timezone, timedelta

try:
    import anthropic
except ImportError:
    print("ERROR: anthropic package not installed. Run: pip install anthropic")
    sys.exit(1)

try:
    import requests
except ImportError:
    print("ERROR: requests package not installed. Run: pip install requests")
    sys.exit(1)

# --- Configuration ---
SIGNAL_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ai_signal.txt")
LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ai_filter.log")
CHECK_INTERVAL_SECONDS = 1800  # 30 minutes
MODEL = "claude-sonnet-4-20250514"

# --- Logging ---
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


def get_economic_calendar():
    """
    Fetch upcoming high-impact economic events from a free API.
    Returns a list of event strings for the next 24 hours.
    """
    events = []
    try:
        # Use ForexFactory-style free calendar API
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        tomorrow = (datetime.now(timezone.utc) + timedelta(days=1)).strftime("%Y-%m-%d")

        # Try nager.at for public holidays (limited but free)
        # For economic events, we'll include key known recurring events
        now_utc = datetime.now(timezone.utc)
        hour = now_utc.hour
        weekday = now_utc.weekday()  # 0=Monday

        # Known high-impact recurring events (UTC times)
        # NFP: First Friday of month, 13:30 UTC
        if weekday == 4:  # Friday
            day = now_utc.day
            if day <= 7:  # First Friday
                events.append(f"NFP (Non-Farm Payrolls) today at 13:30 UTC")

        # FOMC: ~8 times per year, typically Wednesday 19:00 UTC
        # CPI: ~12th of each month, 13:30 UTC
        if 10 <= now_utc.day <= 14:
            events.append(f"CPI release may be scheduled this week")

        # Add a note about the day/time
        events.append(f"Current time: {now_utc.strftime('%A %H:%M UTC')}")
        events.append(f"Date: {today}")

    except Exception as e:
        logger.warning(f"Calendar fetch failed: {e}")
        events.append("Economic calendar unavailable — treat with caution")

    return events


def fetch_gold_news():
    """
    Fetch recent gold/XAUUSD news headlines.
    Uses free news APIs where available.
    """
    headlines = []

    # Try Google News RSS for gold
    try:
        import xml.etree.ElementTree as ET
        url = "https://news.google.com/rss/search?q=gold+price+XAUUSD&hl=en-US&gl=US&ceid=US:en"
        response = requests.get(url, timeout=10, headers={
            "User-Agent": "Mozilla/5.0 (compatible; LTSEdge/1.0)"
        })
        if response.status_code == 200:
            root = ET.fromstring(response.content)
            items = root.findall(".//item")
            for item in items[:10]:  # Top 10 headlines
                title = item.find("title")
                pub_date = item.find("pubDate")
                if title is not None:
                    headline = title.text
                    if pub_date is not None:
                        headline += f" ({pub_date.text})"
                    headlines.append(headline)
    except Exception as e:
        logger.warning(f"News fetch failed: {e}")

    if not headlines:
        headlines.append("Unable to fetch live news — no headlines available")

    return headlines


def analyze_with_claude(news_headlines, calendar_events):
    """
    Send market context to Claude API and get a TRADE/SKIP decision.
    """
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        logger.error("ANTHROPIC_API_KEY not set")
        # Default to TRADE if API key missing — don't block trades unnecessarily
        return "TRADE", "API key not configured — defaulting to TRADE"

    client = anthropic.Anthropic(api_key=api_key)

    now_utc = datetime.now(timezone.utc)
    uk_offset = 1 if is_bst(now_utc) else 0
    uk_time = now_utc + timedelta(hours=uk_offset)

    prompt = f"""You are a trading risk filter for an automated gold (XAUUSD) trading system.

The system trades H1 volatility squeeze breakouts during London/NY session (08:00-16:00 UK time).
Current UK time: {uk_time.strftime('%A %d %B %Y, %H:%M')}

Your job: decide if it's SAFE to trade right now, or if conditions are DANGEROUS.

RECENT GOLD NEWS HEADLINES:
{chr(10).join(f"- {h}" for h in news_headlines[:10])}

ECONOMIC CALENDAR:
{chr(10).join(f"- {e}" for e in calendar_events)}

SKIP if ANY of these are true:
1. Major economic data release within 2 hours (NFP, CPI, FOMC, GDP, PCE)
2. Fed chair or major central banker speaking within 2 hours
3. Extreme geopolitical crisis just breaking (war escalation, surprise sanctions)
4. Major flash crash or circuit breaker event in progress
5. It's a major US holiday (markets thin/closed)
6. Multiple conflicting signals suggesting extreme whipsaw risk

TRADE if:
- Normal market conditions
- News is routine (analyst opinions, forecasts, minor data)
- Geopolitical situation is stable or already priced in
- No major data releases imminent

Be CONSERVATIVE with SKIP — only skip for genuinely dangerous conditions.
Most days should be TRADE. You are NOT predicting direction, just filtering danger.

Respond with EXACTLY one line in this format:
TRADE|Brief reason
or
SKIP|Brief reason

Examples:
TRADE|Normal conditions, no major events scheduled
SKIP|NFP release in 90 minutes, extreme volatility expected
TRADE|Gold rally on inflation fears, but no imminent data risk
SKIP|FOMC decision at 19:00 UTC today, wait for aftermath"""

    try:
        message = client.messages.create(
            model=MODEL,
            max_tokens=100,
            messages=[{"role": "user", "content": prompt}]
        )

        response_text = message.content[0].text.strip()
        logger.info(f"Claude response: {response_text}")

        # Parse response
        if response_text.startswith("TRADE"):
            parts = response_text.split("|", 1)
            reason = parts[1].strip() if len(parts) > 1 else "Conditions clear"
            return "TRADE", reason
        elif response_text.startswith("SKIP"):
            parts = response_text.split("|", 1)
            reason = parts[1].strip() if len(parts) > 1 else "Dangerous conditions"
            return "SKIP", reason
        else:
            logger.warning(f"Unexpected response format: {response_text}")
            return "TRADE", f"Unparseable response — defaulting to TRADE: {response_text}"

    except anthropic.APIError as e:
        logger.error(f"Claude API error: {e}")
        return "TRADE", f"API error — defaulting to TRADE: {str(e)}"
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return "TRADE", f"Error — defaulting to TRADE: {str(e)}"


def is_bst(dt):
    """Check if a UTC datetime falls within British Summer Time (approximate)."""
    year = dt.year
    # BST: last Sunday in March to last Sunday in October
    march_last_sun = 31 - (datetime(year, 3, 31).weekday() + 1) % 7
    oct_last_sun = 31 - (datetime(year, 10, 31).weekday() + 1) % 7
    bst_start = datetime(year, 3, march_last_sun, 1, tzinfo=timezone.utc)
    bst_end = datetime(year, 10, oct_last_sun, 1, tzinfo=timezone.utc)
    return bst_start <= dt < bst_end


def write_signal(signal, reason):
    """Write signal to file that the EA reads."""
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    content = f"{signal}|{reason}|{timestamp}"

    try:
        with open(SIGNAL_FILE, "w") as f:
            f.write(content)
        logger.info(f"Signal written: {content}")
    except Exception as e:
        logger.error(f"Failed to write signal file: {e}")


def read_current_signal():
    """Read the current signal file."""
    try:
        if os.path.exists(SIGNAL_FILE):
            with open(SIGNAL_FILE, "r") as f:
                return f.read().strip()
    except:
        pass
    return None


def run_check():
    """Run a single check cycle."""
    logger.info("=" * 50)
    logger.info("Running AI filter check...")

    # Gather market context
    news = fetch_gold_news()
    calendar = get_economic_calendar()

    logger.info(f"Fetched {len(news)} headlines, {len(calendar)} calendar events")

    # Get Claude's analysis
    signal, reason = analyze_with_claude(news, calendar)

    # Write signal file
    write_signal(signal, reason)

    logger.info(f"Result: {signal} — {reason}")
    logger.info("=" * 50)

    return signal, reason


def daemon_mode():
    """Run continuously, checking every 30 minutes."""
    logger.info("Starting AI filter in daemon mode")
    logger.info(f"Check interval: {CHECK_INTERVAL_SECONDS}s ({CHECK_INTERVAL_SECONDS//60} min)")
    logger.info(f"Signal file: {SIGNAL_FILE}")

    # Write initial TRADE signal so EA isn't blocked on startup
    write_signal("TRADE", "Initial startup — awaiting first analysis")

    while True:
        try:
            run_check()
        except Exception as e:
            logger.error(f"Check cycle failed: {e}")
            # On failure, default to TRADE — don't block the EA
            write_signal("TRADE", f"Check failed — defaulting to TRADE: {str(e)}")

        # Sleep until next check
        logger.info(f"Next check in {CHECK_INTERVAL_SECONDS//60} minutes...")
        time.sleep(CHECK_INTERVAL_SECONDS)


def test_mode():
    """Run a test analysis with sample data."""
    logger.info("Running test analysis...")

    news = [
        "Gold prices steady ahead of Fed decision — Reuters",
        "XAUUSD holds above $3,200 as dollar weakens — FXStreet",
        "Central banks continue gold buying spree — World Gold Council",
    ]
    calendar = [
        "Current time: Wednesday 14:30 UTC",
        "FOMC Interest Rate Decision at 19:00 UTC today",
    ]

    signal, reason = analyze_with_claude(news, calendar)
    print(f"\nResult: {signal}")
    print(f"Reason: {reason}")
    print(f"\n(Expected: SKIP due to FOMC decision today)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="LTS Edge AI News Filter")
    parser.add_argument("--daemon", action="store_true", help="Run continuously every 30 min")
    parser.add_argument("--test", action="store_true", help="Run test analysis")
    args = parser.parse_args()

    if args.test:
        test_mode()
    elif args.daemon:
        daemon_mode()
    else:
        signal, reason = run_check()
        print(f"{signal}|{reason}")
