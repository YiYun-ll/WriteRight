#!/bin/bash
set -euo pipefail

# Build a device Release app for the recipient's sideloader to sign.
# This never exports a certificate or changes the installed development app.
task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_build="${1:-1}"
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

# Drop any device-specific profile. Keep an ad-hoc signature that carries the
# App Group entitlement so a signer which registers extensions can copy it.
# iLoader 2.4.1 ignores this and reuses the main profile; it cannot enable the widget.
find "$task_stage" -name embedded.mobileprovision -type f -delete
find "$task_stage" -type d -name _CodeSignature -prune -exec rm -rf {} +
task_app_entitlements="$task_root/ios/Config/Shared.entitlements"
task_widget_entitlements="$task_root/ios/Config/SideloadWidget.entitlements"
task_payload_app="$task_stage/Payload/EssayPilot.app"
task_widget="$task_payload_app/PlugIns/WriteRightWidgets.appex"
cp "$task_app_entitlements" "$task_payload_app/archived-expanded-entitlements.xcent"
if [[ -d "$task_widget" ]]; then
  cp "$task_widget_entitlements" "$task_widget/archived-expanded-entitlements.xcent"
  /usr/bin/codesign --force --sign - --entitlements "$task_widget_entitlements" \
    --generate-entitlement-der --timestamp=none "$task_widget"
fi
/usr/bin/codesign --force --sign - --entitlements "$task_app_entitlements" \
  --generate-entitlement-der --timestamp=none "$task_payload_app"
task_version="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$task_app/Info.plist")"
task_ipa="$task_output/WriteRight-${task_version}-${task_build}-sideload.ipa"
ditto -c -k --norsrc --noextattr --keepParent "$task_stage/Payload" "$task_ipa"
unzip -tq "$task_ipa"
task_check="$(mktemp -d)"
unzip -q "$task_ipa" -d "$task_check"
task_signed="$task_check/Payload/EssayPilot.app"
task_group="group.com.yiyun.essaypilot.shared"
task_keychain='$(AppIdentifierPrefix)com.yiyun.essaypilot.dev'
for task_target in "$task_signed" "$task_signed/PlugIns/WriteRightWidgets.appex"; do
  task_entitlements="$(/usr/bin/codesign -d --entitlements :- "$task_target" 2>/dev/null)"
  /usr/bin/grep -F -q "$task_group" <<<"$task_entitlements"
  /usr/bin/grep -F -q "$task_keychain" <<<"$task_entitlements"
done
if find "$task_signed" -name embedded.mobileprovision -print | grep -q .; then
  printf 'Sideload IPA must not contain a provisioning profile.\n' >&2
  exit 1
fi
test "$(/usr/bin/plutil -extract NSSupportsLiveActivities raw -o - "$task_signed/Info.plist")" = "true"
test "$(/usr/bin/plutil -extract NSExtension.NSExtensionPointIdentifier raw -o - "$task_signed/PlugIns/WriteRightWidgets.appex/Info.plist")" = "com.apple.widgetkit-extension"
rm -rf "$task_check"
(cd "$task_output" && shasum -a 256 "$(basename "$task_ipa")" > "$(basename "$task_ipa").sha256")
printf 'Device Release IPA with widget entitlements, ready for a signer that registers extensions:\n%s\n' "$task_ipa"
