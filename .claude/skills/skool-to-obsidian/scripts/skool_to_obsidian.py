#!/usr/bin/env python3
"""
skool_to_obsidian.py — archive a Skool community's classroom into an Obsidian vault.

Pipeline (verified against a live Skool community — see references/skool-internals.md):
  auth (persistent browser profile, carries paid access)
   -> enumerate (Playwright renders classroom + each lesson, reads __NEXT_DATA__ tree + video iframe)
   -> download (yt-dlp, host-aware: YouTube / Loom / Vimeo / Wistia / Skool-native HLS)
   -> transcript (YouTube subs free; otherwise whisper.cpp large-v3-turbo)
   -> format (one Obsidian note per lesson + a course _index MOC)

Notes live IN the vault (light, searchable). Videos download to a media dir OUTSIDE the
vault by default (so the repo doesn't bloat) and are linked from the note.

Subcommands:
  login    one-time: open a browser, log into Skool; the session is saved to a private profile
  setup    download the whisper transcription model (~1.5 GB, once)
  scrape   walk a community's classroom into a vault category folder

Examples:
  python skool_to_obsidian.py login
  python skool_to_obsidian.py setup
  python skool_to_obsidian.py scrape \
      --url "https://www.skool.com/<community-slug>/classroom/<course-id>" \
      --name "Your Community" --category "AI" --limit 3

Requires: playwright (.venv) + chromium ; yt-dlp, ffmpeg, whisper-cpp (brew).
"""
import argparse, json, os, random, re, shutil, subprocess, sys, time
from pathlib import Path

# ---------------------------------------------------------------- config
DEFAULT_VAULT = os.environ.get("SKOOL_VAULT", str(Path.home() / "Obsidian" / "Skool_Community_Resources"))
DEFAULT_MEDIA = str(Path.home() / "SkoolDownloads")          # videos live here, OUTSIDE the vault
PROFILE_DIR   = str(Path.home() / ".skool-obsidian" / "chrome-profile")
MODEL_DIR     = Path.home() / ".skool-obsidian" / "models"
WHISPER_MODEL = os.environ.get("WHISPER_MODEL", "large-v3-turbo")
DELAY_MIN     = float(os.environ.get("SKOOL_DELAY_MIN", "2.5"))  # randomised polite delay between
DELAY_MAX     = float(os.environ.get("SKOOL_DELAY_MAX", "5.0"))  # lessons — human-paced, dodges the WAF
FORBIDDEN     = r'[\/:\[\]#<>|"*^\\]'                         # Obsidian-forbidden filename chars

def log(m): print(f"[skool] {m}", flush=True)
def esc(s): return (s or "").replace('"', '\\"')

def sanitise(name, maxlen=90):
    name = re.sub(FORBIDDEN, "-", name or "")
    name = re.sub(r"[-\s]+", " ", name).strip(" -.")
    return (name[:maxlen]).strip() or "untitled"

def need(cmd, hint):
    p = shutil.which(cmd)
    if not p:
        sys.exit(f"[skool] missing '{cmd}'  —  install with: {hint}")
    return p

# ---------------------------------------------------------------- video host detection
def classify_video(url):
    """(host, normalised_download_url) for a candidate URL, or (None, None)."""
    if not url:
        return (None, None)
    m = re.search(r"(?:youtube\.com/(?:watch\?v=|embed/)|youtu\.be/)([\w-]{6,})", url)
    if m:
        return ("youtube", f"https://www.youtube.com/watch?v={m.group(1)}")
    m = re.search(r"loom\.com/(?:share|embed)/([0-9a-f]{20,})", url)
    if m:
        return ("loom", f"https://www.loom.com/share/{m.group(1)}")
    m = re.search(r"(?:player\.)?vimeo\.com/(?:video/)?(\d+)", url)
    if m:
        return ("vimeo", f"https://player.vimeo.com/video/{m.group(1)}")
    if "wistia" in url:
        return ("wistia", url)
    if ".m3u8" in url or "stream.mux.com" in url or "stream.video.skool.com" in url:
        return ("skool-native", url)          # keep the full signed URL (token in query)
    return (None, None)

