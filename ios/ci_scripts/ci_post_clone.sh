#!/bin/sh
set -e

# ── Install Flutter ──────────────────────────────────────────────
echo "Installing Flutter…"
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"

flutter precache --ios
flutter --version

# ── Install CocoaPods ────────────────────────────────────────────
echo "Installing CocoaPods…"
gem install cocoapods

# ── Generate Flutter artifacts & install Pods ────────────────────
echo "Running flutter pub get…"
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

echo "Running pod install…"
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install

echo "ci_post_clone.sh complete ✓"
