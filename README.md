# Form Bridge

<div align="center">
  <h1>🚀 Form Bridge</h1>
  <p><strong>Living Forms & Field Intelligence Platform</strong></p>
  <p>Turn every form into a guided, AI-driven workflow with real-time context and validation</p>
</div>

## 📋 Overview

Form Bridge is a comprehensive Flutter/Dart full-stack platform that breathes life into forms by pairing a modern mobile + web experience with AI guardrails, real-time collaboration, and offline-first resilience. It correlates employees, job sites, training, vendors, equipment, and documents so every submission carries the right context for action, analysis, verification, and validation.

**Why Form Bridge**
- Living forms with photos, video, GPS, date/time stamps, and conditional logic baked in.
- AI co-pilots for validation, OCR, and suggestions that keep data clean at the edge.
- Real-time signal routing: push notifications, news, alerts, and assignments across teams.
- Enterprise data mesh linking employees, job sites, training, vendors, equipment, and documents.
- Export/ingest ready with reporting, CSV/PDF/Excel, and integration hooks for RFID, iBeacon, and fleet GPS.

### ✨ Key Features

#### 📱 Multi-Platform Support
- **Flutter Mobile** - iOS & Android apps with native performance
- **Flutter Web** - Responsive web application
- **Offline-First** - Work anywhere, sync when connected

#### 🎨 Custom Form Builder
- Drag-and-drop form designer
- 20+ field types (text, photo, video, GPS, signatures, etc.)
- Conditional logic and validation rules
- Template library for common forms

#### 🤖 AI-Enhanced Data Capture
- Intelligent field validation
- OCR for photo/document extraction
- Auto-complete suggestions
- Data quality assurance

#### 📸 Rich Media Capture
- Photo capture with GPS tagging
- Video recording with timestamps
- Document upload and management
- Signature capture
- Barcode/QR code scanning
- RFID tag reading

#### 👥 Team Collaboration
- Real-time form submissions
- Push notifications
- Employee roster management
- Training and compliance tracking
- Role-based access control

#### 📊 Advanced Features
- Client and vendor portals
- Job site management
- Equipment tracking
- Document version control
- Custom reporting and analytics
- Data export (CSV, PDF, Excel)

#### 🔒 Security & Compliance
- End-to-end encryption
- Secure authentication (JWT)
- Audit logging
- GDPR compliance ready

## 🏗️ Architecture

```
Form_Pulse/
├── apps/
│   └── mobile/          # Flutter app (iOS, Android, Web)
├── packages/
│   ├── shared/          # Shared domain models and utilities
│   ├── backend/         # Dart REST API server
│   └── ai_service/      # AI validation and enhancement service
└── .github/
    └── copilot-instructions.md
```

### Tech Stack

**Frontend:**
- Flutter 3.x (Web + Mobile)
- Riverpod (State Management)
- Drift (Local Database)
- Google Maps, Camera, GPS integrations

**Backend:**
- Dart + Shelf (REST API)
- PostgreSQL (Primary Database)
- WebSockets (Real-time features)
- Docker (Containerization)

**AI/ML:**
- OpenAI API (GPT-4)
- OCR for text extraction
- Image analysis
- Data validation

**Infrastructure:**
- Firebase (Push Notifications)
- AWS S3 (File Storage)
- Redis (Caching - Optional)

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** 3.10.3 or higher
- **Dart SDK** 3.10.3 or higher
- **PostgreSQL** 14 or higher
- **Docker** (optional, for containerized deployment)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/form_pulse.git
   cd form_pulse
   ```

2. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Install dependencies**

   Flutter app:
   ```bash
   cd apps/mobile
   flutter pub get
   ```

   Backend:
   ```bash
   cd packages/backend
   dart pub get
   ```

   Shared packages:
   ```bash
   cd packages/shared
   dart pub get
   cd ../ai_service
   dart pub get
   ```

4. **Set up the database**
   ```bash
   # Create PostgreSQL database
   createdb formpulse
   
   # Run migrations (coming soon)
   # dart run packages/backend/bin/migrate.dart
   ```

### Running the Applications

**Start the backend server:**
```bash
cd packages/backend
dart run bin/server.dart
```

**Run the mobile app:**
```bash
./run-mobile.sh
# or manually:
cd apps/mobile
flutter run
```

**Run the web app:**
```bash
./run-web.sh
# or manually:
cd apps/mobile
flutter run -d chrome
```

## 📖 Documentation

### Project Structure

- **`apps/mobile/`** - Flutter multi-platform application (iOS, Android, Web)
  - `lib/features/` - Feature-based modules (auth, forms, dashboard, etc.)
  - `lib/core/` - Core services and utilities
  - `lib/app/` - App-level configuration

- **`packages/shared/`** - Shared code
  - `lib/src/models/` - Domain models
  - `lib/src/enums/` - Enumerations
  - `lib/src/constants/` - Constants
  - `lib/src/utils/` - Utility functions

- **`packages/backend/`** - Dart backend API
  - `bin/server.dart` - Main server entry point
  - REST API endpoints for all features

- **`packages/ai_service/`** - AI integration
  - Data validation
  - Text extraction (OCR)
  - Image analysis

### Key Concepts

#### Form Definitions
Forms are defined with flexible field types and validation rules. Each form can have:
- Multiple field types (text, number, photo, GPS, etc.)
- Conditional logic (show/hide fields based on answers)
- Custom validation rules
- Media attachments

#### Offline-First Architecture
- All data stored locally in SQLite (via Drift)
- Automatic sync when network is available
- Conflict resolution strategies
- Queue management for pending submissions

#### Real-Time Features
- WebSocket connections for live updates
- Push notifications via Firebase
- Collaborative form editing
- Live activity feeds

## 🔧 Configuration

### Mobile App Configuration

**Android:**
- Update `android/app/build.gradle` with your package name
- Configure Firebase in `android/app/google-services.json`

**iOS:**
- Update `ios/Runner/Info.plist` with permissions
- Configure Firebase in `ios/Runner/GoogleService-Info.plist`

### Backend Configuration

Edit `.env` file with your settings:
- Database connection
- JWT secrets
- OpenAI API key
- Firebase credentials
- AWS S3 credentials

## 🧪 Testing

```bash
# Run mobile app tests
cd apps/mobile
flutter test

# Run backend tests
cd packages/backend
dart test

# Run shared package tests
cd packages/shared
dart test
```

## 📦 Deployment

### Backend Deployment

**Using Docker:**
```bash
cd packages/backend
docker build -t formpulse-api .
docker run -p 8080:8080 --env-file .env formpulse-api
```

**Without Docker:**
```bash
dart compile exe bin/server.dart -o server
./server
```

### Mobile App Deployment

**iOS:**
```bash
cd apps/mobile
flutter build ios --release
```

**Android:**
```bash
cd apps/mobile
flutter build apk --release
# or
flutter build appbundle --release
```

### Web Deployment

```bash
cd apps/web
flutter build web --release
# Deploy the build/web directory to your hosting service
```

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- OpenAI for AI capabilities
- All open-source package contributors

## 📞 Support

For support, email support@formpulse.com or join our Slack channel.

## 🗺️ Roadmap

- [ ] Advanced form analytics dashboard
- [ ] Multi-language support
- [ ] Voice input for form fields
- [ ] Advanced AI auto-fill
- [ ] Blockchain verification (optional)
- [ ] Desktop applications (Windows, macOS, Linux)
- [ ] Integration marketplace (Zapier, Make, etc.)

---

<div align="center">
  Made with ❤️ by the Form Bridge Team
</div>
