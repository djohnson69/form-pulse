# Form Bridge Mobile

Flutter client for Form Bridge.

## Running with AI enabled

Pass your OpenAI key as a dart define (do not commit secrets):

```bash
flutter run \
	--dart-define=OPENAI_API_KEY=sk-... \
	--dart-define=OPENAI_MODEL=gpt-4o-mini \
	--dart-define=OPENAI_BASE_URL=https://api.openai.com/v1 \
	--dart-define=SUPABASE_URL=https://your-project.supabase.co \
	--dart-define=SUPABASE_ANON_KEY=your-anon-key
```

The app exposes `aiServiceProvider` for Riverpod consumers.
