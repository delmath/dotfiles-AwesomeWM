#!/usr/bin/env python3
"""Data source for the LuminaHUD blocks: hud.py <field>.

Every network result is cached in ~/.cache/LuminaHUD, so the many blocks reading
the same API only trigger one request per period.

  time date moon moon_light
  weather_now weather_desc weather_detail weather_sun
  weather_forecast weather_day1 weather_day2 weather_day3           (Open-Meteo)
  cpu ram disk cpu_line ram_line disk_line
  iss iss_detail launch launch_in                   (wheretheiss.at, thespacedevs.com)
  btc eth                                           (CoinGecko)
  ft_seat ft_level ft_level_pct ft_stats ft_logtime ft_project ft_event   (API 42)

The API 42 needs an application: https://profile.intra.42.fr/oauth/applications/new
(any redirect URI, no scope); put its UID and SECRET in ~/.config/LuminaHUD/42.env
"""

import fcntl
import math
import os
import sys
import time
from datetime import date, datetime, timedelta, timezone

# json, socket and urllib are imported where they are used: they triple the start-up time,
# and most calls (clock, CPU, cached results) are started every few seconds

# Lyon
LATITUDE = 45.76
LONGITUDE = 4.84

HOME = os.path.expanduser("~")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")), "LuminaHUD")
ENV_FILE = os.path.join(HOME, ".config", "LuminaHUD", "42.env")
API_42 = "https://api.intra.42.fr"

DAYS = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
SHORT_DAYS = ["lun.", "mar.", "mer.", "jeu.", "ven.", "sam.", "dim."]
MONTHS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août",
          "septembre", "octobre", "novembre", "décembre"]


def age(path):
    try:
        return time.time() - os.path.getmtime(path)
    except OSError:
        return float("inf")


