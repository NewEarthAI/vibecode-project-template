# Claude Agent SDK Session Manager

Build a full-stack application for managing Claude Agent SDK sessions. An agentic chat interface where users can create sessions, chat with Claude agents, see tool usage inline, and resume any past conversation with full history.

## Problem Statement

The Claude Agent SDK doesn't expose an API to fetch historical messages when resuming a session. Claude remembers the context internally, but you can't programmatically retrieve past messages to display in a UI.

**Solution**: Store messages in our own database while using the SDK's session_id for context resumption.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | React, TypeScript, Vite, Tailwind, shadcn/ui |
| Backend | Python, FastAPI, sse-starlette |
| Database | SQLite with aiosqlite |
| Agent SDK | claude-agent-sdk |

## Project Structure

```
agent-session-manager/
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py           # FastAPI app entry
│   │   ├── database.py       # SQLite connection + queries
│   │   ├── models.py         # Pydantic models
│   │   ├── routes/
│   │   │   ├── sessions.py   # Session CRUD
│   │   │   └── chat.py       # Chat with SSE streaming
│   │   └── sdk_client.py     # Claude Agent SDK wrapper
│   ├── requirements.txt
│   └── pyproject.toml
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   │   ├── SessionSidebar.tsx
│   │   │   ├── ChatView.tsx
│   │   │   ├── MessageList.tsx
│   │   │   ├── MessageBlock.tsx
│   │   │   ├── ToolUseCard.tsx
│   │   │   └── NewSessionDialog.tsx
│   │   ├── lib/
│   │   │   ├── api.ts
│   │   │   └── types.ts
│   │   ├── App.tsx
│   │   └── main.tsx
│   ├── package.json
│   ├── vite.config.ts
│   └── tailwind.config.js
└── README.md
```

## Agent Build Order & Communication

When building with an agent team, agents MUST follow this contract-first sequence:

### Phase 1: Database Agent
1. Build schema, CRUD functions, Pydantic models
2. **Send function signatures and model definitions** to lead
3. Lead verifies and forwards to backend agent

### Phase 2: Backend Agent (after receiving DB contract)
1. Build FastAPI app, routes, SSE streaming, SDK client
2. **Send complete API contract** to lead — must include:
   - Exact endpoint URLs with trailing slashes noted
   - Exact request/response JSON shapes
   - Exact SSE event format with all event types
   - Status codes for success and error cases
3. Lead verifies and forwards to frontend agent

### Phase 3: Frontend Agent (after receiving API contract)
1. Build React app, components, API client **conforming exactly to the verified API contract**
2. Do NOT guess endpoint URLs or response shapes — use what was provided

### Phase 4: Lead Validation
1. Contract diff — compare backend's actual endpoints vs frontend's fetch calls
2. Start both servers
3. Run E2E browser tests

## Database Schema

### Sessions Table
```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,              -- Claude SDK session_id
    title TEXT NOT NULL,
    system_prompt TEXT,               -- Optional custom system prompt
    working_directory TEXT,
    model TEXT DEFAULT 'claude-sonnet-4-20250514',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_accessed TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Messages Table
```sql
CREATE TABLE messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    role TEXT NOT NULL,               -- 'user', 'assistant', 'system'
    content TEXT,
    message_type TEXT NOT NULL,       -- 'text', 'tool_use', 'tool_result', 'thinking'
    tool_name TEXT,
    tool_input TEXT,                  -- JSON
    tool_output TEXT,                 -- JSON
    is_error BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

CREATE INDEX idx_messages_session ON messages(session_id);
```

## API Contract

**IMPORTANT:** This is the authoritative API contract. Both backend and frontend MUST conform to these exact specifications. The lead agent should verify alignment before integration.

### Endpoints

| Method | Endpoint (exact) | Request Body | Response |
|--------|-------------------|-------------|----------|
| GET | `/health` | — | `{"status": "ok"}` |
| POST | `/api/sessions/` | `{"title": "...", "system_prompt?": "...", "working_directory?": "...", "model?": "..."}` | `SessionResponse` (200) |
| GET | `/api/sessions/` | — | `SessionResponse[]` (200) |
| GET | `/api/sessions/{id}` | — | `{"session": SessionResponse, "messages": MessageResponse[]}` (200) or 404 |
| POST | `/api/sessions/{id}/chat` | `{"message": "..."}` | SSE stream |
| DELETE | `/api/sessions/{id}` | — | 204 No Content |

**Note:** POST and GET list endpoints use **trailing slash** (`/api/sessions/`). GET by ID, DELETE, and chat do NOT use trailing slash.

### Response Shapes

**SessionResponse:**
```json
{"id": "uuid", "title": "string", "system_prompt": "string|null", "working_directory": "string|null", "model": "string", "created_at": "ISO8601", "last_accessed": "ISO8601"}
```

**MessageResponse:**
```json
{"id": 1, "session_id": "uuid", "role": "user|assistant", "content": "string|null", "message_type": "text|thinking|tool_use|tool_result", "tool_name": "string|null", "tool_input": "string|null", "tool_output": "string|null", "is_error": false, "timestamp": "ISO8601"}
```

**GET /api/sessions/{id} returns a NESTED object** (not flat):
```json
{
  "session": { "SessionResponse fields" },
  "messages": [ "MessageResponse", "..." ]
}
```
The frontend must destructure this into a flat `SessionWithMessages` for its internal state.

## SDK Integration

### Authentication

**NO MOCKING REQUIRED.** We are already authenticated with Anthropic via global CLI auth. The Claude Agent SDK automatically uses these credentials. Do not mock the SDK or create fake responses — test against the real API.

### Key Pattern: Dual Storage with Text Accumulation

**IMPORTANT:** The SDK streams text in small chunks. Do NOT store each chunk as a separate database row — this causes the frontend to render N separate bubbles when loading message history. Instead, **accumulate text chunks** and store ONE row per complete text response.

```python
async def chat(session_id: str, user_message: str):
    # 1. Store user message in OUR database
    await db.add_message(session_id, "user", user_message, "text")

    # 2. Accumulate text chunks, store other types immediately
    accumulated_text = ""

    async for msg in query(prompt=user_message, options=ClaudeAgentOptions(resume=session_id)):
        if msg.type == "text":
            accumulated_text += msg.content  # Accumulate, don't store yet
        elif msg.type == "tool_use":
            # Flush accumulated text before tool use
            if accumulated_text:
                await db.add_message(session_id, "assistant", accumulated_text, "text")
                accumulated_text = ""
            await db.add_message(session_id, "assistant", None, "tool_use", tool_name=msg.tool_name, ...)
        elif msg.type == "done":
            # Flush remaining accumulated text
            if accumulated_text:
                await db.add_message(session_id, "assistant", accumulated_text, "text")
                accumulated_text = ""

        # 3. Yield EVERY event to frontend via SSE (streaming feel)
        yield msg
