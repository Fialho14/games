#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
product_name="PuzzleGames"
bundle_name="Puzzle Games.app"
archive_name="Puzzle Games.zip"
artifacts_dir="$project_dir/Artifacts"
final_app="$artifacts_dir/$bundle_name"
final_archive="$artifacts_dir/$archive_name"
info_plist="$project_dir/macOS/Info.plist"
verify_script="$script_dir/verify-macos.sh"

fail() {
    print -u2 -- "error: $*"
    exit 1
}

[[ "$(uname -s)" == "Darwin" ]] || fail "the macOS app bundle can only be built on macOS"
[[ -f "$project_dir/Package.swift" ]] || fail "Package.swift was not found at $project_dir"
[[ -f "$info_plist" ]] || fail "Info.plist was not found at $info_plist"
[[ -x "$verify_script" ]] || fail "verification script is missing or not executable: $verify_script"

for required_tool in swift plutil ditto xattr codesign; do
    command -v "$required_tool" >/dev/null 2>&1 || fail "required tool is unavailable: $required_tool"
done

packaging_temp_parent="${TMPDIR:-/tmp}"
[[ -d "$packaging_temp_parent" ]] || fail "temporary directory is unavailable: $packaging_temp_parent"
packaging_work_dir="$(mktemp -d "$packaging_temp_parent/puzzle-games-build.XXXXXX")"
[[ -n "$packaging_work_dir" && -d "$packaging_work_dir" ]] || fail "unable to create a temporary build directory"

cleanup() {
    if [[ -n "${packaging_work_dir:-}" && -d "$packaging_work_dir" ]]; then
        rm -rf "$packaging_work_dir"
    fi
}
trap cleanup EXIT INT TERM

staged_app="$packaging_work_dir/staged/$bundle_name"
relocated_app="$packaging_work_dir/relocated/$bundle_name"
archive_check_dir="$packaging_work_dir/archive-check"
staged_archive="$packaging_work_dir/$archive_name"

print -- "Building $product_name (Release)..."
cd "$project_dir"
swift build --configuration release --product "$product_name"
release_bin_dir="$(swift build --configuration release --show-bin-path)"
release_binary="$release_bin_dir/$product_name"
[[ -x "$release_binary" ]] || fail "Release executable was not produced at $release_binary"

install -d "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources"
install -m 0755 "$release_binary" "$staged_app/Contents/MacOS/$product_name"
install -m 0644 "$info_plist" "$staged_app/Contents/Info.plist"

icon_source=""
for icon_candidate in \
    "$project_dir/resources/AppIcon.icns" \
    "$project_dir/Resources/AppIcon.icns" \
    "$project_dir/Assets/AppIcon.icns" \
    "$project_dir/macOS/AppIcon.icns" \
    "$project_dir/macOS/Resources/AppIcon.icns"; do
    if [[ -f "$icon_candidate" ]]; then
        icon_source="$icon_candidate"
        break
    fi
done

if [[ -n "$icon_source" ]]; then
    install -m 0644 "$icon_source" "$staged_app/Contents/Resources/AppIcon.icns"
else
    print -u2 -- "warning: AppIcon.icns was not found; the bundle will use the generic app icon"
fi

plutil -lint "$staged_app/Contents/Info.plist" >/dev/null

# Extended Finder metadata must be removed before the bundle is sealed. Signing
# is deliberately the final mutation of the staged app.
xattr -cr "$staged_app"
codesign --force --sign - --timestamp=none "$staged_app" >/dev/null

"$verify_script" "$staged_app"

# The staged bundle has already passed validation, so it is safe to replace the
# previous generated artifact without carrying stale files into the new bundle.
install -d "$artifacts_dir"
if [[ -e "$final_app" ]]; then
    rm -rf "$final_app"
fi
ditto "$staged_app" "$final_app"

# Desktop/File Provider locations can attach Finder metadata while copying.
# Clear it at the delivery location and make signing the final bundle mutation.
xattr -cr "$final_app"
codesign --force --sign - --timestamp=none "$final_app" >/dev/null
"$verify_script" "$final_app"

# A second copy proves that the app bundle and its signature do not depend on
# the source tree or its original path. Launching is intentionally left to the
# final UI inspection step.
install -d "${relocated_app:h}"
ditto "$final_app" "$relocated_app"
"$verify_script" "$relocated_app"

# A ZIP is the durable transport artifact when the source tree lives in a
# Desktop/iCloud File Provider folder. Finder may attach metadata to a visible
# .app there after signing; the archived bundle remains byte-for-byte clean.
ditto -c -k --keepParent "$staged_app" "$staged_archive"
install -d "$archive_check_dir"
ditto -x -k "$staged_archive" "$archive_check_dir"
"$verify_script" "$archive_check_dir/$bundle_name"
ditto "$staged_archive" "$final_archive"

print -- "Built: $final_app"
print -- "Transport archive: $final_archive"
print -- "Verified a relocated copy in a temporary directory."
