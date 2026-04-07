import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/blogmae_entry.dart';
import '../services/learning_items_loader.dart';
import '../widgets/slide_page_route.dart';
import 'session_complete_screen.dart';
import 'speech_evaluation_screen.dart';

/// Supabase の問題を順にカード表示。英語の入力または発話 STT → 解答確認。
class BlogmaeDeckFlowScreen extends StatefulWidget {
  const BlogmaeDeckFlowScreen({
    super.key,
    required this.courseKey,
    required this.courseTitle,
  });

  final String courseKey;
  final String courseTitle;

  @override
  State<BlogmaeDeckFlowScreen> createState() => _BlogmaeDeckFlowScreenState();
}

class _BlogmaeDeckFlowScreenState extends State<BlogmaeDeckFlowScreen> {
  late Future<List<BlogmaeEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = LearningItemsLoader.loadForCourse(widget.courseKey);
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
          quizHint: '${items.length}問（苦手優先のランダム）',
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
    this.quizHint,
  });

  final List<BlogmaeEntry> entries;
  final String courseTitle;
  final int initialIndex;
  final String? quizHint;

  @override
  State<BlogmaeDeckScreen> createState() => _BlogmaeDeckScreenState();
}

class _BlogmaeDeckScreenState extends State<BlogmaeDeckScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  /// 発話 STT もキーボード入力も同じフィールドに入れる（部分認識は controller 更新のみで再描画が局所的）。
  final TextEditingController _answerController = TextEditingController();
  final List<int> _sessionScores = <int>[];
  late int _index;
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

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
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
    });
    _answerController.clear();
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final t = result.recognizedWords;
        _answerController.value = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: t.length),
        );
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

  Future<void> _confirmAnswer() async {
    if (_listening) {
      await _speech.stop();
    }
    if (!mounted) return;
    setState(() => _listening = false);

    if (!context.mounted) return;
    final score = await Navigator.of(context).push<int?>(
      slideFromRightRoute<int?>(
        SpeechEvaluationScreen(
          entry: _current,
          userTranscript: _answerController.text.trim(),
        ),
      ),
    );
    if (!mounted || score == null) return;

    _sessionScores.add(score);

    if (_index + 1 < widget.entries.length) {
      setState(() {
        _index++;
        _answerController.clear();
      });
    } else {
      final avg = _sessionScores.isEmpty
          ? 0.0
          : _sessionScores.reduce((a, b) => a + b) / _sessionScores.length;
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => SessionCompleteScreen(
            courseTitle: widget.courseTitle,
            sessionAverage: avg,
          ),
        ),
        (route) => route.isFirst,
      );
    }
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
            child: Column(
              children: [
                Text(
                  '$n / $total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                if (widget.quizHint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.quizHint!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0.12, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: Card(
                  key: ValueKey<int>(_index),
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
                            if (_current.grammar.trim().isNotEmpty)
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
                      constraints: const BoxConstraints(minHeight: 88, maxHeight: 160),
                      child: TextField(
                        controller: _answerController,
                        maxLines: null,
                        minLines: 3,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '英語で入力するか、マイクで話してください',
                          hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                          contentPadding: const EdgeInsets.all(12),
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
                        '音声を使う場合は Chrome 推奨・マイクの許可が必要です。入力のみでも解答できます。',
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
