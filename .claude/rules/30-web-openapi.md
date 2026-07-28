---
description: Backend application-layer web and OpenAPI contract rules.
paths:
  - "backend/application/src/main/java/**/*.java"
---

# Web And OpenAPI Rules

- OpenAPI YAML is the contract source of truth.
- Controllers implement generated `*Api` interfaces.
- Do not replace generated-interface routing with handwritten `@RequestMapping` contracts.
- Keep controller methods focused on auth, service delegation, and mapping.
- Map service models to OpenAPI DTOs through application mappers.
- API controllers must not branch, loop, catch exceptions, access repositories,
  or construct generated `*Vn` DTOs. Infrastructure controllers under `web/`
  are exempt when they only own HTTP/static-routing behavior.
- Every controllable OpenAPI input has an explicit constraint or a meaningful
  `x-unconstrained-reason`; each constrained operation has a negative MVC test
  asserting `400 Bad Request`.
- Static gates reject deterministic controller logic shapes; reviewers still
  reject multi-step business orchestration even where individual delegation
  calls are syntactically legal.
- Centralize error mapping in `GlobalExceptionHandler` and its response helper.
