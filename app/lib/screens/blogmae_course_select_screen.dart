import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/learning_items_loader.dart';
import '../utils/env_config.dart';
import '../widgets/score_donut.dart';
import 'auth_screen.dart';
import 'blogmae_deck_screen.dart';

/// 学習開始後、BlogMAE 教材を選ぶ。
class BlogmaeCourseSelectScreen extends StatefulWidget {
  const BlogmaeCourseSelectScreen({super.key});

  @override
  State<BlogmaeCourseSelectScreen> createState() => _BlogmaeCourseSelectScreenState();
}

class _BlogmaeCourseSelectScreenState extends State<BlogmaeCourseSelectScreen> {
  late Future<Map<String, double>> _averagesFuture;

  @override
  void initState() {
    super.initState();
    _averagesFuture = _loadAverages();
  }

  Future<Map<String, double>> _loadAverages() async {
    if (!EnvConfig.hasSupabase) return {};
    final keys = [
      LearningItemsLoader.courseBasic,
      LearningItemsLoader.courseBeginner,
      LearningItemsLoader.courseParticiple,
      LearningItemsLoader.courseIntermediate,
      LearningItemsLoader.courseAdvanced,
    ];
    final out = <String, double>{};
    await Future.wait(
      keys.map((k) async {
        try {
          out[k] = await LearningItemsLoader.averageScoreForCourse(k);
        } catch (_) {
          out[k] = 0;
        }
      }),
    );
    return out;
  }

  Future<void> _refreshAverages() async {
    setState(() {
      _averagesFuture = _loadAverages();
    });
    await _averagesFuture;
  }

  Future<void> _openLesson(String title, String courseKey) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlogmaeDeckFlowScreen(
          courseKey: courseKey,
          courseTitle: title,
        ),
      ),
    );
    if (mounted) await _refreshAverages();
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
          if (EnvConfig.hasSupabase && !needAuth)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '平均スコアを更新',
              onPressed: () => _refreshAverages(),
            ),
        ],
      ),
      body: needAuth
          ? _NeedAuthBody(colorScheme: colorScheme, textTheme: textTheme)
          : FutureBuilder<Map<String, double>>(
              future: _averagesFuture,
              builder: (context, snap) {
                final averages = snap.data ?? {};
                final showDonut =
                    EnvConfig.hasSupabase && snap.connectionState == ConnectionState.done;
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
                      'BlogMAE 瞬間英作トレーニング',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (EnvConfig.hasSupabase) ...[
                      const SizedBox(height: 8),
                      Text(
                        '右の円は全問の「直近スコア」の平均です（未挑戦は0、満点は100）。',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _CourseTile(
                      title: 'BlogMAE 基礎編',
                      subtitle: '文法単元別の短文ドリル（pronunciation1）',
                      showDonut: showDonut,
                      averageScore: averages[LearningItemsLoader.courseBasic] ?? 0,
                      onOpen: () => _openLesson(
                        'BlogMAE 基礎編',
                        LearningItemsLoader.courseBasic,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CourseTile(
                      title: 'BlogMAE 初級編',
                      subtitle: '初級の総合トレーニング（pronunciation2）',
                      showDonut: showDonut,
                      averageScore: averages[LearningItemsLoader.courseBeginner] ?? 0,
                      onOpen: () => _openLesson(
                        'BlogMAE 初級編',
                        LearningItemsLoader.courseBeginner,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CourseTile(
                      title: 'BlogMAE 分詞・関係代名詞編',
                      subtitle: '分詞・関係詞・知覚動詞など（1-2）',
                      showDonut: showDonut,
                      averageScore: averages[LearningItemsLoader.courseParticiple] ?? 0,
                      onOpen: () => _openLesson(
                        'BlogMAE 分詞・関係代名詞編',
                        LearningItemsLoader.courseParticiple,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CourseTile(
                      title: 'BlogMAE 中級編',
                      subtitle: '口語的・やや長めの文（pronunciation3）',
                      showDonut: showDonut,
                      averageScore: averages[LearningItemsLoader.courseIntermediate] ?? 0,
                      onOpen: () => _openLesson(
                        'BlogMAE 中級編',
                        LearningItemsLoader.courseIntermediate,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CourseTile(
                      title: 'BlogMAE 上級編',
                      subtitle: 'より複雑な表現（pronunciation4）',
                      showDonut: showDonut,
                      averageScore: averages[LearningItemsLoader.courseAdvanced] ?? 0,
                      onOpen: () => _openLesson(
                        'BlogMAE 上級編',
                        LearningItemsLoader.courseAdvanced,
                      ),
                    ),
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
  });

  final String title;
  final String subtitle;
  final bool showDonut;
  final double averageScore;
  final Future<void> Function() onOpen;

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
