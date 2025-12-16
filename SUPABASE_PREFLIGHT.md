# 🚀 Supabase Integration - Pre-Flight Checklist

## ✅ Code Integration Status

### Mobile App
- [x] `supabase_flutter` package installed
- [x] Supabase initialized in main.dart with dart-define support
- [x] Environment variables configured (SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_BUCKET)
- [x] Upload paths use org-{orgId} prefix
- [x] Offline queue updated with org prefix support
- [x] SupabaseDashboardRepository implemented with fallback
- [x] User profile provider fetches orgId from profiles table
- [x] VS Code launch configurations created
- [x] Run script created: ./run-mobile.sh

### Web App
- [x] `supabase_flutter` package installed
- [x] Supabase initialized in main.dart with dart-define support
- [x] Run script created: ./run-web.sh

### Database Schema
- [x] schema.sql created with all tables and RLS policies
- [x] Storage policies configured for org-{orgId} prefix
- [x] seed.sql created with demo org and sample form
- [x] Indexes created for performance

### Documentation
- [x] SUPABASE_QUICKREF.md - Quick reference
- [x] SUPABASE_SETUP.md - Comprehensive guide
- [x] .env.example updated
- [x] This checklist

---

## 🔧 Supabase Dashboard Setup

### 1. Apply Database Schema
```bash
# Copy contents of supabase/schema.sql
# Go to Supabase Dashboard > SQL Editor > New query
# Paste and run
```
- [ ] schema.sql applied successfully
- [ ] Verified all tables created: orgs, org_members, profiles, forms, form_versions, submissions, attachments, notifications, audit_log
- [ ] Verified RLS enabled on all tables
- [ ] Verified all policies created

### 2. Create Storage Bucket
- [ ] Go to Storage > New Bucket
- [ ] Name: `formbridge-attachments`
- [ ] Public access: **OFF** ⚠️
- [ ] Bucket created successfully
- [ ] Verified storage policies applied (check Policies tab)

### 3. Apply Seed Data
```bash
# Copy contents of supabase/seed.sql
# Go to Supabase Dashboard > SQL Editor > New query
# Paste and run
```
- [ ] seed.sql applied successfully
- [ ] Demo organization created (ID: 00000000-0000-0000-0000-000000000001)
- [ ] Sample form created

### 4. Verify Configuration
- [ ] Project URL matches: https://xpcibptzncfmifaneoop.supabase.co
- [ ] Anon key matches configured value
- [ ] Service role key stored securely (NEVER in client code)

---

## 👤 User Setup (First Time)

### 1. Sign Up Test User
- [ ] Run the mobile app: `./run-mobile.sh`
- [ ] Navigate to sign up/authentication
- [ ] Create test account (email/password)
- [ ] Note the user's email: _________________

### 2. Get User ID
- [ ] Go to Supabase Dashboard > Authentication > Users
- [ ] Find your test user
- [ ] Copy the UUID: _________________

### 3. Add User to Organization
```sql
-- Run in Supabase SQL Editor
INSERT INTO org_members (org_id, user_id, role, created_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',  -- Demo org
  'PASTE_USER_UUID_HERE',                    -- Your user UUID
  'admin',
  NOW()
);
```
- [ ] Query executed successfully
- [ ] Verified in org_members table

### 4. Create User Profile
```sql
-- Run in Supabase SQL Editor
INSERT INTO profiles (id, org_id, email, first_name, last_name, role, created_at, updated_at)
VALUES (
  'PASTE_USER_UUID_HERE',                    -- Same user UUID
  '00000000-0000-0000-0000-000000000001',  -- Demo org
  'your-email@example.com',                 -- User's email
  'Test',
  'User',
  'admin',
  NOW(),
  NOW()
);
```
- [ ] Query executed successfully
- [ ] Verified in profiles table
- [ ] org_id is set correctly

### 5. Restart App
- [ ] Stop the app
- [ ] Run again: `./run-mobile.sh`
- [ ] Sign in with test user
- [ ] Dashboard should now load with org data

