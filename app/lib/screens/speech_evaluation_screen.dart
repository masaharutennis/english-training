import 'package:flutter/material.dart';

import '../models/blogmae_entry.dart';
import '../models/speech_evaluation_result.dart';
import '../services/composition_api_client.dart';
import '../services/learning_progress_service.dart';
import '../utils/english_answer_diff.dart';

/// 発話の簡易評価（スコア + 短いアドバイス）。「次へ」で [Navigator.pop] にスコアを返す。
class SpeechEvaluationScreen extends StatefulWidget {
  const SpeechEvaluationScreen({
    super.key,
    required this.entry,
    required this.userTranscript,
  });

  final BlogmaeEntry entry;
  final String userTranscript;

  @override
  State<SpeechEvaluationScreen> createState() => _SpeechEvaluationScreenState();
}

class _SpeechEvaluationScreenState extends State<SpeechEvaluationScreen> {
  late Future<SpeechEvaluationResult> _future;

  @override
  void initState() {
    super.initState();
    _future = CompositionApiClient().evaluateSpeech(
      entry: widget.entry,
      userEnglish: widget.userTranscript,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('解答を確認'),
      ),
      body: FutureBuilder<SpeechEvaluationResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('評価中…'),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('戻る'),
                    ),
                  ],
                ),
              ),
            );
          }

          final r = snapshot.data!;
          final colorScheme = Theme.of(context).colorScheme;
          final baseStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(height: 1.4);
          final model = widget.entry.english;
          final user = widget.userTranscript;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _block(context, 'お題（日本語）', widget.entry.japanese),
              _labeledDiffSection(
                context,
                label: 'あなたの発話（認識結果）',
                spans: EnglishAnswerDiff.spansForUser(
                  model,
                  user,
                  baseStyle,
                  colorScheme.onSurface,
                ),
                baseStyle: baseStyle,
              ),
              _labeledDiffSection(
                context,
                label: '模範解答（英文）',
                spans: EnglishAnswerDiff.spansForModel(
                  model,
                  user,
                  baseStyle,
                  colorScheme.onSurface,
                ),
                baseStyle: baseStyle,
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'スコア',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${r.score} / 100',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
              ),
              if (r.advice.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'フィードバック',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  r.advice,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () async {
                  await LearningProgressService.recordAttempt(
                    learningItemId: widget.entry.learningItemId,
                    score: r.score.clamp(0, 100),
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).pop(r.score.clamp(0, 100));
                },
                child: const Text('次の問題へ'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _block(BuildContext context, String label, String body) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _labeledDiffSection(
    BuildContext context, {
    required String label,
    required List<TextSpan> spans,
    required TextStyle baseStyle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          SelectableText.rich(
            TextSpan(style: baseStyle, children: spans),
          ),
        ],
      ),
    );
  }
}
