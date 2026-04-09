#!/usr/bin/env bash
# Vercel: buildCommand は 256 文字制限のためロジックはここに集約する。
set -euo pipefail
git clone --depth 1 -b stable https://github.com/flutter/flutter.git "${HOME}/flutter"
export PATH="${PATH}:${HOME}/flutter/bin"
flutter config --no-analytics
flutter precache --web
flutter pub get
# --wasm: Chromium 系は skwasm を優先（フォールバックで従来レンダラ）。モバイル Safari は主に CanvasKit だがビルド成果物は共通。
# -O4: JS フォールバックの最適化（Safari / iOS Chrome(WebKit) で効く）
flutter build web --release --wasm -O4 \
  --dart-define="CORRECTION_API_BASE_URL=${CORRECTION_API_BASE_URL:-}" \
  --dart-define="SUPABASE_URL=${SUPABASE_URL:-}" \
  --dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}" \
  --dart-define="SPEECH_USE_WHISPER=${SPEECH_USE_WHISPER:-false}"