---

## 🧪 Testing Flows

### Authentication Flow
- [ ] User can sign up
- [ ] User can sign in
- [ ] User profile loads with orgId
- [ ] Dashboard displays after login
- [ ] User can sign out

### Dashboard Data Flow
- [ ] Forms list loads from Supabase
- [ ] Submissions list loads
- [ ] Notifications load
- [ ] Stats calculate correctly (forms count, submissions count, unread notifications)
- [ ] No demo fallback data shown (real Supabase data)

### Form Creation Flow
- [ ] Navigate to create form
- [ ] Fill out form details
- [ ] Submit form
- [ ] Form appears in Supabase `forms` table
- [ ] Form has correct org_id
- [ ] Form appears in app's form list

### Form Submission Flow (Critical Path)
- [ ] Select a form to fill
- [ ] Fill out form fields
- [ ] Add a photo/file attachment
- [ ] Submit form
- [ ] Check Supabase:
  - [ ] Submission in `submissions` table with org_id
  - [ ] Attachment record in `attachments` table with org_id
  - [ ] File in Storage bucket at path: `org-{orgId}/submissions/{timestamp}_{filename}`
- [ ] Verify RLS:
  - [ ] Can view own org's submissions
  - [ ] Cannot view other org's submissions (create second org to test)

### Storage Security Testing
- [ ] Upload file through app
- [ ] Note the path: `org-{orgId}/submissions/...`
- [ ] Go to Storage > formbridge-attachments
- [ ] Verify file exists at correct path
- [ ] Check file is accessible by org member
- [ ] Try to access file from different org (should fail)

### Offline Queue Flow
- [ ] Turn off device network/airplane mode
- [ ] Fill and submit a form with attachment
- [ ] Verify "Submit failed" message
- [ ] Check SharedPreferences has pending submission
- [ ] Turn network back on
- [ ] Wait or trigger retry
- [ ] Verify submission syncs to Supabase
- [ ] Verify pending queue clears

### RLS Policy Verification
```sql
-- Test as authenticated user in SQL Editor
-- Should only see your org's data
SELECT * FROM forms;
SELECT * FROM submissions;
SELECT * FROM attachments;
```
- [ ] Only sees own org's forms
- [ ] Only sees own org's submissions
- [ ] Only sees own org's attachments
- [ ] Cannot INSERT into another org's data

---

## 🔍 Monitoring & Verification

### In Supabase Dashboard

#### Database
- [ ] Table Editor > orgs (at least 1 row)
- [ ] Table Editor > org_members (your user)
- [ ] Table Editor > profiles (your user with org_id)
- [ ] Table Editor > forms (has data)
- [ ] Table Editor > submissions (after testing)
- [ ] Table Editor > attachments (after upload testing)

#### Storage
- [ ] Storage > formbridge-attachments
- [ ] Files organized under org-{orgId}/submissions/
- [ ] File count matches attachment records
- [ ] No files in "public" folder (production)

#### Authentication
- [ ] Authentication > Users (shows test users)
- [ ] Authentication > Policies (RLS active)
- [ ] No failed auth attempts (or expected ones)

#### Logs
- [ ] Logs > API Logs (check for errors)
- [ ] Logs > Auth Logs (check failed attempts)
- [ ] Logs > Storage Logs (check upload activity)

---

## ⚠️ Common Issues & Solutions

### 403 Forbidden on File Upload
**Symptoms:** Upload fails with 403 error
**Causes:**
- User not in org_members table
- Path doesn't start with org-{orgId}/
- Storage bucket is public (should be private with RLS)
- Storage policies not applied

**Fix:**
1. Verify user in org_members: `SELECT * FROM org_members WHERE user_id = 'USER_UUID';`
2. Check upload path in logs
3. Verify bucket is NOT public
4. Re-run storage policy section of schema.sql

