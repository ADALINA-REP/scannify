#!/usr/bin/env bash
set -euo pipefail

SYMBOLS_DIR="build/app/outputs/symbols"
mkdir -p "$SYMBOLS_DIR"

# 1. Clean project and fetch dependencies
flutter clean
flutter pub get

# 2. Build Play Store App Bundle (AAB) with obfuscation, tree-shaken icons & stripped debug symbols
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR" \
  --tree-shake-icons

# 3. Build Split-ABI APKs (arm64-v8a, armeabi-v7a, x86_64) for local device testing (< 20MB per ABI)
flutter build apk --release \
  --split-per-abi \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR" \
  --tree-shake-icons

ls -lh build/app/outputs/bundle/release/*.aab
ls -lh build/app/outputs/flutter-apk/*-release.apk

