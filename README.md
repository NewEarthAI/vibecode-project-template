# Claude Code Project Template

> A run-once starter that turns a blank repo into a fully wired, context-aware
> AI building environment — the best of everything learned over months of
> shipping real software with Claude Code, in one place.

You open it in Claude Code, type **`/setup`**, answer a short interview, and walk
away with a project that already knows what you're building, what "done" looks
like, how to keep itself safe, how to spend AI budget wisely, and how to plan
your day. Nothing here is tied to anyone else's business — it's a blank,
white-label starter you make your own.

---

## Table of contents

1. [Is it safe to download?](#1--is-it-safe-to-download)
2. [Quick start (5 minutes)](#2--quick-start-5-minutes)
3. [The one command that does it all: `/setup`](#3--the-one-command-that-does-it-all-setup)
4. [Destination + roadmap: always in tandem](#4--destination--roadmap-always-in-tandem)
5. [The full toolkit, grouped](#5--the-full-toolkit-grouped)
6. [Your daily rhythm](#6--your-daily-rhythm)
7. [Opt-in walkthroughs (you choose)](#7--opt-in-walkthroughs-you-choose)
8. [Credentials & security, done properly](#8--credentials--security-done-properly)
9. [Staying up to date](#9--staying-up-to-date)
10. [The philosophy underneath](#10--the-philosophy-underneath)

---

## 1 · Is it safe to download?

**Yes — safe to download and use.** This repo was security-audited before
release. Here it is in plain English:

- **No passwords or keys live in any shared file.** Every spot that needs a
  secret is a labelled blank you fill in on your own machine. Those filled-in
  files are automatically kept out of GitHub, so you can't accidentally publish
  them.
- **Nothing runs without you.** The setup script only ever *asks you* for your
  own keys and saves them privately on your own computer. It downloads nothing
  from the internet and runs nothing remote. It can't damage your machine or
  send your data anywhere.
- **The safety tools point inward, not outward.** The dozens of built-in checks
  ("hooks") exist to *stop* dangerous commands — deleting the wrong folder,
  force-pushing over someone's work, running a database query that would cost a
  fortune. They protect you; they don't do anything risky themselves.
- **You can verify it yourself.** The template ships with five security skills
  (a deep security review, a quick scan, a threat-model builder, an "agent
  shield", and a multi-tenant-auth checker). Type *"run a security review on
  this repo"* any time and Claude will audit it in front of you.

> **MCP** = the bridge that lets Claude Code control your other tools (your
> database, your automations, GitHub, a browser). It's how one chat can read a
> table, deploy a function, and open a pull request without you switching apps.

---

## 2 · Quick start (5 minutes)

**Download it — don't clone it.** On the GitHub page, click **Code → Download
ZIP**, unzip it, and rename the folder to your project. Downloading (rather than
cloning) gives you a clean copy that's yours from commit zero, with no git
history tying it back to the template. You'll still be able to pull future
improvements — see [§9](#9--staying-up-to-date).

Then:

| Step | What you do | What happens |
|---|---|---|
| 1 | Open the folder in Claude Code | Claude reads the starter rules and skills |
| 2 | Type **`/setup`** | A guided interview builds your project's brain (15–45 min) |
| 3 | Type **`/prime`** | Claude reads everything back to confirm it understood you |
| 4 | Type **`/daily-plan`** | You get a ranked to-do list for your first session |
| 5 | Start building | Just describe what you want, in plain English |

> **Prefer a visual tour first?** Open 📊 the welcome deck — the file
> `docs/welcome-deck.html` — in any browser for a 12-slide walkthrough (arrow
> keys to move). `/setup` offers to show it automatically at the start and end.

**Connecting your tools (optional, when you're ready):** if you want Claude to
control a database, automations, GitHub, or a browser, there's a one-time helper
script that asks for each key and saves it privately on your Mac. It's covered
in [§8](#8--credentials--security-done-properly). You can skip this and still
use everything that doesn't need external tools.

> **Mac vs Windows:** the credential helper is Mac-first today. On Windows,
> `/setup` will walk you through the same steps by hand and store keys the
> Windows-safe way. Either way, no key is ever committed to GitHub.

---

## 3 · The one command that does it all: `/setup`

`/setup` is the heart of this template. It's a structured interview that turns a
blank repo into a project Claude deeply understands. You answer questions in
plain English; Claude writes the files. Here's the journey:

```mermaid
flowchart LR
  A(["You run /setup"]) --> B["① Learns your project"]
  B --> C["② Writes DESTINATION.md<br/>(what done looks like)"]
  C --> D["③ Builds ROADMAP<br/>+ North Star metric"]
  D --> E["④ Wires safety +<br/>token-saving guards"]
  E --> F["⑤ Tunes /daily-plan"]
  F --> G["⑥ Turns on<br/>autonomous shipping"]
  G --> H(["A project Claude<br/>understands as well as you"])
```

**① It learns your project.** What problem you solve and for whom, what success
looks like in 3–6 months, what you're deliberately *not* building, and your
constraints. → writes your project's memory file (`CLAUDE.md`), a vision spec,
and a domain model (your core "things" and how they relate).

**② It writes your destination.** Before anything else, `/setup` runs the
**`/define-destination`** skill — a guided recipe that produces a 📄
`DESTINATION.md`: a written, testable statement of what "done" actually looks
like, that any reader (you, a teammate, or Claude) can use later to judge
whether the work is on course. This is the single source of truth for success.

**③ It builds your roadmap, locked to that destination.** A wizard turns "what
are you working on now / next / later" into a four-lane roadmap with a **North
Star metric** — the single number that, if it moves, proves the whole thing is
working. The roadmap and the destination stay in sync by design (see
[§4](#4--destination--roadmap-always-in-tandem)).

**④ It wires safety + token-saving for *your* tools.** `/setup` detects which
external tools you've connected and switches on the matching guardrails — so a
careless database query gets a warning, a risky workflow edit gets a checklist,
and Claude never wastes budget fetching whole files when a snippet will do. You
don't configure these by hand; setup does it.

**⑤ It tunes your daily planner.** It asks for your North Star (and any
sub-goals per area of the business), then configures **`/daily-plan`** to rank
each session's work by how much it moves that number.

**⑥ It turns on autonomous shipping.** The **`/autovibe`** orchestrator —
plan → council review → execute → code review → ship — is ready immediately.
An optional "autofire" mode (a fresh chat launches itself to continue the next
step) is offered but off by default.

**⑦ It offers the extras.** Strategic-intelligence scaffolding (competitor
analysis, positioning) for product/agency projects; your second-brain
connection (see [§7](#7--opt-in-walkthroughs-you-choose)); and parallel agent
teams. Each is opt-in — you're never forced into anything.

**End state:** a project Claude understands as well as you do, that plans itself,
guards itself, and ships itself — built from your own answers, not anyone's
template content.

> Short on time? **`/setup quick`** does a 5-question version in about five
> minutes. You can deepen it later.

---

## 4 · Destination + roadmap: always in tandem

These two files are a matched pair, and the template keeps them honest:

- 📄 **`DESTINATION.md`** — *what* success is. A falsifiable end-state with a
  third-party-observable test ("you'll know it's done when…"). It rarely changes.
- 📄 **`ROADMAP.md`** — *how* you get there. Four lanes (Now / Next / Later /
  Horizon) plus the North Star metric. It changes every week.

```mermaid
flowchart LR
  DEST["DESTINATION.md<br/>what done looks like<br/>(rarely changes)"] -->|points to| ROAD["ROADMAP.md<br/>Now / Next / Later<br/>(changes weekly)"]
  ROAD --> LED["Goal ledger<br/>intent behind each task"]
  LED --> PLAN["/daily-plan<br/>ranked by North Star"]
  PLAN -->|every morning| YOU(["You: the highest-leverage<br/>next step"])
```

The roadmap's "done when" cell **points to** the destination rather than
copying it — one source of truth, never two drifting versions. A built-in
**goal ledger** records the intent behind each piece of work so that, even
across many chats and many days, what you *meant* to do stays linked to what
actually shipped. **`/daily-plan`** reads all of it each morning and ranks your
work by North Star impact, so you always open a session knowing the single
highest-leverage thing to do next.

If your project is genuinely open-ended exploration with no measurable
end-state, `/setup` notices and skips forcing a fake destination — honesty over
ceremony.

---

## 5 · The full toolkit, grouped

Around **90+ skills**, **28 commands**, **~25 specialist agents**, and **~60
safety/efficiency hooks** ship in the box. You rarely call most of them by name —
Claude reaches for the right one automatically. Grouped by what they're for:

### 🧭 Think before you build — first principles & systems thinking
A "framing audit" checks you're answering the *right question* before you commit.

| Tool | What it does |
|---|---|
| `/reduce-to-first-principles` | Strips a proposal to its irreducible question; flags hidden assumptions |
| `/check-commensurability` | "Are we comparing apples to pears?" — rates how solid a comparison really is |
| `/map-feedback-loops` | Projects the second-order ripple effects of a decision over time |
| `/diagnose-bottleneck` | Finds the one real constraint slowing a system down |
| `/decide-under-uncertainty` | Structures an option-choice once the framing is sound |
| `/audit-artefact-grounding` | Checks whether a skill/rule has quietly drifted from its purpose |

### 🏛️ The Council — structured disagreement on demand
| Tool | What it does |
|---|---|
| `/council` | 5–8 AI advisors (optimist, devil's advocate, neutral analyst, reliability engineer, and more) debate a decision from opposing angles, then synthesise |
| `/code-council` | The same idea for code: 6–9 reviewers (security, silent-failure, performance, spec-alignment…) produce a Pass / Advisory / Blocking verdict, each finding independently double-checked |

### 🚀 Ship it — autonomous, with guardrails
| Tool | What it does |
|---|---|
| `/autovibe` | The full loop in one command: plan → council → execute → code review → ship |
| `/ship` | Commit, branch, and open a pull request safely (quick / PR / hotfix modes) |
| `/execute` | Turn an approved plan into working code |
| `/verify-shipped` | Cross-checks that what you *think* shipped actually deployed (catches silent drift) |
| `/e2e-test` | Self-healing end-to-end browser tests with database validation |

### 🗺️ See what's actually there — a live map of your project

Every project drifts. Configs get hand-edited in the cloud, code changes don't make it back to the repo, dashboards quietly tell different stories. The template ships a **live map** of your real system — four scrapers read your database, your cloud automations, your code, and your in-repo configs, and write to a single JSON file per repo. Two read tools sit on top.

| Tool | What it does |
|---|---|
| `/topology status` | The map at a glance — counts, freshness per source, what's not yet wired |
| `/topology health` | One verdict — FRESH / STALE / PARTIAL — plus per-source coverage and any anomalies |
| `/topology reconcile` | Where the live system has drifted from the repo (e.g. a hand-edited workflow), ranked by impact, with one named action per drift (`revert` / `reconcile` / `approve_as_intentional` / `escalate`) |
| `topology-substrate` skill | The shared map file (one JSON, per repo, gitignored) + the helpers the four scrapers write to |
| Four emitters | `supabase-live-emitter` (live Postgres tables / RLS / RPCs), `n8n-cloud-emitter` (live workflows), `code-emitter` (TypeScript + edge functions), `repo-config-emitter` (in-repo n8n exports + `vercel.json` + package config) |

> **Honest scope.** This ships the "actual" half (the live map) and the "drift" half (live-vs-repo). The third half — *intended-vs-actual* drift (intent capture) — is a named future step, not in the box yet. Doctrines 04–06 in `docs/operational-doctrine/` explain the full design. Run it now to see what you actually have; run it later for the proper drift catch.

### 💸 Spend AI budget wisely — token efficiency
The template is built to make your AI accounts last far longer.

| Tool | What it does |
|---|---|
| `caveman` skill (always on) | Strips filler from replies — same meaning, fewer tokens |
| Layman voice (always on) | Plain-English answers you can forward to a non-technical teammate |
| MCP token-saver hooks (~12) | Block wasteful patterns automatically: no whole-file fetches, no `SELECT *`, no full-page screenshots, smart database queries, never dumping giant tool lists |
| `prime-lite` | A <2,000-token state briefing instead of a full context reload |

### 🧠 Memory & handoff — never lose context
| Tool | What it does |
|---|---|
| `/prompt-forge` | Turns a messy idea into a production-grade prompt for a fresh chat |
| `/Master-Continuation-Prompt` | A full, self-contained handoff so a new session resumes exactly where you left off |
| `/reflect` | Spots patterns worth turning into new skills |
| `refactor-memory-md` / `refactor-claude-md` | Keep the memory and project files lean |

### 📓 Second brain — Obsidian + knowledge intelligence
| Tool | What it does |
|---|---|
| `obsidian-second-brain` | Connect an Obsidian vault for durable, cross-session memory |
| `/vault-review`, `/vault-sync`, `/trace`, `/drift`, `/emerge`, `/graduate` | Surface patterns, sync notes into Claude's recall path, promote durable ideas |
| `ki-*` skills (research, profile, insight, evaluate, apply, vault) | A "knowledge intelligence" pipeline that captures and acts on incoming information |

### 🤝 Work with your team & reach the world
| Tool | What it does |
|---|---|
| `/collab` | Drop a shared idea, bug, question, or decision; a teammate's `/daily-plan` pulls it in automatically, against *their* own context |
| WhatsApp (via Wassenger) / Telegram | Send and triage messages from a chat — pick whichever messenger you prefer |

### 🗓️ Control your Google Workspace
Drive your whole Google account from a chat (needs a small `gws` command-line tool, which Claude helps you install):

| Tool | What it does |
|---|---|
| `gws-gmail` | Send, read, triage, reply to, and forward email |
| `gws-calendar` · `gws-meet` | Schedule events and meetings |
| `gws-docs` · `gws-sheets` · `gws-drive` | Create and edit documents, spreadsheets, and files |
| `gws-tasks` · `gws-keep` | Manage tasks and notes |

### 🎨 Frontend & design
| Tool | What it does |
|---|---|
| `ui-design-system` *(branded name being retired)* | A premium, minimal design system + dark preset |
| `/design-review` | Visual + accessibility + responsive audit of a built UI |
| `landing-page-mvp` | A fast, conversion-aware landing page |
| `tailwind-shadcn-system`, `data-table-design`, `build-dashboard`, `kpi-dashboard-design`, `guided-tour` | Component patterns, tables, dashboards, and onboarding tours |

### 🌐 Deploy & infrastructure
| Tool | What it does |
|---|---|
| `/deploy-vercel` | Ship a frontend to Vercel with the right cache + speed settings |
| `digitalocean` / `digitalocean-infra` | Provision and manage DigitalOcean (or any VPS) infrastructure |
| `lovable-to-vercel-migration` | Move a Lovable.dev app onto Vercel cleanly |
| `dev-prod` | Keep production safe — route changes through a staging copy first, with promotion + rollback discipline |

**Bring your own host.** Vercel, Lovable, DigitalOcean, or any VPS — your
choice. The GitHub command-line tool and GitHub itself work out of the box for
branches, pull requests, and releases.

### 🛡️ Security — verify your own work
| Tool | What it does |
|---|---|
| `master-security-review` | Deep, multi-area security review (auth, RLS, edge functions, injection) |
| `security-scan-agentshield` | Fast scan for the common high-impact issues |
| `security-threat-model` | Build a threat model for a repo |
| `better-auth-security`, `saas-multi-tenant-auth` | Auth and multi-tenant isolation patterns |
| `safe-bash` | Audit-logged, injection-resistant shell for privileged steps |

### 🗂️ Research, diagrams & decks
| Tool | What it does |
|---|---|
| `/agentresearch` / `deep-research` | Coordinated multi-agent research with independent verification |
| `competitive-intelligence` | Competitor profiles, SWOT roll-ups, positioning |
| `/diagram` | Generates Excalidraw diagrams that argue a point visually |
| `/present` | Premium, minimal presentation decks |

### 🧩 Parallel sessions & worktrees
| Tool | What it does |
|---|---|
| `/where` | Plain-English map of every running chat, branch, and working copy — derived live from git, never a stale list |
| Worktree guardrails | Each chat gets its own isolated working copy so two sessions never corrupt each other's files |
| `/build-with-agent-team` | Several Claude instances build in parallel, contract-first (needs `tmux`) |
| `ssh-claude-setup` | The plumbing for launching fresh Claude sessions over SSH (advanced) |

### 🗄️ Databases
`postgres`, `supabase-postgres-best-practices`, `postgresql-code-review`,
`postgresql-patterns`, `supabase-database-hygiene` — performance rules, safe
query patterns, and hygiene checks with worked SQL examples.

### ♻️ Keep improving — skill-craft & templatisation
| Tool | What it does |
|---|---|
| `skill-creator` | Turn a repeated pattern into a new reusable skill |
| `skill-auditor-merger` | Ingest an external skill, audit it, merge the best of both |
| `/reflect` | Analyse how you've used Claude Code this session — surface patterns worth keeping |
| `apply-insights` | Turn those insights into concrete improvements to your own setup |
| `/push-to-template` | Contribute an improvement back to your template |
| `/update-latest` | Pull new skills the template gained since your last sync |

> **Keep getting better at this.** Run `/reflect` now and then to see how you've
> been using Claude Code, then `apply-insights` to fold what it learns straight
> into your project — your setup improves the more you use it.

*(Plus monitoring dashboards, cost-spike diagnostics, marketing skills, and
more — Claude surfaces them when relevant.)*

---

## 6 · Your daily rhythm

```
Morning   →  /daily-plan      ranked work list, North-Star weighted, waits for your "go"
During    →  describe work    Claude picks the right skills; hooks keep it safe + cheap
Shipping  →  /ship            commit + PR, with pre-flight safety gates
            →  /verify-shipped confirm it actually deployed (no silent drift)
End        →  (automatic)     a session summary + memory + second-brain sync are written for you
```

```mermaid
flowchart LR
  M(["Morning"]) --> P["/daily-plan<br/>ranked work list"]
  P --> W["Build —<br/>describe it in plain English"]
  W --> S["/ship<br/>commit + PR, safely"]
  S --> V["/verify-shipped<br/>confirm it really deployed"]
  V --> E(["Session summary +<br/>memory saved for you"])
```

Behind the scenes, **session hooks** run at the start, middle, and end of every
chat: loading your context in, capturing decisions to your second brain, and
writing a durable session log so tomorrow's chat starts informed. Each new chat
can also start in its own isolated working copy so parallel sessions never
collide.

---

## 7 · Opt-in walkthroughs (you choose)

`/setup` offers these, and you can ask for any of them at any time. They're
honestly labelled by readiness so you always know what you're getting:

| Walkthrough | Status | What you get |
|---|---|---|
| **Connect your second brain (Obsidian)** | ✅ Ready | Sign up for Obsidian, point the template at a vault, and you inherit the start/mid/end-of-session sync, entity tracking, and visual knowledge graph. Claude will help you decide whether you want one vault per project or sub-projects under one. |
| **Parallel agent teams** | ✅ Ready | Several Claudes build at once, contract-first. Needs a terminal multiplexer (`tmux`, or `cmux` for the multi-pane experience) — Claude walks you through installing it. |
| **Autonomous "autofire" shipping** | ⚙️ Advanced | After a clean ship, a fresh chat launches itself over SSH to continue the next step. Needs an automation workflow + a secure tunnel; Claude walks you through the SSH setup. |
| **Cheaper models via OpenRouter** | ⚙️ Advanced | Route some work through lower-cost models (including strong Chinese open models) to stretch budget. Claude helps you wire it up. |
| **Scheduled & recurring agents** | ✅ Ready | Set Claude to run a task on a schedule (a morning brief, a nightly check) using built-in scheduling. |
| **Team collaboration (`/collab`)** | ✅ Ready | Drop a shared note — idea, bug, question, decision — and a teammate's `/daily-plan` picks it up automatically. Fill in 📄 the team registry (`team.json`) and you're set. |
| **Control your Google Workspace** | ✅ Ready | Drive Gmail, Calendar, Docs, Drive, Sheets, Tasks, Meet, and Keep from chat. Needs the small `gws` command-line tool — Claude walks you through installing it. |
| **Dev / prod separation** | ✅ Ready | Route changes through a staging copy first, with promotion + rollback discipline, so an autonomous run can't touch production by accident. |
| **Messaging bridge — WhatsApp or Telegram** | ⚙️ Advanced | Pipe incoming messages into the `ki-*` knowledge pipeline. The skills ship; the bridge (WhatsApp via Wassenger, or Telegram — your choice) is wired up with a guided walkthrough. |
| **Migrate to a cheaper PI-to-PI agent stack** | ⚙️ Optional | Move the repo to a cheaper agent stack entirely. Fully optional, advanced — ask and I'll link you the walkthrough. |
| **API cost tracking / agency portal** | 🔜 Coming | Still being finished on our side — not in this template yet. Tell me what you need and I'll help you set it up directly. |

> I'd rather tell you something is "coming" than pretend it ships. Everything
> marked ✅ works today; ⚙️ works with a guided setup; 🔜 isn't in the box yet.

---

## 8 · Credentials & security, done properly

If you connect external tools, your keys deserve enterprise-grade handling.
Here's how the template does it and what it asks of you:

**How keys are stored**
- A one-time helper (`bootstrap.sh` on Mac) asks for each key, hides it as you
  type, and writes it to a private file on your machine with locked-down
  permissions (`chmod 600` — owner-only). It is **never** committed.
- The real config files (the one holding your keys, your local settings) are
  already in the ignore list, so git physically cannot publish them.
- On Windows, `/setup` walks you through the equivalent using the Windows-safe
  store; the principle is identical — keys stay local.

**Best practice the template nudges you toward** (and where we've been weak
ourselves, so learn from it):
- **Rotate and scope your tokens.** Give each token only the access it needs
  (a GitHub token scoped to one repo, a read-only database key where reads are
  all you need), and refresh them periodically.
- **Never paste a secret into a chat or a committed file.** If you ever do by
  accident, rotate that key immediately.
- **Confirm before anything irreversible.** Deploying to production, sending a
  real message to a real person, or deleting a branch always asks first — the
  template keeps those off the auto-allow list on purpose.

Want a hand? Ask Claude to *"set up my credentials securely"* and it will run the
helper, check your ignore rules, and even do as much as possible inside your
terminal so you barely have to touch anything.

---

## 9 · Staying up to date

This template keeps improving. To pull the latest skills, commands, and hooks
into your project **without re-downloading or cloning**, run:

```
/update-latest
```

It reads the upstream template's changelog, shows you a plain-English "what's
new", and lets you accept each addition with a preview. The upstream source is
recorded in 📄 `.claude/template-source.md` — point it at whichever copy of the
template you were given.

Found something great and improved it? **`/push-to-template`** generalises your
improvement (strips out anything project-specific) and contributes it back, so
everyone benefits.

> **Download, don't clone, for friends.** Hand people a downloaded copy so it's
> cleanly theirs. `/update-latest` still lets them pull improvements forever —
> no git relationship required.

---

## 10 · The philosophy underneath

A few principles shaped every choice here:

- **Spend tokens like money.** Never dump giant tool lists, never fetch a whole
  file for one line, always use smart targeted queries. Your AI accounts should
  last.
- **Plain English first.** Answers are written so you could forward them to a
  non-technical teammate without translating. Jargon is defined the first time
  it appears.
- **Frame before you solve.** The most expensive mistake is a thorough answer to
  the wrong question — so the template makes a framing check compulsory before
  big decisions.
- **Decide, don't menu.** When there's a clearly best path, the template takes
  it and tells you, instead of handing you a three-option quiz.
- **Disagree on purpose.** A council with a built-in devil's advocate, and code
  reviewers loyal to the project rather than your feelings, keep quality honest.
- **Verify, never assume.** "Done" needs evidence — a passing test, a real
  deploy, a git check — not a confident claim.

---

## Credits & licence

- Foundational PSB (Prime · Specs · Build) methodology from the
  [Claude Code Project Guide](https://youtu.be/aQvpqlSiUIQ).
- Several skills were ingested from the community (via `skill-auditor-merger`),
  audited, and improved.

**Licence:** MIT — use it, fork it, make it yours.
