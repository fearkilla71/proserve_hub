#!/bin/sh
set -eo pipefail

echo "=== ci_post_clone.sh start ==="
echo "CI_PRIMARY_REPOSITORY_PATH=$CI_PRIMARY_REPOSITORY_PATH"
echo "HOME=$HOME"
echo "PWD=$PWD"

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
if ! command -v pod &>/dev/null; then
  echo "Installing CocoaPods…"
  gem install cocoapods --user-install
  export PATH="$HOME/.gem/ruby/$(ruby -e 'puts RUBY_VERSION')/bin:$PATH"
fi
echo "pod version: $(pod --version)"

# ── Generate Flutter artifacts ───────────────────────────────────
echo "Running flutter pub get…"
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

# ── Install Pods ─────────────────────────────────────────────────
echo "Running pod install…"
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install --verbose

echo "=== ci_post_clone.sh complete ✓ ==="
