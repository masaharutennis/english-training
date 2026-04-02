/// `--dart-define-from-file=.env` または `--dart-define=KEY=value` で渡す。
///
/// OpenAI のキーは **Flutter 側には置かない**。自前 API（`api/main.py`）のベース URL のみ。
class EnvConfig {
  EnvConfig._();

  /// 末尾スラッシュなし。例: http://127.0.0.1:8000 または https://xxx.vercel.app
  static const String correctionApiBaseUrl = String.fromEnvironment(
    'CORRECTION_API_BASE_URL',
  );

  static String get correctionApiBaseUrlResolved => correctionApiBaseUrl.trim();

  static bool get hasCorrectionApiBaseUrl => correctionApiBaseUrlResolved.isNotEmpty;
}
