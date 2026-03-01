#!/bin/bash

# Exit on error, print every command
set -e
set -x

echo "=== ci_post_clone.sh start ==="
echo "CI_PRIMARY_REPOSITORY_PATH=${CI_PRIMARY_REPOSITORY_PATH}"
echo "CI_WORKSPACE=${CI_WORKSPACE}"
echo "HOME=${HOME}"
echo "PWD=$(pwd)"

# Print Xcode and Ruby info
xcodebuild -version || true
ruby --version || true
which pod && pod --version || echo "pod not found in PATH"

# Install Flutter SDK
FLUTTER_DIR="${HOME}/flutter"
if [ ! -d "${FLUTTER_DIR}" ]; then
  echo "Cloning Flutter SDK..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "${FLUTTER_DIR}"
else
  echo "Flutter SDK already present"
fi

export PATH="${FLUTTER_DIR}/bin:${FLUTTER_DIR}/bin/cache/dart-sdk/bin:${PATH}"

echo "Running flutter precache..."
flutter precache --ios

echo "Flutter version:"
flutter --version

# CocoaPods - install only if not available
if ! command -v pod > /dev/null 2>&1; then
  echo "Installing CocoaPods..."
  gem install cocoapods --user-install --no-document
  RUBY_VERSION_STR=$(ruby -e 'puts RUBY_VERSION')
  export PATH="${HOME}/.gem/ruby/${RUBY_VERSION_STR}/bin:${PATH}"
fi
echo "pod version: $(pod --version)"

# Flutter pub get
echo "Running flutter pub get..."
cd "${CI_PRIMARY_REPOSITORY_PATH}"
flutter pub get

# Pod install
echo "Running pod install..."
cd "${CI_PRIMARY_REPOSITORY_PATH}/ios"
pod install

echo "=== ci_post_clone.sh done ==="
