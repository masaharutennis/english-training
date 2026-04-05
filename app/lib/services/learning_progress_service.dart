import 'package:supabase_flutter/supabase_flutter.dart';

/// `learning_item_attempts` への記録。
class LearningProgressService {
  LearningProgressService._();

  static Future<void> recordAttempt({
    required int learningItemId,
    required int score,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('learning_item_attempts').insert({
      'user_id': user.id,
      'learning_item_id': learningItemId,
      'score': score.clamp(0, 100),
    });
  }
}
