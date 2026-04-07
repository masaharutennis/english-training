import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/blogmae_entry.dart';
import '../services/composition_api_client.dart';
import '../services/learning_items_loader.dart';
import '../services/learning_progress_service.dart';
import '../services/user_lessons_service.dart';
import 'blogmae_deck_screen.dart';

/// 自分のユーザーレッスンに問題を追加し、練習に進む。
class UserLessonEditorScreen extends StatefulWidget {
  const UserLessonEditorScreen({
    super.key,
    required this.courseKey,
    required this.title,
  });

  final String courseKey;
  final String title;

  @override
  State<UserLessonEditorScreen> createState() => _UserLessonEditorScreenState();
}

class _UserLessonEditorScreenState extends State<UserLessonEditorScreen> {
  late Future<List<BlogmaeEntry>> _itemsFuture;
  String? _visibility;
  bool _visibilityLoading = true;

  @override
  void initState() {
    super.initState();
    _itemsFuture = LearningItemsLoader.loadAllForCourse(widget.courseKey);
    _loadVisibility();
  }

  Future<void> _loadVisibility() async {
    try {
      final v = await UserLessonsService.fetchVisibility(widget.courseKey);
      if (mounted) {
        setState(() {
          _visibility = v ?? 'private';
          _visibilityLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _visibility = 'private';
          _visibilityLoading = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    setState(() {
      _itemsFuture = LearningItemsLoader.loadAllForCourse(widget.courseKey);
    });
    await _itemsFuture;
  }

  Future<void> _setVisibility(String v) async {
    if (_visibility == v) return;
    final previous = _visibility;
    setState(() => _visibility = v);
    try {
      await UserLessonsService.updateLessonVisibility(
        courseKey: widget.courseKey,
        visibility: v,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(v == 'public' ? '公開にしました' : '非公開にしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _visibility = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新に失敗: $e')),
        );
      }
    }
  }

  Future<void> _showAddItemDialog() async {
    await _showItemEditorDialog();
  }

  Future<void> _showEditItemDialog(BlogmaeEntry entry) async {
    await _showItemEditorDialog(existing: entry);
  }

  Future<void> _showItemEditorDialog({BlogmaeEntry? existing}) async {
    final isEdit = existing != null;
    final fields = await showDialog<_LearningItemFields>(
      context: context,
      builder: (ctx) => _LearningItemEditorDialog(existing: existing),
    );
    if (fields == null || !mounted) return;

    try {
      if (existing != null) {
        await UserLessonsService.updateLearningItem(
          learningItemId: existing.learningItemId,
          grammar: fields.grammar,
          english: fields.english,
          japanese: fields.japanese,
        );
      } else {
        await UserLessonsService.addLearningItem(
          courseKey: widget.courseKey,
          grammar: fields.grammar,
          english: fields.english,
          japanese: fields.japanese,
        );
      }
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? '保存しました' : '追加しました')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isEdit ? '保存' : '追加'}に失敗: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteItem(BlogmaeEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('問題を削除'),
        content: const Text('この問題を削除しますか？元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await UserLessonsService.deleteLearningItem(entry.learningItemId);
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('削除しました')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗: $e')),
        );
      }
    }
  }

  String _subtitleLine(BlogmaeEntry e) {
    final g = e.grammar.trim();
    if (g.isEmpty) return e.english;
    return '$g · ${e.english}';
  }

