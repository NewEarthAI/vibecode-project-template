# Array Operations

## Indexing

```sql
-- GIN index for array containment
CREATE INDEX idx_products_categories ON products USING gin(categories);
```

## Query Patterns

```sql
-- ✅ Containment (uses GIN index)
SELECT * FROM products WHERE categories @> ARRAY['electronics'];

-- ✅ Overlap (any element matches)
SELECT * FROM posts WHERE tags && ARRAY['database', 'sql'];

-- ✅ Array length check
SELECT * FROM posts WHERE array_length(tags, 1) > 3;

-- ✅ ANY for single element
SELECT * FROM posts WHERE 'postgresql' = ANY(tags);

-- ❌ BAD: ANY without index
SELECT * FROM products WHERE 'electronics' = ANY(categories);
-- Use @> containment operator instead for GIN index support
```

## Aggregation

```sql
-- Collect distinct values
SELECT array_agg(DISTINCT category)
FROM posts, unnest(categories) as category;

-- Bulk update
UPDATE products SET categories = categories || ARRAY['new_category']
WHERE id IN (SELECT id FROM products WHERE condition);
```
