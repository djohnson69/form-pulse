# Supabase Setup

1) Create a storage bucket for attachments, e.g. `formbridge-attachments` (public access off).
2) Run `schema.sql` in the Supabase SQL editor to create tables and RLS policies.
   - If your project already has the older UUID-based forms table, run `add_missing_columns.sql` first to migrate ids to text and add fields/tags/metadata.
3) Set project env values (do not commit secrets):
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY` (server-side only)
   - `SUPABASE_STORAGE_BUCKET` (e.g. `formbridge-attachments`)
4) Mobile/web: pass `SUPABASE_URL` and `SUPABASE_ANON_KEY` via `--dart-define`.
5) Server-side jobs/exports/webhooks: use the service role key and bucket in backend/.env (service key must never ship in clients).

Buckets & policies:
- Use the provided RLS to enforce org membership.
- Configure storage policies to allow authenticated users to upload/read objects scoped to their org prefix (e.g. `org-{orgId}/...`) if you adopt per-org prefixes.
