# mysql adapter
STATUS: stub

> **Not yet wired — no client runs on MySQL.** This is a stub per the adapter contract
> (`_PATTERN.md`). The skill STOPS here for a MySQL system: it must NOT invent a recipe. A guessed
> recipe risks a real client database. To wire it, answer all 7 questions below with concrete,
> proven commands, prove the full recipe on a throwaway copy of a real MySQL database, THEN flip
> `STATUS: wired`.

## The 7 questions to answer when a MySQL client appears

| Step | Question | Likely MySQL tooling (UNVERIFIED — prove before wiring) |
|---|---|---|
| 0 freeze-check | Read the migration-ledger size/HEAD to detect active shipping | depends on the migration tool (Flyway `flyway_schema_history`, Liquibase `DATABASECHANGELOG`, Rails `schema_migrations`, etc.) |
| 0b topology | Read the system's topology shape if a map exists | topology-substrate (system-agnostic) |
| 1 snapshot | Structure-only dump + connection + auth quirks | `mysqldump --no-data --routines --triggers --events` |
| 2 strip wrapper | Client-only directives to strip | `mysqldump` emits `/*!… */` version-gated comments + `SET` session lines — verify which a replay engine rejects |
| 3 fold add-ons + freshness | Enumerate omitted plugins/components; assert newest migration present | MySQL components/plugins differ fundamentally from Postgres extensions — research |
| 4 idempotent | Make creates re-runnable | `CREATE TABLE IF NOT EXISTS` / `CREATE … OR REPLACE` where supported (NOT universal in MySQL) |
| 5 path-rescan | Grep patterns for migration-path readers | depends on the migration tool's file layout |
| 6 reconcile | Blessed ledger-reconcile command | the migration tool's repair/baseline command (e.g. Flyway `baseline`) |
| 7 prove | Throwaway-rebuild + healthy signal | rebuild into a scratch schema; diff structure vs prod |

**Wire it the moment a client lands on MySQL — not before.** A speculative MySQL recipe authored
with no client to prove it against is operate-negative.
