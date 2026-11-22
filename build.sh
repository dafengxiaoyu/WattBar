#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
app_path="${1:-"$project_dir/build/WattBar.app"}"
if [[ "$app_path" != *.app || -e "$app_path" || -L "$app_path" ]]; then
    printf 'Specify a new .app path. Existing bundles are left intact.\n' >&2
    exit 1
fi

mkdir -p "$(dirname "$app_path")"
staging="$(mktemp -d "$(dirname "$app_path")/.wattbar-build.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
bundle="$staging/WattBar.app"

mkdir -p "$bundle/Contents/MacOS"
cp "$project_dir/WattBar/Info.plist" "$bundle/Contents/Info.plist"
xcrun --sdk macosx clang -arch arm64 -mmacosx-version-min=14.0 -O -Wall -Wextra -Werror \
    -c "$project_dir/WattBar/SMCReader.c" -o "$staging/SMCReader.o"
xcrun --sdk macosx swiftc -swift-version 6 -target arm64-apple-macosx14.0 \
    -O -whole-module-optimization -warnings-as-errors -module-name WattBar \
    -import-objc-header "$project_dir/WattBar/SMCReader.h" \
    "$project_dir"/WattBar/*.swift "$staging/SMCReader.o" -o "$bundle/Contents/MacOS/WattBar"
/usr/bin/codesign --force --sign - "$bundle"
/usr/bin/codesign --verify --strict "$bundle"
/bin/mv -n "$bundle" "$app_path"
if [[ -d "$bundle" ]]; then
    printf 'The destination appeared while WattBar was building.\n' >&2
    exit 1
fi
printf '%s\n' "$app_path"
