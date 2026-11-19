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

_, data = get("https://www.pornhub.com/webmasters/search?page=1&ordering=mostviewed")
vk = json.loads(data)["videos"][0]["video_id"]
note("viewkey", vk)

# --- embed flashvars
_, emb = get(f"https://www.pornhub.com/embed/{vk}")
i = emb.find('mediaDefinitions')
note("embed_len", f"{len(emb)} mediaDefinitions_at={i}")
m = re.search(r'"mediaDefinitions"\s*:\s*(\[.*?\])\s*,\s*"', emb, re.S)
md = []
if m:
    try:
        md = json.loads(m.group(1))
    except Exception as e:
        note("md_parse_error", e)
note("md_summary", json.dumps([{k: (v if k != "videoUrl" else v[:110]) for k, v in d.items()} for d in md])[:2800])
for d in md:
    if d.get("remote") or d.get("format") == "mp4":
        u = d["videoUrl"]
        if u.startswith("/"): u = "https://www.pornhub.com" + u
        c, body = get(u)
        note("get_media_" + str(d.get("quality")), f"{c} {body[:1200]}")
        break
for d in md:
    if d.get("format") == "hls":
        c, body = get(d["videoUrl"])
        note("hls_master", f"{c} {body[:1500]}")
        break
# other keys in the embed flashvars
note("embed_keys", " ".join(sorted(set(re.findall(r'"(video_[a-z_]+|image_url|link_url|title|[a-z_]*uploader[a-z_]*|[a-z_]*author[a-z_]*)"\s*:', emb)))))

# --- watch page: uploader
_, html = get(f"https://www.pornhub.com/view_video.php?viewkey={vk}")
note("watch_len", len(html))
links = collections.Counter(re.findall(r'href="(/(?:channels|model|pornstar|users)/[^"?#]+)', html))
note("watch_owner_links", " | ".join(f"{k}:{v}" for k, v in links.most_common(15)))
j = html.find("userInfoContainer")
note("userInfoContainer", html[j - 100:j + 1800] if j >= 0 else "none")
j = html.find("videoUploaderBadge")
note("uploaderBadge", html[j - 100:j + 600] if j >= 0 else "none")
ld = re.findall(r'<script type="application/ld\+json">(.*?)</script>', html, re.S)
for b in ld[:1]:
    try:
        jj = json.loads(b)
        note("ld_author", json.dumps({k: jj.get(k) for k in ("author", "creator", "publisher")})[:700])
    except Exception as e:
        note("ld_err", e)

# --- channel / model pages
owner = None
for pat in (r'href="(/channels/[^"?#]+)', r'href="(/model/[^"?#]+)', r'href="(/pornstar/[^"?#]+)', r'href="(/users/[^"?#]+)'):
    mm = re.search(pat, html)
    if mm:
        owner = mm.group(1); break
note("owner", owner)
if owner:
    for suffix in ("/videos?o=vi", "/videos?o=mr", ""):
        c, page = get("https://www.pornhub.com" + owner + suffix)
        note("owner_page" + suffix, f"{c} len={len(page)}")
        if c == 200 and len(page) > 5000:
            break
    k = page.find('data-video-vkey')
    if k < 0: k = page.find('videoblock')
    note("owner_first_item", page[max(k - 400, 0):k + 2200])
    note("owner_header", " | ".join(re.findall(r'<(?:h1|title)[^>]*>(.*?)</', page, re.S)[:4]))
    note("owner_avatar_imgs", " | ".join(re.findall(r'<img[^>]+(?:avatar|Avatar|profile)[^>]*>', page)[:4])[:1500])
    note("owner_sort_links", " | ".join(sorted(set(re.findall(r'href="([^"]*[?&]o=[a-z]+[^"]*)"', page)))[:20]))
    note("owner_pagination", " | ".join(sorted(set(re.findall(r'href="([^"]*[?&]page=\d+[^"]*)"', page)))[:8]))
    note("owner_item_count", len(re.findall(r'data-video-vkey', page)))