  Future<void> _openPractice() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlogmaeDeckFlowScreen(
          courseKey: widget.courseKey,
          courseTitle: widget.title,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _confirmResetScores() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('スコアをリセット'),
        content: Text(
          '「${widget.title}」の全問題について、あなたの採点履歴を削除します。'
          '教材一覧の平均や出題の重み付けが初期状態に戻ります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('リセットする'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await LearningProgressService.resetScoresForCourseKey(widget.courseKey);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('スコアをリセットしました')),
      );
      await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('リセットに失敗: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteLesson() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('レッスンを削除'),
        content: Text(
          '「${widget.title}」と含まれる全ての問題・履歴を削除します。元に戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await UserLessonsService.deleteUserLesson(widget.courseKey);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('レッスンを削除しました')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final vis = _visibility ?? 'private';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '練習を開始',
            icon: const Icon(Icons.play_circle_outline_rounded),
            onPressed: () async {
              final entries = await _itemsFuture;
              if (!context.mounted) return;
              if (entries.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('先に問題を1件以上追加してください。')),
                );
                return;
              }
              await _openPractice();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'その他',
            onSelected: (value) {
              if (value == 'reset_scores') _confirmResetScores();
              if (value == 'delete_lesson') _confirmDeleteLesson();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem<String>(
                value: 'reset_scores',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, size: 22),
                    SizedBox(width: 12),
                    Text('スコアをリセット'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete_lesson',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_outlined, color: colorScheme.error, size: 22),
                    const SizedBox(width: 12),
                    Text('レッスンを削除', style: TextStyle(color: colorScheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('問題を追加'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_visibilityLoading)
            Material(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('公開設定', style: textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'private',
                          label: Text('非公開'),
                          icon: Icon(Icons.lock_outline_rounded),
                        ),
                        ButtonSegment<String>(
                          value: 'public',
                          label: Text('公開'),
                          icon: Icon(Icons.public_rounded),
                        ),
                      ],
                      selected: {vis},
                      onSelectionChanged: (s) => _setVisibility(s.first),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<BlogmaeEntry>>(
              future: _itemsFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('読み込みエラー: ${snap.error}'));
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.library_add_check_rounded,
                              size: 56, color: colorScheme.outline),
                          const SizedBox(height: 16),
                          Text(
                            'まだ問題がありません',
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '右下の「問題を追加」から登録してください。',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return Card(
                      child: ListTile(
                        title: Text(
                          e.japanese,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _subtitleLine(e),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        leading: CircleAvatar(
                          child: Text('${e.id}'),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showEditItemDialog(e);
                            } else if (value == 'delete') {
                              _confirmDeleteItem(e);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('編集'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('削除'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 確定時に [showDialog] へ返すフィールド（コントローラはダイアログ [State] が所有・dispose）。
class _LearningItemFields {
  const _LearningItemFields({
    required this.grammar,
    required this.english,
    required this.japanese,
  });

  final String grammar;
  final String english;
  final String japanese;
}

class _LearningItemEditorDialog extends StatefulWidget {
  const _LearningItemEditorDialog({this.existing});

  final BlogmaeEntry? existing;

  @override
  State<_LearningItemEditorDialog> createState() => _LearningItemEditorDialogState();
}

class _LearningItemEditorDialogState extends State<_LearningItemEditorDialog> {
  late final TextEditingController _grammarCtrl;
  late final TextEditingController _englishCtrl;
  late final TextEditingController _japaneseCtrl;
  bool _suggestingEn = false;
  bool _suggestingJa = false;

  @override
  void initState() {
    super.initState();
    _grammarCtrl = TextEditingController(text: widget.existing?.grammar ?? '');
    _englishCtrl = TextEditingController(text: widget.existing?.english ?? '');
    _japaneseCtrl = TextEditingController(text: widget.existing?.japanese ?? '');
  }

  @override
  void dispose() {
    _grammarCtrl.dispose();
    _englishCtrl.dispose();
    _japaneseCtrl.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  bool get _aiBusy => _suggestingEn || _suggestingJa;

  Future<void> _suggestEnglishFromJapanese() async {
    final jp = _japaneseCtrl.text.trim();
    if (jp.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に日本語（お題）を入力してください')),
      );
      return;
    }
    setState(() => _suggestingEn = true);
    try {
      final text = await CompositionApiClient().suggestDrillLine(
        direction: 'ja_to_en',
        grammar: _grammarCtrl.text,
        sourceText: jp,
      );
      if (!mounted) return;
      _englishCtrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } on CompositionApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _suggestingEn = false);
    }
  }

  Future<void> _suggestJapaneseFromEnglish() async {
    final en = _englishCtrl.text.trim();
    if (en.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に英語（正解）を入力してください')),
      );
      return;
    }
    setState(() => _suggestingJa = true);
    try {
      final text = await CompositionApiClient().suggestDrillLine(
        direction: 'en_to_ja',
        grammar: _grammarCtrl.text,
        sourceText: en,
      );
      if (!mounted) return;
      _japaneseCtrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } on CompositionApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _suggestingJa = false);
    }
  }

  void _onSave() {
    if (_englishCtrl.text.trim().isEmpty || _japaneseCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('英語と日本語は必須です。')),
      );
      return;
    }
    Navigator.pop(
      context,
      _LearningItemFields(
        grammar: _grammarCtrl.text,
        english: _englishCtrl.text,
        japanese: _japaneseCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final screenH = MediaQuery.sizeOf(context).height;
    const edge = 12.0;
    final dialogW = math.min(screenW - edge * 2, 960.0);
    final dialogMaxH = screenH * 0.92;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: edge, vertical: 20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogW,
          maxHeight: dialogMaxH,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  _isEdit ? '問題を編集' : '問題を追加',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _grammarCtrl,
                      decoration: const InputDecoration(
                        labelText: '文法タグ（任意・AIのヒントに使われます）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '日本語（お題）',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: _suggestingJa
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome_outlined, size: 18),
                        label: const Text('英語からお題を生成'),
                        onPressed: _aiBusy ? null : _suggestJapaneseFromEnglish,
                      ),
                    ),
                    TextField(
                      controller: _japaneseCtrl,
                      decoration: const InputDecoration(
                        hintText: '学習者に見せる日本語',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      minLines: 4,
                      maxLines: 10,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '英語（正解）',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: _suggestingEn
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome_outlined, size: 18),
                        label: const Text('日本語から英語を生成'),
                        onPressed: _aiBusy ? null : _suggestEnglishFromJapanese,
                      ),
                    ),
                    TextField(
                      controller: _englishCtrl,
                      decoration: const InputDecoration(
                        hintText: '模範となる英文',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      minLines: 4,
                      maxLines: 10,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                    FilledButton(
                      onPressed: _aiBusy ? null : _onSave,
                      child: Text(_isEdit ? '保存' : '追加'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
