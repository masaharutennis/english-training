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

  /// 問題登録用。`ja_to_en`: 日本語お題から英文 / `en_to_ja`: 英文から日本語お題。
  Future<String> suggestDrillLine({
    required String direction,
    required String grammar,
    required String sourceText,
  }) async {
    if (!EnvConfig.hasCorrectionApiBaseUrl) {
      throw CompositionApiException(
        'CORRECTION_API_BASE_URL が設定されていません。app/.env.example を参照し、'
        '--dart-define-from-file=.env で起動してください。',
      );
    }
    final trimmed = sourceText.trim();
    if (trimmed.isEmpty) {
      throw CompositionApiException('変換元のテキストが空です。');
    }

    final base = EnvConfig.correctionApiBaseUrlResolved;
    final url = Uri.parse('$base/v1/composition/suggest_drill_line');

    final res = await http.post(
      url,
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'direction': direction,
        'grammar': grammar.trim(),
        'source_text': trimmed,
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
      final text = map['text']?.toString().trim() ?? '';
      if (text.isEmpty) {
        throw CompositionApiException('API が空のテキストを返しました');
      }
      return text;
    } catch (e) {
      if (e is CompositionApiException) rethrow;
      throw CompositionApiException('レスポンスの解析に失敗: $e');
    }
  }
}
