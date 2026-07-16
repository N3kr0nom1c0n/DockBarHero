#!/bin/zsh
set -euo pipefail

script_name="$0"

usage() {
  echo "usage: $script_name [--debug|--logs|--telemetry|--verify] [--fast|--speed N]" >&2
}

mode="run"
simulation_speed="1"

while (( $# > 0 )); do
  case "$1" in
    --debug|--logs|--telemetry|--verify)
      mode="${1#--}"
      shift
      ;;
    --fast)
      simulation_speed="25"
      shift
      ;;
    --speed)
      if (( $# < 2 )); then
        usage
        exit 2
      fi
      simulation_speed="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

case "$simulation_speed" in
  ''|*[!0-9]*)
    usage
    exit 2
    ;;
esac

app_path=".build/RunDerivedData/Build/Products/Debug/DockBarHero.app"
binary_path="$app_path/Contents/MacOS/DockBarHero"
launch_args=()
if (( simulation_speed > 1 )); then
  launch_args=(--args --simulation-speed "$simulation_speed")
fi

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
    if (( simulation_speed > 1 )); then
      exec /usr/bin/lldb --one-line "settings set target.run-args --simulation-speed $simulation_speed" "$binary_path"
    fi
    exec /usr/bin/lldb "$binary_path"
    ;;
  logs)
    /usr/bin/open -n "$app_path" "${launch_args[@]}"
    exec /usr/bin/log stream --style compact --predicate 'process == "DockBarHero"'
    ;;
  telemetry)
    /usr/bin/open -n "$app_path" "${launch_args[@]}"
    exec /usr/bin/log stream --style compact --predicate 'subsystem == "com.n3kr0nom1c0n.DockBarHero"'
    ;;
  run)
    exec /usr/bin/open -n "$app_path" "${launch_args[@]}"
    ;;
  verify)
    /usr/bin/open -n "$app_path" "${launch_args[@]}"
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
