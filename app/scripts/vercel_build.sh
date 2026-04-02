#!/usr/bin/env bash
# Vercel: buildCommand は 256 文字制限のためロジックはここに集約する。
set -euo pipefail
git clone --depth 1 -b stable https://github.com/flutter/flutter.git "${HOME}/flutter"
export PATH="${PATH}:${HOME}/flutter/bin"
flutter config --no-analytics
flutter precache --web
flutter pub get
flutter build web --release --dart-define="CORRECTION_API_BASE_URL=${CORRECTION_API_BASE_URL:-}"
