---
name: skool-to-obsidian
description: |-
  Archive an entire Skool.com community classroom (course videos, lesson text,
  resources, and video transcripts) into an Obsidian vault — one tidy Markdown
  note per lesson, sorted by category. Works on free AND paywalled communities
  the user is a member of, and any video host (YouTube, Loom, Vimeo, Wistia, or
  Skool's own player). Use when: "scrape a Skool community", "download a Skool
  course", "import Skool classroom to Obsidian", "get all the videos/transcripts
  from a Skool group", "skool to obsidian", "back up my Skool community".
  Do NOT trigger for: scraping member data/leads/emails (this skill is
  classroom-content only), or accessing communities the user has not joined.
version: 1.0
classification: capability-uplift
created: 2026-06-20
updated: 2026-06-20
---

# Skool → Obsidian archiver

Pulls everything from a Skool community's Classroom into an Obsidian vault. Notes
(light + searchable) live in the vault; video files download to a folder **outside**
the vault so the repo never bloats. Built and verified 2026-06-20 — see
[`references/skool-internals.md`](references/skool-internals.md) for the proven
Skool mechanics this rests on.

## The pipeline (what it does each run)

| Stage | How |
|---|---|
| **Auth** | A private browser profile holds your Skool login (carries paid-community access). |
| **Enumerate** | Renders the classroom + each lesson logged-in; reads the module/lesson tree from the page data and the video embed from the lesson DOM. |
| **Download** | `yt-dlp` per lesson — host-aware (YouTube / Loom / Vimeo / Wistia / Skool-native HLS). `--download-archive` makes re-runs skip what's already done. |
| **Transcript** | yt-dlp pulls captions for YouTube **and Loom** (Loom's own auto-transcript via its GraphQL — no auth), plus Vimeo/Wistia where present. Only Skool-native videos (or any genuinely caption-less) fall back to local `whisper.cpp` (`large-v3-turbo`). |
| **Format** | One Obsidian note per lesson (frontmatter + lesson text + video link + resources + transcript callout) into `{vault}/{category}/{community}/{module}/`, plus a course `_index.md` map-of-content. |

## Prerequisites (one time)

```bash
# system tools
brew install yt-dlp ffmpeg whisper-cpp
# python deps (already set up in the skill's .venv)
cd .claude/skills/skool-to-obsidian
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt && .venv/bin/playwright install chromium
```

## Usage

Run each step on its own line — **no inline `#` comments** (zsh runs them as commands).
Use the venv python (`.venv/bin/python`).

**1. Log into Skool** (one time — a browser opens; log in, switch back to Terminal, press ENTER; the script closes the browser and saves the session):
```bash
cd "<your-repo>/.claude/skills/skool-to-obsidian"
.venv/bin/python scripts/skool_to_obsidian.py login
```

**2. Download the transcription model** (one time, ~1.5 GB — only used for videos that have no captions):
```bash
.venv/bin/python scripts/skool_to_obsidian.py setup
```

**3. Test on the first few lessons** (replace SLUG/COURSEID from the classroom URL):
```bash
.venv/bin/python scripts/skool_to_obsidian.py scrape --url "https://www.skool.com/SLUG/classroom/COURSEID" --name "Community Name" --category "AI" --limit 3
```

**4. Full run** — drop `--limit`:
```bash
.venv/bin/python scripts/skool_to_obsidian.py scrape --url "CLASSROOM_URL" --name "Community Name" --category "AI"
```

Tip: set `SKOOL_DEBUG=1` before the `scrape` command to print, per lesson, what video sources it found (iframes / page-data candidates / data keys) — useful if a lesson's video isn't detected.

### Options

| Flag | Meaning |
|---|---|
| `--url` | The classroom URL (`.../classroom/<courseId>`), copied from the browser. |
| `--name` | Community name → folder + note frontmatter. |
| `--category` | Vault subfolder (existing: AI · General Business · Investing · Life · Real Estate · Trading). |
| `--vault` | Vault root (default: `~/Obsidian/Skool_Community_Resources`). |
| `--media-dir` | Where videos download (default: `~/SkoolDownloads`, outside the vault). |
| `--limit N` | Only the first N lessons (testing). |
| `--transcribe never` | Skip local transcription (keep platform captions only). |
| `--media` | `frames` (default) = transcript + key screenshots of each distinct on-screen moment, drop the video (light + AI-readable). `full` = keep the video files. `none` = transcript only. |
| `--headed` | Show the browser (debugging). |

## Idempotent + resumable

Re-running the same community tops up new lessons and re-writes notes; `yt-dlp
--download-archive` skips already-downloaded videos. Safe to run repeatedly. Cookies
in the private profile last ~3.5 days (Skool's WAF token) — re-run `login` when a
paid community starts returning empty pages.

## Troubleshooting

| Symptom | Fix |
|---|---|
| "could not read page data — not logged in" | Run `login` again (session expired). |
| "no lessons found" | Use the `.../classroom/<id>` URL, not the community home URL. |
| A lesson has no video | Some lessons are text-only — the note is still written. |
| YouTube download fails on this machine only | The Claude Code sandbox blocks YouTube egress; run in a normal Terminal. |
| Transcript missing on Loom lessons | Loom has no captions — ensure `whisper-cpp` is installed + `setup` ran. |
| Skool-native video won't download | Token is short-lived; the run grabs a fresh one per lesson — re-run that lesson. |

## Scope / etiquette

Personal archival of content you have authorised access to (a community you are a
member of), into your own vault. Randomised polite crawl (2.5–5s between lessons,
no proxy). Don't redistribute creators' content.

## Anti-patterns

| Don't | Why | Instead |
|---|---|---|
| Run on a community you haven't joined | Skool serves only what your session can access — there's no content to retrieve, and this skill doesn't support paywall bypass | Join the community (free or paid), then scrape |
| Scrape the community feed / member posts | Classroom-only is a deliberate scope — harvesting member names/emails/posts is the POPIA/GDPR-risky thing | Use a purpose-built member-data tool (e.g. an Apify actor) if you ever need that, and mind consent |
| Randomise the user-agent | Your login is bound to one browser fingerprint; rotating it mid-session looks *more* bot-like and raises ban risk | Keep one real UA (the persistent profile already does) — only the delay should vary |
| Point `--media-dir` inside the repo/vault | Course videos are large; committing them bloats git | Leave the default `~/SkoolDownloads` (outside the vault); the note links to it |
| Remove the crawl delay (`SKOOL_DELAY_MIN=0`) to go fast | Rapid automated requests are exactly what Skool's WAF bans accounts for | Keep the randomised 2.5–5s delay; run one community at a time |

## Files

- `scripts/skool_to_obsidian.py` — the engine (login · setup · scrape).
- `references/skool-internals.md` — verified Skool page/API/video mechanics.
- `requirements.txt` — Python + system deps.
