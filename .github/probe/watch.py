import json, re, urllib.request, urllib.error, collections

UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
COOKIE = "accessAgeDisclaimerPH=1; accessAgeDisclaimerUK=1; platform=mobile; hasVisited=1"

def get(url, extra=None):
    h = {"User-Agent": UA, "Cookie": COOKIE, "Accept-Encoding": "identity", **(extra or {})}
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=30) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except Exception as e:
        return 0, str(e)

def note(title, msg, n=3000):
    msg = re.sub(r"\s+", " ", str(msg)).replace("%", "%25")
    print(f"::notice title={title}::{msg[:n]}")

def skeleton(h):
    """Markup structure only: tags, attribute names, class names; text and slugs masked."""
    h = re.sub(r"<script.*?</script>|<style.*?</style>", "", h, flags=re.S)
    out = []
    for t in re.findall(r"<[^>]+>", h):
        t = re.sub(r'(href|src|data-[a-z_-]*(?:thumb|src|path)[a-z_-]*|title|alt)="[^"]*"', lambda m: f'{m.group(1)}="…"' if m.group(1) in ("title", "alt") else f'{m.group(1)}="{re.sub(r"[A-Za-z0-9_-]{6,}", "X", m.group(0)[len(m.group(1))+2:-1])}"', t)
        out.append(t)
    return "".join(out)

def bracket(s, start):
    depth = 0; ins = False; esc = False
    for i in range(start, len(s)):
        c = s[i]
        if ins:
            if esc: esc = False
            elif c == "\\": esc = True
            elif c == '"': ins = False
        else:
            if c == '"': ins = True
            elif c == "[": depth += 1
            elif c == "]":
                depth -= 1
                if depth == 0: return s[start:i + 1]
    return None

_, data = get("https://www.pornhub.com/webmasters/search?page=1&ordering=mostviewed")
vk = json.loads(data)["videos"][0]["video_id"]

_, emb = get(f"https://www.pornhub.com/embed/{vk}")
i = emb.find('"mediaDefinitions"')
md = []
if i >= 0:
    raw = bracket(emb, emb.find("[", i))
    try: md = json.loads(raw)
    except Exception as e: note("md_parse_error", e)
def mask(u): return re.sub(r"[A-Za-z0-9_=%-]{12,}", "X", u)[:140]
note("md_summary", json.dumps([{k: (mask(v) if k == "videoUrl" else v) for k, v in d.items()} for d in md]))
for d in md:
    if d.get("remote") or d.get("format") == "mp4":
        u = d["videoUrl"]
        if u.startswith("/"): u = "https://www.pornhub.com" + u
        c, body = get(u)
        try:
            arr = json.loads(body)
            note("get_media", f"{c} " + json.dumps([{k: (mask(v) if k == "videoUrl" else v) for k, v in a.items()} for a in arr]))
        except Exception as e:
            note("get_media_raw", f"{c} {mask(body[:300])}")
        break
for d in md:
    if d.get("format") == "hls":
        c, body = get(d["videoUrl"])
        note("hls_master", f"{c} " + re.sub(r"https?://\S+|[A-Za-z0-9_=%/.-]{25,}", "U", body)[:900])
        break
note("embed_has_flashvars_keys", " ".join(sorted(set(re.findall(r'"(video_[a-z_]+|[a-z_]*uploader[a-z_]*|[a-z_]*author[a-z_]*|[a-z_]*quality[a-z_]*)"\s*:', emb)))))

_, html = get(f"https://www.pornhub.com/view_video.php?viewkey={vk}")
links = collections.Counter(re.sub(r"^(/[a-z]+/).*", r"\1", l) for l in re.findall(r'href="(/(?:channels|model|pornstar|users)/[^"?#]+)', html))
note("watch_owner_link_kinds", dict(links))
j = html.find("userInfoContainer")
note("userInfo_skeleton", skeleton(html[j - 50:j + 3500]) if j >= 0 else "none", 2500)
j = html.find("videoUploaderBadge")
note("badge_skeleton", skeleton(html[j - 50:j + 800]) if j >= 0 else "none", 900)

owner = None
for pat in (r'href="(/channels/[^"?#]+)', r'href="(/model/[^"?#]+)', r'href="(/pornstar/[^"?#]+)', r'href="(/users/[^"?#]+)'):
    mm = re.search(pat, html)
    if mm: owner = mm.group(1); break
note("owner_kind", re.sub(r"^(/[a-z]+/).*", r"\1", owner or "none"))
if owner:
    for suffix in ("/videos?o=vi", "/videos", ""):
        c, page = get("https://www.pornhub.com" + owner + suffix)
        note("owner_page_status" + suffix, f"{c} len={len(page)} items={len(re.findall('data-video-vkey', page))}")
        if c == 200 and "data-video-vkey" in page: break
    k = page.find("data-video-vkey")
    note("item_skeleton", skeleton(page[max(k - 300, 0):k + 2500]) if k >= 0 else "no items", 3000)
    note("sort_params", " | ".join(sorted(set(re.sub(r"^.*?[?&](o=[a-z]+).*$", r"\1", l) for l in re.findall(r'href="([^"]*[?&]o=[a-z]+[^"]*)"', page)))))
    note("page_params", len(set(re.findall(r'[?&]page=(\d+)', page))))
    h = page.find("<h1")
    note("header_skeleton", skeleton(page[h - 600:h + 900]) if h >= 0 else "none", 1800)
    note("avatar_tags", " ".join(skeleton(t) for t in re.findall(r'<img[^>]+(?:avatar|Avatar|profile|Profile)[^>]*>', page)[:3]), 900)
