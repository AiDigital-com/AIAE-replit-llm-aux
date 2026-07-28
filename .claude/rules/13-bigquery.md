---
description: BigQuery query construction rules.
paths:
  - "backend/service/src/main/java/**/*.java"
  - "backend/external-services/src/main/java/**/*.java"
---

# BigQuery Rules

- This file is the authoritative BigQuery rule set. Read it in full before adding or changing any BigQuery-backed feature.
- Google BigQuery SDK code belongs only in `backend/external-services`.
- Service code owns the whitelisted SQL builder because it maps business fields, filters, visibility, sorting, and paging.
- Use a top-level `BqRequest` record plus top-level `BqRequestBuilder` or feature-specific builder. Do not use nested production builders.
- One configured builder must emit both the paged data query and the matching count query over the same `WHERE` clause.
- Table names, column names, selected fields, group-by columns, and order-by expressions must come from service-owned constants or exhaustive enum/switch mappings.
- User input may only enter as parsed numeric values or escaped BigQuery string literals. It must never supply raw SQL, column names, table names, predicates, selected fields, or order expressions.
