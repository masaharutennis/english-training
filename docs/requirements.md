# Flutter Web 瞬間英作文アプリ 仕様書

## 1. 概要

本アプリは **Flutter Web** 上で動作する個人用の**瞬間英作文（発話）**練習アプリである。

- 教材データは **Supabase** の `public.lessons` / `public.learning_items` を **ログイン済みユーザー（authenticated）** が読み込む。
- **各レッスン（コース）あたり 1 セッション 10 問**。全問から、**直近スコアが低いほど出やすい重み付き**で無作為に選ぶ（未挑戦は 0 点扱い）。
- 画面上に**日本語お題**と**模範英文**を表示し、ユーザーは**英語で発話**。ブラウザの **STT（en-US）** でテキスト化しリアルタイム表示する。
- **自前 API**（`api/main.py`）が OpenAI を呼び、**100 点満点のスコア**と**短い日本語アドバイス**だけを返す（全文添削ではなく「意味がどれだけ言えているか」の評価。模範英文との完全一致は不要）。

**認証**: Supabase Auth の **メール + パスワード**（確認メールなし想定。ローカルは `supabase/config.toml` の `[auth.email] enable_confirmations = false`、本番はダッシュボードで無効化）。

**スコア永続化**: `public.learning_item_attempts` に 1 回答ごと 1 行（履歴）。「直近スコア」は同一 `(user_id, learning_item_id)` で `created_at` が最新の行。

**レッスン一覧の平均**: そのコースの全 `learning_items` について、直近スコアが無ければ **0**、あればその値の**単純平均**（0〜100）。

### 1.1 画面遷移

1. **ホーム** … 未ログインなら **ログイン / 新規登録**、ログイン後 **「学習をスタート」**
2. **教材選択** … 各コースに **レッスン平均（0〜100）** を表示
3. **学習カード** … 進捗（例: 3/10）、`id`・`grammar`、**日本語**、**模範英文**、認識テキスト欄、**マイク**、**解答を確認**
4. **解答を確認** … API 評価中 → **スコア**、お題・発話・模範英文、**アドバイス**、**次の問題へ**（押下で DB に履歴 INSERT）
5. 10 問終了でカードを閉じ、完了メッセージ

---

## 2. 開発前提

- 対象: **Flutter Web**（マイク・STT は **Chrome 推奨**、`localhost` / HTTPS）
- 評価 API: `POST /v1/composition/evaluate_speech`（`api/main.py`）
- OpenAI キーは **サーバー環境変数のみ**；Flutter は `CORRECTION_API_BASE_URL` と Supabase の `SUPABASE_URL` / `SUPABASE_ANON_KEY`（`api/README.md`）
- データ: Supabase（Postgres）／シード再生成元は `tools/scraping/output/*.csv`

---

## 3. ユーザー体験

1. メールでログインまたは新規登録  
2. コースを選ぶ（平均スコアを確認）  
3. 10 問を順に（出題順はセッションごとにランダム・苦手優先）  
4. マイクで英語を話す → **解答を確認**  
5. スコアとアドバイス → **次の問題へ**（保存）  

---

## 4. 必要な UI 要素（学習カード）

- 閉じる（一覧へ）
- 進捗表示・プログレスバー
- 文法チップ、`id`（`item_number`）
- 日本語お題
- **認識テキスト**表示エリア（リアルタイム）
- **マイク**ボタン
- **解答を確認**

---

## 5. データモデル（DB）

**lessons** … コース（全 5 件）。`course_key` で一意。

**learning_items** … `lesson_id` でコースに紐づく。`item_number` はコース内通し（元 CSV の id）。

**profiles** … `auth.users.id` と 1:1。新規ユーザーはトリガーで作成。

**learning_item_attempts** … `user_id`, `learning_item_id`, `score` (0–100), `created_at`。RLS で本人のみ SELECT/INSERT。

教材テーブルは **authenticated のみ SELECT**（anon からの読み取り不可）。

| テーブル | 主な列 |
|----------|--------|
| lessons | `course_key`, `title`, `sort_order` |
| learning_items | `id`, `lesson_id`, `item_number`, `grammar`, `english`, `japanese` |
| learning_item_attempts | `user_id`, `learning_item_id`, `score`, `created_at` |

シード SQL 生成: `tools/generate_learning_seed.py`

---

## 6. API（evaluate_speech）

### リクエスト

`grammar`, `japanese`, `english`, `user_english`（発話認識テキスト）

### レスポンス（JSON）

- `score` … 0–100 整数  
- `advice` … 日本語 1〜3 文程度（褒め＋具体的改善があれば短く）

---

## 7. ファイル構成（目安）

```text
api/main.py
app/lib/screens/
  home_screen.dart
  auth_screen.dart
  blogmae_course_select_screen.dart
  blogmae_deck_screen.dart
  speech_evaluation_screen.dart
app/lib/services/
  composition_api_client.dart
  learning_items_loader.dart
  learning_progress_service.dart
  quiz_picker.dart
app/lib/models/
  blogmae_entry.dart
  speech_evaluation_result.dart
```

---

## 8. 開発メモ

- API キーはコミットしない。  
- 本番 Supabase では **Authentication → メール確認をオフ** にし、仕様どおり即ログインできるようにする。  
- 旧フロー（問題一覧・全文添削 `/v1/composition/correct`）はコードベースからは外している場合がある。  
