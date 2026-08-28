#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
native_temp_parent="${TMPDIR:-/tmp}"
native_work_dir="$(mktemp -d "$native_temp_parent/puzzle-games-native-tests.XXXXXX")"

cleanup() {
    if [[ -n "${native_work_dir:-}" && -d "$native_work_dir" ]]; then
        rm -rf "$native_work_dir"
    fi
}
trap cleanup EXIT INT TERM

cd "$project_dir"

cc -std=c11 -O2 -Wall -Wextra -Wpedantic \
    -I Sources/CalcudokuEngine \
    -I Sources/CalcudokuEngine/include \
    Sources/CalcudokuEngine/CalcudokuEngine.c \
    Sources/CalcudokuEngine/cdok.c \
    Sources/CalcudokuEngine/generator.c \
    Sources/CalcudokuEngine/solver.c \
    Tests/Native/CalcudokuEngineTests.c \
    -o "$native_work_dir/CalcudokuEngineTests"

c++ -std=c++17 -O2 -Wall -Wextra -Wpedantic \
    -I Sources/SudokuEngine \
    -I Sources/SudokuEngine/include \
    Sources/SudokuEngine/block.cpp \
    Sources/SudokuEngine/command.cpp \
    Sources/SudokuEngine/i18n.cpp \
    Sources/SudokuEngine/scene.cpp \
    Sources/SudokuEngine/mac_engine.cpp \
    Tests/Native/SudokuEngineTests.cpp \
    -o "$native_work_dir/SudokuEngineTests"

"$native_work_dir/CalcudokuEngineTests"
"$native_work_dir/SudokuEngineTests"
