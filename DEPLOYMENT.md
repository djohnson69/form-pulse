# 🚀 Form Bridge - Deployment Guide

## Production Deployment Checklist

### Pre-Deployment Requirements

#### 1. Environment Configuration
- [ ] Supabase project created (production instance)
- [ ] Database schema applied ([supabase/schema.sql](supabase/schema.sql))
- [ ] Storage bucket created: `formbridge-attachments`
- [ ] RLS policies verified and enabled
- [ ] Seed data applied if needed ([supabase/seed.sql](supabase/seed.sql))

#### 2. Credentials & Secrets
- [ ] Production Supabase URL obtained
- [ ] Production Supabase Anon Key obtained  
- [ ] Service Role Key secured (backend only, never in client)
- [ ] All keys stored in secure location (e.g., 1Password, AWS Secrets Manager)
- [ ] Environment variables configured for CI/CD

#### 3. Code Review
- [ ] Remove all demo/fallback data
- [ ] Remove debug logging
- [ ] Update API base URLs to production
- [ ] Verify error handling is comprehensive
- [ ] Security audit completed

---

## Platform-Specific Deployment

### 📱 iOS App Store

#### Prerequisites
- Apple Developer Account ($99/year)
- Xcode 15+ on macOS
- Valid certificates and provisioning profiles

#### Steps

1. **Configure iOS Project**
   ```bash
   cd apps/mobile/ios
   open Runner.xcworkspace
   ```
   - Set Bundle Identifier (e.g., `com.formbridge.mobile`)
   - Set Version and Build Number
   - Configure signing (Team & Provisioning Profile)
   - Update `Info.plist` with required permissions

2. **Build for Release**
   ```bash
   cd apps/mobile
   flutter build ios --release \
     --dart-define=SUPABASE_URL=https://your-prod-project.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=your_prod_anon_key \
     --dart-define=SUPABASE_BUCKET=formbridge-attachments
   ```

3. **Archive & Upload**
   - Open Xcode
   - Product > Archive
   - Distribute App > App Store Connect
   - Upload to TestFlight first for testing
   - Submit for App Review when ready

4. **App Store Connect**
   - Set app metadata (name, description, screenshots)
   - Set pricing and availability
   - Submit for review

**Required Permissions in Info.plist:**
```xml
<key>NSCameraUsageDescription</key>
<string>Take photos for form submissions</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Select photos for form submissions</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Capture location data with submissions</string>
<key>NSMicrophoneUsageDescription</key>
<string>Record videos for form submissions</string>
```

---

### 🤖 Android Play Store

#### Prerequisites
- Google Play Console Account ($25 one-time)
- Android signing keys (keystore)

#### Steps

1. **Generate Signing Key**
   ```bash
   keytool -genkey -v -keystore ~/formbridge-release-key.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias formbridge
   ```

2. **Configure Signing**
   Create `apps/mobile/android/key.properties`:
   ```properties
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=formbridge
   storeFile=<path-to-keystore>
   ```

   Update `apps/mobile/android/app/build.gradle`:
   ```gradle
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }

   android {
       ...
       signingConfigs {
           release {
               keyAlias keystoreProperties['keyAlias']
               keyPassword keystoreProperties['keyPassword']
               storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
               storePassword keystoreProperties['storePassword']
           }
       }
       buildTypes {
           release {
               signingConfig signingConfigs.release
           }
       }
   }
   ```

3. **Build Release APK/AAB**
   ```bash
   cd apps/mobile
   flutter build appbundle --release \
     --dart-define=SUPABASE_URL=https://your-prod-project.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=your_prod_anon_key \
     --dart-define=SUPABASE_BUCKET=formbridge-attachments
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`

4. **Upload to Play Console**
   - Create app listing
   - Upload AAB
   - Complete store listing (screenshots, descriptions)
   - Submit for review

**Required Permissions in AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

---

### 🌐 Web Deployment

#### Build for Production
```bash
cd apps/mobile
flutter build web --release \
  --dart-define=SUPABASE_URL=https://your-prod-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_prod_anon_key \
  --dart-define=SUPABASE_BUCKET=formbridge-attachments
```
Output directory: `build/web/`

#### Deployment Options

**Option 1: Firebase Hosting**
```bash
npm install -g firebase-tools
firebase login
firebase init hosting
firebase deploy
```

**Option 2: Vercel**
```bash
npm install -g vercel
cd build/web
vercel --prod
```

**Option 3: Netlify**
- Drag & drop `build/web` to Netlify
- Or connect GitHub repo and set build command:
  ```
  flutter build web --release
  ```
  Publish directory: `build/web`

