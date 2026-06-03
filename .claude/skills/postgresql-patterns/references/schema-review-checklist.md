# Schema Design Review Checklist

## Data Types
- [ ] Using `TIMESTAMPTZ` not `TIMESTAMP` (timezone-aware)
- [ ] Using `TEXT` not `VARCHAR(n)` unless max length is a business rule
- [ ] Using `CITEXT` for case-insensitive fields (email, username)
- [ ] Using `BIGSERIAL` or `UUID` for primary keys (not `SERIAL` for new tables)
- [ ] Using `JSONB` not `JSON` (indexable, binary storage)
- [ ] Using `ENUM` types for constrained value sets (not VARCHAR)
- [ ] Using `DOMAIN` types for reusable validation patterns

## Constraints
- [ ] Primary key on every table
- [ ] Foreign keys with appropriate ON DELETE behavior
- [ ] NOT NULL on columns that should never be null
- [ ] CHECK constraints for business rules
- [ ] UNIQUE constraints where applicable
- [ ] Exclusion constraints for overlap prevention (ranges, schedules)

## Naming
- [ ] All identifiers lowercase (PostgreSQL folds to lowercase anyway)
- [ ] `snake_case` for tables and columns
- [ ] Foreign key columns named `{referenced_table}_id`
- [ ] Index names: `idx_{table}_{columns}`
- [ ] Constraint names: `{table}_{type}_{columns}` (e.g., `orders_check_amount_positive`)

## Indexes
- [ ] Foreign key columns have indexes
- [ ] Columns used in WHERE/JOIN/ORDER BY have appropriate indexes
- [ ] No duplicate indexes (same columns, same order)
- [ ] Partial indexes where full table coverage is unnecessary
