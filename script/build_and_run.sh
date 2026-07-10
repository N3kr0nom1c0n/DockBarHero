#!/bin/zsh
set -euo pipefail

script_name="$0"

usage() {
  echo "usage: $script_name [--debug|--logs|--telemetry|--verify]" >&2
}

mode="run"
if (( $# > 1 )); then
  usage
  exit 2
fi

if (( $# == 1 )); then
  case "$1" in
    --debug|--logs|--telemetry|--verify)
      mode="${1#--}"
      ;;
    *)
      usage
      exit 2
      ;;
  esac
fi

app_path=".build/RunDerivedData/Build/Products/Debug/DockBarHero.app"
binary_path="$app_path/Contents/MacOS/DockBarHero"

pkill -x DockBarHero 2>/dev/null || true
xcodegen generate
xcodebuild \
  -project DockBarHero.xcodeproj \
  -scheme DockBarHero \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/RunDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build

case "$mode" in
  debug)
    exec /usr/bin/lldb "$binary_path"
    ;;
  logs)
    /usr/bin/open -n "$app_path"
    exec /usr/bin/log stream --style compact --predicate 'process == "DockBarHero"'
    ;;
  telemetry)
    /usr/bin/open -n "$app_path"
    exec /usr/bin/log stream --style compact --predicate 'subsystem == "com.n3kr0nom1c0n.DockBarHero"'
    ;;
  run)
    exec /usr/bin/open -n "$app_path"
    ;;
  verify)
    /usr/bin/open -n "$app_path"
    for (( attempt = 1; attempt <= 20; attempt++ )); do
      if pgrep -x DockBarHero >/dev/null; then
        echo "DockBarHero launched (pid $(pgrep -x DockBarHero | head -1))"
        exit 0
      fi
      sleep 0.25
    done
    echo "DockBarHero did not appear after launch" >&2
    exit 1
    ;;
esac
