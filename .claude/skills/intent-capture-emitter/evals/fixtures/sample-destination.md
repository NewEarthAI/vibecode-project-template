---
artefact: destination
status: confirmed
owner: sample-owner
version: 1
---

# Sample Destination — self-contained fixture for the destination parser

A minimal, entity-agnostic destination carrier so the parsers eval is portable to any repo that
has no real `DESTINATION.md` yet (a fresh template clone or a freshly-set-up receiving entity).
The eval prefers the repo's real `DESTINATION.md` when present; this fixture is the fallback.

## End-state (Element 1)

One falsifiable end-state condition: an operator can ask the sample system a structured question
and receive a source-derived answer in under five seconds, traceable to the artefact that produced it.

## Binary success test (Element 2)

A third party runs the sample check on the claimed date and observes the Element-1 condition holds —
the structured answer returns in under five seconds and is traceable to its source.

## Could the test lie? (Element 4)

A prose falsifier candidate (surfaced for an operator to convert into a machine-executable check —
NEVER auto-promoted into the falsifier field; NSF-2 rejects prose, D2 forbids guessing): the answer
could be returned from a cached fixture rather than a fresh source-derivation.
