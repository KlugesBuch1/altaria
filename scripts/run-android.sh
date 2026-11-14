#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  export PATH="/c/tools/flutter/bin:$PATH"
fi

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/AppData/Local/Android/Sdk}}"
if ! command -v adb >/dev/null 2>&1 && [ -x "$SDK/platform-tools/adb" ]; then
  export PATH="$SDK/platform-tools:$PATH"
fi

cd "$(dirname "$0")/.."

flutter pub get
flutter build apk --release
APK="build/app/outputs/flutter-apk/app-release.apk"

if ! adb get-state >/dev/null 2>&1; then
  echo "No Android device or emulator is connected."
  echo "The APK is at $APK."
  exit 1
fi

adb install -r "$APK"
adb shell am start \
  -n dev.klugesbuch.altaria/com.ryanheise.audioservice.AudioServiceActivity
exec adb logcat -s flutter
