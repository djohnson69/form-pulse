# Supabase Integration Setup & Validation Guide

## Prerequisites Completed ✅
- Supabase Flutter package added and initialized
- Environment configuration with dart-define support
- Storage bucket policies configured for org-{orgId} prefix
- Upload paths use org-{orgId} prefix when orgId is available
- VS Code launch configurations with proper dart-defines

## Setup Steps

### 1. Apply Database Schema
```sql
-- In Supabase SQL Editor, run:
-- 1. supabase/schema.sql (creates tables, RLS policies, storage policies)
-- 2. supabase/seed.sql (creates demo org and sample form)
-- If you already created the older UUID-based forms table, run supabase/add_missing_columns.sql before loading templates.
```

### 2. Create Storage Bucket
1. Go to Supabase Dashboard > Storage
2. Click "New bucket"
3. Name: `formbridge-attachments`
4. Public: **OFF** (RLS will control access)
5. Click "Create bucket"

### 3. Populate User Data
After signing up a user through the app:

1. Get user ID from Supabase Dashboard > Authentication > Users
2. Add user to organization:
```sql
INSERT INTO org_members (org_id, user_id, role, created_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',  -- Demo org ID from seed.sql
  'YOUR_USER_UUID_HERE',                    -- Replace with actual user ID
  'admin',
  NOW()
);
```

3. Create user profile:
```sql
INSERT INTO profiles (id, org_id, email, first_name, last_name, role, created_at, updated_at)
VALUES (
  'YOUR_USER_UUID_HERE',                    -- Same user ID
  '00000000-0000-0000-0000-000000000001',  -- Demo org ID
  'user@example.com',                       -- User's email
  'Demo',
  'User',
  'admin',
  NOW(),
  NOW()
);
```

### 4. Environment Variables

#### Client-side (Mobile/Web)
Pass via `--dart-define`:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xpcibptzncfmifaneoop.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_FHD_ihfrKsprgm1C3d9ang_xWjS21JW \
  --dart-define=SUPABASE_BUCKET=formbridge-attachments
```

Or use VS Code launch configurations (already configured in `.vscode/launch.json`)

#### Server-side (Backend - Never in clients!)
```env
SUPABASE_URL=https://xpcibptzncfmifaneoop.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
SUPABASE_STORAGE_BUCKET=formbridge-attachments
```

## Validation Flows

### 1. Sign Up / Sign In
- [ ] User can sign up with email/password
- [ ] User can sign in
- [ ] Profile is returned with orgId and role
- [ ] Dashboard loads org-specific data

### 2. Upload Attachments
- [ ] Upload uses path: `org-{orgId}/submissions/{timestamp}_{filename}`
- [ ] File appears in Supabase Storage under correct org prefix
- [ ] Storage RLS allows authenticated org member to read/write
- [ ] Non-org members cannot access the file

### 3. Create Form
- [ ] Create form in the app
- [ ] Form appears in Supabase `forms` table with correct org_id
- [ ] RLS enforces org member can see their org's forms only

### 4. Submit Form with Attachments
- [ ] Fill and submit form with photos/files
- [ ] Submission created in `submissions` table with org_id
- [ ] Attachments uploaded to `org-{orgId}/submissions/...`
- [ ] Attachment records created in `attachments` table
- [ ] RLS enforces org scope for submissions and attachments

### 5. Offline Queue (Optional)
- [ ] Turn off network
- [ ] Submit form
- [ ] Submission queued locally
- [ ] Turn on network
- [ ] Pending submissions auto-retry and sync
- [ ] Uploads include correct org prefix

## Storage Policy Verification

Check in Supabase Dashboard > Storage > Policies for bucket `formbridge-attachments`:

```sql
-- These policies should exist (created by schema.sql):
1. "Org members can upload in their prefix" (INSERT)
   - Checks auth.uid() in org_members
   - Validates path starts with org-{orgId}/

2. "Org members can read their prefix" (SELECT)
   - Checks auth.uid() in org_members
   - Validates path starts with org-{orgId}/

3. "Org members can delete their prefix" (DELETE)
   - Checks auth.uid() in org_members
   - Validates path starts with org-{orgId}/
```

## RLS Policy Verification

In Supabase Dashboard > Database > Policies, verify:
- `orgs`: Org members can read their org
- `org_members`: Users manage their own membership
- `profiles`: Org members read profiles, users manage own
- `forms`: Org members read/manage forms
- `form_versions`: Org members read/manage versions
- `submissions`: Org members read/insert submissions
- `attachments`: Org members read/insert attachments
- `notifications`: Users read/update own notifications
- `audit_log`: Org members read their org's audit logs

## Clean Up Fallbacks (After Validation)

Once Supabase integration is validated, remove demo fallbacks:

1. In [dashboard_repository.dart](apps/mobile/lib/features/dashboard/data/dashboard_repository.dart):
   - Remove `_demoFallback()` method
   - Remove demo data constants (`_demoForms`, `_demoSubmissions`, etc.)
   - Replace fallback returns with proper error handling

2. Tighten error handling:
   - Show user-friendly error messages
   - Log errors for debugging
   - Implement retry logic for transient failures

## Production Hygiene

### Storage & File Management
- [ ] Set file size limits in Supabase Storage
- [ ] Configure retention policies for old files
- [ ] Set up automatic cleanup for abandoned uploads
- [ ] Monitor storage usage in Supabase Dashboard

### CI/CD
```yaml
# .github/workflows/flutter.yml (example)
- name: Analyze
  run: flutter analyze

- name: Test
  run: flutter test
```

### Monitoring
- [ ] Monitor RLS policy activity in Supabase Dashboard
- [ ] Set up alerts for storage quota
- [ ] Track authentication failures
- [ ] Monitor API rate limits

### Security Checklist
- [ ] NEVER commit service role key
- [ ] Verify RLS policies are active on all tables
- [ ] Storage bucket is NOT public
- [ ] Auth email confirmation enabled (production)
- [ ] Rate limiting configured
- [ ] CORS settings properly configured

## Upload Path Implementation

Current implementation in [form_fill_page.dart](apps/mobile/lib/features/dashboard/presentation/pages/form_fill_page.dart):

```dart
final prefix = _orgId != null ? 'org-$_orgId' : 'public';
final path = '$prefix/submissions/${DateTime.now().microsecondsSinceEpoch}_${item.label}';
```

**Note**: The `public` fallback is only for development. In production, ensure:
1. All users have `orgId` in their profile
2. Remove `public` fallback and show error if orgId is missing
3. Block uploads until orgId is available

## Troubleshooting

### Upload Fails with 403
- Check user is in `org_members` table
- Verify storage policies exist
- Confirm path starts with `org-{orgId}/`
- Check bucket is NOT public (should use RLS)

### Forms/Submissions Not Visible
- Verify user's profile has correct `org_id`
- Check RLS policies are enabled on tables
- Confirm user is in `org_members` for their org

### Offline Queue Not Syncing
- Check network connectivity detection
- Verify pending_submissions stored in SharedPreferences
- Check PendingSubmissionQueue.retryAll() is called on reconnect