```

This way the frontend gets real-time streaming chunks, but the database stores one clean row per response.

### Capturing Session ID

For new sessions, capture the session_id from the init message:

```python
if isinstance(message, SystemMessage) and message.subtype == "init":
    session_id = message.data.get("session_id")
```

### SSE Event Types

```typescript
type StreamMessage =
  | { type: 'text'; content: string }
  | { type: 'thinking'; content: string }
  | { type: 'tool_use'; tool_name: string; tool_input: object }
  | { type: 'tool_result'; content: string; is_error: boolean }
  | { type: 'session_init'; session_id: string }
  | { type: 'done'; session_id: string; total_cost_usd: number; duration_ms: number }
```

## Cross-Cutting Concerns

These behaviors span multiple agents and MUST be explicitly assigned during the build:

| Concern | Owner | Coordinates With | Detail |
|---------|-------|-----------------|--------|
| Text chunk accumulation | Backend | Frontend | Backend accumulates streamed text chunks into ONE DB row. Frontend renders one bubble per DB row on reload. |
| URL trailing slashes | Backend | Frontend | FastAPI router uses trailing slashes on collection endpoints. Frontend fetch URLs must match exactly. |
| Response envelope | Backend | Frontend | GET session returns nested object, NOT flat. Frontend must destructure. |
| UI accessibility | Frontend | Lead (for E2E testing) | All interactive elements need aria-label attributes. Delete buttons must be clickable. |
| SSE event format | Backend | Frontend | Exact JSON shapes for each event type documented in API Contract. Both sides must match. |

## Frontend Components

### SessionSidebar
- List of sessions sorted by last_accessed
- New session button opens NewSessionDialog
- Click session to load it
- Delete button per session with aria-label="Delete session"

### NewSessionDialog
- Title input (required)
- System prompt textarea (optional, placeholder with examples)
- Working directory input (optional, defaults to ".")
- Create button

### ChatView
- Message input at bottom
- Send button (disabled while streaming)
- Shows session title and metadata

### MessageList
- Scrollable container
- Auto-scroll on new messages
- Groups consecutive assistant messages

### MessageBlock
Renders based on message_type:
- **text**: Chat bubble (user=blue right, assistant=gray left)
- **tool_use**: ToolUseCard component
- **tool_result**: Inline result (collapsible if long)
- **thinking**: Italic, muted, collapsed by default

### ToolUseCard
- Icon + tool name header
- Collapsed: one-line summary
- Expanded: formatted JSON input and output
- Error state styling for is_error=true

## Styling

- shadcn/ui as component base
- Tailwind for custom styling
- Dark mode support
- Responsive: sidebar collapses on mobile
- User messages: right-aligned, blue background
- Assistant messages: left-aligned, gray background
- Tool cards: subtle border, expand/collapse animation

## Dependencies

### Backend
```
fastapi>=0.109.0
uvicorn[standard]>=0.27.0
sse-starlette>=1.8.0
aiosqlite>=0.19.0
claude-agent-sdk>=0.1.0
pydantic>=2.0.0
python-dotenv>=1.0.0
```

### Frontend
```
react
react-dom
typescript
vite
tailwindcss
@shadcn/ui
lucide-react
```

## Acceptance Criteria

1. **New Session**: User creates session with title + optional system prompt -> session saved
2. **Chat**: User sends message -> response streams in real-time -> tool usage visible inline
3. **Resume**: User clicks past session -> full message history loads -> can continue chatting
4. **Delete**: User deletes session -> session and messages removed
5. **Error Handling**: Network/SDK errors displayed gracefully
6. **Responsive**: Works on desktop and mobile

## Validation

Each agent validates their own domain before reporting done. The lead agent runs end-to-end validation after all agents complete.

### Database Validation

Run from backend/:

```bash
python -c "
import asyncio
from app.database import init_db, get_db
asyncio.run(init_db())
print('Schema created')
"
```

### Backend Validation

Run from backend/:

```bash
uvicorn app.main:app --reload &
sleep 2
curl -s http://localhost:8000/health | grep -q 'ok' && echo 'Server running'
```

### Frontend Validation

Run from frontend/:

```bash
npm install && echo 'Dependencies installed'
npx tsc --noEmit && echo 'TypeScript valid'
npm run build && echo 'Build successful'
```

### End-to-End Validation (Lead Agent)

After all agents report done, the lead agent spins up both servers and runs E2E validation.

**Success criteria:**
- All steps pass
- No server errors in terminal
- SSE streaming works (responses appear incrementally, not all at once)
- Session persistence works across page refresh
- Tool use cards render correctly with real tool output (not mocked)
