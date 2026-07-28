# BigQuery Query Construction Rules

Canonical pattern for generated projects that read from BigQuery. This is
adapted from the Operational Hub `BqRequest` approach, but shaped for the
generated-project module boundaries and backend rules.

## Module ownership

BigQuery is an outbound vendor integration, so the Google SDK client lives in
`backend/external-services` whenever BigQuery is used.

Use this split:

```text
service
  -> owns business search criteria, whitelisted fields, query assembly, paging,
     row-to-service-record mapping, and external exception translation
external-services
  -> owns Google BigQuery SDK setup, authentication, request execution, and
     provider-specific exceptions only
```

`external-services` stays a leaf. It must not depend on `service`, `domain`,
JPA repositories, generated OpenAPI DTOs, or application controllers.

## Required pattern

For every BigQuery-backed search/list flow:

1. Build SQL through a small typed request builder, never by scattering raw
   string concatenation across services.
2. Build both queries from the same configured builder:
   - paged data query: `SELECT ... FROM ... WHERE ... GROUP BY ... ORDER BY ... LIMIT ... OFFSET ...`
   - count query: `SELECT COUNT(DISTINCT ...) ...` over the same `WHERE` clause
3. Run filtering, sorting, grouping, count, and paging in BigQuery, not in Java,
   unless the dataset is explicitly tiny and documented.
4. Keep table names, column names, selected fields, group-by columns, and
   order-by expressions service-owned constants from fixed whitelists.
5. Never accept table names, column names, field lists, predicates, order
   expressions, or raw SQL from the user, request DTO, frontend, or config that
   non-engineers edit.
6. User-provided numeric filter values are parsed to the expected numeric type;
   non-numeric values are ignored or rejected by service validation.
7. User-provided string filter values are escaped as BigQuery string literals
   before they enter SQL.
8. Unsupported filter fields are skipped or rejected explicitly; never fall back
   to using the request field name as a SQL column.
9. Sort direction is reduced to an enum (`ASC`/`DESC`) with a safe default.
10. Page number and size are normalized before `LIMIT` / `OFFSET`; offset cannot
    be negative.

## Recommended service layout

```text
backend/service/src/main/java/<base>/service/<feature>/bigquery/
  BqRequest.java                 # record with assembled SQL
  BqRequestBuilder.java          # fluent, top-level builder
  BqRow.java                     # typed row access helpers
  BigQuerySearchGateway.java     # service-side gateway over external client
  <Source>Columns.java           # whitelisted column constants
```

Do not use a nested `BqRequest.Builder` in generated projects. The Operational
Hub source uses a nested builder, but this template forbids nested production
types. Use a top-level `BqRequestBuilder` or a feature-specific top-level
builder instead.

`BigQuerySearchGateway` belongs in `service`: it can inject the
`external-services` BigQuery client, centralize table qualification, convert
rows into `BqRow`, and wrap `<Provider>ExternalException` into `AppException`.
The Google SDK client itself remains in `external-services`.

## Canonical usage shape

```java
BqRequestBuilder query = new BqRequestBuilder()
        .from(gateway.table())
        .fields(FIELDS)
        .countDistinct(AGENCY_ID)
        .whereNotNull(AGENCY_ID)
        .whereIn(AGENCY_ID, visibility.agencyIds())
        .groupBy(AGENCY_ID)
        .orderBy(sortExpression(criteria.sort()))
        .sortBy(criteria.sort())
        .page(criteria.pageNumber(), criteria.pageSize());

applyFilters(query, criteria.filters());

long total = gateway.count(query.buildCount());
List<AgencyRecord> rows = total == 0 ? List.of() : gateway.fetch(query.build(), this::toAgency);
```

The important part is not the exact class names. The important part is that one
configured builder owns the shared `WHERE` clause, then emits the data query and
the matching count query.

## Filter and sort mapping

Map request fields to SQL through exhaustive enums/switches:

```java
void applyFilters(BqRequestBuilder query, List<FilterCriterion<AgencyField>> filters) {
    if (filters == null) {
        return;
    }
    for (FilterCriterion<AgencyField> filter : filters) {
        switch (filter.field()) {
            case NAME -> query.filter(AGENCY, false, filter);
            case ID -> query.filter(AGENCY_ID, true, filter);
            default -> { /* field is not available in this BigQuery source */ }
        }
    }
}
```

Sort expressions are also whitelisted:

```java
String sortExpression(SortCriterion<AgencyField> sort) {
    AgencyField field = sort == null ? null : sort.field();
    if (field == null) {
        return "LOWER(ANY_VALUE(`" + AGENCY + "`))";
    }
    return switch (field) {
        case ID -> "`" + AGENCY_ID + "`";
        case CLIENTS_COUNT -> "COUNT(DISTINCT `" + ADVERTISER_ID + "`)";
        case NAME, EMAIL, STATUS -> "LOWER(ANY_VALUE(`" + AGENCY + "`))";
    };
}
```

## Forbidden

- Raw `String sql = "SELECT ..."` assembled inside controllers.
- SQL fragments assembled in multiple unrelated services for the same source.
- User-controlled SQL fragments, column names, sort expressions, table names, or
  selected fields.
- Java-side filtering, sorting, or paging after fetching an unbounded BigQuery
  result set.
- Google BigQuery SDK imports outside `backend/external-services`.
- `external-services` code importing service models, search criteria, JPA
  entities, repositories, or generated OpenAPI DTOs.
- Nested production builders or nested DTO/record/class types.

## Tests

Add focused unit tests for the builder and each feature mapping:

- data query contains the expected `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY`,
  `LIMIT`, and `OFFSET`;
- count query reuses the same filters as the data query;
- string filters escape quotes and backslashes;
- numeric filters drop or reject non-numeric input;
- unsupported filters do not become SQL;
- sort fields map only to whitelisted expressions;
- empty visibility or empty allowed-id lists do not issue a BigQuery query when
  the business rule says the user sees nothing.
