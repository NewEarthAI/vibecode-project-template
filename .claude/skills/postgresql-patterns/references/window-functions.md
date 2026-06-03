# Window Functions & Analytics

## Running Totals & Moving Averages

```sql
SELECT
    product_id,
    sale_date,
    amount,
    -- Running total
    SUM(amount) OVER (
        PARTITION BY product_id ORDER BY sale_date
    ) as running_total,
    -- 3-period moving average
    AVG(amount) OVER (
        PARTITION BY product_id ORDER BY sale_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) as moving_avg
FROM sales;
```

## Rankings

```sql
SELECT
    product_id,
    amount,
    -- Dense rank (no gaps)
    DENSE_RANK() OVER (
        PARTITION BY EXTRACT(month FROM sale_date)
        ORDER BY amount DESC
    ) as monthly_rank,
    -- Row number (unique per partition)
    ROW_NUMBER() OVER (
        PARTITION BY product_id ORDER BY amount DESC
    ) as rank
FROM sales;
```

## Lag/Lead Comparisons

```sql
SELECT
    product_id,
    sale_date,
    amount,
    LAG(amount, 1) OVER (
        PARTITION BY product_id ORDER BY sale_date
    ) as prev_amount,
    amount - LAG(amount, 1) OVER (
        PARTITION BY product_id ORDER BY sale_date
    ) as change
FROM sales;
```
