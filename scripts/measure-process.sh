#!/bin/zsh
set -euo pipefail

if (( $# < 1 || $# > 3 )); then
  echo "usage: $0 PID [DURATION_SECONDS] [INTERVAL_SECONDS]" >&2
  exit 64
fi

pid="$1"
duration="${2:-300}"
interval="${3:-5}"
samples=$(( duration / interval ))
output="$(mktemp)"
trap 'rm -f "$output"' EXIT

for (( index = 0; index < samples; index++ )); do
  if ! ps -p "$pid" -o %cpu=,rss= >> "$output"; then
    echo "process $pid exited before measurement completed" >&2
    exit 1
  fi
  sleep "$interval"
done

awk '
  { cpu += $1; rss += $2; count += 1 }
  END {
    if (count == 0) exit 1
    printf "samples=%d average_cpu_percent=%.3f average_rss_mb=%.2f\n", count, cpu / count, (rss / count) / 1024
  }
' "$output"
