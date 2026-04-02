import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/blogmae_entry.dart';
import '../services/blogmae_basic_loader.dart';
import '../widgets/slide_page_route.dart';
import 'speech_evaluation_screen.dart';

/// CSV を順番にカード表示。発話 STT → 解答確認。
class BlogmaeDeckFlowScreen extends StatefulWidget {
  const BlogmaeDeckFlowScreen({
    super.key,
    required this.assetPath,
    required this.courseTitle,
  });

  final String assetPath;
  final String courseTitle;

  @override
  State<BlogmaeDeckFlowScreen> createState() => _BlogmaeDeckFlowScreenState();
}

class _BlogmaeDeckFlowScreenState extends State<BlogmaeDeckFlowScreen> {
  late Future<List<BlogmaeEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = BlogmaeBasicLoader.load(widget.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BlogmaeEntry>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.courseTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.courseTitle)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('読み込みエラー: ${snapshot.error}'),
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.courseTitle)),
            body: const Center(child: Text('問題がありません')),
          );
        }
        return BlogmaeDeckScreen(
          entries: items,
          courseTitle: widget.courseTitle,
        );
      },
    );
  }
}

class BlogmaeDeckScreen extends StatefulWidget {
  const BlogmaeDeckScreen({
    super.key,
    required this.entries,
    required this.courseTitle,
    this.initialIndex = 0,
  });

  final List<BlogmaeEntry> entries;
  final String courseTitle;
  final int initialIndex;

  @override
  State<BlogmaeDeckScreen> createState() => _BlogmaeDeckScreenState();
}

class _BlogmaeDeckScreenState extends State<BlogmaeDeckScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  late int _index;
  String _transcript = '';
  bool _speechReady = false;
  String? _speechError;
  bool _listening = false;

  BlogmaeEntry get _current => widget.entries[_index];

  @override
  void initState() {
    super.initState();
    final maxI = widget.entries.isEmpty ? 0 : widget.entries.length - 1;
    _index = widget.initialIndex.clamp(0, maxI);
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(
      onError: (e) {
        if (mounted) {
          setState(() => _speechError = e.errorMsg);
        }
      },
      onStatus: (status) {
        if (mounted && status == 'done') {
          setState(() => _listening = false);
        }
      },
    );
    if (mounted) {
      setState(() {
        _speechReady = ok;
        if (!ok) {
          _speechError ??= '音声認識を初期化できません（ブラウザの許可・HTTPS/localhost を確認）';
        }
      });
    }
  }

  Future<void> _toggleMic() async {
    if (!_speechReady) return;
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() {
      _speechError = null;
      _transcript = '';
    });
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _transcript = result.recognizedWords);
        }
      },
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
    if (mounted) setState(() => _listening = true);
  }

  void _goToNextFromEvaluation(BuildContext evaluationContext) {
    final next = _index + 1;
    if (next < widget.entries.length) {
      Navigator.of(evaluationContext).pushAndRemoveUntil<void>(
        slideFromRightRoute<void>(
          BlogmaeDeckScreen(
            entries: widget.entries,
            courseTitle: widget.courseTitle,
            initialIndex: next,
          ),
        ),
        (route) => route.isFirst,
      );
    } else {
      final messenger = ScaffoldMessenger.of(evaluationContext);
      Navigator.of(evaluationContext).popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Text('すべての問題を終えました')),
      );
    }
  }

  Future<void> _confirmAnswer() async {
    if (_listening) {
      await _speech.stop();
    }
    if (!mounted) return;
    setState(() => _listening = false);

    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      slideFromRightRoute<void>(
        SpeechEvaluationScreen(
          entry: _current,
          userTranscript: _transcript.trim(),
          onGoToNextQuestion: _goToNextFromEvaluation,
        ),
      ),
    );
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.entries.length;
    final n = _index + 1;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.courseTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: n / total,
            minHeight: 4,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '$n / $total',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text('#${_current.id}'),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text(_current.grammar),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _current.japanese,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_speechError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _speechError!,
                        style: TextStyle(color: colorScheme.error, fontSize: 12),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 88, maxHeight: 140),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _transcript.isEmpty
                              ? '（英語で話すとここに文字起こしが表示されます）'
                              : _transcript,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontStyle: _transcript.isEmpty ? FontStyle.italic : FontStyle.normal,
                                color: _transcript.isEmpty
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Semantics(
                      label: _listening ? '録音を停止' : '録音を開始',
                      button: true,
                      child: Material(
                        color: _listening ? colorScheme.errorContainer : colorScheme.primaryContainer,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _speechReady ? _toggleMic : null,
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: Icon(
                              _listening ? Icons.stop_rounded : Icons.mic_rounded,
                              size: 36,
                              color: _listening
                                  ? colorScheme.onErrorContainer
                                  : colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _confirmAnswer,
                    child: const Text('解答を確認'),
                  ),
                  if (kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Chrome 推奨。マイクの許可が必要です。',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
