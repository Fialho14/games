#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
build_bundle=false

case "${1:-}" in
    "") ;;
    --bundle) build_bundle=true ;;
    -h|--help)
        print -- "usage: ${0:t} [--bundle]"
        print -- "Runs strict Swift tests and native engine tests."
        print -- "--bundle also builds, verifies and locally installs the macOS app."
        exit 0
        ;;
    *)
        print -u2 -- "error: unknown option: $1"
        print -u2 -- "usage: ${0:t} [--bundle]"
        exit 2
        ;;
esac

cd "$project_dir"

print -- "Running Swift tests with warnings treated as errors..."
swift test -Xswiftc -warnings-as-errors

print -- "Running native engine tests..."
"$script_dir/test-native.sh"

if [[ "$build_bundle" == true ]]; then
    print -- "Building and verifying the distributable bundle..."
    "$script_dir/build-macos.sh"
fi

print -- "All requested project checks passed."
