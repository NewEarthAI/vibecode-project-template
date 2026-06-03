---
name: pydantic-ai-agent-builder
description: |
  Expert guidance for building AI agents with Pydantic AI framework. Use when creating multi-agent systems, AI orchestration workflows, or structured LLM applications with type safety and validation. (user)
version: 2.0.0
triggers:
  - building AI agents
  - multi-agent systems
  - pydantic AI
  - structured LLM outputs
  - type-safe AI workflows
  - agent orchestration
  - dependency injection agents
parameters:
  - name: pattern_type
    type: enum
    values: [basic, advanced, multi-agent, production]
    description: Type of pattern to focus on
validated_on:
  - movie recommendation agent
  - code review agent
  - research orchestrator
  - RAG pipeline
  - multi-agent workflow system
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
paths:
  - "**/*.py"
---

# Pydantic AI Agent Builder

Comprehensive system for building production-grade AI agents using Pydantic AI with type safety, structured outputs, and enterprise patterns.

## Core Concepts

Pydantic AI is a Python agent framework designed to make it less painful to build production-grade applications with Generative AI.

### Key Features

- **Type-safe**: Built on Pydantic for runtime validation
- **Model-agnostic**: Works with OpenAI, Anthropic, Gemini, Ollama
- **Structured outputs**: Guaranteed valid responses
- **Dependency injection**: Clean testing and modularity
- **Streaming support**: Real-time responses
- **Tool/function calling**: External integrations

## Architectural Components

Understanding Pydantic AI's architecture helps build maintainable agents. These are the conceptual building blocks:

### AgentDefinition (Immutable Configuration)

The `Agent` class is fundamentally an **immutable configuration container**. It holds model, system prompt, result type, and tools - but NOT conversation state.

```python
from pydantic_ai import Agent
from pydantic import BaseModel

class TaskResult(BaseModel):
    answer: str
    confidence: float

# AgentDefinition: immutable, reusable, thread-safe
task_agent = Agent(
    'anthropic:claude-3-5-sonnet-20241022',
    result_type=TaskResult,
    system_prompt='You are a task completion assistant.',
    retries=3,
)
# This agent can be used across multiple concurrent requests
```

| ❌ Wrong | Why Bad | ✅ Right |
|----------|---------|----------|
| `agent.current_task = task` | Mutable state on agent | Pass state via `deps` |
| `agent.history = []` | Breaks thread safety | Use `RunContext` |
| Recreating agent per request | Wastes resources | Reuse agent instance |

### AgentRunner (Stateful Execution)

Each `agent.run()` call creates an implicit **AgentRunner** that manages conversation history for that specific execution.

```python
# Each run() creates isolated state
async def process_request(user_input: str):
    # This run has its own conversation history
    result = await task_agent.run(user_input)

    # Access run-specific data
    print(f"Messages: {result.all_messages()}")
    print(f"Usage: {result.usage()}")
    print(f"Cost: ${result.cost():.4f}")
    return result.data

# Concurrent runs are isolated - no state bleeding
results = await asyncio.gather(
    process_request("Task A"),
    process_request("Task B"),
)
```

### DependencyContainer (Injectable Context)

Use `@dataclass` containers for runtime dependencies. This enables clean testing and modularity.

```python
from dataclasses import dataclass
from pydantic_ai import Agent, RunContext

@dataclass
class ServiceDeps:
    """Container for all runtime dependencies."""
    db_connection: DatabasePool
    api_client: APIClient
    current_user_id: str
    feature_flags: dict[str, bool]

agent = Agent(
    'openai:gpt-4o',
    deps_type=ServiceDeps,
)

@agent.tool
async def get_user_data(ctx: RunContext[ServiceDeps]) -> dict:
    """Tool accesses deps through typed context."""
    return await ctx.deps.db_connection.fetch_user(ctx.deps.current_user_id)

# Runtime injection
deps = ServiceDeps(
    db_connection=pool,
    api_client=client,
    current_user_id="user_123",
    feature_flags={"new_feature": True},
)
result = await agent.run("Get my profile", deps=deps)
```

| ❌ Wrong | Why Bad | ✅ Right |
|----------|---------|----------|
| Global variables in tools | Untestable, race conditions | Inject via `deps` |
| `import config` in tool body | Tight coupling | Pass config in deps |
| Mutable deps container | State leakage | Use immutable dataclass |

### ResultValidator (Type-Safe Outputs)

Validation happens at two levels: Pydantic model validation AND custom business logic.

```python
from pydantic_ai import Agent, ModelRetry, RunContext
from pydantic import BaseModel, Field, field_validator

class OrderResult(BaseModel):
    """Validated order output."""
    item_id: str = Field(pattern=r'^[A-Z]{3}-\d{6}$')
    quantity: int = Field(ge=1, le=100)
    total_price: float = Field(ge=0)

    @field_validator('total_price')
    @classmethod
    def validate_price(cls, v: float, info) -> float:
        """Price must match quantity * unit price."""
        # Note: This runs AFTER LLM output, before final return
        return round(v, 2)

agent = Agent('openai:gpt-4o', result_type=OrderResult, retries=3)

@agent.result_validator
async def validate_order(ctx: RunContext, result: OrderResult) -> OrderResult:
    """Business logic validation with retry capability."""
    # Check inventory (async operation)
    available = await check_inventory(result.item_id)
    if result.quantity > available:
        raise ModelRetry(f'Only {available} units available. Adjust quantity.')
    return result
```

**Critical Warning**: Type coercion vs validation:
```python
# ❌ WRONG: Defeats type safety
raw_result = await agent.run("...")
price = str(raw_result.data.total_price)  # Coercing back to string

# ✅ RIGHT: Use validated types directly
result = await agent.run("...")
order: OrderResult = result.data  # Fully validated
await process_order(order)  # Pass typed object
```

### ModelManager (Backend Abstraction)

Pydantic AI abstracts LLM backends. Use `infer_model` for custom configurations.

```python
from pydantic_ai import Agent
from pydantic_ai.models import infer_model
from openai import AsyncOpenAI

# Custom client configuration
custom_client = AsyncOpenAI(
    api_key=os.getenv("OPENAI_API_KEY"),
    base_url="https://custom-proxy.example.com/v1",
    timeout=120.0,
    max_retries=5,
)

# Wrap in Pydantic AI model
custom_model = infer_model('openai:gpt-4o', openai_client=custom_client)

# Use across agents
agent = Agent(custom_model, system_prompt="...")

# Runtime model switching
result = await agent.run(
    "Analyze this",
    model='anthropic:claude-3-5-sonnet-20241022',  # Override for this run
)
```

