#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_temp="$(mktemp -d)"
trap 'rm -rf "$task_temp"' EXIT
task_platform="$(xcrun --sdk macosx --show-sdk-platform-path)"
cat > "$task_temp/main.swift" <<'SWIFT'
import XCTest
let suite = XCTestSuite(name: "OCR and source sentence layout")
suite.addTest(OCRLayoutTests.defaultTestSuite)
suite.addTest(SentenceLayoutTests.defaultTestSuite)
suite.addTest(ImageUploadTests.defaultTestSuite)
suite.addTest(ScanImageStoreTests.defaultTestSuite)
suite.run()
guard let result = suite.testRun, result.executionCount == 12 else {
    fatalError("Expected all twelve shared scan tests to execute")
}
exit(result.hasSucceeded ? 0 : 1)
SWIFT
xcrun swiftc \
  -I "$task_platform/Developer/usr/lib" \
  -L "$task_platform/Developer/usr/lib" \
  -Xlinker -rpath -Xlinker "$task_platform/Developer/usr/lib" \
  -F "$task_platform/Developer/Library/Frameworks" \
  -Xlinker -rpath -Xlinker "$task_platform/Developer/Library/PrivateFrameworks" \
  -Xlinker -rpath -Xlinker "$task_platform/Developer/Library/Frameworks" \
  "$task_root"/ios/EssayPilot/Domain/*.swift \
  "$task_root/ios/EssayPilot/Core/Text/WritingText.swift" \
  "$task_root/ios/EssayPilot/Core/Scanning/OCRLayout.swift" \
  "$task_root/ios/EssayPilot/Core/Scanning/ScanImageStore.swift" \
  "$task_root/ios/EssayPilot/Core/Scanning/ImageUploadEncoder.swift" \
  "$task_root/ios/EssayPilotTests/OCRLayoutTests.swift" \
  "$task_root/ios/EssayPilotTests/SentenceLayoutTests.swift" \
  "$task_root/ios/EssayPilotTests/ImageUploadTests.swift" \
  "$task_root/ios/EssayPilotTests/ScanImageStoreTests.swift" \
  "$task_temp/main.swift" -o "$task_temp/ocr-layout-tests"
"$task_temp/ocr-layout-tests"
