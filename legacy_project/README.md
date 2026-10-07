# Northwind Analytics

dbt project for the Northwind Logistics analytics warehouse. Migrated from SQL
Server to Snowflake in 2023.

Owner: Data Platform team
Slack: #northwind-data

## Layout

```
models/
  staging/        1:1 with source tables. Light renaming and casting only.
  intermediate/   Ephemeral joins and reshaping. Not exposed to BI.
  marts/          What BI and the finance team consume.
  dynamic/        Dynamic tables for near-real-time shipment tracking.
```

## Key models

| Model | What it is |
|---|---|
| `fct_orders` | Order header grain. One row per order. |
| `fct_shipments` | Shipment grain. One row per shipment. |
| `fct_deliveries` | Delivery confirmation grain, one row per delivered leg. |
| `dim_customer` | Customer dimension, SCD type 1. |
| `dim_region` | Sales region hierarchy. Feeds the regional rollups. |
| `revenue_by_customer` | Customer revenue rollup. Finance uses this one directly. |

## Refresh cadence

- Staging and marts run nightly at 02:00 UTC via the `northwind_nightly` job.
- The dynamic tables in `models/dynamic/` refresh every 15 minutes, which is
  what the shipment tracking dashboard needs.

## Conventions

- Models are named `stg_`, `int_`, `dim_`, `fct_` by layer.
- All marts models have tests on their primary key and on any foreign key.
- Every model uses CTEs. No nested subqueries.
- Money columns are `NUMBER(18,2)` and named `*_amount`.

## Things to know

- The `migration_cutoff_date` var exists because pre-July-2023 data came across
  from SQL Server with unreliable timestamps. Filter on it.
- `exclude_test_carriers` should be `true` everywhere. The carrier feed includes
  a handful of internal test carriers that would otherwise show up in reporting.
- `sql/adhoc/` holds one-off scripts. They are not part of the dbt DAG.

## Running it

```
dbt deps
dbt build --target dev
```

Ask in #northwind-data before running against prod.
