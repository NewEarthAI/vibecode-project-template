# DB Adapter Contract — what every `<system>.md` must answer

> The `make-safe-baseline` recipe (`references/make-safe-baseline.md`) is **system-agnostic**.
> Each database system supplies its tooling via an adapter file in this directory. This file is
> the contract: an adapter is `wired` only when it answers ALL of the questions below with a
> concrete, proven command. Until then it stays `STUB`.
>
> **The skill reads the `STATUS:` token, not any prose heading.** Anything other than exactly
> `wired` = STOP. A guessed recipe risks a real client database — never invent one for a stub.

## Adapter file shape

Every `references/db-adapters/<system>.md` opens with:

```
# <system> adapter
STATUS: wired | stub
```

and answers each of the 7 recipe steps:

| Step | The question the adapter MUST answer |
|---|---|
| 0 — freeze-check | How do I read the migration-ledger size/HEAD to detect active shipping? |
| 0b — topology read | How do I read this system's shape from the topology map (if present)? |
| 1 — snapshot | What is the structure-only dump command + connection method + auth/host quirks? |
| 2 — strip wrapper | Which client-only/tool-only directives must be stripped from the dump? |
| 3 — fold add-ons | How do I enumerate live extensions/plugins the dump omits + inject them idempotently? And: what artefact do I grep to assert the dump is FRESH (newest migration present)? |
| 4 — idempotent | What transform makes every create/alter re-runnable? |
| 5 — path-rescan | What grep patterns find code/tests that read a migration by path? |
| 6 — reconcile | What is the blessed ledger-reconcile / repair command? |
| 7 — prove | How do I rebuild a throwaway copy + what "healthy" signal do I read? |

## Wiring a new system (fill-in-the-blanks, not a redesign)

1. Copy this contract's 7 questions into a new `<system>.md`, header `STATUS: stub`.
2. Answer each question with a concrete command, proven against a real (non-production-first) copy.
3. Prove the full recipe end-to-end on a throwaway copy of a real database on that system.
4. ONLY THEN flip `STATUS: wired` and add the system to the skill's `validated_on`.
5. If the system has brittle hand-edits (like the Postgres `\restrict` strip), write a small
   `scripts/make-safe-baseline-<system>.sh` automating them with a `--self-test`.

A speculative adapter authored without a real client on that system is **operate-negative** — it
ships untested steps under a "bulletproof" label. Stub until a client exists; wire when one does.