# ---------------------------------------------------------------- Skool page parsing
def get_next_data(page):
    txt = page.evaluate(
        "() => { const e = document.getElementById('__NEXT_DATA__'); return e ? e.textContent : null; }"
    )
    return json.loads(txt) if txt else None

def parse_tree(course_obj):
    """pageProps.course -> ordered lessons {id, title, path:[ancestor module titles]}.
    Each tree entry is a WRAPPER {'course': <node>, 'children': [<wrapper>, ...]}; the
    real id/title live on the inner 'course' node. Leaves (no children) are lessons."""
    lessons = []
    def walk(wrapper, path):
        if not isinstance(wrapper, dict):
            return
        node = wrapper.get("course") or {}
        title = (node.get("metadata") or {}).get("title") or node.get("name")
        kids = wrapper.get("children") or []
        if kids:                              # section/module — descend, extend path
            newpath = path + ([title] if title else [])
            for k in kids:
                walk(k, newpath)
        elif node.get("id") and title:        # leaf = lesson
            lessons.append({"id": node["id"], "title": title, "path": path})
    for k in (course_obj.get("children") or []):
        walk(k, [])
    seen, out = set(), []                      # tree appears twice (course + renderData) — dedupe
    for l in lessons:
        if l["id"] in seen:
            continue
        seen.add(l["id"])
        out.append(l)
    return out

def skool_richtext_to_text(desc):
    """Skool stores lesson body as '[v2][{type:paragraph,children:[{text:...}]}]'."""
    if not desc:
        return ""
    s = desc[4:] if desc.startswith("[v2]") else desc
    try:
        nodes = json.loads(s)
    except Exception:
        return ""
    def node_text(n):
        if isinstance(n, dict):
            if isinstance(n.get("text"), str):
                return n["text"]
            return "".join(node_text(c) for c in n.get("children", []))
        if isinstance(n, list):
            return "".join(node_text(c) for c in n)
        return ""
    paras = [node_text(n).strip() for n in nodes] if isinstance(nodes, list) else []
    return "\n\n".join(p for p in paras if p)

def extract_lesson_meta(nd, lesson_id):
    """desc text + resources [{label,url}] for a lesson id, from __NEXT_DATA__."""
    md = {}
    def walk(o):
        nonlocal md
        if isinstance(o, dict):
            if o.get("id") == lesson_id and "metadata" in o:
                md = o["metadata"]
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    if nd:
        walk(nd)
    desc = skool_richtext_to_text(md.get("desc"))
    resources = []
    raw = md.get("resources")
    try:
        arr = json.loads(raw) if isinstance(raw, str) else (raw or [])
        for r in arr:
            if isinstance(r, dict) and r.get("url"):
                resources.append({"label": r.get("label") or r.get("title") or r["url"], "url": r["url"]})
    except Exception:
        pass
    return desc, resources

def lesson_video_candidates(nd, lesson_id):
    """External video URLs from a lesson's __NEXT_DATA__ node (metadata.videoLink +
    videoLinksData). More robust than iframe-scraping — the URL is in the server-rendered
    data, with no lazy-load race. Confirmed by the balmasi/skool-downloader approach."""
    cands = []
    def walk(o):
        if isinstance(o, dict):
            if o.get("id") == lesson_id:
                md = o.get("metadata") or {}
                if md.get("videoLink"):
                    cands.append(md["videoLink"])
                vld = md.get("videoLinksData")
                try:
                    arr = json.loads(vld) if isinstance(vld, str) else (vld or [])
                    cands.extend(v["url"] for v in arr if isinstance(v, dict) and v.get("url"))
                except Exception:
                    pass
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    if nd:
        walk(nd)
    return cands

