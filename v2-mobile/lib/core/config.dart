import 'dart:convert';

class AppConfig {
  const AppConfig(this.url, this.key);
  const AppConfig.environment()
    : url = const String.fromEnvironment('SUPABASE_URL'),
      key = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final String url;
  final String key;
  bool get isValid {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    if (key.startsWith('sb_publishable_')) return true;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(key.split('.')[1]))),
      );
      return payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }
}
