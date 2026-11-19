import json, re, urllib.request, urllib.error

UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
COOKIE = "accessAgeDisclaimerPH=1; accessAgeDisclaimerUK=1; platform=mobile; hasVisited=1"

def get(url, extra=None):
    h = {"User-Agent": UA, "Cookie": COOKIE, **(extra or {})}
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=30) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")

def note(title, msg, n=3000):
    msg = re.sub(r"\s+", " ", msg).replace("%", "%25")
    print(f"::notice title={title}::{msg[:n]}")

_, data = get("https://www.pornhub.com/webmasters/search?page=1&ordering=mostviewed")
vk = json.loads(data)["videos"][0]["video_id"]
code, html = get(f"https://www.pornhub.com/view_video.php?viewkey={vk}")
note("watch_status", f"{code} len={len(html)} vk={vk}")

m = re.search(r'<meta[^>]+property="og:description"[^>]+content="([^"]*)"', html) or re.search(r'<meta[^>]+content="([^"]*)"[^>]+property="og:description"', html)
note("og_description", m.group(1) if m else "none")
m = re.search(r'name="description"[^>]*content="([^"]*)"', html)
note("meta_description", m.group(1) if m else "none")
ld = re.findall(r'<script type="application/ld\+json">(.*?)</script>', html, re.S)
note("ldjson", " || ".join(x.strip()[:1200] for x in ld[:2]) if ld else "none")

rel = re.findall(r'data-video-vkey="([^"]+)"', html)
note("related_vkeys", f"count={len(rel)} first={rel[:6]}")
for kw in ["relatedVideo", "recommended", "commentsCount", "videoComments", "comment/show", "data-video-id", "\"video_id\"", "playlistVideo"]:
    ms = list(re.finditer(re.escape(kw), html))
    if ms:
        s = max(0, ms[0].start() - 80)
        note("kw_" + re.sub(r"\W", "", kw), f"n={len(ms)} :: " + html[s:ms[0].start() + 300], 700)
