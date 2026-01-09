# Case Study 2: Pizza Runner — SQL Solutions

This repository contains my full SQL solution for **Case Study #2: Pizza Runner** from Danny Ma’s **#8WeekSQLChallenge**, implemented in PostgreSQL.

Unlike Case Study 1, this week focuses less on storytelling and more on data integrity, schema limitations, and careful query design. Several questions require reasoning about *individual pizzas*, not just orders, which exposes important flaws in the original schema and drives many of the design choices in this solution.

---

## Business Context

Pizza Runner is a fictional pizza delivery startup that tracks:
- customer orders
- pizza types and toppings
- runner deliveries and performance

The business wants insights across:
- pizza volume and customization
- runner efficiency and delivery success
- ingredient usage and pricing impacts
- schema extensions (ratings, new pizzas)

---

## Repository Structure

| File | Purpose |
|-----|--------|
| **setup.sql** | Creates schemas, tables, and inserts the raw Pizza Runner data |
| **solution.sql** | Full end-to-end solution: data cleaning, SQL answers for Parts A–E, and inline result outputs. Additional documentation for specific answers are also included under each question.|
| **README.md** | Explains context, data issues, and solution decisions |

---

## Data Cleaning & Normalization Decisions

Same as any analysis, the provided raw data required cleanup for functionality:

### 1. String “null” Values
Several columns stored `'null'`, `'NaN'`, or empty strings instead of actual NULLs:
- `extras`
- `exclusions`
- `pickup_time`
- `distance`
- `duration`
- `cancellation`

These were explicitly normalized to real NULL values to prevent:
- incorrect joins
- broken aggregations
- misleading counts

### 2. Mixed Data Types
Runner metrics were stored as strings:
- `"10km"`, `"25 km"`
- `"15 mins"`, `"40 minutes"`

These were cleaned and cast to numeric values to enable:
- distance calculations
- speed metrics
- profit analysis

---

## Critical Schema Nuance: Why `num_row` Exists in solution

At first glance, some of the logic and SQL in the solutions file may look longer or more complex than expected.
This is intentional - most of the extra logic comes from having to explicitly model pizza-level identity in a schema that is not provided originally.

### The Core Problem

The `customer_orders` table **does not have a pizza-level primary key**.

Each row represents a pizza, but:
- multiple pizzas in the same order can have identical attributes (for example, same multiple pizzas and toppings for each order)
- there is **no line item identifier**
- grouping by `(order_id, pizza_id, exclusions, extras, order_time)` is **not safe**

This may lead to an unnoticed but major issue when querying: Multiple distinct pizzas collapse into one logical pizza during aggregation.

---

### The Consequence

Without a unique row identifier:
- ingredient counts become inflated or understated
- pizzas merge when they shouldn’t
- extras and exclusions bleed across pizzas

---

## My Solution: Synthetic Pizza Identifier (`num_row`)

To preserve pizza-level granularity, I introduce:

```sql
ROW_NUMBER() OVER (
  ORDER BY order_id, pizza_id, exclusions, extras, order_time
) AS num_row
```
