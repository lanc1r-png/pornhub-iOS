import json, re, urllib.request, urllib.error

MOB = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
DESK = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
CM = "accessAgeDisclaimerPH=1; accessAgeDisclaimerUK=1; platform=mobile; hasVisited=1"
CD = "accessAgeDisclaimerPH=1; accessAgeDisclaimerUK=1; platform=pc; hasVisited=1"

def get(url, ua, ck, extra=None):
    h = {"User-Agent": ua, "Cookie": ck, "Accept-Encoding": "identity", **(extra or {})}
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=30) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except Exception as e:
        return 0, str(e)

def note(t, m, n=2500):
    print(f"::notice title={t}::" + re.sub(r"\s+", " ", str(m)).replace("%", "%25")[:n])

def bracket(s, start):
    d = 0; ins = False; esc = False
    for i in range(start, len(s)):
        c = s[i]
        if ins:
            if esc: esc = False
            elif c == "\\": esc = True
            elif c == '"': ins = False
        else:
            if c == '"': ins = True
            elif c == "[": d += 1
            elif c == "]":
                d -= 1
                if d == 0: return s[start:i + 1]

def mdlist(html):
    i = html.find('"mediaDefinitions"')
    if i < 0: return None
    try: return json.loads(bracket(html, html.find("[", i)))
    except Exception: return None

def qs(md):
    return [(d.get("format"), d.get("quality") if not isinstance(d.get("quality"), list) else "list%d" % len(d["quality"]), bool(d.get("remote")), d.get("height")) for d in md]

_, data = get("https://www.pornhub.com/webmasters/search?page=1&ordering=mostviewed", MOB, CM)
vids = json.loads(data)["videos"][:3]
for v in vids:
    vk = v["video_id"]
    for label, ua, ck, kind in (("embed_mob", MOB, CM, "embed"), ("embed_desk", DESK, CD, "embed"), ("watch_mob", MOB, CM, "watch"), ("watch_desk", DESK, CD, "watch")):
        url = f"https://www.pornhub.com/embed/{vk}" if kind == "embed" else f"https://www.pornhub.com/view_video.php?viewkey={vk}"
        c, html = get(url, ua, ck)
        md = mdlist(html)
        note(f"{vk[-4:]}_{label}", f"{c} len={len(html)} md={qs(md) if md else None}")
        if md:
            for d in md:
                if d.get("remote"):
                    u = d["videoUrl"]; u = "https://www.pornhub.com" + u if u.startswith("/") else u
                    c2, body = get(u, ua, ck)
                    try:
                        note(f"{vk[-4:]}_{label}_getmedia", f"{c2} " + str([(a.get("format"), a.get("quality"), a.get("height")) for a in json.loads(body)]))
                    except Exception:
                        note(f"{vk[-4:]}_{label}_getmedia", f"{c2} nonjson len={len(body)}")
                    break
            for d in md:
                if d.get("format") == "hls":
                    c3, body = get(d["videoUrl"], ua, ck)
                    note(f"{vk[-4:]}_{label}_hls", f"{c3} variants=" + str(re.findall(r"RESOLUTION=(\d+x\d+)", body)) + f" lines={len(body.splitlines())}")
                    break