def cached(name, ttl, produce):
    """Returns the content of the cache file, refreshed with produce() when it is due.

    A failed refresh keeps the previous content and is retried after 60 s."""
    path = os.path.join(CACHE, name)
    stamp = path + ".stamp"
    with open(path + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if age(stamp) >= (ttl if os.path.exists(path) else 60):
            open(stamp, "w").close()
            try:
                content = produce()
                with open(path + ".tmp", "w") as tmp:
                    tmp.write(content)
                os.replace(path + ".tmp", path)
            except Exception:
                pass
    try:
        with open(path) as file:
            return file.read()
    except OSError:
        return None


def http(url, headers=None, data=None):
    import urllib.request
    request = urllib.request.Request(url, data=data, headers={"User-Agent": "LuminaHUD", **(headers or {})})
    with urllib.request.urlopen(request, timeout=8) as response:
        return response.read().decode()


def fetch_json(name, ttl, url, headers=None):
    import json
    content = cached(name, ttl, lambda: http(url, headers))
    try:
        return json.loads(content) if content else None
    except ValueError:
        return None


def shorten(text, width):
    return text if len(text) <= width else text[:width - 1] + "…"


def duration(seconds):
    return "%dh%02d" % (seconds // 3600, seconds % 3600 // 60)


# --- clock ---------------------------------------------------------------

def moon():
    # Days since the new moon of 2000-01-06 18:14 UTC, modulo the synodic month
    period = 29.530588853
    moon_age = (time.time() - 947182440) / 86400 % period
    light = (1 - math.cos(2 * math.pi * moon_age / period)) / 2 * 100
    names = ["Nouvelle lune", "Premier croissant", "Premier quartier", "Gibbeuse croissante",
             "Pleine lune", "Gibbeuse décroissante", "Dernier quartier", "Dernier croissant"]
    return names[int(moon_age / period * 8 + 0.5) % 8], light, moon_age


def clock(field):
    now = datetime.now()
    if field == "time":
        return now.strftime("%H:%M")
    if field == "date":
        return "%s %d %s" % (DAYS[now.weekday()], now.day, MONTHS[now.month - 1])
    name, light, moon_age = moon()
    if field == "moon":
        return name
    return "éclairée à %d%% · jour %d" % (round(light), moon_age + 1)


# --- weather -------------------------------------------------------------

def weather_icon(code, day=True):
    if code == 0:
        return "" if day else ""
    if code <= 2:
        return "" if day else ""
    if code == 3:
        return ""
    if code <= 48:
        return ""
    if code <= 57:
        return ""
    if code <= 67 or 80 <= code <= 82:
        return ""
    if code <= 86:
        return ""
    return ""


def weather_label(code):
    for limit, label in [(0, "Ciel dégagé"), (2, "Peu nuageux"), (3, "Couvert"), (48, "Brouillard"),
                         (57, "Bruine"), (67, "Pluie"), (77, "Neige"), (82, "Averses"),
                         (86, "Averses de neige")]:
        if code <= limit:
            return label
    return "Orage"


def weather(field):
    data = fetch_json("weather.json", 600,
        "https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s"
        "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,is_day"
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max"
        "&timezone=auto&forecast_days=4" % (LATITUDE, LONGITUDE))
    if not data:
        return "météo indisponible" if field == "weather_now" else ""

    now, daily = data["current"], data["daily"]
    if field == "weather_now":
        return "%s  %d°" % (weather_icon(now["weather_code"], now["is_day"] == 1), round(now["temperature_2m"]))
    if field == "weather_desc":
        return "%s · ressenti %d°" % (weather_label(now["weather_code"]), round(now["apparent_temperature"]))
    if field == "weather_detail":
        return "  %d km/h     %d%%" % (round(now["wind_speed_10m"]), now["relative_humidity_2m"])
    if field == "weather_sun":
        return "  %s     %s" % (daily["sunrise"][0][11:16], daily["sunset"][0][11:16])

    lines = []
    for i in range(1, 4):
        lines.append("%s  %s  %2d° / %2d°     %3d%%" % (
            SHORT_DAYS[date.fromisoformat(daily["time"][i]).weekday()],
            weather_icon(daily["weather_code"][i]),
            round(daily["temperature_2m_min"][i]), round(daily["temperature_2m_max"][i]),
            daily["precipitation_probability_max"][i] or 0))
    if field.startswith("weather_day"):
        return lines[int(field[-1]) - 1]
    return "\n".join(lines)


# --- system --------------------------------------------------------------

def cpu():
    def sample():
        with open("/proc/stat") as stat:
            values = [int(v) for v in stat.readline().split()[1:9]]
        user, nice, system, idle, iowait, irq, softirq, steal = values
        busy = user + nice + system + irq + softirq + steal
        total = busy + idle + iowait

        # Usage since the previous sample
        percent = 0
        try:
            with open(os.path.join(CACHE, "cpu")) as previous:
                last_busy, last_total, _ = [int(v) for v in previous.read().split()]
            if total > last_total:
                percent = (busy - last_busy) * 100 // (total - last_total)
        except (OSError, ValueError):
            pass
        return "%d %d %d" % (busy, total, percent)

    return int((cached("cpu", 2, sample) or "0 0 0").split()[2])


def ram():
    values = {}
    with open("/proc/meminfo") as meminfo:
        for line in meminfo:
            key, value = line.split(":")
            values[key] = int(value.split()[0])
    return (values["MemTotal"] - values["MemAvailable"]) * 100 // values["MemTotal"]


def disk():
    stats = os.statvfs(HOME)
    return (stats.f_blocks - stats.f_bavail) * 100 // stats.f_blocks


def system(field):
    name, _, line = field.partition("_")
    value = {"cpu": cpu, "ram": ram, "disk": disk}[name]()
    if not line:
        return str(value)
    return "%-4s %3d%%" % ({"disk": "HOME"}.get(name, name.upper()), value)


# --- space ---------------------------------------------------------------

def space(field):
    if field.startswith("iss"):
        data = fetch_json("iss.json", 30, "https://api.wheretheiss.at/v1/satellites/25544")
        if not data:
            return ""
        if field == "iss":
            latitude, longitude = data["latitude"], data["longitude"]
            return "  ISS  %.1f°%s  %.1f°%s" % (abs(latitude), "N" if latitude >= 0 else "S",
                                                   abs(longitude), "E" if longitude >= 0 else "O")
        return "%d km · %d km/h · %s" % (round(data["altitude"]), round(data["velocity"]),
                                         "côté jour" if data["visibility"] == "daylight" else "côté nuit")

    data = fetch_json("launch.json", 1800, "https://ll.thespacedevs.com/2.2.0/launch/upcoming/?limit=5&mode=list")
    now = datetime.now(timezone.utc)
    for launch in (data or {}).get("results", []):
        left = (datetime.fromisoformat(launch["net"].replace("Z", "+00:00")) - now).total_seconds()
        if left <= 0:
            continue
        if field == "launch":
            return "  " + shorten(launch["name"], 34)
        if left >= 172800:
            return "décollage dans %d jours" % (left // 86400)
        if left >= 3600:
            return "décollage dans " + duration(int(left))
        return "décollage dans %d min" % (left // 60)
    return ""


# --- crypto --------------------------------------------------------------

def crypto(field):
    data = fetch_json("crypto.json", 300,
        "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=eur&include_24hr_change=true")
    coin = (data or {}).get("bitcoin" if field == "btc" else "ethereum")
    if not coin:
        return ""
    change = coin.get("eur_24h_change") or 0
    return "%s %7s €  %s %.1f%%" % (field.upper(), format(round(coin["eur"]), ",").replace(",", " "),
                                    "▲" if change >= 0 else "▼", abs(change))


# --- 42 ------------------------------------------------------------------

def ft_credentials():
    values = {}
    try:
        with open(ENV_FILE) as env:
            for line in env:
                key, separator, value = line.strip().partition("=")
                if separator and not key.startswith("#"):
                    values[key.strip()] = value.strip().strip("\"'")
    except OSError:
        pass
    return values


def ft_get(name, ttl, path, credentials):
    import json

    def token():
        import urllib.parse
        body = urllib.parse.urlencode({"grant_type": "client_credentials",
                                       "client_id": credentials["FT_UID"],
                                       "client_secret": credentials["FT_SECRET"]}).encode()
        return json.loads(http(API_42 + "/oauth/token", data=body))["access_token"]

    def produce():
        access_token = cached("42_token", 6600, token)
        if not access_token:
            raise RuntimeError("no token")
        return http(API_42 + path, {"Authorization": "Bearer " + access_token})

    content = cached(name, ttl, produce)
    try:
        return json.loads(content) if content else None
    except ValueError:
        return None


def ft(field):
    if field == "ft_seat":
        import socket
        return socket.gethostname().split(".")[0]

    def unavailable(message):
        return {"ft_level": message, "ft_level_pct": "0"}.get(field, "")

    credentials = ft_credentials()
    if not credentials.get("FT_UID") or not credentials.get("FT_SECRET"):
        return unavailable("clés API à mettre dans 42.env")

    login = credentials.get("FT_LOGIN") or os.environ.get("USER", "")
    user = ft_get("42_user.json", 300, "/v2/users/" + login, credentials)
    if not user:
        return unavailable("API 42 injoignable")

    if field in ("ft_level", "ft_level_pct"):
        cursus = [c for c in user["cursus_users"] if c["cursus_id"] == 21] or user["cursus_users"][-1:]
        level = cursus[0]["level"] if cursus else 0.0
        if field == "ft_level":
            return "niveau %.2f" % (math.floor(level * 100) / 100)
        return str(int(level % 1 * 100))
    if field == "ft_stats":
        return "wallet %s · éval %s pts" % (user["wallet"], user["correction_point"])
    if field == "ft_project":
        names = [p["project"]["name"] for p in user["projects_users"] if p["status"] == "in_progress"]
        return "  " + shorten(", ".join(names[:2]), 26) if names else "aucun projet en cours"
    if field == "ft_logtime":
        monday = date.today() - timedelta(days=date.today().weekday())
        stats = ft_get("42_logtime.json", 300,
                       "/v2/users/%s/locations_stats?begin_at=%s" % (login, monday.isoformat()), credentials)
        if stats is None:
            return ""

        def seconds(value):
            hours, minutes, rest = value.split(":")
            return int(hours) * 3600 + int(minutes) * 60 + int(float(rest))

        return "logtime %s · sem. %s" % (duration(seconds(stats.get(date.today().isoformat(), "0:0:0"))),
                                          duration(sum(seconds(v) for v in stats.values())))
    if field == "ft_event":
        if not user.get("campus"):
            return ""
        events = ft_get("42_events.json", 1800,
                        "/v2/campus/%s/events?filter[future]=true&sort=begin_at&page[size]=1" % user["campus"][0]["id"],
                        credentials)
        if not events:
            return ""
        begin = datetime.fromisoformat(events[0]["begin_at"].replace("Z", "+00:00")).astimezone()
        return "  %s · %s" % (shorten(events[0]["name"], 20), begin.strftime("%d/%m %Hh"))
    return ""


def main():
    field = sys.argv[1] if len(sys.argv) > 1 else ""
    os.makedirs(CACHE, exist_ok=True)
    os.umask(0o077)

    if field in ("time", "date", "moon", "moon_light"):
        output = clock(field)
    elif field.startswith("weather_"):
        output = weather(field)
    elif field.split("_")[0] in ("cpu", "ram", "disk"):
        output = system(field)
    elif field in ("iss", "iss_detail", "launch", "launch_in"):
        output = space(field)
    elif field in ("btc", "eth"):
        output = crypto(field)
    elif field.startswith("ft_"):
        output = ft(field)
    else:
        sys.exit(__doc__)
    print(output)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # A block shows nothing rather than a traceback
        pass
