# Custom Types, Domains & Range Types

## ENUM Types

```sql
CREATE TYPE order_status AS ENUM ('pending', 'processing', 'shipped', 'delivered', 'cancelled');
CREATE TYPE currency_code AS ENUM ('USD', 'EUR', 'GBP', 'ZAR');

CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    status order_status DEFAULT 'pending',
    currency currency_code NOT NULL
);
```

## Domains (Reusable Constraints)

```sql
CREATE DOMAIN email_address AS TEXT
CHECK (VALUE ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

CREATE DOMAIN positive_amount AS DECIMAL(10,2)
CHECK (VALUE > 0);

CREATE TABLE transactions (
    amount positive_amount NOT NULL,
    recipient_email email_address NOT NULL
);
```

## Composite Types

```sql
CREATE TYPE address_type AS (
    street TEXT,
    city TEXT,
    postal_code TEXT,
    country TEXT
);

CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    billing_address address_type,
    shipping_address address_type
);
```

## Range Types

```sql
CREATE TABLE reservations (
    id SERIAL PRIMARY KEY,
    room_id INTEGER,
    reservation_period tstzrange,
    price_range numrange
);

-- Overlap query
SELECT * FROM reservations
WHERE reservation_period && tstzrange('2024-07-20', '2024-07-25');

-- Exclusion constraint (prevent overlapping bookings)
ALTER TABLE reservations
ADD CONSTRAINT no_overlap
EXCLUDE USING gist (room_id WITH =, reservation_period WITH &&);
```

## Anti-Patterns

| Wrong | Why | Right |
|-------|-----|-------|
| `VARCHAR(20)` for status | No validation | `ENUM` type |
| `DECIMAL` without constraint | Allows negatives | `DOMAIN` with CHECK |
| Separate street/city/zip columns | No grouping | Composite type |
| Two date columns for ranges | No overlap protection | Range type + exclusion constraint |
