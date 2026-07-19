#!/usr/bin/env bash
# Vercel install step for Flutter web builds.
# Fetches Flutter SDK to /tmp/flutter and runs pub get.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_HOME="/tmp/flutter"

if [ ! -d "$FLUTTER_HOME" ]; then
  echo "→ downloading flutter ($FLUTTER_VERSION)"
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}.tar.xz" \
    -o /tmp/flutter.tar.xz || \
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.3-stable.tar.xz" \
    -o /tmp/flutter.tar.xz
  tar -xf /tmp/flutter.tar.xz -C /tmp
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
flutter --version
flutter config --no-analytics
flutter pub get
