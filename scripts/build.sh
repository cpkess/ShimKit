#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
# Keep signed build products outside cloud-synced Documents/Desktop folders.
# File providers can attach Finder metadata that causes codesign to reject bundles.
shimkit_build_dir="${TMPDIR:-/tmp/}ShimKitDerivedData"
xcodebuild -project ShimKit.xcodeproj -scheme ShimKit -configuration Release -derivedDataPath "$shimkit_build_dir" build
print "Built: $shimkit_build_dir/Build/Products/Release/ShimKit.app"