def scrape_lesson(page, classroom_url, lesson_id):
    """Render a lesson page; return {url, host, video_url, desc, resources}.
    Video URL resolution order (most → least robust):
      1. __NEXT_DATA__ metadata.videoLink / videoLinksData (server-rendered, no race)
      2. rendered iframe src (Loom/YouTube/Vimeo/Wistia embeds)
      3. intercepted native HLS .m3u8 (Skool-native / Mux — token injected client-side)"""
    url = classroom_url.split("?")[0] + f"?md={lesson_id}"
    captured = {"native": None}
    def on_response(resp):
        u = resp.url
        if ".m3u8" in u or "stream.mux.com" in u or "stream.video.skool.com" in u:
            captured["native"] = u
    page.on("response", on_response)
    try:
        page.goto(url, wait_until="domcontentloaded", timeout=45000)
        time.sleep(3)                          # let the embedded player render / fire its requests
        iframes = page.eval_on_selector_all("iframe", "els => els.map(e => e.src).filter(Boolean)")
    finally:
        page.remove_listener("response", on_response)

    nd = get_next_data(page)
    cands = lesson_video_candidates(nd, lesson_id)
    host = video_url = None
    for src in cands + list(iframes):
        h, n = classify_video(src)
        if h:
            host, video_url = h, n
            break
    if not video_url and captured["native"]:
        host, video_url = "skool-native", captured["native"]

    if os.environ.get("SKOOL_DEBUG"):
        meta_keys = []
        def _peek(o):
            if isinstance(o, dict):
                if o.get("id") == lesson_id and "metadata" in o:
                    meta_keys.append(sorted((o.get("metadata") or {}).keys()))
                for v in o.values():
                    _peek(v)
            elif isinstance(o, list):
                for v in o:
                    _peek(v)
        if nd:
            _peek(nd)
        log(f"  [debug] host={host or 'NONE'} iframes={len(iframes)} "
            f"node_cands={len(cands)} native={'y' if captured['native'] else 'n'}")
        for s in (cands + list(iframes))[:5]:
            log(f"  [debug]   src: {s[:95]}")
        log(f"  [debug]   lesson metadata keys: {meta_keys}")

    desc, resources = extract_lesson_meta(nd, lesson_id)
    return {"url": url, "host": host, "video_url": video_url, "desc": desc, "resources": resources}

# ---------------------------------------------------------------- download + transcribe
def download_video(item, media_dir, stem, do_download):
    """Run yt-dlp; return (video_path|None, subtitle_path|None)."""
    yt = need("yt-dlp", "brew install yt-dlp")
    host, vurl = item["host"], item["video_url"]
    out = str(media_dir / f"{stem}.%(ext)s")
    cmd = [yt, "--no-warnings", "--no-progress",
           "--download-archive", str(media_dir / "archive.txt"),
           "-o", out]
    if not do_download:
        cmd += ["--skip-download"]
    else:
        # bv*+ba/b merges adaptive HLS (separate video+audio) AND takes progressive formats.
        # The old "[ext=mp4]/best" chain failed on Loom videos that only offer adaptive HLS
        # (no single combined file) — "Requested format is not available". Remux to mp4.
        cmd += ["-f", "bv*+ba/b", "--merge-output-format", "mp4", "--remux-video", "mp4"]
    if host in ("youtube", "loom", "vimeo", "wistia"):
        # yt-dlp pulls Loom's own transcript (via Loom GraphQL, no auth) + YouTube auto-captions
        # + Vimeo/Wistia creator subs where present — only fall back to whisper when none exist.
        cmd += ["--write-subs", "--write-auto-subs", "--sub-langs", "en.*",
                "--sub-format", "vtt", "--convert-subs", "srt"]
    elif host == "skool-native":
        cmd += ["--referer", "https://www.skool.com"]
    cmd += [vurl]
    subprocess.run(cmd, check=False)
    vids = sorted(media_dir.glob(f"{stem}.mp4")) or sorted(media_dir.glob(f"{stem}.*.mp4"))
    subs = sorted(media_dir.glob(f"{stem}*.srt"))
    return (str(vids[0]) if vids else None, str(subs[0]) if subs else None)

