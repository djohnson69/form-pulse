# Form Force 2.0 - Copilot Instructions

## Project Overview
Form Force 2.0 is a comprehensive Flutter/Dart full-stack platform that transforms traditional forms into intelligent, living processes with AI-enhanced data capture.

## Architecture
- **Multi-platform**: Single Flutter codebase for Web, iOS, and Android
- **Monorepo structure**: Apps and shared packages
- **Backend**: Dart-based REST API with WebSocket support
- **Database**: PostgreSQL with offline-first sync
- **AI Integration**: OpenAI for intelligent data validation

## Tech Stack
- Flutter 3.x (Web + Mobile)
- Dart backend (dart_frog framework)
- PostgreSQL + Drift (local DB)
- Firebase (push notifications)
- OpenAI API (AI features)
- Docker (deployment)

## Project Structure
```
/apps
  /mobile - Flutter mobile application
  /web - Flutter web application
/packages
  /backend - Dart REST API server
  /shared - Shared models and utilities
  /ai_service - AI validation and enhancement
```

## Development Guidelines
- Use null-safety and strong typing
- Follow Flutter/Dart best practices
- Implement offline-first architecture
- Use dependency injection (get_it)
- State management with Riverpod
- Write unit and widget tests

## Key Features to Implement
- Custom drag-and-drop form builder
- Real-time collaboration and notifications
- Photo/video capture with GPS/timestamp
- Employee training and compliance tracking
- Document management with versioning
- Client/vendor portals
- Advanced reporting and analytics
- RFID/Beacon/GPS integration
- End-to-end encryption

## Status: In Progress
Currently scaffolding the project structure and implementing core features.
