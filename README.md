# english-training

個人用の**瞬間英作文（発話）**練習。Flutter Web クライアントと FastAPI（OpenAI 経由の評価 API）のモノレポです。

## 構成

| ディレクトリ | 内容 |
|-------------|------|
| [`app/`](app/) | Flutter Web（教材 CSV・STT・評価画面） |
| [`api/`](api/) | FastAPI … `POST /v1/composition/evaluate_speech` など |
| [`tools/scraping/`](tools/scraping/) | BlogMAE 記事から CSV を生成するスクレイパー |
| [`docs/`](docs/) | 仕様メモ |

## ローカル開発（概要）

- **API**: `api/` で `cp .env.example .env` のうえ `./start.sh`（`OPENAI_API_KEY` 必須）
- **Flutter**: `app/` で `cp .env.example .env`（`CORRECTION_API_BASE_URL` のみ）し、`flutter run -d chrome --dart-define-from-file=.env`

詳細は [`api/README.md`](api/README.md) を参照。

## Vercel（Flutter Web をビルドして配信）

フロント用に **別プロジェクト** を作り、リポジトリは同じで **Root Directory を `app`** にします（API 用プロジェクトは Root を `api`）。

### ダッシュボードでの設定

1. **Add New Project** → 本リポジトリをインポート
2. **Root Directory** → `app` に変更（「Edit」でサブフォルダ指定）
3. **Framework Preset** → *Other*（自動検出に任せずとも可。`app/vercel.json` が効く）
4. **Environment Variables**（Production / Preview どちらにでも）  
   - `CORRECTION_API_BASE_URL` = デプロイ済み API のオリジン（例: `https://your-api.vercel.app`、末尾スラッシュなし）  
   - ビルド時に `--dart-define=CORRECTION_API_BASE_URL=...` へ渡る
5. **Deploy**

[`app/vercel.json`](app/vercel.json) の内容:

- **buildCommand**: 安定版 Flutter を clone → `flutter precache --web` → `pub get` → `build web --release`
- **outputDirectory**: `build/web`
- **routes**: 先に静的ファイルを配信し、それ以外を `index.html` へ（SPA のリロード対策）

初回ビルドは Flutter 取得で **数分かかる**ことがあります。API 側の Vercel では [`api/README.md`](api/README.md) のとおり `ALLOWED_ORIGINS` に、このフロントの URL（例: `https://your-app.vercel.app`）を入れて CORS を通してください。

## ライセンス・教材

教材データは BlogMAE の公開記事をスクレイプした CSV をアセットに含めています。サイトの利用条件に従ってください。
