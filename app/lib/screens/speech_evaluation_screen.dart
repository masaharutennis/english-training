import 'package:flutter/material.dart';

import '../models/blogmae_entry.dart';
import '../models/speech_evaluation_result.dart';
import '../services/composition_api_client.dart';

/// 発話の簡易評価（スコア + 短いアドバイス）。
class SpeechEvaluationScreen extends StatefulWidget {
  const SpeechEvaluationScreen({
    super.key,
    required this.entry,
    required this.userTranscript,
    required this.onGoToNextQuestion,
  });

  final BlogmaeEntry entry;
  final String userTranscript;
  final void Function(BuildContext context) onGoToNextQuestion;

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

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _block(context, 'お題（日本語）', widget.entry.japanese),
              _block(
                context,
                'あなたの発話（認識結果）',
                widget.userTranscript.isEmpty ? '（空）' : widget.userTranscript,
              ),
              _block(context, '模範解答（英文）', widget.entry.english),
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
                onPressed: () => widget.onGoToNextQuestion(context),
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
}
