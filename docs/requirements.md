# Flutter Web 瞬間英作文アプリ 仕様書

## 1. 概要

本アプリは **Flutter Web** 上で動作する個人用の**瞬間英作文（発話）**練習アプリである。

- 教材データは **Supabase** の `public.learning_items`（`course_key` でコース別）を **anon** で読み込む。
- **カード式**で `lesson_number` 昇順に問題を進める（一覧から選ばない）。
- 画面上に**日本語お題**と**模範英文**を表示し、ユーザーは**英語で発話**。ブラウザの **STT（en-US）** でテキスト化しリアルタイム表示する。
- **自前 API**（`api/main.py`）が OpenAI を呼び、**100 点満点のスコア**と**短い日本語アドバイス**だけを返す（全文添削ではなく「意味がどれだけ言えているか」の評価。模範英文との完全一致は不要）。

ログイン・スコアの永続化は不要（個人利用想定）。教材はホスト済み DB から取得する。

### 1.1 画面遷移

1. **ホーム** … **「学習をスタート」**
2. **学習カード** … 進捗（例: 3/130）、`id`・`grammar`、**日本語**、**模範英文**、認識テキスト欄、**マイク**（録音 ON/OFF）、**解答を確認**（押下時にマイク OFF）
3. **解答を確認** … API 評価中 → **スコア**、お題・発話テキスト・模範英文、**アドバイス**、**次の問題へ**
4. 最終問題のあとカード画面を閉じ、完了メッセージ

---

## 2. 開発前提

- 対象: **Flutter Web**（マイク・STT は **Chrome 推奨**、`localhost` / HTTPS）
- 評価 API: `POST /v1/composition/evaluate_speech`（`api/main.py`）
- OpenAI キーは **サーバー環境変数のみ**；Flutter は `CORRECTION_API_BASE_URL` と Supabase の `SUPABASE_URL` / `SUPABASE_ANON_KEY`（`api/README.md`）
- データ: Supabase（Postgres）／シード再生成元は `tools/scraping/output/*.csv`

---

## 3. ユーザー体験

1. お題（日本語）と模範英文を見る  
2. マイクで英語を話す（認識結果が随時表示）  
3. 話し終えたらマイクを止め、**解答を確認**  
4. スコア（0–100）と短いアドバイスを読む  
5. **次の問題へ**でリストの次の問題へ  

---

## 4. 必要な UI 要素（学習カード）

- 閉じる（一覧に戻る＝ホームへ）
- 進捗表示・プログレスバー
- 文法チップ、`id`
- 日本語お題、模範英文（`english`）
- **認識テキスト**表示エリア（リアルタイム）
- **マイク**ボタン（画面下部寄せ）
- **解答を確認**（マイクを自動停止してから評価画面へ）

---

## 5. 教材データ（lessons + learning_items）

**lessons** … コース（全 5 件: basic / beginner / participle / intermediate / advanced）。`course_key` で一意。

**learning_items** … `lesson_id` でコースに紐づく。`item_number` がコース内の通し（元 CSV の id）。

| テーブル | 主な列 |
|----------|--------|
| lessons | `course_key`, `title`, `sort_order` |
| learning_items | `lesson_id`, `item_number`, `grammar`, `english`, `japanese` |

シード SQL 生成: `tools/generate_learning_seed.py`（入力 CSV は `tools/scraping/output/`）

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
api/main.py          # /v1/composition/evaluate_speech ほか
app/lib/screens/
  blogmae_deck_screen.dart
  speech_evaluation_screen.dart
app/lib/services/composition_api_client.dart
app/lib/models/speech_evaluation_result.dart
```

---

## 8. 開発メモ

- API キーはコミットしない。  
- 旧フロー（問題一覧・全文添削 `/v1/composition/correct`）はコードベースからは外しているが、`main.py` にエンドポイントは残している場合がある。  
