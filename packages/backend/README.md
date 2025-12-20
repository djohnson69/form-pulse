# Admin API (Shelf + Supabase)

A lightweight admin/backoffice API that fronts Supabase with a service role key.
It exposes secure endpoints for dashboard stats, forms management, and recent submissions.

## Endpoints
- `GET /health` — liveness.
- `GET /admin/stats` — counts for forms, submissions, attachments + category breakdown.
- `GET /admin/forms` — list forms with search/category/published filters, pagination.
- `GET /admin/forms/:id` — fetch a single form.
- `PATCH /admin/forms/:id` — update form fields (title, description, category, tags, is_published, version, metadata, fields).
- `GET /admin/submissions` — list recent submissions, optional status filter.

All `/admin/*` endpoints require header `x-api-key: $ADMIN_API_KEY`.

## Configuration
Set environment variables (can be loaded via your process manager or `.env` when developing):
```
SUPABASE_URL=https://xpcibptzncfmifaneoop.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
ADMIN_API_KEY=choose_a_strong_random_key
PORT=8080
```

## Run locally
```
cd packages/backend
dart pub get
SUPABASE_URL=... \
SUPABASE_SERVICE_ROLE_KEY=... \
ADMIN_API_KEY=... \
dart run bin/server.dart
```

## Example calls
```
curl -H "x-api-key: $ADMIN_API_KEY" http://localhost:8080/admin/stats
curl -H "x-api-key: $ADMIN_API_KEY" "http://localhost:8080/admin/forms?search=safety&limit=20"
curl -H "x-api-key: $ADMIN_API_KEY" http://localhost:8080/admin/forms/jobsite-safety
curl -H "x-api-key: $ADMIN_API_KEY" \
  -X PATCH \
  -H "Content-Type: application/json" \
  -d '{"title":"Job Site Safety Walk (Updated)"}' \
  http://localhost:8080/admin/forms/jobsite-safety
```
