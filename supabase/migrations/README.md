# Database migrations

| ファイル | 内容 |
|----------|------|
| `20260404000000_learning_lessons_and_items.sql` | `lessons`（5コース）と `learning_items`（`lesson_id` + `item_number`）を一括作成。 |
| `20260408100000_profiles_and_learning_attempts.sql` | `profiles`（`auth.users` と同期）、`learning_item_attempts`（採点履歴）。教材テーブルは **authenticated** のみ SELECT。 |

教材データは `supabase db reset` 後に `config.toml` の `db.seed` で `seeds/learning_items.sql` が流れる。

**既存の Supabase プロジェクト**に、以前の複数マイグレーション名が `schema_migrations` に残っている場合、このリポジトリだけ差し替えて `db push` すると履歴と実体がずれます。ゼロから合わせるならローカルは `supabase db reset`、リモートは新規プロジェクトにするか、[migration repair](https://supabase.com/docs/guides/cli/managing-environments#migration-repair) で履歴を整合させてください。
