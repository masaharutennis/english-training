#!/usr/bin/env bash
# 開発用: API は常に http://127.0.0.1:8000（app/.env.example の CORRECTION_API_BASE_URL と揃える）
# Flutter Web のポートは変わってよい → 既定 CORS は *（api/.env で上書き可）
set -euo pipefail

cd "$(dirname "$0")"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

# 未設定なら全オリジン許可（ローカル専用。本番 Vercel では必ず具体 URL を .env / ダッシュボードで指定）
: "${ALLOWED_ORIGINS:=*}"
export ALLOWED_ORIGINS

: "${API_HOST:=127.0.0.1}"
: "${API_PORT:=8000}"

if [[ -d .venv ]]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
elif [[ -d venv ]]; then
  # shellcheck disable=SC1091
  source venv/bin/activate
fi

echo "API: http://${API_HOST}:${API_PORT}"
echo "ALLOWED_ORIGINS=${ALLOWED_ORIGINS}"
exec uvicorn main:app --reload --host "$API_HOST" --port "$API_PORT"
