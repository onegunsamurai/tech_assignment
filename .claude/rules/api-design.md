# API Design Rules

> **This is a template.** Replace the placeholders with your project's
> actual API conventions, then rename to `api-design.md`.

## Conventions

- **Base path:** <e.g., `/api`, `/api/v1`>
- **Versioning:** <URL-path / header / none>
- **Serialization case:** <snake_case / camelCase / kebab-case in JSON>
- **Content-Type:** <`application/json` / other>
- **Authentication:** <JWT bearer / session cookie / API key>

## Resource naming

- Use nouns, not verbs: `/users/{id}`, not `/getUser`
- Plural collections: `/users`, not `/user`
- Nested resources only when the child cannot exist without the parent
- Keep URLs ≤3 segments deep; use query params for filtering

## Request / response shape

- Request bodies and response bodies use <your case convention>
- Every list endpoint supports pagination — document the shape
  (`?page=`, `?cursor=`, or `Link` header)
- Every list endpoint documents its sort / filter parameters
- Every response includes a request ID (header or body) for traceability

## Error responses

Every error response uses the same shape. Example:

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Human-readable summary",
    "details": [ { "field": "email", "reason": "invalid" } ],
    "request_id": "..."
  }
}
```

- `4xx` for client errors, `5xx` for server errors — never mix them
- `422` for validation; `400` for malformed requests
- `401` for missing/invalid credentials; `403` for authenticated but
  unauthorized; never leak whether a resource exists to an unauthorized
  caller
- Never return raw stack traces to the client

## Streaming / real-time (if applicable)

Document the transport (SSE / WebSocket / long-poll), message envelope,
and control signals. Sanitize any user-provided content before streaming
it to prevent injection.

## Contract source of truth

- **Source of truth:** <e.g., OpenAPI YAML, Pydantic models, Protobuf, GraphQL
  schema>
- **Generated clients:** <where they live, which command regenerates them>
- **Never edit generated code manually** — regenerate from the source

After changing any public contract, run the regenerate command and commit
the generated artifacts together with the source change.

## Rate limiting

- Rate-limit at the edge (gateway or middleware), not inside handlers
- Authentication endpoints get a stricter limit than general traffic
- Return `429` with `Retry-After` when a limit is hit
