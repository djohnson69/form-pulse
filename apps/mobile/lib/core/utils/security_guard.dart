class SecurityGuard {
  static void ensureHttps(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw StateError('Invalid SUPABASE_URL provided.');
    }
    final isLocalhost =
        uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (uri.scheme != 'https' && !isLocalhost) {
      throw StateError('SUPABASE_URL must use https for encrypted transport.');
    }
  }
}
