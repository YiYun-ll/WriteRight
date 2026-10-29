#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
"$task_root/scripts/build-ios.sh"
task_selection="$(xcrun simctl list devices available --json | node -e '
  let input="";
  process.stdin.on("data", chunk => input += chunk);
  process.stdin.on("end", () => {
    const devices = Object.entries(JSON.parse(input).devices)
      .filter(([runtime]) => runtime.includes("SimRuntime.iOS"))
      .flatMap(([, devices]) => devices).filter(device => device.name.startsWith("iPhone"));
    const selected = devices.find(device => device.state === "Booted")
      ?? devices.find(device => device.name === "iPhone 17") ?? devices[0];
    if (!selected) { console.error("Install an iOS runtime and create an iPhone simulator first."); process.exit(1); }
    console.log(selected.udid + " " + selected.state);
  });
')"
read -r task_device task_state <<< "$task_selection"
if [[ "$task_state" != "Booted" ]]; then
  xcrun simctl boot "$task_device"
fi
xcrun simctl bootstatus "$task_device" -b
xcrun simctl install "$task_device" "$task_root/DerivedData/Build/Products/Debug-iphonesimulator/EssayPilot.app"
xcrun simctl launch "$task_device" com.yiyun.essaypilot.dev
