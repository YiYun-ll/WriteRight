#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
if ! xcodebuild -version >/dev/null 2>&1; then
  print -u2 'Full Xcode is required. Install Xcode and select its Developer directory.'
  exit 1
fi
if [[ ! -d "$task_root/ios/EssayPilot.xcodeproj" ]]; then
  "$task_root/scripts/generate-ios.sh"
fi
xcodebuild \
  -project "$task_root/ios/EssayPilot.xcodeproj" \
  -scheme EssayPilot \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$task_root/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build