def whisper_model_path():
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    p = MODEL_DIR / f"ggml-{WHISPER_MODEL}.bin"
    if not p.exists():
        log(f"whisper model missing — downloading {WHISPER_MODEL} (~1.5 GB, one time)…")
        url = f"https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-{WHISPER_MODEL}.bin"
        subprocess.run(["curl", "-L", "--fail", "-o", str(p), url], check=False)
    return str(p) if p.exists() else None

def transcribe(video_path, stem, media_dir):
    """Audio -> whisper.cpp -> return transcript text (also leaves a .srt)."""
    wcli = shutil.which("whisper-cli") or shutil.which("whisper-cpp")
    if not wcli:
        log("  whisper-cli not found (brew install whisper-cpp) — skipping transcript")
        return None
    model = whisper_model_path()
    if not model:
        log("  whisper model unavailable — skipping transcript")
        return None
    wav = media_dir / f"{stem}.wav"
    subprocess.run(["ffmpeg", "-y", "-i", video_path, "-ar", "16000", "-ac", "1",
                    "-c:a", "pcm_s16le", str(wav)], check=False, capture_output=True)
    if not wav.exists():
        return None
    of = str(media_dir / stem)                 # whisper writes {stem}.txt + {stem}.srt
    subprocess.run([wcli, "-m", model, "-f", str(wav), "--output-txt", "--output-srt",
                    "--max-len", "47", "-of", of], check=False)
    wav.unlink(missing_ok=True)
    txt = media_dir / f"{stem}.txt"
    return txt.read_text(encoding="utf-8", errors="replace").strip() if txt.exists() else None

def extract_keyframes(video_path, stem, out_dir, max_frames=24):
    """Capture each distinct on-screen state (scene change) as a JPG for the vault — the
    visual record that replaces the full video. Falls back to one frame / 60s if scene
    detection finds too few (a static screen-share that never 'changes' enough)."""
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob(f"{stem}_f*.jpg"):
        old.unlink(missing_ok=True)
    pat = str(out_dir / f"{stem}_f%02d.jpg")
    base = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(video_path)]
    # scene-change frames (distinct screens: new slide, new code, n8n canvas update)
    subprocess.run(base + ["-vf", "select='gt(scene,0.3)',scale=1280:-1",
                           "-fps_mode", "vfr", "-frames:v", str(max_frames), "-q:v", "3", pat],
                   check=False, capture_output=True)
    frames = sorted(out_dir.glob(f"{stem}_f*.jpg"))
    if len(frames) < 4:                          # static screen-share → time-sample instead
        for f in frames:
            f.unlink(missing_ok=True)
        subprocess.run(base + ["-vf", "fps=1/60,scale=1280:-1",
                               "-frames:v", str(max_frames), "-q:v", "3", pat],
                       check=False, capture_output=True)
        frames = sorted(out_dir.glob(f"{stem}_f*.jpg"))
    return [f.name for f in frames]

def srt_to_text(srt):
    out = []
    for ln in srt.splitlines():
        ln = ln.strip()
        if not ln or ln.isdigit() or "-->" in ln or ln.startswith("WEBVTT"):
            continue
        ln = re.sub(r"<[^>]+>", "", ln)        # strip inline tags
        if not out or out[-1] != ln:           # drop consecutive dupes (auto-subs)
            out.append(ln)
    return " ".join(out)

# ---------------------------------------------------------------- Obsidian output
def transcript_lines(t, width=300):
    sents, out, buf = re.split(r"(?<=[.!?])\s+", t), [], ""
    for s in sents:
        buf = (buf + " " + s).strip()
        if len(buf) >= width:
            out.append(buf); buf = ""
    if buf:
        out.append(buf)
    return out

