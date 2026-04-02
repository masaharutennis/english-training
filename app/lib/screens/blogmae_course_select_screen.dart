import 'package:flutter/material.dart';

import '../services/blogmae_basic_loader.dart';
import 'blogmae_deck_screen.dart';

/// 学習開始後、BlogMAE 教材を選ぶ。
class BlogmaeCourseSelectScreen extends StatelessWidget {
  const BlogmaeCourseSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('教材を選ぶ'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Text(
            'BlogMAE 瞬間英作トレーニング',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _CourseTile(
            title: 'BlogMAE 基礎編',
            subtitle: '文法単元別の短文ドリル（pronunciation1）',
            assetPath: BlogmaeBasicLoader.basicAssetPath,
          ),
          const SizedBox(height: 12),
          _CourseTile(
            title: 'BlogMAE 初級編',
            subtitle: '初級の総合トレーニング（pronunciation2）',
            assetPath: BlogmaeBasicLoader.beginnerAssetPath,
          ),
          const SizedBox(height: 12),
          _CourseTile(
            title: 'BlogMAE 分詞・関係代名詞編',
            subtitle: '分詞・関係詞・知覚動詞など（1-2）',
            assetPath: BlogmaeBasicLoader.participleAssetPath,
          ),
          const SizedBox(height: 12),
          _CourseTile(
            title: 'BlogMAE 中級編',
            subtitle: '口語的・やや長めの文（pronunciation3）',
            assetPath: BlogmaeBasicLoader.intermediateAssetPath,
          ),
          const SizedBox(height: 12),
          _CourseTile(
            title: 'BlogMAE 上級編',
            subtitle: 'より複雑な表現（pronunciation4）',
            assetPath: BlogmaeBasicLoader.advancedAssetPath,
          ),
        ],
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.title,
    required this.subtitle,
    required this.assetPath,
  });

  final String title;
  final String subtitle;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.primary),
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => BlogmaeDeckFlowScreen(
                assetPath: assetPath,
                courseTitle: title,
              ),
            ),
          );
        },
      ),
    );
  }
}
