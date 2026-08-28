// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PuzzleGames",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PuzzleGames", targets: ["PuzzleGames"]),
    ],
    targets: [
        .target(
            name: "SudokuEngine",
            path: "Sources/SudokuEngine",
            exclude: [
                "color.h", "display_symbol.h",
                "input.cpp", "input.h", "main.cpp", "system_env.hpp"
            ],
            sources: ["block.cpp", "command.cpp", "i18n.cpp", "scene.cpp", "mac_engine.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [.headerSearchPath(".")]
        ),
        .target(
            name: "CalcudokuEngine",
            path: "Sources/CalcudokuEngine",
            exclude: ["UPSTREAM-LICENSE.txt"],
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath(".")]
        ),
        .executableTarget(
            name: "PuzzleGames",
            dependencies: ["SudokuEngine", "CalcudokuEngine"],
            path: "Sources/PuzzleGames",
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .testTarget(
            name: "PuzzleGamesTests",
            dependencies: ["PuzzleGames", "SudokuEngine", "CalcudokuEngine"],
            path: "Tests/PuzzleGamesTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
