#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
source_dir="$project_dir/WattBar"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

xcrun --sdk macosx clang -arch arm64 -mmacosx-version-min=14.0 -Wall -Wextra -Werror \
    -c "$source_dir/SMCReader.c" -o "$scratch/SMCReader.o"
xcrun --sdk macosx swiftc -swift-version 6 -target arm64-apple-macosx14.0 -warnings-as-errors \
    -import-objc-header "$source_dir/SMCReader.h" "$source_dir/BatteryReader.swift" \
    "$source_dir/BatteryReading.swift" "$project_dir/Tests/BatteryChecks.swift" "$scratch/SMCReader.o" \
    -o "$scratch/BatteryChecks"
"$scratch/BatteryChecks" "$@"
