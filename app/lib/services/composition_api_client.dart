import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/blogmae_entry.dart';
import '../models/speech_evaluation_result.dart';
import '../utils/env_config.dart';

class CompositionApiException implements Exception {
  CompositionApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 自前 API（`api/main.py`）へだけ HTTP する。
class CompositionApiClient {
  Future<SpeechEvaluationResult> evaluateSpeech({
    required BlogmaeEntry entry,
    required String userEnglish,
  }) async {
    if (!EnvConfig.hasCorrectionApiBaseUrl) {
      throw CompositionApiException(
        'CORRECTION_API_BASE_URL が設定されていません。app/.env.example を参照し、'
        '--dart-define-from-file=.env で起動してください。',
      );
    }

    final base = EnvConfig.correctionApiBaseUrlResolved;
    final url = Uri.parse('$base/v1/composition/evaluate_speech');

    final res = await http.post(
      url,
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'grammar': entry.grammar,
        'japanese': entry.japanese,
        'english': entry.english,
        'user_english': userEnglish,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      var msg = res.body;
      try {
        final err = jsonDecode(res.body);
        if (err is Map && err['detail'] != null) {
          msg = err['detail'].toString();
        }
      } catch (_) {}
      final snippet = msg.length > 280 ? '${msg.substring(0, 280)}…' : msg;
      throw CompositionApiException('API エラー (${res.statusCode}): $snippet');
    }

    try {
      final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return SpeechEvaluationResult.fromJson(map);
    } catch (e) {
      throw CompositionApiException('レスポンスの解析に失敗: $e');
    }
  }
}
