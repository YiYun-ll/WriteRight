#!/bin/bash
set -euo pipefail

# Build a device Release app for the recipient's sideloader to sign.
# This never exports a certificate or changes the installed development app.
task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_build="${1:-8}"
if ! [[ "$task_build" =~ ^[1-9][0-9]*$ ]]; then
  printf 'Build number must be a positive integer.\n' >&2
  exit 1
fi
task_output="$task_root/artifacts/sideload-$(TZ=Asia/Shanghai date +%Y%m%d-%H%M%S)"
mkdir -p "$task_output"
cd "$task_root"

xcodebuild build \
  -project ios/EssayPilot.xcodeproj \
  -scheme EssayPilot \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$task_output/DerivedData" \
  -clonedSourcePackagesDirPath "$task_root/DerivedData/SourcePackages" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
  DEVELOPMENT_TEAM= CURRENT_PROJECT_VERSION="$task_build" \
  > "$task_output/build.log" 2>&1

task_app="$task_output/DerivedData/Build/Products/Release-iphoneos/EssayPilot.app"
node scripts/check-ios-cloud.mjs "$task_app"
task_stage="$(mktemp -d "$task_output/stage.XXXXXX")"
trap 'rm -rf "$task_stage"' EXIT
mkdir -p "$task_stage/Payload"
ditto --norsrc --noextattr "$task_app" "$task_stage/Payload/EssayPilot.app"

# Remove signing remnants from the copy only. The recipient signs it locally.
find "$task_stage" -type d -name _CodeSignature -prune -exec rm -rf {} +
find "$task_stage" -name embedded.mobileprovision -type f -delete
task_ipa="$task_output/WriteRight-0.1.0-$task_build-sideload.ipa"
ditto -c -k --norsrc --noextattr --keepParent "$task_stage/Payload" "$task_ipa"
unzip -tq "$task_ipa"
(cd "$task_output" && shasum -a 256 "$(basename "$task_ipa")" > "$(basename "$task_ipa").sha256")
printf 'Unsigned device Release IPA ready for recipient signing:\n%s\n' "$task_ipa"
