/// Build-time public backend settings. Never supplies a fallback backend.
class Configuration {
  const Configuration({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  factory Configuration.fromEnvironment() => const Configuration(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get isValid {
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        (uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                [
                  'localhost',
                  '127.0.0.1',
                  '::1',
                  '10.0.2.2',
                ].contains(uri.host))) &&
        RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$')
            .hasMatch(supabasePublishableKey);
  }
}
