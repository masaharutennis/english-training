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

## ライセンス・教材

教材データは BlogMAE の公開記事をスクレイプした CSV をアセットに含めています。サイトの利用条件に従ってください。
