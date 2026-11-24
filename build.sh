#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
destination="${1:-$PWD/build/Markdown++.app}"
if [[ "$destination" != /* || "$destination" != *.app ]]; then
    echo "请提供以 .app 结尾的绝对路径。" >&2
    exit 2
fi
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
app="$scratch/Markdown++.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/Info.plist"
cp -R Resources/Preview "$app/Contents/Resources/Preview"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

sdk="$(xcrun --sdk macosx --show-sdk-path)"
for arch in arm64 x86_64; do
    xcrun swiftc -O -sdk "$sdk" -target "$arch-apple-macosx13.0" \
        -module-name MarkdownPlusPlus Sources/*.swift -o "$scratch/MarkdownPlusPlus-$arch"
done
xcrun lipo -create "$scratch"/MarkdownPlusPlus-* -output "$app/Contents/MacOS/MarkdownPlusPlus"
codesign --force --sign - "$app"
mkdir -p "$(dirname "$destination")"
ditto "$app" "$destination"
codesign --verify --strict "$destination"
echo "$destination"
