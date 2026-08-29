# Legacy code

`CalcudokuCLI/` preserves the command-line parts of the original `cdok`
project (parser, printer, CLI entry point and Makefile) for reference. The
reusable generator and solver are maintained separately in
`Sources/CalcudokuEngine/`, together with the upstream licence notice.

The project also descends from a terminal Sudoku implementation. Its reusable
C++ engine and the files retained for historical CLI compatibility live in
`Sources/SudokuEngine/`; Swift Package Manager excludes the terminal-only files
from the macOS application target.

The legacy folders are not required at runtime by `Puzzle Games.app`.
