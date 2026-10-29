#!/bin/zsh
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_generator="$task_root/.tools/bin/xcodegen"
if [[ ! -x "$task_generator" ]]; then
  task_generator="$(command -v xcodegen || true)"
fi
if [[ -z "$task_generator" ]]; then
  print -u2 'XcodeGen is required. See docs/DevelopmentSetup.md.'
  exit 1
fi
cd "$task_root/ios"
"$task_generator" generate --spec project.yml
