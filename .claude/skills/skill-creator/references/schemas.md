# Eval & Benchmark JSON Schemas

> Reference schemas for all data formats used by the skill-creator evaluation system.

---

## 1. evals.json — Test Case Definitions

**Location:** `{skill-dir}/evals/evals.json`

```json
{
  "evals": [
    {
      "id": "eval-001",
      "prompt": "The user prompt to test with",
      "description": "What this eval tests",
      "should_trigger": true,
      "input_files": ["optional/path/to/file.txt"],
      "expectations": [
        "The output should contain X",
        "The skill should handle Y correctly",
        "Error Z should be caught"
      ]
    }
  ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique eval identifier |
| `prompt` | string | yes | The user prompt to send |
| `description` | string | no | What this eval validates |
| `should_trigger` | boolean | yes | Whether the skill should activate |
| `input_files` | string[] | no | Files to stage before running |
| `expectations` | string[] | yes (if should_trigger) | Verifiable assertions |

---

## 2. grading.json — Grader Agent Output

**Location:** `{run-dir}/grading.json`

```json
{
  "expectations": [
    {
      "text": "The output should contain X",
      "passed": true,
      "evidence": "Found X at line 15 of output.md"
    }
  ],
  "summary": {
    "total": 3,
    "passed": 2,
    "failed": 1,
    "pass_rate": 0.67
  },
  "metrics": {
    "tool_calls": {"Read": 5, "Write": 2, "Bash": 1},
    "steps": 8,
    "files_created": ["output.md"],
    "errors": []
  },
  "claims": [
    {
      "text": "Created a valid SKILL.md",
      "verified": true,
      "evidence": "File exists with valid frontmatter"
    }
  ],
  "user_notes": "Summary of executor notes",
  "eval_feedback": {
    "trivial_expectations": ["Expectation 3 would pass without the skill"],
    "unverifiable_expectations": [],
    "suggestions": ["Add edge case expectation"]
  }
}
```

---

## 3. metrics.json — Execution Metrics

**Location:** `{run-dir}/outputs/metrics.json`

```json
{
  "tool_calls": {"Read": 12, "Write": 3, "Bash": 2, "Grep": 4},
  "steps": 15,
  "files_created": ["SKILL.md", "evals/evals.json"],
  "errors": [],
  "output_chars": 2450,
  "transcript_chars": 18200
}
```

---

## 4. timing.json — Wall-Clock Timing

**Location:** `{run-dir}/timing.json`

```json
{
  "executor": {
    "start": "2026-03-05T10:00:00Z",
    "end": "2026-03-05T10:02:30Z",
    "duration_ms": 150000,
    "tokens": 25000
  },
  "grader": {
    "start": "2026-03-05T10:02:35Z",
    "end": "2026-03-05T10:03:15Z",
    "duration_ms": 40000,
    "tokens": 8000
  }
}
```

---

## 5. benchmark.json — Aggregated Benchmark Results

**Location:** `{skill-dir}/benchmarks/{timestamp}/benchmark.json`

```json
{
  "metadata": {
    "skill_name": "my-skill",
    "benchmark_dir": "benchmarks/2026-03-05/",
    "timestamp": "2026-03-05T10:15:00Z"
  },
  "summary": {
    "pass_rate": {"mean": 0.85, "stddev": 0.05, "min": 0.75, "max": 0.95},
    "duration_ms": {"mean": 145000, "stddev": 12000, "min": 130000, "max": 165000},
    "tokens": {"mean": 23000, "stddev": 3000, "min": 18000, "max": 28000},
    "run_count": 5
  },
  "runs": [
    {
      "run_id": "run-001",
      "pass_rate": 0.85,
      "duration_ms": 145000,
      "tokens": 23000
    }
  ]
}
```

---

## 6. comparison.json — Blind Comparator Output

**Location:** `{grading-dir}/comparison.json`

```json
{
  "winner": "A",
  "reasoning": "Output A demonstrated stronger task completion...",
  "rubric": {
    "A": {
      "content": {
        "task_completion": {"score": 4, "note": "..."},
        "accuracy": {"score": 5, "note": "..."},
        "completeness": {"score": 4, "note": "..."},
        "edge_cases": {"score": 3, "note": "..."},
        "total": 16
      },
      "structure": {
        "clarity": {"score": 4, "note": "..."},
        "organization": {"score": 5, "note": "..."},
        "conciseness": {"score": 4, "note": "..."},
        "usability": {"score": 4, "note": "..."},
        "total": 17
      },
      "overall": 8
    },
    "B": {
      "content": {"total": 14},
      "structure": {"total": 15},
      "overall": 7
    }
  },
  "quality_summary": {
    "A": {"strengths": ["..."], "weaknesses": ["..."]},
    "B": {"strengths": ["..."], "weaknesses": ["..."]}
  },
  "expectations": {
    "A": {"passed": 2, "total": 3, "rate": 0.67},
    "B": {"passed": 1, "total": 3, "rate": 0.33}
  }
}
```

---

## 7. analysis.json — Post-hoc Analyzer Output

**Location:** `{grading-dir}/analysis.json`

```json
{
  "comparison_summary": "Output A won due to stronger error handling...",
  "instruction_following": {
    "A": {"score": 8, "issues": ["Minor: skipped step 3"]},
    "B": {"score": 6, "issues": ["Major: ignored error handling requirement"]}
  },
  "winner_strengths": ["Quoted evidence from skill/transcript..."],
  "loser_weaknesses": ["Connected gap to performance..."],
  "suggestions": [
    {
      "category": "instructions",
      "priority": "high",
      "description": "Add explicit error handling guidance",
      "rationale": "Executor missed this because instructions were ambiguous"
    }
  ],
  "execution_patterns": {
    "tool_usage_diff": "A used Grep 3x more for validation",
    "approach_diff": "A read existing code before writing, B jumped to implementation",
    "time_diff": "A was 20% slower but produced higher quality"
  }
}
```

---

## 8. history.json — Iterative Improvement History

**Location:** `{skill-dir}/evals/history.json`

```json
{
  "skill_name": "my-skill",
  "iterations": 3,
  "best_iteration": 2,
  "best_pass_rate": 0.95,
  "history": [
    {
      "iteration": 0,
      "description": "Original description...",
      "train_pass_rate": 0.7,
      "test_pass_rate": 0.65,
      "timestamp": "2026-03-05T10:00:00Z"
    },
    {
      "iteration": 1,
      "description": "Improved description v1...",
      "train_pass_rate": 0.85,
      "test_pass_rate": 0.8,
      "timestamp": "2026-03-05T10:05:00Z"
    },
    {
      "iteration": 2,
      "description": "Improved description v2...",
      "train_pass_rate": 0.95,
      "test_pass_rate": 0.9,
      "timestamp": "2026-03-05T10:10:00Z"
    }
  ],
  "final_description": "The best description text..."
}
```

---

*Schemas v1.0 — Unified Skill-Creator Suite*
