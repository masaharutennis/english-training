/// 発話の正誤評価（簡易スコア + 短いアドバイス）。
class SpeechEvaluationResult {
  const SpeechEvaluationResult({
    required this.score,
    required this.advice,
  });

  final int score;
  final String advice;

  factory SpeechEvaluationResult.fromJson(Map<String, dynamic> json) {
    final s = json['score'];
    int score = 0;
    if (s is int) {
      score = s.clamp(0, 100);
    } else if (s is num) {
      score = s.round().clamp(0, 100);
    }
    return SpeechEvaluationResult(
      score: score,
      advice: json['advice']?.toString() ?? '',
    );
  }
}
