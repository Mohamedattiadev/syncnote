#!/usr/bin/env bash
# Vercel build step — assumes vercel-install.sh already ran.
set -euo pipefail
export PATH="/tmp/flutter/bin:$PATH"
flutter build web --release
