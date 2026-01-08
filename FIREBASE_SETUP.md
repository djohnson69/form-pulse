# Firebase Setup Guide

Firebase is currently **disabled** to allow the app to run without configuration.

## Why Firebase?

Firebase provides:
- **Push Notifications** - Real-time alerts for form submissions, assignments, etc.
- **Cloud Messaging** - Cross-platform notification delivery
- **Analytics** - User behavior tracking (optional)

## Quick Setup (When Ready)

### Step 1: Install Firebase CLI

```bash
# Using npm
npm install -g firebase-tools

# Or using curl
curl -sL https://firebase.tools | bash
```

### Step 2: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Name it `formbridge-app` (or your preferred name)
4. Disable Google Analytics if you don't need it
5. Click "Create project"

### Step 3: Login to Firebase

```bash
firebase login
```

This will open your browser to authenticate.

### Step 4: Configure FlutterFire

```bash
# Navigate to mobile app
cd apps/mobile

# Run FlutterFire configuration
flutterfire configure --project=formbridge-app --platforms=ios,android,web

# This will:
# - Create lib/firebase_options.dart
# - Download android/app/google-services.json
# - Download ios/Runner/GoogleService-Info.plist
```

### Step 5: Enable Firebase in pubspec.yaml

Uncomment these lines in `apps/mobile/pubspec.yaml`:

```yaml
# Push Notifications
firebase_core: ^4.3.0        # Uncomment
firebase_messaging: ^16.1.0  # Uncomment
flutter_local_notifications: ^19.5.0
```

### Step 6: Install Dependencies

```bash
cd apps/mobile
flutter pub get
```

### Step 7: Enable Cloud Messaging

In Firebase Console:
1. Go to your project
2. Navigate to **Build** → **Cloud Messaging**
3. Click on **Cloud Messaging API (Legacy)** 
4. Enable the API

For iOS:
1. Upload your APNs certificate or key
2. Get from Apple Developer Portal

### Step 8: Test

```bash
./run-mobile.sh
# or
./run-web.sh
```

## Current State

✅ FlutterFire CLI installed  
❌ Firebase CLI not installed  
❌ Firebase project not created  
❌ Firebase dependencies disabled in pubspec.yaml  
✅ Push notification service handles missing Firebase gracefully

## Alternative: Skip Firebase

If you don't need push notifications yet:
1. Keep Firebase disabled (current state)
2. The app will run fine without it
3. Push notifications will be skipped
4. You can add Firebase later when needed

## Troubleshooting

### Error: "Firebase not initialized"
- Make sure `firebase_options.dart` exists
- Check that `firebase_core` is uncommented in pubspec.yaml

### Error: "google-services.json not found"
- Run `flutterfire configure` again
- Make sure file is in `android/app/google-services.json`

### iOS Build Error
- Check that `GoogleService-Info.plist` is in `ios/Runner/`
- Rebuild with `flutter clean && flutter build ios`

### Already Configured?
If you've already run `flutterfire configure`:
1. Uncomment Firebase dependencies in pubspec.yaml
2. Run `flutter pub get`
3. Rebuild the app

## References

- [FlutterFire Docs](https://firebase.flutter.dev/docs/overview)
- [Firebase Console](https://console.firebase.google.com/)
- [Cloud Messaging Setup](https://firebase.flutter.dev/docs/messaging/overview)
