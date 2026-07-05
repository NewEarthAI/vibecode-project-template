# Skool.com internals — verified mechanics (2026-06-20)

Empirically confirmed against a live Skool community during the build smoke-test. This is the ground truth the skill is built on.

## Page architecture
- Skool is a **Next.js** app. Each page bakes a JSON blob into `<script id="__NEXT_DATA__">` at `props.pageProps`.
- API base (from `pageProps.env.API_URL`): **`https://api2.skool.com`**. Community posts: `GET /posts/{id}` (works; returns "post not found" for non-post ids — lessons are NOT posts).
- WebSocket: `wss://groups-ps.skool.com/ws`. Telemetry: `https://ct.skool.com`. Video player ≥ v4.9 mentions HLS (`streaming.useNativeHlsForFairPlay`) → confirms native player is HLS when present.

## Classroom tree (enumeration)
- Classroom URL: `https://www.skool.com/{slug}/classroom/{courseId}` and per-lesson `...?md={lessonId}`.
- `pageProps.course` = nested `{course, children}` tree. Lessons are nodes with `unitType: "module"`, carrying `id`, `metadata.title`, `parentId`, `rootId`, `groupId`, `metadata.hasAccess` (paywall flag, 1 = accessible), `metadata.desc` (rich-text body, often `[v2][...]`), `metadata.resources` (attachments array, often `[]`).
- The tree gives **titles + ids + structure** for every lesson — reliably present in static `__NEXT_DATA__`.

## Per-lesson VIDEO — the load-bearing finding
- `pageProps.video` is **null** even when authenticated. The lesson's video is **NOT** in static SSR data as a clean field.
- The video is rendered into the lesson DOM as an **`<iframe>`** (Loom/YouTube/Vimeo/Wistia embed) OR, for Skool-native, an HLS player (`stream.video.skool.com` / Mux `stream.mux.com/{id}.m3u8?token=JWT`).
- The embed URLs DO appear inside the authenticated page's `__NEXT_DATA__` blob (regex over `JSON.stringify(__NEXT_DATA__)` finds `loom.com/share/...`, `youtu.be/...`), but not under a single predictable key — so **rendering the lesson page and reading the iframe `src` is the robust extraction path**. This also uniformly handles native HLS (read the player/network) and carries auth naturally.
- Observed in a test community: lesson "Rules and Guidelines" → `https://www.loom.com/embed/<loom-video-id>`. Community is **Loom-heavy**. No Mux/HLS in this community (but other communities have it — handle generically).

## Video host → download + transcript matrix
| Host | Download (yt-dlp) | Transcript |
|---|---|---|
| YouTube | `youtube.com/watch?v=` or `youtu.be/` | **Free** via `--write-subs --write-auto-subs` |
| Loom | `loom.com/share/{id}` (extractor fixed 2025-12-08) | **yt-dlp `--write-subs` pulls Loom's OWN transcript** via Loom GraphQL (`FetchVideoTranscript`, no auth for public/unlisted shares) → whisper.cpp only as fallback. (Corrects the earlier "Loom has no subs" finding.) |
| Vimeo | use `player.vimeo.com/video/{id}` (avoid 403) | manual subs only if uploaded |
| Wistia | yt-dlp Wistia extractor | VTT if creator uploaded |
| Skool-native (Mux HLS) | `yt-dlp --cookies-from-browser chrome --referer https://www.skool.com <lesson_page_url>` resolves the signed `.m3u8` from the live session; OR feed the `stream.mux.com/...m3u8?token=` directly. Token is short-lived (~hours) → download in-session. | none → whisper.cpp |

- `yt-dlp -g` on a bare Skool classroom URL = **"Unsupported URL"** (no Skool extractor). Must extract the embed/native URL first, then hand the real video URL to yt-dlp.

