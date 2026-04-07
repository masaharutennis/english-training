import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lesson_list_row.dart';
import '../services/learning_items_loader.dart';
import '../services/user_lessons_service.dart';
import '../widgets/score_donut.dart';
import '../utils/env_config.dart';
import 'auth_screen.dart';
import 'blogmae_deck_screen.dart';
import 'user_lesson_create_screen.dart';
import 'user_lesson_editor_screen.dart';

/// 学習開始後、教材を選ぶ（公式 BlogMAE + ユーザーレッスン）。
class BlogmaeCourseSelectScreen extends StatefulWidget {
  const BlogmaeCourseSelectScreen({super.key});

  @override
  State<BlogmaeCourseSelectScreen> createState() => _BlogmaeCourseSelectScreenState();
}

class _CourseSelectData {
  const _CourseSelectData({
    required this.lessons,
    required this.averages,
  });

  final List<LessonListRow> lessons;
  final Map<String, double> averages;
}

class _BlogmaeCourseSelectScreenState extends State<BlogmaeCourseSelectScreen> {
  late Future<_CourseSelectData> _dataFuture;

  static const Map<String, String> _systemSubtitles = {
    LearningItemsLoader.courseBasic: '文法単元別の短文ドリル（pronunciation1）',
    LearningItemsLoader.courseBeginner: '初級の総合トレーニング（pronunciation2）',
    LearningItemsLoader.courseParticiple: '分詞・関係詞・知覚動詞など（1-2）',
    LearningItemsLoader.courseIntermediate: '口語的・やや長めの文（pronunciation3）',
    LearningItemsLoader.courseAdvanced: 'より複雑な表現（pronunciation4）',
  };

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_CourseSelectData> _loadData() async {
    if (!EnvConfig.hasSupabase) {
      return const _CourseSelectData(lessons: [], averages: {});
    }
    final lessons = await UserLessonsService.fetchLessonList();
    final averages = <String, double>{};
    await Future.wait(
      lessons.map((l) async {
        try {
          averages[l.courseKey] =
              await LearningItemsLoader.averageScoreForCourse(l.courseKey);
        } catch (_) {
          averages[l.courseKey] = 0;
        }
      }),
    );
    return _CourseSelectData(lessons: lessons, averages: averages);
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _loadData();
    });
    await _dataFuture;
  }

  String _subtitleFor(LessonListRow r) {
    if (r.isSystem) {
      return _systemSubtitles[r.courseKey] ?? '';
    }
    if (r.isOwner) {
      return r.visibility == 'public' ? '自作 · 公開' : '自作 · 非公開';
    }
    return '他ユーザーの公開レッスン';
  }

  Future<void> _openSystemOrPublicDeck(String title, String courseKey) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlogmaeDeckFlowScreen(
          courseKey: courseKey,
          courseTitle: title,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openUserOwnedEditor(LessonListRow row) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UserLessonEditorScreen(
          courseKey: row.courseKey,
          title: row.title,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _onLessonTap(LessonListRow row) async {
    if (row.isSystem) {
      await _openSystemOrPublicDeck(row.title, row.courseKey);
      return;
    }
    if (row.isOwner) {
      await _openUserOwnedEditor(row);
      return;
    }
    await _openSystemOrPublicDeck(row.title, row.courseKey);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final needAuth =
        EnvConfig.hasSupabase && Supabase.instance.client.auth.currentSession == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('教材を選ぶ'),
        actions: [
          if (EnvConfig.hasSupabase && !needAuth) ...[
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'マイレッスンを作成',
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const UserLessonCreateScreen(),
                  ),
                );
                if (mounted) await _refresh();
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '一覧を更新',
              onPressed: () => _refresh(),
            ),
          ],
        ],
      ),
      body: needAuth
          ? _NeedAuthBody(colorScheme: colorScheme, textTheme: textTheme)
          : FutureBuilder<_CourseSelectData>(
              future: _dataFuture,
              builder: (context, snap) {
                final data = snap.data;
                final showDonut =
                    EnvConfig.hasSupabase && snap.connectionState == ConnectionState.done;
                final lessons = data?.lessons ?? [];
                final averages = data?.averages ?? {};

                final systemLessons = lessons.where((l) => l.isSystem).toList();
                final userLessons = lessons.where((l) => !l.isSystem).toList();

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    if (!EnvConfig.hasSupabase)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Material(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Supabase が未設定です。app/.env に SUPABASE_URL と '
                              'SUPABASE_ANON_KEY を書き、--dart-define-from-file=.env で起動してください。',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Text(
                      '教材一覧',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (EnvConfig.hasSupabase) ...[
                      const SizedBox(height: 8),
                      Text(
                        '公式教材はタップで練習開始。自作レッスンは編集画面で問題を追加できます。'
                        '右の円は全問の直近スコアの平均です。',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      '公式（BlogMAE）',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (snap.connectionState != ConnectionState.done)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      ...systemLessons.map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CourseTile(
                            title: row.title,
                            subtitle: _subtitleFor(row),
                            showDonut: showDonut,
                            averageScore: averages[row.courseKey] ?? 0,
                            trailingHint: row.isOwner ? Icons.edit_note_rounded : null,
                            onOpen: () async {
                              await _onLessonTap(row);
                            },
                          ),
                        ),
                      ),
                      if (userLessons.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'ユーザーレッスン',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...userLessons.map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CourseTile(
                              title: row.title,
                              subtitle: _subtitleFor(row),
                              showDonut: showDonut,
                              averageScore: averages[row.courseKey] ?? 0,
                              trailingHint:
                                  row.isOwner ? Icons.edit_note_rounded : null,
                              onOpen: () async {
                              await _onLessonTap(row);
                            },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _NeedAuthBody extends StatelessWidget {
  const _NeedAuthBody({
    required this.colorScheme,
    required this.textTheme,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '教材を開くにはログインが必要です。',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const AuthScreen(),
                  ),
                );
              },
              child: const Text('ログインへ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.title,
    required this.subtitle,
    required this.showDonut,
    required this.averageScore,
    required this.onOpen,
    this.trailingHint,
  });

  final String title;
  final String subtitle;
  final bool showDonut;
  final double averageScore;
  final Future<void> Function() onOpen;
  final IconData? trailingHint;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingHint != null) ...[
              Icon(trailingHint, size: 20, color: colorScheme.outline),
              const SizedBox(width: 4),
            ],
            if (showDonut) ...[
              ScoreDonut(score: averageScore),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
          ],
        ),
        onTap: () async {
          await onOpen();
        },
      ),
    );
  }
}