### Forms/Submissions Not Loading
**Symptoms:** Empty lists or errors in app
**Causes:**
- User profile missing org_id
- Not in org_members table
- RLS policies not enabled
- Wrong org_id in profile

**Fix:**
1. Check profile: `SELECT * FROM profiles WHERE id = 'USER_UUID';`
2. Verify org_id is set
3. Check org_members: `SELECT * FROM org_members WHERE user_id = 'USER_UUID';`
4. Verify RLS enabled: Check Database > Policies

### orgId is null in App
**Symptoms:** Upload falls back to "public" folder
**Causes:**
- Profile not created for user
- Profile fetch failed
- App not restarted after profile creation

**Fix:**
1. Create profile with org_id
2. Restart app completely
3. Check userProfileProvider in code
4. Add logging to verify profile fetch

### Demo Fallback Data Shows Instead of Real Data
**Symptoms:** Sample data appears instead of Supabase data
**Causes:**
- Supabase query failing silently
- Network issues
- RLS blocking access
- Wrong credentials

**Fix:**
1. Check network connectivity
2. Verify credentials in dart-defines
3. Check Supabase logs for errors
4. Test query in SQL Editor as same user

---

## 🏁 Production Readiness Checklist

### Security
- [ ] Service role key stored server-side only
- [ ] Anon key is truly anonymous (RLS enforced)
- [ ] All tables have RLS enabled
- [ ] All tables have appropriate policies
- [ ] Storage bucket is NOT public
- [ ] Storage policies enforce org boundaries
- [ ] No sensitive data in client code
- [ ] .env files in .gitignore

### Code Quality
- [ ] Remove demo fallback code (or document as temporary)
- [ ] Add proper error handling
- [ ] Add user-friendly error messages
- [ ] Add loading states
- [ ] Add retry logic for transient failures
- [ ] Add conflict resolution for offline sync

### Performance
- [ ] Indexes created on foreign keys
- [ ] Queries use .select() with specific columns
- [ ] Large lists paginated
- [ ] Images compressed before upload
- [ ] File size limits enforced

### Monitoring
- [ ] CI/CD runs `flutter analyze`
- [ ] CI/CD runs `flutter test`
- [ ] Error tracking configured
- [ ] Storage usage monitored
- [ ] API usage monitored
- [ ] Alerts set up for quota limits

### Documentation
- [ ] API documented for team
- [ ] RLS policies documented
- [ ] Storage structure documented
- [ ] Deployment process documented
- [ ] Rollback process documented

---

## 📝 Test Sign-Off

### Tested By: _________________
### Date: _________________
### Environment: [ ] Dev [ ] Staging [ ] Production

### All Critical Flows Passing?
- [ ] Authentication ✓
- [ ] Data Loading ✓
- [ ] Form Creation ✓
- [ ] Form Submission ✓
- [ ] File Upload ✓
- [ ] Offline Sync ✓
- [ ] RLS Security ✓

### Notes:
```
Add any issues found, workarounds, or observations here:




```

---

## 🎯 Next Steps After Testing

1. **If All Tests Pass:**
   - [ ] Remove demo fallback code
   - [ ] Add production error handling
   - [ ] Set up CI/CD pipeline
   - [ ] Configure production Supabase project
   - [ ] Deploy to TestFlight/Play Store internal testing

2. **If Issues Found:**
   - [ ] Document issues in GitHub Issues
   - [ ] Prioritize fixes
   - [ ] Re-test after fixes
   - [ ] Update documentation

3. **Team Onboarding:**
   - [ ] Share SUPABASE_QUICKREF.md with team
   - [ ] Walk through setup process
   - [ ] Document any team-specific processes
   - [ ] Set up shared development org

---

**Quick Start Command:**
```bash
# Mobile
./run-mobile.sh

# Web
./run-web.sh
```

**Documentation:**
- Quick Ref: `SUPABASE_QUICKREF.md`
- Full Setup: `SUPABASE_SETUP.md`
- This Checklist: `SUPABASE_PREFLIGHT.md`
