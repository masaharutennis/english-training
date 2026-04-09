# english-training

個人用の**瞬間英作文（発話）**練習。Flutter Web クライアントと FastAPI（OpenAI 経由の評価 API）のモノレポです。

## 構成

| ディレクトリ | 内容 |
|-------------|------|
| [`app/`](app/) | Flutter Web（Supabase 教材・STT・評価画面） |
| [`api/`](api/) | FastAPI … 添削・`evaluate_speech`・**Whisper** `POST /v1/speech/transcribe` など |
| [`tools/scraping/`](tools/scraping/) | 教材元サイトから CSV を生成するスクレイパー |
| [`docs/`](docs/) | 仕様メモ |

## ローカル開発（概要）

- **API**: `api/` で `cp .env.example .env` のうえ `./start.sh`（`OPENAI_API_KEY` 必須）
- **Flutter**: `app/` で `cp .env.example .env`（`CORRECTION_API_BASE_URL` と `SUPABASE_URL` / `SUPABASE_ANON_KEY`）し、`flutter run -d chrome --dart-define-from-file=.env`

詳細は [`api/README.md`](api/README.md) を参照。

### 音声を Whisper で書き起こす（任意）

既定はブラウザの音声認識（`speech_to_text`）です。**OpenAI Whisper 経由**にするには次を足します。

1. **`api/.env`** に `OPENAI_API_KEY` があること（添削と同じキーで課金）。
2. **`app/.env`** に `SPEECH_USE_WHISPER=true` を書く。
3. `api` を `./start.sh`、`app` を `flutter run ... --dart-define-from-file=.env` で起動。

録音 → `POST /v1/speech/transcribe` → 英語テキストが入力欄に入ります。任意で `OPENAI_WHISPER_MODEL`（既定 `whisper-1`）を `api/.env` に指定できます。

## Vercel（Flutter Web をビルドして配信）

フロント用に **別プロジェクト** を作り、リポジトリは同じで **Root Directory を `app`** にします（API 用プロジェクトは Root を `api`）。

### ダッシュボードでの設定

1. **Add New Project** → 本リポジトリをインポート
2. **Root Directory** → `app` に変更（「Edit」でサブフォルダ指定）
3. **Framework Preset** → *Other*（自動検出に任せずとも可。`app/vercel.json` が効く）
4. **Environment Variables**（Production / Preview どちらにでも）  
   - `CORRECTION_API_BASE_URL` = デプロイ済み API のオリジン（例: `https://your-api.vercel.app`、末尾スラッシュなし）  
   - `SUPABASE_URL` / `SUPABASE_ANON_KEY` = Supabase ダッシュボードの Project URL と anon public キー  
   - （任意）`SPEECH_USE_WHISPER` = `true` … マイクを Whisper 経由にする（API 側に `OPENAI_API_KEY` が必要）  
   - ビルド時に `scripts/vercel_build.sh` 経由で `--dart-define` に渡る
5. **Deploy**

[`app/vercel.json`](app/vercel.json) の **buildCommand** は 256 文字制限のため、実処理は [`app/scripts/vercel_build.sh`](app/scripts/vercel_build.sh) にあります（Flutter clone → `precache --web` → `build web --release`）。
- **outputDirectory**: `build/web`
- **routes**: 先に静的ファイルを配信し、それ以外を `index.html` へ（SPA のリロード対策）

初回ビルドは Flutter 取得で **数分かかる**ことがあります。API 側の Vercel では [`api/README.md`](api/README.md) のとおり `ALLOWED_ORIGINS` に、このフロントの URL（例: `https://your-app.vercel.app`）を入れて CORS を通してください。

## ライセンス・教材

教材データは元サイト由来の CSV を Supabase に保持しています（生成は [`tools/`](tools/) など）。サイトの利用条件に従ってください。
