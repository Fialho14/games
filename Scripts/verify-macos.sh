#!/bin/zsh
set -euo pipefail
setopt extended_glob

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
default_app="$project_dir/Artifacts/Puzzle Games.app"
app_path="${1:-$default_app}"

fail() {
    print -u2 -- "error: $*"
    exit 1
}

warn() {
    print -u2 -- "warning: $*"
}

[[ $# -le 1 ]] || fail "usage: ${0:t} [path-to-app]"
[[ "$(uname -s)" == "Darwin" ]] || fail "bundle verification is only supported on macOS"

for required_tool in plutil codesign otool file xattr; do
    command -v "$required_tool" >/dev/null 2>&1 || fail "required tool is unavailable: $required_tool"
done

[[ -d "$app_path" ]] || fail "app bundle was not found: $app_path"
info_plist="$app_path/Contents/Info.plist"
[[ -f "$info_plist" ]] || fail "bundle is missing Contents/Info.plist"
plutil -lint "$info_plist" >/dev/null || fail "Info.plist is invalid"

plist_value() {
    plutil -extract "$1" raw -o - "$info_plist" 2>/dev/null
}

bundle_name="$(plist_value CFBundleName)"
display_name="$(plist_value CFBundleDisplayName)"
executable_name="$(plist_value CFBundleExecutable)"
bundle_identifier="$(plist_value CFBundleIdentifier)"
package_type="$(plist_value CFBundlePackageType)"
icon_name="$(plist_value CFBundleIconFile)"

[[ "$bundle_name" == "Puzzle Games" ]] || fail "unexpected CFBundleName: $bundle_name"
[[ "$display_name" == "Puzzle Games" ]] || fail "unexpected CFBundleDisplayName: $display_name"
[[ "$executable_name" == "PuzzleGames" ]] || fail "unexpected CFBundleExecutable: $executable_name"
[[ "$bundle_identifier" == "local.sudoku.mac" ]] || fail "unexpected CFBundleIdentifier: $bundle_identifier"
[[ "$package_type" == "APPL" ]] || fail "unexpected CFBundlePackageType: $package_type"
[[ "$icon_name" == "AppIcon" || "$icon_name" == "AppIcon.icns" ]] || fail "unexpected CFBundleIconFile: $icon_name"

executable_path="$app_path/Contents/MacOS/$executable_name"
[[ -x "$executable_path" ]] || fail "bundle executable is missing or not executable: $executable_path"
file "$executable_path" | grep -q "Mach-O" || fail "bundle executable is not a Mach-O binary"

resolved_icon_name="$icon_name"
[[ "$resolved_icon_name" == *.icns ]] || resolved_icon_name="$resolved_icon_name.icns"
if [[ ! -f "$app_path/Contents/Resources/$resolved_icon_name" ]]; then
    warn "Contents/Resources/$resolved_icon_name is absent; macOS will show a generic app icon"
fi

if xattr -p com.apple.FinderInfo "$app_path" >/dev/null 2>&1; then
    fail "disallowed com.apple.FinderInfo metadata is attached to the bundle"
fi
if xattr -p com.apple.ResourceFork "$app_path" >/dev/null 2>&1; then
    fail "disallowed com.apple.ResourceFork metadata is attached to the bundle"
fi

codesign --verify --deep --strict --verbose=2 "$app_path"

dependency_output="$(otool -L "$executable_path")"
while IFS= read -r dependency_line; do
    dependency_path="${dependency_line##[[:space:]]#}"
    dependency_path="${dependency_path%% *}"
    [[ -n "$dependency_path" ]] || continue
    case "$dependency_path" in
        /System/Library/*|/usr/lib/*) ;;
        *) fail "non-system runtime dependency is not bundled: $dependency_path" ;;
    esac
done < <(print -r -- "$dependency_output" | tail -n +2)

if command -v xcrun >/dev/null 2>&1 && xcrun --find swift-stdlib-tool >/dev/null 2>&1; then
    swift_runtime_dependencies="$(xcrun swift-stdlib-tool --print \
        --scan-executable "$executable_path" --platform macosx 2>&1)" || \
        fail "swift-stdlib-tool could not inspect the executable"
    if [[ -n "${swift_runtime_dependencies//[[:space:]]/}" ]]; then
        fail "Swift runtime libraries still need to be embedded: $swift_runtime_dependencies"
    fi
fi

print -- "Verified: $app_path"
