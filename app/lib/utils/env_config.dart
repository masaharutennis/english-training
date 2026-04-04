/// `--dart-define-from-file=.env` または `--dart-define=KEY=value` で渡す。
///
/// OpenAI のキーは **Flutter 側には置かない**。自前 API（`api/main.py`）のベース URL のみ。
/// Supabase の anon キーはクライアントに埋め込まれる前提（RLS で保護する）。
class EnvConfig {
  EnvConfig._();

  /// 末尾スラッシュなし。例: http://127.0.0.1:8000 または https://xxx.vercel.app
  static const String correctionApiBaseUrl = String.fromEnvironment(
    'CORRECTION_API_BASE_URL',
  );

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get correctionApiBaseUrlResolved => correctionApiBaseUrl.trim();
  static String get supabaseUrlResolved => supabaseUrl.trim();
  static String get supabaseAnonKeyResolved => supabaseAnonKey.trim();

  static bool get hasCorrectionApiBaseUrl => correctionApiBaseUrlResolved.isNotEmpty;
  static bool get hasSupabase =>
      supabaseUrlResolved.isNotEmpty && supabaseAnonKeyResolved.isNotEmpty;
}
