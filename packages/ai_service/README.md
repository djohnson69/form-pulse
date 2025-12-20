<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages). 
-->


## Form Force AI Service

This package provides AI-powered data validation, text extraction, and image analysis for the Form Force 2.0 platform. It now calls OpenAI's chat/vision endpoints out of the box.


## Features
- AI-powered form data validation (OpenAI chat)
- OCR and text extraction from images (OpenAI vision)
- Image content analysis and quality checks
- Suggestions and field enhancement


## Getting started
Add this package as a dependency in your Dart/Flutter project:

```yaml
dependencies:
	ai_service:
		path: ../ai_service
```

### Configuration

Set your OpenAI API key before running. For local dev you can use a `.env` file or shell export (do not commit secrets):

```bash
export OPENAI_API_KEY=sk-...
export OPENAI_MODEL=gpt-4o-mini           # optional
export OPENAI_BASE_URL=https://api.openai.com/v1  # optional
export OPENAI_ORG=org_...                 # optional
```

For Flutter, you can also pass build-time defines:

```bash
flutter run --dart-define=OPENAI_API_KEY=sk-... --dart-define=OPENAI_MODEL=gpt-4o-mini
```

Constructor options:
- `apiKey` (required): your OpenAI key.
- `model` (optional): defaults to `gpt-4o-mini`.
- `baseUrl` (optional): defaults to `https://api.openai.com/v1` (supports compatible proxies).
- `organization` (optional): forwarded via `OpenAI-Organization` header.

You can also load from env/defines:

```dart
final config = AIServiceConfig.fromEnvironment();
final ai = config.toService();
```


## Usage
Import and use the AI service:

```dart
import 'package:ai_service/ai_service.dart';

final ai = AIService(apiKey: Platform.environment['OPENAI_API_KEY']!);

// Validate a payload
final result = await ai.validateData(data: {'email': 'user@domain'}, context: 'signup');

// Enhance a single field
final enhanced = await ai.enhanceFieldValue(value: 'Main st', fieldType: 'address');

// OCR an image
final text = await ai.extractTextFromImage('/tmp/photo.png');

// Analyze image quality
final quality = await ai.checkImageQuality('/tmp/photo.png');
```


## Supabase Setup Checklist

- [ ] Apply schema.sql and seed.sql to your Supabase project
- [ ] Create a storage bucket named `formbridge-attachments`
- [ ] Set environment variables: SUPABASE_URL, SUPABASE_ANON_KEY
- [ ] Add at least one org member and user profile

## Additional information
See the main project README for more details. Contributions welcome!