## Auth
- Bot protection: **AWS WAF** (cookies `aws-waf-token` rotate ~3.5 days = session expiry), Cloudflare as CDN. Session cookies: `auth_token` (JWT, ~1yr, httpOnly), `client_id`.
- A **free** community's classroom pages are public-readable (fetched fine with only `AWSALB*` cookies). **Paid** communities require the real session — supplied by running the skill's browser engine against the user's logged-in Chrome profile (or a `cookies.txt` export incl. `auth_token`).
- Safe crawl: ≤60 page reads/min, ~2s delay, low concurrency. No residential proxy needed for a member reading their own community. Keep user-agent consistent.

## Build implications
1. **Enumerate** = render classroom + each lesson page in a logged-in browser engine (Playwright, persistent Chrome profile) → read tree from `__NEXT_DATA__` + read each lesson's video iframe `src` + `desc` + `resources`.
2. **Download** = yt-dlp per extracted URL (host-aware), `--download-archive` for idempotent re-runs.
3. **Transcript** = YouTube free via yt-dlp subs; Loom/Vimeo-no-subs/Skool-native → whisper.cpp `large-v3-turbo`.
4. **Format** = one Obsidian note per lesson into `Skool_Community_Resources/{category}/{community}/{module}/`.

## Environment notes (build/test machine)
- The Claude Code Bash sandbox **blocks egress to youtube.com** (connection refused) — skool.com is reachable. yt-dlp YouTube steps must be validated in the user's own Terminal, where YouTube works normally.
- yt-dlp `--cookies-from-browser chrome` on this machine captured only `AWSALB*` cookies (not `auth_token`) — for paid communities prefer the persistent-browser-profile approach or a "Get cookies.txt LOCALLY" export.

## Deep-dive corrections (2026-06-20, post-KI competitor review)

Cross-checked against this morning's KI submissions (4 Skool-scraping videos) + open-source Skool downloaders (`balmasi/skool-downloader`, `reid82/skool-downloader`, `usamakhan10/skoolapi`) + Apify actors. Findings folded into the build:

1. **The 4 KI videos are lead/analytics-focused, not content-archival.** They scrape member profiles / posts / MRR via paid Apify actors (`memo23`, `gordian`, `louisdeconinck` [deprecated], `dz_omar/skool-scraper-pro`, `takshit/skool-community-video-scraper`). None does course-video + transcript → Obsidian. They CONFIRM cookie-session auth + idempotency, and contrast with our **classroom-only, no-member-PII** scope (privacy-safe).

2. **`api2.skool.com` has NO clean lesson-content-with-video endpoint.** `reid82` tried `course/{id}/modules`, `v2/course/{id}`, `groups/{gid}/courses/{cid}` — all return structure only, never the video. `api2` is the WRITE side; reads come from Next.js SSR `__NEXT_DATA__`. So the browser/SSR approach is correct, not a shortcut we missed. (`api2.skool.com/files/{fileId}/download-url?expire=28800` exists for file attachments — possible future use for resources.)

3. **Video URL resolution order** (now implemented in `lesson_video_candidates` + `scrape_lesson`): `__NEXT_DATA__ metadata.videoLink` / `videoLinksData` (server-rendered, no race — `balmasi`'s proven approach) → rendered `iframe src` → intercepted native `.m3u8`. Native Mux: `pageProps.video.{playbackId,playbackToken}` is client-side only (null in SSR), so the `page.on('response')` `.m3u8` intercept stays required.

4. **Loom transcripts ARE available** (corrects earlier finding): yt-dlp's `loom.py` extractor uses Loom's `https://www.loom.com/graphql` `FetchVideoTranscript` op (no auth for public/unlisted) → `captions_source_url` (VTT) / `source_url` (JSON). So `--write-subs` on Loom yields the transcript; whisper.cpp is fallback-only. Applied to loom/vimeo/wistia hosts. Watch-out: Loom may rotate its Apollo client-version header — yt-dlp maintains it.

**Net: no architectural change. Two refinements applied — `__NEXT_DATA__`-first video resolution (robustness) + yt-dlp Loom/Vimeo/Wistia subtitles (skips whisper for most lessons, big speed win) — plus randomised 2.5–5s crawl delay (anti-ban).**
