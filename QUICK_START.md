# 🚀 Quick Start Guide - Form Bridge

## Prerequisites Check
- ✅ Flutter SDK 3.10.3+ installed
- ✅ Dart SDK 3.10.3+ installed  
- ✅ All dependencies resolved

## 🎯 Running Your Application

### Option 1: Backend Server Only
```bash
cd packages/backend
dart run bin/server.dart
```
Server will start at: **http://localhost:8080**

Test it:
```bash
curl http://localhost:8080
# Response: Form Bridge API Server - Version: 2.0.0

curl http://localhost:8080/health
# Response: OK
```

### Option 2: Mobile App
```bash
cd apps/mobile
flutter run
```
Choose your device:
- `1` - iOS Simulator
- `2` - Android Emulator
- `3` - Chrome (Web)

### Option 3: Run Both (Development Mode)

**Terminal 1 - Backend:**
```bash
cd packages/backend
dart run bin/server.dart
```

**Terminal 2 - Mobile App:**
```bash
cd apps/mobile
flutter run
```

## 📱 Test the Mobile App

1. **Login Screen** - Should see Form Bridge branding
2. **Dashboard** - Navigate through tabs (Home, Forms, Alerts, Profile)
3. **Quick Actions** - Photo Capture, Scan QR, Documents, Training

## 🔌 API Endpoints Available

All endpoints at **http://localhost:8080/api/**:

### Authentication
- `POST /api/auth/login`
- `POST /api/auth/register`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`

### Forms
- `GET /api/forms` - List all forms
- `GET /api/forms/:id` - Get specific form
- `POST /api/forms` - Create new form
- `PUT /api/forms/:id` - Update form
- `DELETE /api/forms/:id` - Delete form

### Submissions
- `GET /api/submissions`
- `POST /api/submissions`
- `GET /api/submissions/:id`
- `PUT /api/submissions/:id`

### Employees
- `GET /api/employees`
- `POST /api/employees`

### And many more! (50+ endpoints total)

## 🛠️ Development Workflow

### 1. Make Changes to Backend
```bash
cd packages/backend
# Edit bin/server.dart or add new routes
# Server will auto-reload (or restart manually)
dart run bin/server.dart
```

### 2. Make Changes to Mobile
```bash
cd apps/mobile
# Edit lib/ files
# Hot reload: Press 'r' in terminal
# Hot restart: Press 'R' in terminal
flutter run
```

### 3. Make Changes to Shared Models
```bash
cd packages/shared
# Edit lib/src/models/
# Both backend and mobile will use updated models
dart pub get  # If needed
```

## 🔍 Debugging

### Check Logs
```bash
# Backend logs in terminal
# Mobile app logs in terminal or device console
```

### Common Issues

**Port already in use:**
```bash
lsof -ti:8080 | xargs kill -9
```

**Dependencies out of sync:**
```bash
flutter pub get
dart pub get
```

**iOS build issues:**
```bash
cd apps/mobile/ios
pod install
cd ..
flutter clean
flutter pub get
```

## 📊 Project Structure Quick Reference

```
Form_Pulse/
├── apps/
│   ├── mobile/          # Flutter app (iOS/Android)
│   │   ├── lib/
│   │   │   ├── features/    # Feature modules
│   │   │   ├── core/        # Core services
│   │   │   └── main.dart    # Entry point
│   │   └── pubspec.yaml
│   └── web/             # Flutter web app
├── packages/
│   ├── shared/          # Shared models/utils
│   │   └── lib/src/
│   │       ├── models/      # Domain models
│   │       ├── enums/       # Enumerations
│   │       ├── constants/   # Constants
│   │       └── utils/       # Utilities
│   ├── backend/         # Dart API server
│   │   └── bin/server.dart  # Main server
│   └── ai_service/      # AI integration
├── .env.example         # Environment template
└── README.md           # Full documentation
```

## 🎨 Customization Tips

### Change App Theme
Edit: `apps/mobile/lib/main.dart`
```dart
colorScheme: ColorScheme.fromSeed(
  seedColor: const Color(0xFF2196F3), // Change this color
),
```

### Add New API Endpoint
Edit: `packages/backend/bin/server.dart`
```dart
final _router = Router()
  ..get('/api/your-endpoint', _yourHandler);

Response _yourHandler(Request req) {
  return Response.ok('{"data": "your data"}');
}
```

### Add New Model
Create: `packages/shared/lib/src/models/your_model.dart`
Export in: `packages/shared/lib/shared.dart`

## ✅ Verification Checklist

- [ ] Backend starts on http://localhost:8080
- [ ] Mobile app builds without errors
- [ ] Can navigate between screens
- [ ] All packages resolve dependencies
- [ ] No compilation errors

## 🚀 Ready to Build!

You're all set! Start by:
1. Implementing the form builder UI
2. Adding database integration
3. Creating actual API implementations
4. Setting up Firebase
5. Integrating OpenAI for AI features

Check [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) for what's been built.
Check [README.md](README.md) for comprehensive documentation.

Happy coding! 🎉
