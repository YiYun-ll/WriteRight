#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_device="$(xcrun simctl list devices available --json | node -e '
let input="";process.stdin.on("data",d=>input+=d);process.stdin.on("end",()=>{
const devices=Object.entries(JSON.parse(input).devices).filter(([key])=>key.includes("SimRuntime.iOS")).flatMap(([,v])=>v);
const selected=devices.find(d=>d.state==="Booted"&&d.name.startsWith("iPhone"))??devices.find(d=>d.name==="iPhone 17");
if(!selected){console.error("No available iPhone simulator.");process.exit(1);}console.log(selected.udid);
});')"
# The system Photos picker test uses a freshly imported synthetic image, never an existing personal photo.
xcrun simctl boot "$task_device" 2>/dev/null || true
xcrun simctl bootstatus "$task_device" -b >/dev/null
task_photo_dir="$(mktemp -d)"
trap 'rm -rf "$task_photo_dir"' EXIT
cp "$task_root/tests/fixtures/profile-widget.png" "$task_photo_dir/profile-widget.png"
xcrun simctl addmedia "$task_device" "$task_photo_dir/profile-widget.png"
task_result="$task_root/artifacts/ios-tests-$(date +%Y%m%d-%H%M%S).xcresult"
mkdir -p "$task_root/artifacts"
xcodebuild test \
  -project "$task_root/ios/EssayPilot.xcodeproj" \
  -scheme EssayPilot \
  -destination "platform=iOS Simulator,id=$task_device" \
  -derivedDataPath "$task_root/DerivedData" \
  -resultBundlePath "$task_result" \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
  "$@"
