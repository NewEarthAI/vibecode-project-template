# mongo adapter
STATUS: stub

> **Not yet wired — no client runs on MongoDB.** This is a stub per the adapter contract
> (`_PATTERN.md`). The skill STOPS here for a Mongo system: it must NOT invent a recipe.
>
> **Note the framing shift before wiring.** MongoDB is schema-flexible: there is no DDL ledger in
> the Postgres sense. The "structure" that matters is collections + indexes + validators + the
> application-level migration tool's ledger (migrate-mongo, mongock, etc.). The universal PATTERN
> still holds (snapshot the structure → make replayable → reconcile the migration-tool ledger →
> prove on a throwaway copy), but "structure" means index/validator definitions, not table DDL.
> Do NOT assume the Postgres tooling transfers — re-derive each step.

## The 7 questions to answer when a Mongo client appears

| Step | Question | Likely Mongo tooling (UNVERIFIED — prove before wiring) |
|---|---|---|
| 0 freeze-check | Read the migration-tool ledger to detect active shipping | migrate-mongo `changelog` collection / mongock `mongockChangeLog` |
| 0b topology | Read the system's topology shape if a map exists | topology-substrate (system-agnostic) |
| 1 snapshot | Structure snapshot + connection | index + validator definitions per collection (`db.getCollectionInfos()`, `getIndexes()`); `mongodump` captures data, not the structure-replay you want |
| 2 strip wrapper | Client-only directives to strip | likely N/A (JSON/JS, not a SQL dump) — verify |
| 3 fold add-ons + freshness | Omitted server features; assert newest migration present | search/text indexes, custom roles — research |
| 4 idempotent | Make creates re-runnable | `createIndex` is idempotent; `createCollection` is not — guard with existence checks |
| 5 path-rescan | Grep patterns for migration-path readers | depends on the migration tool's file layout |
| 6 reconcile | Blessed ledger-reconcile command | the migration tool's baseline/reset command |
| 7 prove | Throwaway-rebuild + healthy signal | rebuild structure into a scratch DB; diff index/validator sets vs prod |

**Wire it the moment a client lands on MongoDB — not before.**