## Basic Agent Patterns

### 1. Simple Agent

```python
from pydantic_ai import Agent
from pydantic import BaseModel

# Define response model
class MovieRecommendation(BaseModel):
    title: str
    year: int
    genre: str
    reason: str

# Create agent
agent = Agent(
    'openai:gpt-4o',
    result_type=MovieRecommendation,
    system_prompt='You are a movie recommendation expert.',
)

# Run agent
async def get_recommendation(preferences: str):
    result = await agent.run(preferences)
    return result.data

# Usage
recommendation = await get_recommendation("sci-fi with time travel")
print(f"{recommendation.title} ({recommendation.year})")
```

### 2. Agent with Tools

```python
from pydantic_ai import Agent, RunContext
from dataclasses import dataclass

@dataclass
class SearchDeps:
    """Dependencies for search tools."""
    api_key: str
    database_url: str

agent = Agent(
    'anthropic:claude-3-5-sonnet-20241022',
    deps_type=SearchDeps,
    system_prompt='You are a research assistant with web search capabilities.',
)

@agent.tool
async def search_web(ctx: RunContext[SearchDeps], query: str) -> str:
    """Search the web for information."""
    # Use ctx.deps.api_key for API access
    results = await perform_search(query, ctx.deps.api_key)
    return f"Found {len(results)} results for '{query}'"

@agent.tool
async def search_database(ctx: RunContext[SearchDeps], query: str) -> list[dict]:
    """Search internal database."""
    # Use ctx.deps.database_url for DB access
    return await db_query(ctx.deps.database_url, query)

# Run with dependencies
deps = SearchDeps(
    api_key=os.getenv("SEARCH_API_KEY"),
    database_url=os.getenv("DATABASE_URL"),
)

result = await agent.run("Find information about quantum computing", deps=deps)
```

### 3. Multi-Step Agent with State

```python
from pydantic_ai import Agent
from pydantic import BaseModel, Field

class ResearchState(BaseModel):
    """Track research progress."""
    query: str
    sources_found: list[str] = Field(default_factory=list)
    summary: str = ""
    confidence: float = 0.0

class ResearchResult(BaseModel):
    """Final research output."""
    answer: str
    sources: list[str]
    confidence_score: float

agent = Agent(
    'openai:gpt-4o',
    result_type=ResearchResult,
    system_prompt='''You are a thorough researcher.
    First search for sources, then analyze them, then provide a summary.''',
)

@agent.tool
async def search_sources(ctx: RunContext[ResearchState], topic: str) -> list[str]:
    """Find relevant sources."""
    sources = await find_sources(topic)
    ctx.deps.sources_found.extend(sources)
    return sources

@agent.tool
async def analyze_source(ctx: RunContext[ResearchState], source_url: str) -> str:
    """Analyze a specific source."""
    content = await fetch_content(source_url)
    analysis = await analyze_content(content)
    return analysis

# Run research agent
state = ResearchState(query="What is quantum entanglement?")
result = await agent.run(state.query, deps=state)
```

### 4. Agent with Structured Output

```python
from pydantic_ai import Agent
from pydantic import BaseModel, Field
from typing import Literal

class CodeReview(BaseModel):
    """Structured code review output."""
    overall_quality: Literal["excellent", "good", "needs_improvement", "poor"]
    issues: list[str] = Field(description="List of identified issues")
    suggestions: list[str] = Field(description="Improvement suggestions")
    security_concerns: list[str] = Field(default_factory=list)
    performance_notes: list[str] = Field(default_factory=list)
    score: int = Field(ge=0, le=100, description="Overall score")

agent = Agent(
    'anthropic:claude-3-5-sonnet-20241022',
    result_type=CodeReview,
    system_prompt='''You are an expert code reviewer.
    Analyze code for quality, security, performance, and best practices.
    Provide actionable feedback.''',
)

async def review_code(code: str, language: str) -> CodeReview:
    prompt = f"Review this {language} code:\n\n```{language}\n{code}\n```"
    result = await agent.run(prompt)
    return result.data

# Usage
review = await review_code(open("app.py").read(), "python")
print(f"Quality: {review.overall_quality}, Score: {review.score}/100")
for issue in review.issues:
    print(f"- {issue}")
```

## Advanced Patterns

### 5. Multi-Agent Orchestration Patterns

Three primary patterns for coordinating multiple agents, each suited to different use cases.

#### Pattern A: Orchestrator/Worker

Central orchestrator distributes tasks to specialized workers, aggregates results.

```
┌─────────────────────────────────────────────────────────────┐
│                       ORCHESTRATOR                          │
│  • Receives request                                         │
│  • Decomposes into tasks                                    │
│  • Dispatches to workers                                    │
│  • Aggregates results                                       │
└────────────┬──────────────┬──────────────┬─────────────────┘
             │              │              │
       ┌─────▼────┐  ┌─────▼────┐  ┌─────▼────┐
       │ Worker A │  │ Worker B │  │ Worker C │
       │(Research)│  │(Analysis)│  │(Writing) │
       └──────────┘  └──────────┘  └──────────┘
             │              │              │
             └──────────────┴──────────────┘
                           │
                    ┌──────▼──────┐
                    │  AGGREGATED │
                    │   RESULT    │
                    └─────────────┘
```

```python
from pydantic_ai import Agent, RunContext
from pydantic import BaseModel
from dataclasses import dataclass
import asyncio

class WorkerResult(BaseModel):
    content: str
    confidence: float
    source: str

class AggregatedResult(BaseModel):
    summary: str
    worker_outputs: list[WorkerResult]
    consensus_score: float

@dataclass
class OrchestratorDeps:
    timeout_seconds: int = 30
    max_workers: int = 5

# Define specialized workers (NO tools that call orchestrator - DAG only!)
research_worker = Agent(
    'anthropic:claude-3-5-sonnet-20241022',
    result_type=WorkerResult,
    system_prompt='You are a research specialist. Find relevant information.',
)

analysis_worker = Agent(
    'openai:gpt-4o',
    result_type=WorkerResult,
    system_prompt='You are an analysis specialist. Identify patterns and insights.',
)

writing_worker = Agent(
    'anthropic:claude-3-5-sonnet-20241022',
    result_type=WorkerResult,
    system_prompt='You are a writing specialist. Create clear, concise content.',
)

# Orchestrator coordinates workers
orchestrator = Agent(
    'openai:gpt-4o',
    deps_type=OrchestratorDeps,
    result_type=AggregatedResult,
    system_prompt='''You are a project orchestrator.
    Decompose tasks, delegate to specialists, and synthesize results.''',
)

@orchestrator.tool
async def delegate_research(ctx: RunContext[OrchestratorDeps], query: str) -> WorkerResult:
    """Delegate research task to research specialist."""
    result = await asyncio.wait_for(
        research_worker.run(query),
        timeout=ctx.deps.timeout_seconds,
    )
    return result.data

@orchestrator.tool
async def delegate_analysis(ctx: RunContext[OrchestratorDeps], data: str) -> WorkerResult:
    """Delegate analysis task to analysis specialist."""
    result = await asyncio.wait_for(
        analysis_worker.run(data),
        timeout=ctx.deps.timeout_seconds,
    )
    return result.data

@orchestrator.tool
async def delegate_writing(ctx: RunContext[OrchestratorDeps], brief: str) -> WorkerResult:
    """Delegate writing task to writing specialist."""
    result = await asyncio.wait_for(
        writing_worker.run(brief),
        timeout=ctx.deps.timeout_seconds,
    )
    return result.data

# Execute orchestrated workflow
async def run_orchestrated_task(task: str):
    deps = OrchestratorDeps(timeout_seconds=30)
    result = await orchestrator.run(task, deps=deps)
    return result.data
```

