#!/usr/bin/env python3
"""Polls the Presseportal police RSS feeds and sends a OneSignal push for new
articles. Designed to run in GitHub Actions on a schedule.

State (already-seen GUIDs per city) is persisted between runs via the Actions
cache. The OneSignal credentials are read from the environment:

    ONESIGNAL_APP_ID         OneSignal app id (also embedded in the iOS app)
    ONESIGNAL_REST_API_KEY   OneSignal REST API key (keep secret!)
    ONESIGNAL_AUTH_SCHEME    "Basic" (default) or "Key" for newer keys

If the credentials are missing the script does a DRY RUN: it fetches and logs
new items but sends nothing. The very first run with state seeds the cache and
sends nothing, so existing articles are not blasted out as notifications.
"""

import json
import os
import re
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime

# Keep in sync with StadtNews/Models/City.swift (id -> display name).
CITIES = {
    "51056": "Gelsenkirchen",
}

FEED_URL = "https://www.presseportal.de/rss/dienststelle_{}.rss2"
ONESIGNAL_API = "https://onesignal.com/api/v1/notifications"
USER_AGENT = "Gelsenkirchen.news-push/1.0 (+https://github.com/koljasagorski/stadt.news)"
STATE_FILE = os.environ.get("STATE_FILE", "state/seen.json")

MAX_PER_CITY = 5                      # never send more than this per city per run
MAX_SEEN_PER_CITY = 300               # cap stored guids per city
FRESH_WINDOW = timedelta(hours=24)    # don't notify about items older than this
PRESS_CODE = re.compile(r"^[A-ZÄÖÜ0-9]{2,}(?:[ \-][A-ZÄÖÜ0-9]+)*:\s*")


def log(*args):
    print(*args, flush=True)


def clean_title(title: str) -> str:
    """Drop a leading "POL-XX:" press code, mirroring the iOS app."""
    return PRESS_CODE.sub("", title).strip() or title


def fetch_feed(city_id: str) -> list[dict]:
    request = urllib.request.Request(
        FEED_URL.format(city_id),
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/rss+xml, application/xml;q=0.9",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        data = response.read()

    root = ET.fromstring(data)
    items = []
    for item in root.iter("item"):
        def text(tag: str) -> str:
            el = item.find(tag)
            return el.text.strip() if el is not None and el.text else ""

        guid = text("guid") or text("link")
        if not guid:
            continue
        published = None
        raw_date = text("pubDate")
        if raw_date:
            try:
                published = parsedate_to_datetime(raw_date)
                if published.tzinfo is None:
                    published = published.replace(tzinfo=timezone.utc)
            except (TypeError, ValueError):
                published = None
        items.append({
            "guid": guid,
            "title": text("title"),
            "link": text("link") or guid,
            "published": published,
        })
    return items


def load_state() -> dict:
    try:
        with open(STATE_FILE, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}
    except (OSError, ValueError) as error:
        log("WARN: konnte State nicht lesen:", error)
        return {}


def save_state(state: dict) -> None:
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False)


def send_push(app_id: str, api_key: str, scheme: str,
              city_id: str, city_name: str, item: dict) -> bool:
    payload = {
        "app_id": app_id,
        "headings": {"en": city_name, "de": city_name},
        "contents": {"en": clean_title(item["title"]), "de": clean_title(item["title"])},
        "filters": [
            {"field": "tag", "key": f"city_{city_id}", "relation": "=", "value": "1"},
        ],
        "url": item["link"],
        "data": {"city_id": city_id, "article_url": item["link"]},
    }
    request = urllib.request.Request(
        ONESIGNAL_API,
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
    )
    request.add_header("Content-Type", "application/json; charset=utf-8")
    request.add_header("Authorization", f"{scheme} {api_key}")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            result = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        log("  HTTP-Fehler beim Senden:", error.code,
            error.read().decode("utf-8", "ignore"))
        return False
    except (urllib.error.URLError, ValueError) as error:
        log("  Fehler beim Senden:", error)
        return False

    errors = result.get("errors")
    if errors:
        # "All included players are not subscribed" simply means nobody follows
        # this city yet – not a real failure.
        log("  OneSignal:", errors)
        return False
    log("  gesendet:", result.get("id", "?"),
        "Empfänger:", result.get("recipients", "?"))
    return True


def main() -> None:
    app_id = os.environ.get("ONESIGNAL_APP_ID", "").strip()
    api_key = os.environ.get("ONESIGNAL_REST_API_KEY", "").strip()
    scheme = os.environ.get("ONESIGNAL_AUTH_SCHEME", "Basic").strip() or "Basic"
    dry_run = not (app_id and api_key)
    if dry_run:
        log("DRY RUN: ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY fehlen – "
            "es wird nichts gesendet.")

    state = load_state()
    first_run = len(state) == 0
    now = datetime.now(timezone.utc)
    total_sent = 0

    for city_id, city_name in CITIES.items():
        try:
            items = fetch_feed(city_id)
        except Exception as error:  # noqa: BLE001 - keep other cities going
            log(f"[{city_name}] Feed-Fehler:", error)
            continue

        seen = set(state.get(city_id, []))
        new_items = [it for it in items if it["guid"] not in seen]
        new_items.sort(
            key=lambda it: it["published"] or datetime.min.replace(tzinfo=timezone.utc),
            reverse=True,
        )
        log(f"[{city_name}] {len(items)} Einträge, {len(new_items)} neu")

        if not first_run and not dry_run:
            sent = 0
            for item in new_items:
                if sent >= MAX_PER_CITY:
                    break
                published = item["published"]
                if published and (now - published) > FRESH_WINDOW:
                    continue  # zu alt – nicht pushen
                if send_push(app_id, api_key, scheme, city_id, city_name, item):
                    sent += 1
                    total_sent += 1

        current = [it["guid"] for it in items]
        kept = [g for g in state.get(city_id, []) if g not in set(current)]
        state[city_id] = (current + kept)[:MAX_SEEN_PER_CITY]

    save_state(state)
    if first_run:
        log("Erster Lauf – Stand gespeichert, keine Mitteilungen gesendet.")
    log(f"Fertig. Gesendete Mitteilungen: {total_sent}")


if __name__ == "__main__":
    main()
