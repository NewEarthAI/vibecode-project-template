# NewEarth AI — Central Hub

Central command center for NewEarth AI — an AI automation agency and parent company for AI-related businesses.

## Overview

This repo serves as the parent hub with awareness of all clients, projects, automations, and business operations across all NewEarth AI ventures:

- **NewEarth AI Agency** — AI transformation partner for businesses (logistics, PropTech)
- **BuyBox AI / DispoDaddy** — Real estate deal analysis SaaS
- **Property Business** — AI infrastructure for real estate operations

## Structure

```
.claude/
├── commands/              # Slash commands (/setup, /prime, /plan, etc.)
│   ├── prime.md           # Bootstrap: understand project
│   ├── plan.md            # Planning: create implementation specs
│   └── setup.md           # Guided project setup
├── agents/                # Sub-agent definitions
│   ├── fetch_docs.md      # Documentation fetcher
│   ├── test_writer.md     # Test generator
│   └── dashboard-specialists/  # 11 specialized agents
├── skills/                # Reusable knowledge
│   ├── mcp-token-optimizer/       # Token-efficient MCP calls
│   ├── progressive-disclosure/    # 3-tier data loading
│   ├── n8n-data-flow-integrity/   # n8n workflow safety
│   ├── agent-research/            # Multi-agent research
│   ├── skill-creator/             # Create new skills
│   └── project-template-setup/    # /setup command guide
├── hookify.*.local.md     # MCP token optimization rules (8 active)
└── settings.local.json    # MCP server configuration (14 servers)

specs/                     # Implementation specs (vision, domain model)
docs/                      # Architecture & reference docs
ai_docs/                   # Technology documentation cache
reports/                   # Analysis reports
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Database | Supabase (3 instances) |
| Automations | n8n (2 instances), Make.com |
| Frontend | Lovable.dev, Next.js, Tailwind |
| AI/ML | OpenAI, LangChain, Mistral (OCR), Claude |
| Comms | Wassenger (WhatsApp), Gmail |
| DevTools | GitHub, Claude Code, Playwright |

## Getting Started

1. Open in Claude Code
2. Run `/prime` to verify Claude's understanding
3. Run `/plan "task"` to create implementation specs
4. Start building

## Related Repos

| Repo | Purpose |
|------|---------|
| [BuyBox-AI](https://github.com/NewEarthAI/BuyBox-AI) | Real estate deal analysis SaaS |
| [bonus-homes](https://github.com/NewEarthAI/bonus-homes) | Bonus Homes client project (HAP Engine) |
| [nirvana-freight-fleet-insights-automation](https://github.com/NewEarthAI/nirvana-freight-fleet-insights-automation) | Nirvana logistics client |
| [Agency-Main](https://github.com/NewEarthAI/Agency-Main) | Agency resources |

## Credits

- PSB System methodology from [Claude Code Project Guide](https://youtu.be/aQvpqlSiUIQ)
- Template originally from [NewEarthAI/claude-code-project-template](https://github.com/NewEarthAI/claude-code-project-template)

## License

MIT
