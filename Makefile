.PHONY: help ios-preflight ios-build ios-upload ios-release

IOS_VERSION_NAME ?= 1.0.0
IOS_BUILD_NUMBER ?= $(shell date +%Y%m%d%H%M)
IOS_CHANGELOG ?= Automated upload

help:
	@echo "Available targets:"
	@echo "  make ios-preflight"
	@echo "  make ios-build IOS_VERSION_NAME=1.0.0 IOS_BUILD_NUMBER=2"
	@echo "  make ios-upload IOS_CHANGELOG='Bug fixes and improvements'"
	@echo "  make ios-release IOS_VERSION_NAME=1.0.0 IOS_BUILD_NUMBER=2 IOS_CHANGELOG='Release notes'"

ios-preflight:
	bundle exec fastlane ios preflight

ios-build:
	bundle exec fastlane ios build_ipa version_name:$(IOS_VERSION_NAME) build_number:$(IOS_BUILD_NUMBER)

ios-upload:
	bundle exec fastlane ios upload_to_testflight changelog:"$(IOS_CHANGELOG)"

ios-release:
	bundle exec fastlane ios release version_name:$(IOS_VERSION_NAME) build_number:$(IOS_BUILD_NUMBER) changelog:"$(IOS_CHANGELOG)"