def write_note(item, notes_dir, course_title, transcript, video_path, frames=None):
    dest = notes_dir.joinpath(*[sanitise(m) for m in item["path"]]) if item["path"] else notes_dir
    dest.mkdir(parents=True, exist_ok=True)
    module = " / ".join(item["path"]) if item["path"] else ""
    b = ["---",
         f'title: "{esc(item["title"])}"',
         f'course: "{esc(course_title)}"',
         f'module: "{esc(module)}"',
         f"source_url: {item['url']}",
         f"video_host: {item['host'] or 'none'}",
         f"date: {time.strftime('%Y-%m-%d')}",
         "tags: [skool, course]",
         "status: imported",
         "---", "",
         f"# {item['title']}", ""]
    if item.get("desc"):
        b += [item["desc"], ""]
    if video_path:
        uri = Path(video_path).as_uri()
        b += [f'<video src="{uri}" controls width="100%"></video>', "", f"[▶ Open video file]({uri})", ""]
    elif item.get("video_url"):
        b += [f"[▶ Video source]({item['video_url']})", ""]
    if frames:
        b += [f"> [!abstract]- Screenshots ({len(frames)})"] + [f"> ![[{fn}]]" for fn in frames] + [""]
    if item.get("resources"):
        b += ["## Resources"] + [f"- [{r['label']}]({r['url']})" for r in item["resources"]] + [""]
    if transcript:
        b += ["> [!note]- Transcript"] + [f"> {ln}" for ln in transcript_lines(transcript)] + [""]
    (dest / (sanitise(item["title"]) + ".md")).write_text("\n".join(b), encoding="utf-8")

def write_index(notes_dir, community, course_title, items):
    from collections import OrderedDict
    groups = OrderedDict()
    for it in items:
        groups.setdefault(" / ".join(it["path"]) if it["path"] else "(root)", []).append(it)
    b = ["---", f'title: "{esc(community)} — Index"', "tags: [skool, moc]",
         f"date: {time.strftime('%Y-%m-%d')}", "---", "",
         f"# {community} — {course_title}", "", f"> {len(items)} lessons imported from Skool.", ""]
    for module, its in groups.items():
        b.append(f"## {module}")
        for it in its:
            tag = f"🎬 {it['host']}" if it.get("host") else "📄 text"
            b.append(f"- [[{sanitise(it['title'])}]]  ·  {tag}")
        b.append("")
    b += ["```dataview",
          f'TABLE video_host, status WHERE contains(tags, "skool") AND course = "{esc(course_title)}" SORT file.name',
          "```", ""]
    (notes_dir / "_index.md").write_text("\n".join(b), encoding="utf-8")

# ---------------------------------------------------------------- browser
def browser(headless=True):
    from playwright.sync_api import sync_playwright
    Path(PROFILE_DIR).mkdir(parents=True, exist_ok=True)
    pw = sync_playwright().start()
    ctx = pw.chromium.launch_persistent_context(
        PROFILE_DIR, headless=headless, viewport={"width": 1280, "height": 900},
        args=["--disable-blink-features=AutomationControlled"])
    return pw, ctx

# ---------------------------------------------------------------- subcommands
def cmd_login(_a):
    pw, ctx = browser(headless=False)
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    page.goto("https://www.skool.com/login")
    log("A browser opened. Log into Skool (and open a community you're a member of).")
    input("[skool] When you're logged in, press ENTER here to save the session… ")
    ctx.close(); pw.stop()
    log(f"session saved → {PROFILE_DIR}")

def cmd_setup(_a):
    need("yt-dlp", "brew install yt-dlp"); need("ffmpeg", "brew install ffmpeg")
    if not (shutil.which("whisper-cli") or shutil.which("whisper-cpp")):
        log("note: whisper-cpp not found — transcripts for non-YouTube videos need: brew install whisper-cpp")
    whisper_model_path()
    log("setup complete.")

