import json, re, subprocess, sys, urllib.request

UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

def get(url, headers=None):
    req = urllib.request.Request(url, headers={"User-Agent": UA, **(headers or {})})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8", "replace")

def note(title, msg):
    msg = msg.replace("%", "%25").replace("\r", " ").replace("\n", " ")
    print(f"::notice title={title}::{msg[:3500]}")

data = json.loads(get("https://www.pornhub.com/webmasters/search?page=1&ordering=mostviewed"))
vid = data["videos"][0]["video_id"]
note("viewkey", vid)
html = get(f"https://www.pornhub.com/embed/{vid}", {"Cookie": "accessAgeDisclaimerPH=1; accessAgeDisclaimerUK=1; platform=mobile"})
note("embed_len", str(len(html)))
hosts = sorted(set(re.findall(r"https?:\\?/\\?/([a-zA-Z0-9.-]+)", html)))
note("hosts", " ".join(hosts))
for kw in ["preroll", "adRoll", "prerollGlobalConfig", "adRollGlobalConfig", "mediaDefinitions", "pauseroll", "postroll", "isVertical", "hls"]:
    for m in list(re.finditer(kw, html))[:2]:
        s = max(0, m.start() - 60)
        note("ctx_" + kw, html[s:m.start() + 260])
m = re.search(r"var flashvars_\d+ = (\{.*?\});\s*var", html, re.S)
note("flashvars_found", str(bool(m)))
if m:
    try:
        fv = json.loads(m.group(1))
        note("flashvars_keys", " ".join(fv.keys()))
        for md in fv.get("mediaDefinitions", [])[:6]:
            note("mediadef", json.dumps({k: (v[:140] if isinstance(v, str) else v) for k, v in md.items()}))
    except Exception as e:
        note("flashvars_parse_error", str(e))
