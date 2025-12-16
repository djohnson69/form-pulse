# Supabase Integration - Quick Reference

## ✅ What's Been Configured

### 1. **Package Installation**
- `supabase_flutter: ^2.12.0` added to [pubspec.yaml](apps/mobile/pubspec.yaml)
- Initialized in [main.dart](apps/mobile/lib/main.dart) with environment variable support

### 2. **Environment Configuration**
- Uses `String.fromEnvironment()` for dart-define support
- Configuration in [main.dart](apps/mobile/lib/main.dart):
  - `SUPABASE_URL` (default: your Supabase project URL)
  - `SUPABASE_ANON_KEY` (default: your publishable key)
  - `SUPABASE_BUCKET` in [form_fill_page.dart](apps/mobile/lib/features/dashboard/presentation/pages/form_fill_page.dart)

### 3. **Storage Policies** (in [schema.sql](supabase/schema.sql))
- Bucket: `formbridge-attachments`
- Per-org path prefix: `org-{orgId}/submissions/...`
- RLS enforces org membership for upload/read/delete
- Policies check `auth.uid()` against `org_members` table

### 4. **Upload Paths Updated**
- [form_fill_page.dart](apps/mobile/lib/features/dashboard/presentation/pages/form_fill_page.dart#L1098): Uses `org-{orgId}` prefix when orgId available
- [pending_queue.dart](apps/mobile/lib/features/dashboard/data/pending_queue.dart#L118): Offline queue now includes orgId parameter

### 5. **Run Scripts Created**
- `./run-mobile.sh` - Run mobile app with dart-defines
- `./run-web.sh` - Run web app with dart-defines
- Both are executable and include proper configuration

### 6. **VS Code Configuration**
- [.vscode/launch.json](.vscode/launch.json) with configurations:
  - Mobile (Debug/Profile/Release)
  - Web (Debug)
  - All include proper dart-defines

### 7. **Database Schema & Seed Data**
- [schema.sql](supabase/schema.sql): Full RLS policies, storage policies, indexes
- [seed.sql](supabase/seed.sql): Demo org and sample form with instructions

## 🚀 Quick Start

### Option 1: VS Code
1. Open Run & Debug (⇧⌘D)
2. Select "Mobile (Debug)" or "Web (Debug)"
3. Press F5

### Option 2: Command Line
```bash
# Mobile
./run-mobile.sh

# Web
./run-web.sh

# Or manually:
cd apps/mobile
flutter run \
  --dart-define=SUPABASE_URL=https://xpcibptzncfmifaneoop.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_FHD_ihfrKsprgm1C3d9ang_xWjS21JW \
  --dart-define=SUPABASE_BUCKET=formbridge-attachments
```

## 📋 Setup Checklist

### In Supabase Dashboard:

1. **Apply Schema**
   - [ ] Run [schema.sql](supabase/schema.sql) in SQL Editor
   - [ ] Run [seed.sql](supabase/seed.sql) in SQL Editor

2. **Create Storage Bucket**
   - [ ] Storage > New Bucket
   - [ ] Name: `formbridge-attachments`
   - [ ] Public: OFF
   - [ ] Confirm creation

3. **After First User Sign-Up**
   ```sql
   -- Get user_id from Authentication > Users in dashboard
   -- Then run these queries:
   
   INSERT INTO org_members (org_id, user_id, role)
   VALUES (
     '00000000-0000-0000-0000-000000000001',
     'YOUR_USER_ID_HERE',
     'admin'
   );
   
   INSERT INTO profiles (id, org_id, email, first_name, last_name, role)
   VALUES (
     'YOUR_USER_ID_HERE',
     '00000000-0000-0000-0000-000000000001',
     'user@example.com',
     'Demo',
     'User',
     'admin'
   );
   ```

### Verification:

- [ ] Sign in to app
- [ ] Dashboard loads forms/submissions
- [ ] Create and submit a form with photo/file
- [ ] Check Storage bucket for file under `org-{orgId}/submissions/...`
- [ ] Verify submission in `submissions` table
- [ ] Verify attachment in `attachments` table

## 🔒 Security Notes

### ✅ Safe for Clients
- `SUPABASE_URL` - Public project URL
- `SUPABASE_ANON_KEY` - Publishable/anonymous key (RLS protected)
- `SUPABASE_BUCKET` - Bucket name

### ⚠️ NEVER in Clients
- `SUPABASE_SERVICE_ROLE_KEY` - Bypasses RLS, server-side only!

## 📁 Storage Path Convention

```
formbridge-attachments/
├── org-{orgId}/
│   └── submissions/
│       ├── {timestamp}_{filename1}
│       ├── {timestamp}_{filename2}
│       └── ...
└── public/  (fallback only, remove in production)
```

## 🔍 Monitoring

### Check in Supabase Dashboard:

1. **Storage Usage**: Storage > formbridge-attachments
2. **RLS Policies**: Database > Policies (should show all policies active)
3. **Auth Users**: Authentication > Users
4. **Data**: Table Editor > orgs, profiles, forms, submissions, attachments

### Logs:
- Authentication > Logs (sign-in failures)
- API > Logs (API usage, errors)
- Storage > Logs (upload activity)

## 📖 Full Documentation

See [SUPABASE_SETUP.md](SUPABASE_SETUP.md) for:
- Detailed validation flows
- Troubleshooting guide
- Production hygiene checklist
- Cleanup instructions for demo fallbacks

## 🐛 Common Issues

**403 on upload?**
- User not in `org_members` table
- Path doesn't start with `org-{orgId}/`
- Bucket is public (should be private with RLS)

**Forms not loading?**
- Profile missing `org_id`
- RLS policies not applied
- Not in `org_members` table

**orgId is null?**
- Profile not created for user
- Reload app after creating profile
- Check [user_profile_provider.dart](apps/mobile/lib/features/dashboard/data/user_profile_provider.dart)

## 📝 Next Steps

1. Apply schema and create storage bucket
2. Sign up a test user
3. Add user to org_members and create profile
4. Test form submission with attachments
5. Verify storage paths and RLS
6. Remove demo fallbacks once validated
7. Set up CI/CD with `flutter analyze` and `flutter test`

---

**Files Modified:**
- [apps/mobile/pubspec.yaml](apps/mobile/pubspec.yaml)
- [apps/mobile/lib/main.dart](apps/mobile/lib/main.dart)
- [apps/mobile/lib/features/dashboard/data/pending_queue.dart](apps/mobile/lib/features/dashboard/data/pending_queue.dart)
- [apps/mobile/lib/features/dashboard/presentation/pages/form_fill_page.dart](apps/mobile/lib/features/dashboard/presentation/pages/form_fill_page.dart)

**Files Created:**
- [.vscode/launch.json](.vscode/launch.json)
- [supabase/seed.sql](supabase/seed.sql)
- [SUPABASE_SETUP.md](SUPABASE_SETUP.md)
- [run-mobile.sh](run-mobile.sh)
- [run-web.sh](run-web.sh)
- This file: SUPABASE_QUICKREF.md
