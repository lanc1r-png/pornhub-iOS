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

def note(title, msg, n=3200):
    msg = re.sub(r"\s+", " ", msg).replace("%", "%25")
    print(f"::notice title={title}::{msg[:n]}")

_, data = get("https://www.pornhub.com/webmasters/search?page=1&ordering=mostviewed")
vk = json.loads(data)["videos"][0]["video_id"]

# embed page: is the numeric id in there?
_, emb = get(f"https://www.pornhub.com/embed/{vk}")
m = re.search(r'"video_id"\s*:\s*(\d+)', emb)
note("embed_numeric_id", f"found={m.group(1) if m else None} len={len(emb)}")
vid = m.group(1) if m else None
if not vid:
    _, html = get(f"https://www.pornhub.com/view_video.php?viewkey={vk}")
    m = re.search(r'data-video-id="(\d+)"', html)
    vid = m.group(1) if m else None
    note("watch_numeric_id", str(vid))

code, com = get(f"https://www.pornhub.com/comment/show?id={vid}&popular=1&what=video&full=true", {"X-Requested-With": "XMLHttpRequest", "Referer": f"https://www.pornhub.com/view_video.php?viewkey={vk}"})
note("comments_status", f"{code} len={len(com)}")
note("comments_head", com[:3000])
cls = collections.Counter(re.findall(r'class="([^"]+)"', com))
note("comments_classes", " | ".join(f"{k}:{v}" for k, v in cls.most_common(45)))
# first comment block
m = re.search(r'<div[^>]+class="[^"]*commentBlock[^"]*"[^>]*>.*?(?=<div[^>]+class="[^"]*commentBlock)', com, re.S)
note("first_comment_block", m.group(0)[:3000] if m else "no commentBlock")
# description from ld+json on the watch page
_, html = get(f"https://www.pornhub.com/view_video.php?viewkey={vk}")
ld = re.findall(r'<script type="application/ld\+json">(.*?)</script>', html, re.S)
for block in ld[:1]:
    try:
        j = json.loads(block)
        note("ld_keys", " ".join(j.keys()))
        note("ld_description_len", str(len(j.get("description", ""))))
        note("ld_stats", json.dumps(j.get("interactionStatistic"))[:600])
    except Exception as e:
        note("ld_error", str(e))
