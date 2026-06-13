fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios preflight

```sh
[bundle exec] fastlane ios preflight
```

Run release preflight checks

### ios build_ipa

```sh
[bundle exec] fastlane ios build_ipa
```

Build a signed release IPA with explicit version/build numbers

### ios upload_to_testflight

```sh
[bundle exec] fastlane ios upload_to_testflight
```

Upload IPA to App Store Connect/TestFlight using API key

### ios release

```sh
[bundle exec] fastlane ios release
```

Run preflight, build IPA, and upload to App Store Connect

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
