set shell := ["bash", "-cu"]

default:
    @just --list

# Full setup — deps + config wizard + compile CLI
setup:
    ./setup.sh

# ---------- Flutter app ----------

run:
    flutter run -d linux

chrome:
    CHROME_EXECUTABLE=/usr/bin/brave flutter run -d chrome

android:
    flutter run -d $(flutter devices --machine | jq -r '.[] | select(.platform=="android") | .id' | head -1)

# Build + install APK on plugged phone (adb + USB debug required)
apk:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! adb devices | grep -qE 'device$'; then
      echo "no phone detected. plug in USB + enable USB debugging"
      exit 1
    fi
    flutter build apk --release
    APK=build/app/outputs/flutter-apk/app-release.apk
    adb install -r "$APK"
    adb shell monkey -p com.attia.syncnote -c android.intent.category.LAUNCHER 1 >/dev/null || true
    echo "APK installed + launched"

apk-only:
    flutter build apk --release
    @echo "APK: build/app/outputs/flutter-apk/app-release.apk"

# ---------- CLI ----------

# Run CLI from source
cli:
    cd cli && dart run bin/syncnote.dart

# Compile CLI to native binary at ./bin/syncnote
cli-build:
    mkdir -p bin
    cd cli && dart compile exe bin/syncnote.dart -o ../bin/syncnote
    @echo "binary: bin/syncnote"

# Install CLI binary to ~/.local/bin/syncnote (in PATH)
cli-install: cli-build
    install -Dm755 bin/syncnote ~/.local/bin/syncnote
    @echo "installed: ~/.local/bin/syncnote"
    @echo "make sure ~/.local/bin is in PATH"

# Run CLI tests
cli-test:
    cd cli && dart test

# Analyze CLI
cli-check:
    cd cli && dart analyze

# ---------- Web ----------

web:
    flutter build web --release
    cd build/web && python3 -m http.server 8765 --bind 0.0.0.0

# ---------- Housekeeping ----------

clean:
    flutter clean
    rm -rf build .dart_tool cli/.dart_tool bin

deps:
    flutter pub get
    cd cli && dart pub get

check:
    flutter analyze
    cd cli && dart analyze

fmt:
    dart format lib/ cli/

devices:
    flutter devices
