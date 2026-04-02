# 瞬間英作文 API（FastAPI）

Flutter アプリは `CORRECTION_API_BASE_URL` だけを知り、OpenAI キーは **このプロジェクトの環境変数** にだけ置きます。

## 開発環境（ローカル）

**API の URL は変えない前提:** `./start.sh` は常に **`http://127.0.0.1:8000`**。  
`app/.env.example` の `CORRECTION_API_BASE_URL=http://127.0.0.1:8000` と一致するので、ポートをいじらない限り **`.env.example` を書き換える必要はありません**。

**Flutter Web の URL（ポート）** は毎回変わってもよい。`start.sh` の既定は **`ALLOWED_ORIGINS=*`**（ローカル専用）なので、どのポートの `localhost` からでも CORS を通します。

1. 初回だけ依存を入れる。

   ```bash
   cd api
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   cp .env.example .env
   # .env に OPENAI_API_KEY を書く
   ```

2. API を起動する。

   ```bash
   ./start.sh
   ```

3. Flutter 側 `app/.env`（例は `.env.example` と同じでよい）:

   ```
   CORRECTION_API_BASE_URL=http://127.0.0.1:8000
   ```

4. Flutter（ポートは任意）:

   ```bash
   cd ../app
   flutter run -d chrome --dart-define-from-file=.env
   ```

本番に近い厳密 CORSにしたいときだけ、`api/.env` で `ALLOWED_ORIGINS=https://あなたのフロント,http://localhost:54321` のように列挙する（その場合は `*` は使わない）。

## 本番環境（Vercel）

1. [Vercel](https://vercel.com) でこの `api` ディレクトリをルートにしたプロジェクトを作成（またはモノレポで `api` を Root Directory に指定）。

2. Vercel の **Settings → Environment Variables** に少なくとも次を設定する。

   | Name | 値 |
   |------|-----|
   | `OPENAI_API_KEY` | OpenAI のシークレットキー |
   | `ALLOWED_ORIGINS` | デプロイした Flutter Web のオリジン（例: `https://your-app.web.app`）。複数はカンマ区切り。**本番では `*` にしない。** |

   任意: `OPENAI_MODEL`（既定 `gpt-4o-mini`）、`OPENAI_API_BASE`。  
   発話評価 `evaluate_speech` だけ別モデルにする場合は **`OPENAI_EVAL_SPEECH_MODEL`**（未設定時は `OPENAI_MODEL` と同じ）。

### モデル選び（レイテンシ）

- **まず `gpt-4o-mini`（既定）** … コスト・応答速度のバランスが良く、短文 JSON の採点に十分なことが多いです。
- より速さだけ優先するなら、利用可能な範囲で **より小さい / 非推論系** の最新エントリ（例: ベンダーが提供する *mini* / *nano* 系）を `OPENAI_EVAL_SPEECH_MODEL` に指定して試してください。**推論強化モデル（o 系など）は遅くなりがち**なので、この用途には向きません。

3. デプロイ後に表示される URL（例: `https://xxx.vercel.app`）を Flutter のビルド時に渡す。

   ```
   CORRECTION_API_BASE_URL=https://xxx.vercel.app
   ```

   ```bash
   flutter build web --release --dart-define-from-file=.env
   ```

4. 静的ホスティング先のオリジンを `ALLOWED_ORIGINS` に必ず含める。

## エンドポイント

- `GET /` … ヘルスチェック
- `POST /v1/composition/evaluate_speech` … 発話認識テキストの簡易評価 `{ grammar, japanese, english, user_english }` → `{ score, advice }`
- `POST /v1/composition/correct` … 従来の全文添削（未使用なら省略可）
