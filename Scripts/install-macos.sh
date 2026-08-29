#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
verify_script="$script_dir/verify-macos.sh"
source_app="${1:-$project_dir/Artifacts/Puzzle Games.app}"
bundle_name="Puzzle Games.app"

fail() {
    print -u2 -- "error: $*"
    exit 1
}

[[ $# -le 1 ]] || fail "usage: ${0:t} [path-to-app]"
[[ "$(uname -s)" == "Darwin" ]] || fail "installation is only supported on macOS"
[[ -d "$source_app" ]] || fail "source app was not found: $source_app"
[[ -x "$verify_script" ]] || fail "verification script is unavailable: $verify_script"

for required_tool in osascript ditto xattr codesign mdimport; do
    command -v "$required_tool" >/dev/null 2>&1 || fail "required tool is unavailable: $required_tool"
done
[[ -x /usr/bin/trash ]] || fail "/usr/bin/trash is required for recoverable replacement"

applications_dir="$(osascript -e 'POSIX path of (path to applications folder from user domain)')"
applications_dir="${applications_dir%/}"
[[ -n "$applications_dir" && "$applications_dir" != "/" ]] || \
    fail "unable to resolve the user Applications directory safely"
[[ "${applications_dir:t}" == "Applications" ]] || \
    fail "unexpected user Applications directory: $applications_dir"
install -d "$applications_dir"

install_temp_parent="${TMPDIR:-/tmp}"
install_work_dir="$(mktemp -d "$install_temp_parent/puzzle-games-install.XXXXXX")"
staged_app="$install_work_dir/$bundle_name"
installed_app="$applications_dir/$bundle_name"

cleanup() {
    if [[ -n "${install_work_dir:-}" && -d "$install_work_dir" ]]; then
        rm -rf "$install_work_dir"
    fi
}
trap cleanup EXIT INT TERM

ditto --norsrc "$source_app" "$staged_app"
xattr -cr "$staged_app"
codesign --force --sign - --timestamp=none "$staged_app" >/dev/null
"$verify_script" "$staged_app"

# Never leave an old executable running after its bundle has been replaced.
running_app_pattern='Puzzle Games\.app/Contents/MacOS/PuzzleGames$'
if pgrep -f "$running_app_pattern" >/dev/null 2>&1; then
    osascript -e 'tell application "Puzzle Games" to quit' 2>/dev/null || true
    for _ in {1..20}; do
        pgrep -f "$running_app_pattern" >/dev/null 2>&1 || break
        sleep 0.1
    done
    pgrep -f "$running_app_pattern" >/dev/null 2>&1 && \
        fail "Puzzle Games is still running; installation was not changed"
fi

if [[ -e "$installed_app" ]]; then
    /usr/bin/trash "$installed_app"
fi
ditto --norsrc "$staged_app" "$installed_app"
xattr -cr "$installed_app"
codesign --force --sign - --timestamp=none "$installed_app" >/dev/null
"$verify_script" "$installed_app"
mdimport "$installed_app" >/dev/null 2>&1 || true

print -- "Installed: $installed_app"
