#!/bin/bash
set -e
set -x

echo "=== ci_post_clone.sh start ==="
echo "CI_PRIMARY_REPOSITORY_PATH=$CI_PRIMARY_REPOSITORY_PATH"
echo "CI_WORKSPACE=$CI_WORKSPACE"
echo "HOME=$HOME"
echo "PWD=$PWD"
echo "Xcode: $(xcodebuild -version)"
echo "Ruby: $(ruby --version)"
which pod && echo "pod: $(pod --version)" || echo "pod: not found"

# ── Install Flutter ──────────────────────────────────────────────
FLUTTER_HOME="$HOME/flutter"
if [ ! -d "$FLUTTER_HOME" ]; then
  echo "Installing Flutter (stable)…"
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

echo "Flutter precache…"
flutter precache --ios
flutter --version

# ── CocoaPods (use system if available, else install) ────────────
if ! command -v pod > /dev/null 2>&1; then
  echo "Installing CocoaPods…"
  gem install cocoapods --user-install --no-document
  RUBY_VER=$(ruby -e 'puts RUBY_VERSION')
  export PATH="$HOME/.gem/ruby/$RUBY_VER/bin:$PATH"
fi
echo "pod version: $(pod --version)"

# ── Generate Flutter artifacts ───────────────────────────────────
echo "Running flutter pub get…"
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

# ── Install Pods ─────────────────────────────────────────────────
echo "Running pod install…"
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install

echo "=== ci_post_clone.sh complete ✓ ==="