def cmd_scrape(a):
    need("yt-dlp", "brew install yt-dlp"); need("ffmpeg", "brew install ffmpeg")
    vault = Path(a.vault).expanduser()
    notes_dir = vault / sanitise(a.category) / sanitise(a.name)
    media_dir = Path(a.media_dir).expanduser() / sanitise(a.name)
    notes_dir.mkdir(parents=True, exist_ok=True); media_dir.mkdir(parents=True, exist_ok=True)

    pw, ctx = browser(headless=not a.headed)
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    log(f"opening classroom: {a.url}")
    page.goto(a.url, wait_until="domcontentloaded", timeout=60000)
    time.sleep(2)
    nd = get_next_data(page)
    if not nd:
        ctx.close(); pw.stop()
        sys.exit("[skool] could not read page data — not logged in? run:  python skool_to_obsidian.py login")
    pp = nd.get("props", {}).get("pageProps", {})
    course = pp.get("course") or {}
    course_title = ((course.get("course") or {}).get("metadata") or {}).get("title") or a.name
    lessons = parse_tree(course)
    if not lessons:
        ctx.close(); pw.stop()
        sys.exit("[skool] no lessons found — check the classroom URL (use the .../classroom/<id> link).")
    if a.limit:
        lessons = lessons[: a.limit]
    log(f"{len(lessons)} lesson(s) to process → notes:{notes_dir}  media:{media_dir}")

    done = []
    for i, L in enumerate(lessons, 1):
        log(f"[{i}/{len(lessons)}] {L['title']}")
        try:
            info = scrape_lesson(page, a.url, L["id"])
        except Exception as e:
            log(f"  ! failed to load lesson: {e}")
            continue
        item = {**L, **info}
        stem = sanitise(f"{L['id'][:8]}-{L['title']}", 60)
        video_path = subtitle = transcript = None
        frames = []
        if item["video_url"]:
            do_dl = a.media in ("frames", "full")
            log(f"  video: {item['host']} → {'downloading' if do_dl else 'transcript only'}")
            video_path, subtitle = download_video(item, media_dir, stem, do_dl)
            if subtitle and Path(subtitle).exists():
                transcript = srt_to_text(Path(subtitle).read_text(encoding="utf-8", errors="replace"))
            elif a.transcribe != "never" and video_path:
                log("  no captions — transcribing locally (whisper)…")
                transcript = transcribe(video_path, stem, media_dir)
            if a.media == "frames" and video_path and Path(video_path).exists():
                log("  extracting screenshots…")
                frames = extract_keyframes(Path(video_path), stem, notes_dir / "_media")
                Path(video_path).unlink(missing_ok=True)     # keep screenshots, drop the video
                video_path = None
        else:
            log("  (no video on this lesson — text only)")
        write_note(item, notes_dir, course_title, transcript, video_path, frames)
        done.append(item)
        time.sleep(random.uniform(DELAY_MIN, DELAY_MAX))

    write_index(notes_dir, sanitise(a.name), course_title, done)
    ctx.close(); pw.stop()
    log(f"DONE — {len(done)} note(s) → {notes_dir}")

# ---------------------------------------------------------------- cli
def main():
    ap = argparse.ArgumentParser(description="Archive a Skool community into an Obsidian vault.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("login", help="open a browser and log into Skool (saves a private session)").set_defaults(fn=cmd_login)
    sub.add_parser("setup", help="download the whisper transcription model").set_defaults(fn=cmd_setup)
    s = sub.add_parser("scrape", help="scrape a community classroom into the vault")
    s.add_argument("--url", required=True, help="classroom URL, e.g. https://www.skool.com/<slug>/classroom/<id>")
    s.add_argument("--name", required=True, help="community name (folder + frontmatter)")
    s.add_argument("--category", required=True, help="vault category subfolder (AI / Trading / …)")
    s.add_argument("--vault", default=DEFAULT_VAULT)
    s.add_argument("--media-dir", default=DEFAULT_MEDIA, help="where videos download to (outside the vault)")
    s.add_argument("--limit", type=int, default=0, help="only the first N lessons (testing)")
    s.add_argument("--transcribe", choices=["auto", "never"], default="auto")
    s.add_argument("--media", choices=["frames", "full", "none"], default="frames",
                   help="frames=transcript+screenshots (default, light); full=keep video files; none=transcript only")
    s.add_argument("--headed", action="store_true", help="show the browser (debugging)")
    s.set_defaults(fn=cmd_scrape)
    a = ap.parse_args()
    a.fn(a)

if __name__ == "__main__":
    main()