**Option 4: AWS S3 + CloudFront**
```bash
aws s3 sync build/web/ s3://your-bucket-name --delete
aws cloudfront create-invalidation --distribution-id YOUR_DIST_ID --paths "/*"
```

**Option 5: Docker + Nginx**
```dockerfile
# Dockerfile for web
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

### 🖥️ Backend API Deployment

#### Docker Deployment

1. **Build Docker Image**
   ```bash
   cd packages/backend
   docker build -t formbridge-api:latest .
   ```

2. **Deploy Options**

   **AWS ECS/Fargate:**
   ```bash
   # Push to ECR
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ECR_URL
   docker tag formbridge-api:latest YOUR_ECR_URL/formbridge-api:latest
   docker push YOUR_ECR_URL/formbridge-api:latest
   ```

   **Google Cloud Run:**
   ```bash
   gcloud run deploy formbridge-api \
     --image formbridge-api:latest \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated
   ```

   **Digital Ocean App Platform:**
   - Connect GitHub repo
   - Select Dockerfile
   - Configure environment variables
   - Deploy

   **Render:**
   - Connect GitHub repo
   - Auto-detects Dockerfile
   - Deploy

---

## CI/CD Pipeline

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      
      - name: Install dependencies
        run: |
          cd apps/mobile
          flutter pub get
      
      - name: Build Android
        run: |
          cd apps/mobile
          flutter build apk --release \
            --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
            --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }} \
            --dart-define=SUPABASE_BUCKET=formbridge-attachments
      
      - name: Upload to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          packageName: com.formbridge.mobile
          releaseFiles: apps/mobile/build/app/outputs/flutter-apk/app-release.apk
          track: internal

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      
      - name: Build iOS
        run: |
          cd apps/mobile
          flutter build ios --release --no-codesign \
            --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
            --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
      
      # Add fastlane or xcode-archive action for signing & upload

  build-web:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      
      - name: Build Web
        run: |
          cd apps/mobile
          flutter build web --release \
            --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
            --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
      
      - name: Deploy to Firebase
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
```

---

## Environment Variables

### Production Secrets
Store these securely and never commit to source control:

**Client (Mobile/Web):**
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_BUCKET`

**Backend/Server:**
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (never expose to clients!)
- `DATABASE_URL` (if using direct Postgres connection)

### Setting Secrets in CI/CD

**GitHub:**
- Settings > Secrets and variables > Actions
- Add repository secrets

**GitLab:**
- Settings > CI/CD > Variables

**Bitbucket:**
- Repository Settings > Pipelines > Repository variables

---

## Post-Deployment

### Monitoring
- [ ] Set up error tracking (Sentry, Firebase Crashlytics)
- [ ] Configure analytics (Firebase Analytics, Mixpanel)
- [ ] Set up uptime monitoring (UptimeRobot, Pingdom)
- [ ] Monitor Supabase usage and quotas

### Security
- [ ] Enable rate limiting on API
- [ ] Configure CORS properly
- [ ] Review and test RLS policies
- [ ] Enable 2FA on all admin accounts
- [ ] Regular security audits

### Maintenance
- [ ] Document runbook for common issues
- [ ] Set up automated backups (Supabase auto-backups)
- [ ] Create rollback procedure
- [ ] Schedule regular dependency updates

---

## Quick Deploy Commands

### Development
```bash
# Mobile (any platform)
./run-mobile.sh

# Web
./run-web.sh
```

### Production Builds
```bash
# iOS
cd apps/mobile && flutter build ios --release

# Android
cd apps/mobile && flutter build appbundle --release

# Web
cd apps/mobile && flutter build web --release

# Backend
cd packages/backend && docker build -t formbridge-api .
```

---

## Troubleshooting

### Build Failures
- Clear Flutter cache: `flutter clean && flutter pub get`
- Update Flutter: `flutter upgrade`
- Check platform requirements: `flutter doctor`

### Runtime Errors
- Check Supabase connection
- Verify environment variables
- Review logs in Supabase Dashboard
- Check device permissions

### Performance Issues
- Enable release mode optimizations
- Minimize bundle size
- Use tree-shaking
- Optimize images and assets

---

## Support & Resources

- **Flutter Docs:** https://docs.flutter.dev/deployment
- **Supabase Docs:** https://supabase.com/docs
- **App Store Guidelines:** https://developer.apple.com/app-store/review/guidelines/
- **Play Store Guidelines:** https://support.google.com/googleplay/android-developer/answer/9859152

---

**Ready for Production!** 🎉

Follow this guide step-by-step to deploy Form Bridge to production environments.