**When to Use:**
- Independent subtasks that can run in parallel
- Need for specialized expertise per subtask
- Results require synthesis/aggregation

**Anti-Pattern Warning:**
| ❌ Wrong | Why Bad | ✅ Right |
|----------|---------|----------|
| Workers call orchestrator | Circular dependency | DAG-only (one direction) |
| Shared context between workers | "Collective delusion" | Isolated worker contexts |
| No timeout on workers | Hung pipelines | `asyncio.wait_for(timeout=N)` |

---

#### Pattern B: Pipeline (Sequential Chain)

Each agent transforms output, passing to the next. Type-safe transformations.

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  INPUT   │────▶│ Agent 1  │────▶│ Agent 2  │────▶│ Agent 3  │────▶ OUTPUT
│  (Raw)   │     │(Extract) │     │(Transform│     │(Validate)│
└──────────┘     └──────────┘     └──────────┘     └──────────┘
                      │                │                │
                      ▼                ▼                ▼
                 RawData          ProcessedData    ValidatedData
                 (Type A)         (Type B)         (Type C)
```

```python
from pydantic_ai import Agent
from pydantic import BaseModel, Field
from typing import Literal

# Stage 1: Extraction
class ExtractedData(BaseModel):
    entities: list[str]
    relationships: list[tuple[str, str, str]]
    raw_text: str

# Stage 2: Analysis
class AnalyzedData(BaseModel):
    entities: list[str]
    key_insights: list[str]
    sentiment: Literal["positive", "negative", "neutral"]
    confidence: float

# Stage 3: Report
class FinalReport(BaseModel):
    title: str
    executive_summary: str
    detailed_findings: list[str]
    recommendations: list[str]
    confidence_score: float = Field(ge=0, le=1)

# Pipeline stages (each is independent, no circular deps)
extractor = Agent(
    'anthropic:claude-3-5-sonnet-20241022',
    result_type=ExtractedData,
    system_prompt='Extract entities and relationships from text.',
)

analyzer = Agent(
    'openai:gpt-4o',
    result_type=AnalyzedData,
    system_prompt='Analyze extracted data for insights and sentiment.',
)

reporter = Agent(
    'anthropic:claude-3-5-sonnet-20241022',
    result_type=FinalReport,
    system_prompt='Generate executive report from analysis.',
)

class Pipeline:
    """Type-safe sequential pipeline with error boundaries."""

    async def run(self, raw_input: str) -> FinalReport:
        # Stage 1: Extract
        extract_result = await extractor.run(raw_input)
        extracted: ExtractedData = extract_result.data

        # Stage 2: Analyze (receives typed input from Stage 1)
        analysis_prompt = f"""
        Analyze the following extracted data:
        - Entities: {extracted.entities}
        - Relationships: {extracted.relationships}
        - Source text: {extracted.raw_text[:500]}
        """
        analyze_result = await analyzer.run(analysis_prompt)
        analyzed: AnalyzedData = analyze_result.data

        # Stage 3: Report (receives typed input from Stage 2)
        report_prompt = f"""
        Generate report from analysis:
        - Key insights: {analyzed.key_insights}
        - Sentiment: {analyzed.sentiment}
        - Confidence: {analyzed.confidence}
        """
        report_result = await reporter.run(report_prompt)
        return report_result.data

# Usage
pipeline = Pipeline()
report = await pipeline.run("Long document text here...")
print(f"Report: {report.title}")
print(f"Confidence: {report.confidence_score:.0%}")
```

**When to Use:**
- Sequential data transformation
- Each stage has distinct responsibility
- Output type changes between stages
- Error boundaries between stages

**Anti-Pattern Warning:**
| ❌ Wrong | Why Bad | ✅ Right |
|----------|---------|----------|
| Passing raw strings between stages | Loses type safety | Use typed models |
| No error handling between stages | One failure cascades | Wrap each stage |
| Modifying input in place | Side effects | Return new typed object |

---

#### Pattern C: Hierarchical (Manager/Specialist)

Managers delegate to specialists who may further delegate. Authority flows down.

```
                    ┌─────────────────┐
                    │  PROJECT LEAD   │
                    │   (Manager)     │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
    ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
    │   FRONTEND    │ │   BACKEND     │ │   DEVOPS      │
    │   MANAGER     │ │   MANAGER     │ │   MANAGER     │
    └───────┬───────┘ └───────┬───────┘ └───────────────┘
            │                 │
      ┌─────┴─────┐     ┌─────┴─────┐
      ▼           ▼     ▼           ▼
  ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐
  │ React │  │ CSS   │  │ API   │  │ DB    │
  │ Dev   │  │ Dev   │  │ Dev   │  │ Dev   │
  └───────┘  └───────┘  └───────┘  └───────┘
```

```python
from pydantic_ai import Agent, RunContext
from pydantic import BaseModel
from dataclasses import dataclass
from typing import Optional
import asyncio

class TaskResult(BaseModel):
    task_id: str
    status: Literal["success", "partial", "failed"]
    output: str
    sub_results: list["TaskResult"] = []

TaskResult.model_rebuild()  # For recursive type

@dataclass
class HierarchyDeps:
    depth: int = 0
    max_depth: int = 3
    parent_task_id: Optional[str] = None

# Leaf-level specialists (no delegation capability)
react_specialist = Agent(
    'anthropic:claude-3-5-sonnet-20241022',
    result_type=TaskResult,
    system_prompt='You are a React specialist. Implement React components.',
)

api_specialist = Agent(
    'openai:gpt-4o',
    result_type=TaskResult,
    system_prompt='You are an API specialist. Design and implement REST APIs.',
)

# Mid-level manager (can delegate to specialists)
frontend_manager = Agent(
    'openai:gpt-4o',
    deps_type=HierarchyDeps,
    result_type=TaskResult,
    system_prompt='''You are a frontend team lead.
    Decompose frontend tasks and delegate to specialists.''',
)

@frontend_manager.tool
async def assign_to_react_dev(
    ctx: RunContext[HierarchyDeps],
    task: str,
) -> TaskResult:
    """Assign React implementation task."""
    if ctx.deps.depth >= ctx.deps.max_depth:
        return TaskResult(
            task_id=f"react_{ctx.deps.parent_task_id}",
            status="failed",
            output="Max delegation depth reached",
        )
    result = await react_specialist.run(task)
    return result.data

# Top-level project lead (delegates to managers)
project_lead = Agent(
    'anthropic:claude-3-5-sonnet-20241022',
    deps_type=HierarchyDeps,
    result_type=TaskResult,
    system_prompt='''You are a project lead.
    Decompose projects into frontend/backend/devops and delegate to managers.''',
)

@project_lead.tool
async def delegate_to_frontend(
    ctx: RunContext[HierarchyDeps],
    requirements: str,
) -> TaskResult:
    """Delegate frontend work to frontend manager."""
    child_deps = HierarchyDeps(
        depth=ctx.deps.depth + 1,
        max_depth=ctx.deps.max_depth,
        parent_task_id="frontend",
    )
    result = await frontend_manager.run(requirements, deps=child_deps)
    return result.data

# Execute hierarchical project
async def execute_project(requirements: str) -> TaskResult:
    deps = HierarchyDeps(depth=0, max_depth=3)
    result = await project_lead.run(requirements, deps=deps)
    return result.data

# Usage
result = await execute_project("Build an e-commerce platform")
print(f"Status: {result.status}")
for sub in result.sub_results:
    print(f"  - {sub.task_id}: {sub.status}")
```

**When to Use:**
- Complex decomposition requiring multiple levels
- Clear authority/responsibility hierarchy
- Need to limit delegation depth
- Different expertise levels in pipeline

**Anti-Pattern Warning:**
| ❌ Wrong | Why Bad | ✅ Right |
|----------|---------|----------|
| Specialist calls manager | Breaks hierarchy | One-way delegation only |
| No depth limit | Infinite recursion | `max_depth` check |
| Manager does specialist work | Role confusion | Delegate, don't implement |
| Shared state across levels | Unpredictable | Pass explicit context down |

---

**Context Isolation Principle:**

All three patterns MUST maintain context isolation between agents to prevent "collective delusion":

```python
# ❌ WRONG: Shared context (delusion propagation)
shared_context = {"hallucinated_fact": "..."}
result_a = await agent_a.run("...", deps=shared_context)
result_b = await agent_b.run("...", deps=shared_context)  # Inherits hallucination!

# ✅ RIGHT: Isolated contexts
result_a = await agent_a.run("...", deps=DepsA(...))
result_b = await agent_b.run("...", deps=DepsB(...))  # Fresh context

# ✅ BETTER: Independent verification
research_result = await researcher.run(query)
# Verifier has NO access to researcher's context
verification = await verifier.run(
    f"Independently verify: {research_result.data.claims}"
)
```

### 6. Agent with Streaming

```python
from pydantic_ai import Agent
import asyncio

agent = Agent('openai:gpt-4o')

async def stream_response(prompt: str):
    """Stream agent response in real-time."""
    async with agent.run_stream(prompt) as response:
        async for chunk in response.stream_text():
            print(chunk, end='', flush=True)

        # Get final result
        final = await response.get_data()
        return final

# Usage
await stream_response("Explain quantum computing in simple terms")
```

### 7. Agent with Retry Logic

```python
from pydantic_ai import Agent, ModelRetry
from pydantic import BaseModel, Field, field_validator

class ParsedData(BaseModel):
    name: str = Field(min_length=1)
    age: int = Field(ge=0, le=150)
    email: str

    @field_validator('email')
    @classmethod
    def validate_email(cls, v: str) -> str:
        if '@' not in v:
            raise ValueError('Invalid email format')
        return v

agent = Agent(
    'openai:gpt-4o',
    result_type=ParsedData,
    retries=3,  # Retry up to 3 times on validation errors
)

@agent.result_validator
async def validate_result(ctx: RunContext, result: ParsedData) -> ParsedData:
    """Custom validation with retry."""
    if result.age < 18:
        raise ModelRetry('Age must be 18 or older. Please try again.')
    return result

# If validation fails, agent automatically retries with feedback
result = await agent.run("Extract person info: John Doe, 25, john@example.com")
```

### 8. Agent with RAG (Retrieval Augmented Generation)

```python
from pydantic_ai import Agent, RunContext
from dataclasses import dataclass
import chromadb

@dataclass
class RAGDeps:
    vector_db: chromadb.Client
    collection_name: str

agent = Agent(
    'anthropic:claude-3-5-sonnet-20241022',
    deps_type=RAGDeps,
    system_prompt='''You are a helpful assistant with access to a knowledge base.
    Always search the knowledge base before answering questions.''',
)

@agent.tool
async def search_knowledge_base(
    ctx: RunContext[RAGDeps],
    query: str,
    limit: int = 5
) -> list[str]:
    """Search vector database for relevant documents."""
    collection = ctx.deps.vector_db.get_collection(ctx.deps.collection_name)
    results = collection.query(
        query_texts=[query],
        n_results=limit,
    )
    return results['documents'][0]

# Initialize vector DB
chroma_client = chromadb.Client()
collection = chroma_client.create_collection("knowledge_base")

# Add documents
collection.add(
    documents=["Document 1 content...", "Document 2 content..."],
    ids=["doc1", "doc2"],
)

# Run RAG agent
deps = RAGDeps(vector_db=chroma_client, collection_name="knowledge_base")
result = await agent.run("What does the documentation say about X?", deps=deps)
```

### 9. Agent with Custom Model

```python
from pydantic_ai import Agent
from pydantic_ai.models import Model, infer_model
from openai import AsyncOpenAI

# Use custom model configuration
custom_model = infer_model('openai:gpt-4o', openai_client=AsyncOpenAI(
    api_key=os.getenv("OPENAI_API_KEY"),
    timeout=60.0,
    max_retries=3,
))

agent = Agent(
    custom_model,
    system_prompt='You are a helpful assistant.',
)

# Or use model-specific parameters
result = await agent.run(
    "Generate a story",
    model_settings={
        'temperature': 0.9,
        'max_tokens': 2000,
        'top_p': 0.95,
    }
)
```

### 10. Comprehensive Agent Testing

Testing AI agents requires multiple strategies. Here are 5 essential patterns:

---

#### Pattern A: Unit Testing with TestModel

`TestModel` is the primary testing tool - it provides deterministic responses without API calls.

```python
import pytest
from pydantic_ai import Agent
from pydantic_ai.models.test import TestModel
from pydantic import BaseModel

class MovieRecommendation(BaseModel):
    title: str
    genre: str
    confidence: float

@pytest.mark.asyncio
async def test_agent_basic_response():
    """Test agent returns expected structured output."""
    test_model = TestModel()

    agent = Agent(
        test_model,
        result_type=MovieRecommendation,
        system_prompt='You recommend movies based on user preferences.',
    )

    # Configure TestModel to return specific structured data
    test_model.custom_result_args = {
        'title': 'The Matrix',
        'genre': 'Sci-Fi',
        'confidence': 0.95,
    }

    result = await agent.run("I like action movies with deep themes")

    assert result.data.title == 'The Matrix'
    assert result.data.genre == 'Sci-Fi'
    assert result.data.confidence == 0.95

@pytest.mark.asyncio
async def test_agent_handles_edge_cases():
    """Test agent behavior with edge case inputs."""
    test_model = TestModel()
    agent = Agent(test_model, result_type=str)

    # Test empty input
    result = await agent.run("")
    assert result.data is not None

    # Test very long input
    long_input = "x" * 10000
    result = await agent.run(long_input)
    assert result.data is not None
```

**Anti-Pattern Warning:**
| ❌ Wrong | Why Bad | ✅ Right |
|----------|---------|----------|
| Using real API in unit tests | Slow, flaky, costly | Use `TestModel` |
| No assertion on result type | Miss type errors | Assert `.data` matches model |
| Testing only happy path | Miss edge cases | Test empty, long, invalid inputs |

---

#### Pattern B: Integration Testing with Mocked API

Test against real model behavior with mocked HTTP layer.

```python
import pytest
from unittest.mock import AsyncMock, patch
from pydantic_ai import Agent
from pydantic import BaseModel

class AnalysisResult(BaseModel):
    summary: str
    sentiment: str
    key_points: list[str]

@pytest.fixture
def mock_openai_response():
    """Fixture providing realistic OpenAI response structure."""
    return {
        "choices": [{
            "message": {
                "content": '{"summary": "Test summary", "sentiment": "positive", "key_points": ["point1", "point2"]}'
            }
        }],
        "usage": {"prompt_tokens": 100, "completion_tokens": 50}
    }

@pytest.mark.asyncio
async def test_agent_with_mocked_api(mock_openai_response):
    """Integration test with mocked HTTP calls."""
    with patch('httpx.AsyncClient.post') as mock_post:
        mock_post.return_value = AsyncMock(
            status_code=200,
            json=lambda: mock_openai_response
        )

        agent = Agent(
            'openai:gpt-4o',
            result_type=AnalysisResult,
        )

        result = await agent.run("Analyze this document")

        # Verify API was called correctly
        mock_post.assert_called_once()
        call_args = mock_post.call_args
        assert 'gpt-4o' in str(call_args)

        # Verify parsed response
        assert result.data.sentiment == "positive"
        assert len(result.data.key_points) == 2

@pytest.mark.asyncio
async def test_agent_handles_api_errors():
    """Test graceful handling of API failures."""
    with patch('httpx.AsyncClient.post') as mock_post:
        mock_post.side_effect = Exception("API timeout")

        agent = Agent('openai:gpt-4o', result_type=str)

        with pytest.raises(Exception) as exc_info:
            await agent.run("Test prompt")

        assert "timeout" in str(exc_info.value).lower()
```

---

#### Pattern C: Dependency Mocking Patterns

Test tool behavior by mocking dependencies, not the agent.

```python
import pytest
from dataclasses import dataclass, field
from pydantic_ai import Agent, RunContext
from pydantic_ai.models.test import TestModel
from unittest.mock import AsyncMock

@dataclass
class DatabaseDeps:
    """Dependencies that can be mocked for testing."""
    db_client: AsyncMock = field(default_factory=AsyncMock)
    cache_client: AsyncMock = field(default_factory=AsyncMock)

@pytest.fixture
def agent_with_tools():
    """Create agent with testable tools."""
    test_model = TestModel()
    agent = Agent(test_model, deps_type=DatabaseDeps)

    @agent.tool
    async def fetch_user(ctx: RunContext[DatabaseDeps], user_id: str) -> dict:
        """Fetch user from database."""
        return await ctx.deps.db_client.get_user(user_id)

    @agent.tool
    async def cache_result(ctx: RunContext[DatabaseDeps], key: str, value: str) -> bool:
        """Cache a result."""
        return await ctx.deps.cache_client.set(key, value)

    return agent

@pytest.mark.asyncio
async def test_database_tool_is_called(agent_with_tools):
    """Verify tool calls database with correct parameters."""
    # Setup mock responses
    mock_deps = DatabaseDeps()
    mock_deps.db_client.get_user.return_value = {
        "id": "123",
        "name": "Test User",
        "email": "test@example.com"
    }

    # Configure test model to call the tool
    agent_with_tools.model.custom_result_text = "User fetched successfully"

    result = await agent_with_tools.run(
        "Fetch user 123",
        deps=mock_deps
    )

    # Verify database was called correctly
    mock_deps.db_client.get_user.assert_called_once_with("123")

@pytest.mark.asyncio
async def test_cache_tool_handles_failure(agent_with_tools):
    """Test graceful handling when cache fails."""
    mock_deps = DatabaseDeps()
    mock_deps.cache_client.set.side_effect = Exception("Redis connection failed")

    # Tool should handle the exception gracefully
    # (depending on your error handling strategy)
```

---

#### Pattern D: Conversation History Testing

Test multi-turn conversations and context preservation.

```python
import pytest
from pydantic_ai import Agent
from pydantic_ai.models.test import TestModel
from pydantic_ai.messages import (
    ModelRequest,
    ModelResponse,
    UserPromptPart,
    TextPart,
)

@pytest.mark.asyncio
async def test_conversation_history_preserved():
    """Verify conversation context is maintained across turns."""
    test_model = TestModel()
    agent = Agent(test_model, result_type=str)

    # First turn
    test_model.custom_result_text = "Hello! I'm ready to help."
    result1 = await agent.run("Hi, I'm testing")

    # Second turn with history
    test_model.custom_result_text = "Yes, you mentioned you're testing."
    result2 = await agent.run(
        "Do you remember what I said?",
        message_history=result1.new_messages()
    )

    # Verify history was passed
    all_messages = result2.all_messages()
    assert len(all_messages) >= 4  # 2 user + 2 assistant messages

    # Verify message order
    user_messages = [m for m in all_messages if isinstance(m, ModelRequest)]
    assert len(user_messages) == 2

@pytest.mark.asyncio
async def test_message_history_structure():
    """Test the structure of message history objects."""
    test_model = TestModel()
    agent = Agent(test_model, result_type=str)

    result = await agent.run("Test message")

    messages = result.all_messages()

    # Verify message types
    for msg in messages:
        if isinstance(msg, ModelRequest):
            # User/system messages
            assert hasattr(msg, 'parts')
            for part in msg.parts:
                assert isinstance(part, (UserPromptPart, TextPart))
        elif isinstance(msg, ModelResponse):
            # Assistant messages
            assert hasattr(msg, 'parts')

@pytest.mark.asyncio
async def test_conversation_branching():
    """Test branching conversation from a specific point."""
    test_model = TestModel()
    agent = Agent(test_model, result_type=str)

    # Build base conversation
    test_model.custom_result_text = "Base response"
    base_result = await agent.run("Base question")

    # Branch A
    test_model.custom_result_text = "Branch A response"
    branch_a = await agent.run(
        "Follow-up A",
        message_history=base_result.new_messages()
    )

    # Branch B (from same point)
    test_model.custom_result_text = "Branch B response"
    branch_b = await agent.run(
        "Follow-up B",
        message_history=base_result.new_messages()
    )

    # Verify branches are independent
    assert branch_a.data != branch_b.data
    assert len(branch_a.all_messages()) == len(branch_b.all_messages())
```

---

#### Pattern E: Tool Call Verification

Test that agents call tools correctly and handle tool responses.

```python
import pytest
from dataclasses import dataclass
from pydantic_ai import Agent, RunContext
from pydantic_ai.models.test import TestModel
from pydantic import BaseModel
from typing import Callable

class ToolCallTracker:
    """Track tool calls for verification."""

    def __init__(self):
        self.calls: list[dict] = []

    def record(self, tool_name: str, **kwargs):
        self.calls.append({"tool": tool_name, "args": kwargs})

    def assert_called(self, tool_name: str, times: int = 1):
        matching = [c for c in self.calls if c["tool"] == tool_name]
        assert len(matching) == times, f"Expected {tool_name} called {times}x, got {len(matching)}"

    def assert_called_with(self, tool_name: str, **expected_args):
        matching = [c for c in self.calls if c["tool"] == tool_name]
        assert matching, f"{tool_name} was never called"
        assert expected_args.items() <= matching[-1]["args"].items()

@dataclass
class TrackedDeps:
    tracker: ToolCallTracker

@pytest.fixture
def tracked_agent():
    """Agent with tool call tracking."""
    test_model = TestModel()
    agent = Agent(test_model, deps_type=TrackedDeps)

    @agent.tool
    async def search_database(
        ctx: RunContext[TrackedDeps],
        query: str,
        limit: int = 10
    ) -> list[str]:
        """Search the database."""
        ctx.deps.tracker.record("search_database", query=query, limit=limit)
        return ["result1", "result2"]

    @agent.tool
    async def send_notification(
        ctx: RunContext[TrackedDeps],
        user_id: str,
        message: str
    ) -> bool:
        """Send notification to user."""
        ctx.deps.tracker.record("send_notification", user_id=user_id, message=message)
        return True

    return agent

@pytest.mark.asyncio
async def test_tool_called_with_correct_args(tracked_agent):
    """Verify tool is called with expected arguments."""
    tracker = ToolCallTracker()
    deps = TrackedDeps(tracker=tracker)

    # Configure model to trigger tool call
    tracked_agent.model.custom_result_text = "Search complete"

    await tracked_agent.run("Search for Python tutorials", deps=deps)

    # Verify tool was called correctly
    tracker.assert_called("search_database", times=1)
    tracker.assert_called_with("search_database", query="Python tutorials")

@pytest.mark.asyncio
async def test_multiple_tools_called_in_sequence(tracked_agent):
    """Verify multiple tools called in correct order."""
    tracker = ToolCallTracker()
    deps = TrackedDeps(tracker=tracker)

    tracked_agent.model.custom_result_text = "Done"

    await tracked_agent.run(
        "Search for users and notify them",
        deps=deps
    )

    # Verify both tools called
    tracker.assert_called("search_database")
    tracker.assert_called("send_notification")

    # Verify order (search before notify)
    tool_order = [c["tool"] for c in tracker.calls]
    assert tool_order.index("search_database") < tool_order.index("send_notification")

@pytest.mark.asyncio
async def test_tool_not_called_when_unnecessary(tracked_agent):
    """Verify agent doesn't call tools unnecessarily."""
    tracker = ToolCallTracker()
    deps = TrackedDeps(tracker=tracker)

    tracked_agent.model.custom_result_text = "Simple response"

    await tracked_agent.run("What is 2+2?", deps=deps)

    # No tools should be called for simple math
    assert len(tracker.calls) == 0
```

**Testing Best Practices Summary:**

| Pattern | Use When | Key Technique |
|---------|----------|---------------|
| TestModel | Unit tests, fast feedback | `custom_result_args` |
| Mocked API | Integration tests, API contracts | `patch('httpx.AsyncClient')` |
| Dependency Mocking | Tool behavior testing | `AsyncMock` in deps |
| History Testing | Multi-turn conversations | `message_history` parameter |
| Tool Call Verification | Agent decision testing | Custom tracker class |

## Production Patterns

### 11. Error Handling & Logging

```python
from pydantic_ai import Agent, UnexpectedModelBehavior
from pydantic import BaseModel
import logging
import structlog

# Configure structured logging
logger = structlog.get_logger()

class SafeAgent:
    def __init__(self, model: str):
        self.agent = Agent(model)

    async def run_safe(self, prompt: str) -> dict:
        """Run agent with comprehensive error handling."""
        try:
            logger.info("agent.run.start", prompt=prompt)

            result = await self.agent.run(prompt)

            logger.info(
                "agent.run.success",
                prompt=prompt,
                usage=result.usage(),
            )

            return {
                "success": True,
                "data": result.data,
                "cost": result.cost(),
            }

        except UnexpectedModelBehavior as e:
            logger.error(
                "agent.run.model_error",
                prompt=prompt,
                error=str(e),
            )
            return {"success": False, "error": "Model behavior error"}

        except Exception as e:
            logger.exception(
                "agent.run.unexpected_error",
                prompt=prompt,
            )
            return {"success": False, "error": str(e)}

# Usage
safe_agent = SafeAgent('openai:gpt-4o')
result = await safe_agent.run_safe("Complex prompt...")
```

### 12. Rate Limiting & Cost Control

```python
from pydantic_ai import Agent
import asyncio
from datetime import datetime, timedelta

class RateLimitedAgent:
    def __init__(self, model: str, max_requests_per_minute: int = 60):
        self.agent = Agent(model)
        self.max_rpm = max_requests_per_minute
        self.requests = []
        self.total_cost = 0.0
        self.max_cost = 10.0  # $10 limit

    async def run_with_limits(self, prompt: str):
        """Run agent with rate limiting and cost control."""
        # Check rate limit
        now = datetime.now()
        self.requests = [r for r in self.requests if r > now - timedelta(minutes=1)]

        if len(self.requests) >= self.max_rpm:
            wait_time = (self.requests[0] - (now - timedelta(minutes=1))).total_seconds()
            await asyncio.sleep(wait_time)

        # Check cost limit
        if self.total_cost >= self.max_cost:
            raise Exception(f"Cost limit reached: ${self.total_cost:.2f}")

        # Run agent
        result = await self.agent.run(prompt)

        # Track request and cost
        self.requests.append(datetime.now())
        cost = result.cost()
        self.total_cost += cost

        return result.data

# Usage
agent = RateLimitedAgent('openai:gpt-4o', max_requests_per_minute=50)
result = await agent.run_with_limits("Analyze this data...")
```

### 13. Agent Caching

```python
from pydantic_ai import Agent
from functools import lru_cache
import hashlib
import json

class CachedAgent:
    def __init__(self, model: str, cache_size: int = 128):
        self.agent = Agent(model)
        self.cache_size = cache_size

    @lru_cache(maxsize=128)
    async def _run_cached(self, prompt_hash: str, prompt: str):
        """Internal cached run."""
        result = await self.agent.run(prompt)
        return result.data

    async def run(self, prompt: str, use_cache: bool = True):
        """Run with optional caching."""
        if use_cache:
            prompt_hash = hashlib.md5(prompt.encode()).hexdigest()
            return await self._run_cached(prompt_hash, prompt)
        else:
            result = await self.agent.run(prompt)
            return result.data

# Usage
cached_agent = CachedAgent('openai:gpt-4o')
result1 = await cached_agent.run("What is Python?")  # API call
result2 = await cached_agent.run("What is Python?")  # From cache
```

### 14. Prompt Management

```python
from pydantic_ai import Agent
from jinja2 import Template

class PromptLibrary:
    """Centralized prompt management."""

    PROMPTS = {
        "code_review": Template('''
            Review this {{ language }} code for:
            - Code quality and best practices
            - Security vulnerabilities
            - Performance issues
            - Maintainability

            Code:
            ```{{ language }}
            {{ code }}
            ```
        '''),

        "data_analysis": Template('''
            Analyze this dataset and provide:
            - Summary statistics
            - Key insights
            - Anomalies or patterns
            - Recommendations

            Data: {{ data }}
        '''),
    }

    @classmethod
    def render(cls, template_name: str, **kwargs) -> str:
        """Render prompt template with variables."""
        template = cls.PROMPTS.get(template_name)
        if not template:
            raise ValueError(f"Template '{template_name}' not found")
        return template.render(**kwargs)

# Usage
agent = Agent('anthropic:claude-3-5-sonnet-20241022')

prompt = PromptLibrary.render(
    "code_review",
    language="python",
    code=open("app.py").read(),
)

result = await agent.run(prompt)
```

### 15. Agent Composition

```python
from pydantic_ai import Agent
from pydantic import BaseModel

class ComposableAgent:
    """Compose multiple specialized agents."""

    def __init__(self):
        self.summarizer = Agent(
            'openai:gpt-4o',
            system_prompt='Summarize text concisely.',
        )

        self.analyzer = Agent(
            'anthropic:claude-3-5-sonnet-20241022',
            system_prompt='Analyze sentiment and key themes.',
        )

        self.translator = Agent(
            'openai:gpt-4o',
            system_prompt='Translate text accurately.',
        )

    async def process_document(self, text: str, target_language: str = None):
        """Process document through multiple agents."""
        # Step 1: Summarize
        summary_result = await self.summarizer.run(
            f"Summarize this text:\n{text}"
        )
        summary = summary_result.data

        # Step 2: Analyze
        analysis_result = await self.analyzer.run(
            f"Analyze this summary:\n{summary}"
        )
        analysis = analysis_result.data

        # Step 3: Translate if requested
        if target_language:
            translation_result = await self.translator.run(
                f"Translate to {target_language}:\n{summary}"
            )
            summary = translation_result.data

        return {
            "summary": summary,
            "analysis": analysis,
        }

# Usage
composer = ComposableAgent()
result = await composer.process_document(
    text=long_document,
    target_language="Spanish",
)
```

## Anti-Patterns Reference

Comprehensive list of common mistakes and their solutions.

### State Management Anti-Patterns

| ❌ Wrong | Why Bad | ✅ Right |
|----------|---------|----------|
| `agent.state = {}` | Breaks thread safety | Use `deps_type` with dataclass |
| `global conversation_history` | Race conditions in async | Each `run()` has isolated history |
| Mutable default in deps | Shared state across runs | `Field(default_factory=list)` |
| `ctx.deps.items.append(x)` | Side effects leak | Return new state, don't mutate |

### Async Anti-Patterns

| ❌ Wrong | Why Bad | ✅ Right |
|----------|---------|----------|
| `time.sleep(5)` in tool | Blocks event loop | `await asyncio.sleep(5)` |
| `requests.get(url)` | Blocking HTTP | `await httpx.get(url)` or `aiohttp` |
| `with open()` for large files | Blocks I/O | `aiofiles.open()` |
| Sync database calls | Thread starvation | Use async driver (asyncpg, motor) |

```python
# ❌ WRONG: Blocking operations in async tool
@agent.tool
async def fetch_data(ctx: RunContext, url: str) -> str:
    import requests
    response = requests.get(url)  # BLOCKS!
    time.sleep(1)  # BLOCKS!
    return response.text

# ✅ RIGHT: Fully async
@agent.tool
async def fetch_data(ctx: RunContext, url: str) -> str:
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
    await asyncio.sleep(1)  # Non-blocking
    return response.text
```

### Multi-Agent Anti-Patterns

| ❌ Wrong | Why Bad | ✅ Right |
|----------|---------|----------|
| Agent A calls Agent B calls Agent A | Infinite recursion | DAG-only orchestration |
| Shared context between workers | "Collective delusion" | Isolated worker contexts |
| No timeout on sub-agents | Hung pipelines | `asyncio.wait_for(timeout=30)` |
| Fire-and-forget workers | Lost results | Always await or track |

```python
# ❌ WRONG: Circular agent dependency
agent_a = Agent('openai:gpt-4o')
agent_b = Agent('openai:gpt-4o')

@agent_a.tool
async def call_b(ctx: RunContext) -> str:
    return (await agent_b.run("...")).data

@agent_b.tool
async def call_a(ctx: RunContext) -> str:
    return (await agent_a.run("...")).data  # INFINITE LOOP!

# ✅ RIGHT: DAG structure (no cycles)
orchestrator = Agent('openai:gpt-4o')
worker_a = Agent('openai:gpt-4o')  # No tools that call orchestrator
worker_b = Agent('openai:gpt-4o')  # No tools that call orchestrator

@orchestrator.tool
async def delegate_to_a(ctx: RunContext, task: str) -> str:
    return (await worker_a.run(task)).data

@orchestrator.tool
async def delegate_to_b(ctx: RunContext, task: str) -> str:
    return (await worker_b.run(task)).data
```

### Type Safety Anti-Patterns

| ❌ Wrong | Why Bad | ✅ Right |
|----------|---------|----------|
| `str(result.data.price)` | Throws away validation | Use typed attribute directly |
| `result.data.dict()` then modify | Bypasses model | Create new model instance |
| `Any` as result_type | No validation | Define proper Pydantic model |
| Ignoring validation errors | Silent failures | Handle or let propagate |

### Tool Definition Anti-Patterns

| ❌ Wrong | Why Bad | ✅ Right |
|----------|---------|----------|
| No docstring on tool | LLM can't understand purpose | Always add clear docstring |
| `**kwargs` parameters | LLM can't know options | Explicit typed parameters |
| Returning raw exceptions | Confuses LLM | Return error message string |
| Side effects without confirmation | Dangerous actions | Add confirmation parameter |

```python
# ❌ WRONG: Unsafe tool definition
@agent.tool
async def delete_file(ctx: RunContext, **kwargs):  # No types, no docs
    os.remove(kwargs.get('path'))  # Dangerous!

# ✅ RIGHT: Safe, documented tool
@agent.tool
async def delete_file(
    ctx: RunContext,
    path: str,
    confirm: bool = False,
) -> str:
    """Delete a file from the filesystem.

    Args:
        path: Full path to the file to delete
        confirm: Must be True to actually delete (safety check)
    """
    if not confirm:
        return f"To delete {path}, call again with confirm=True"
    if not os.path.exists(path):
        return f"File not found: {path}"
    os.remove(path)
    return f"Deleted: {path}"
```

### Error Handling Anti-Patterns

| ❌ Wrong | Why Bad | ✅ Right |
|----------|---------|----------|
| Bare `except:` | Swallows all errors | Catch specific exceptions |
| `raise ModelRetry` always | Infinite retry loop | Check retry count |
| No logging in error handlers | Blind debugging | Use structured logging |
| Re-raising without context | Lost stack trace | `raise ... from e` |

## Best Practices

### Type Safety
- Always define `result_type` for structured outputs
- Use Pydantic models for complex types
- Validate inputs with field validators
- Use `deps_type` for dependency injection

### Performance
- Implement caching for repeated queries
- Use streaming for long responses
- Set appropriate timeouts
- Monitor token usage and costs

### Error Handling
- Use `retries` parameter for transient failures
- Implement custom validators with `ModelRetry`
- Log all agent interactions
- Handle `UnexpectedModelBehavior` exceptions

### Testing
- Use `TestModel` for unit tests
- Mock dependencies with dataclasses
- Test validation logic separately
- Verify tool calls and responses

### Production
- Implement rate limiting
- Set cost limits and monitoring
- Use structured logging
- Version your prompts
- Monitor model performance

## Quick Reference

```python
# Basic agent
agent = Agent('openai:gpt-4o', result_type=MyModel)
result = await agent.run("prompt")

# Agent with tools
@agent.tool
async def my_tool(ctx: RunContext[Deps], arg: str) -> str:
    return "result"

# Agent with validation
@agent.result_validator
async def validate(ctx: RunContext, result: Model) -> Model:
    if not valid(result):
        raise ModelRetry("Try again")
    return result

# Streaming
async with agent.run_stream("prompt") as response:
    async for chunk in response.stream_text():
        print(chunk, end='')

# Custom settings
result = await agent.run(
    "prompt",
    model_settings={'temperature': 0.7},
)
```

---

**When to Use This Skill:**

Invoke when building AI agents, multi-agent systems, structured LLM applications, or when implementing type-safe AI workflows with Pydantic AI.

---

## Reference Links

### Official Documentation
- [Pydantic AI Documentation](https://ai.pydantic.dev/) - Complete framework reference
- [Pydantic AI GitHub](https://github.com/pydantic/pydantic-ai) - Source code and issues

### Guides by Topic
- [Results & Type Safety](https://ai.pydantic.dev/results/) - Structured output validation
- [Tools Guide](https://ai.pydantic.dev/tools/) - Tool definition and usage
- [Dependencies](https://ai.pydantic.dev/dependencies/) - Dependency injection patterns
- [Multi-Agent Patterns](https://ai.pydantic.dev/multi-agent/) - Agent composition and orchestration
- [Testing Guide](https://ai.pydantic.dev/testing/) - TestModel and testing patterns
- [Message History](https://ai.pydantic.dev/message-history/) - Conversation continuity

### Model Providers
- [OpenAI Models](https://ai.pydantic.dev/models/#openai) - GPT-4, GPT-4o configuration
- [Anthropic Models](https://ai.pydantic.dev/models/#anthropic) - Claude configuration
- [Gemini Models](https://ai.pydantic.dev/models/#gemini) - Google AI configuration
- [Ollama (Local)](https://ai.pydantic.dev/models/#ollama) - Local model setup

### Related Libraries
- [Pydantic v2 Documentation](https://docs.pydantic.dev/latest/) - Core validation library
- [httpx Documentation](https://www.python-httpx.org/) - Async HTTP client for tools
- [pytest-asyncio](https://pytest-asyncio.readthedocs.io/) - Async testing support

---

*Skill Version: 2.0.0 — Updated with architectural components, anti-patterns, multi-agent orchestration patterns, and comprehensive testing.*
