import 'package:flutter/material.dart';

import '../services/user_lessons_service.dart';
import 'user_lesson_editor_screen.dart';

/// タイトルと公開範囲を決めて空のユーザーレッスンを作成する。
class UserLessonCreateScreen extends StatefulWidget {
  const UserLessonCreateScreen({super.key});

  @override
  State<UserLessonCreateScreen> createState() => _UserLessonCreateScreenState();
}

class _UserLessonCreateScreenState extends State<UserLessonCreateScreen> {
  final _titleController = TextEditingController();
  String _visibility = 'private';
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final key = await UserLessonsService.createUserLesson(
        title: _titleController.text,
        visibility: _visibility,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => UserLessonEditorScreen(
            courseKey: key,
            title: _titleController.text.trim().isEmpty
                ? 'マイレッスン'
                : _titleController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('作成に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('マイレッスンを作成')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '問題は次の画面から追加できます。',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'レッスン名',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
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
            selected: {_visibility},
            onSelectionChanged: (s) => setState(() => _visibility = s.first),
          ),
          const SizedBox(height: 8),
          Text(
            _visibility == 'public'
                ? '他のログインユーザーもこのレッスンを開いて練習できます。'
                : 'あなただけが一覧に表示され、練習できます。',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('作成して問題を追加'),
          ),
        ],
      ),
    );
  }
}
