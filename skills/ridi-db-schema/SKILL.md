---
name: ridi-db-schema
description: Use when locating RIDI database domains, schema files, or key payment, money, book, coupon, and review tables before writing queries, changing backend flows, or investigating data issues.
---

# RIDI DB Schema

This skill is a routing guide for schema work. Start with the SQL files, then open only the domain reference needed for the task.

## When to use

- You need to find which schema file owns a table
- You are tracing order, payment, money, book, coupon, or review data
- You are checking whether code assumptions match the DB
- You need a deeper reference before writing a query or migration

## Primary source

- `backends/src/db/schemas/`

Common files:

- `bom.sql`
- `platform.sql`
- `ownership.sql`
- `platform_finance.sql`
- `ridiselect.sql`
- `outbox.sql`
- `trx.sql`

## References

- `references/domain-map.md`: domain table map for order, payment, money, books, ownership, coupons, reviews, outbox, event participation, subscriptions, CRM, CP/finance, and infrastructure.
- `DB_SCHEMA_COMPREHENSIVE.md`: larger table-by-table guide. Use only when the short domain map is not enough.

## Things to remember

- `tb_pay_info` is broader than just book orders
- Money usage follows FIFO-style balance consumption
- Book and series relations have historical fields and conventions; verify in SQL before assuming constraints
- If a skill and SQL disagree, trust `backends/src/db/schemas/` first -> Update skill later to make it up-to-date

## Related skills

- `ridi-project-structure`
- `ridi-event-structure`
