import 'package:english_training/models/speech_evaluation_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SpeechEvaluationResult.fromJson', () {
    final r = SpeechEvaluationResult.fromJson({
      'score': 82,
      'advice': 'よく言えています。',
    });
    expect(r.score, 82);
    expect(r.advice, 'よく言えています。');
  });
}
