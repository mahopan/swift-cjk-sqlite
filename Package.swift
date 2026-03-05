// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-cjk-sqlite",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "CJKSQLite",
            targets: ["CJKSQLite"]
        ),
    ],
    targets: [
        // Bundled SQLite with FTS5 enabled
        .target(
            name: "CSQLite",
            path: "Sources/CSQLite",
            cSettings: [
                .define("SQLITE_ENABLE_FTS5"),
                .define("SQLITE_ENABLE_FTS4"),
                .define("SQLITE_ENABLE_JSON1"),
                .define("SQLITE_ENABLE_RTREE"),
                .define("SQLITE_MAX_VARIABLE_NUMBER", to: "250000"),
                .define("SQLITE_THREADSAFE", to: "1"),
                .define("HAVE_USLEEP", to: "1"),
                .define("SQLITE_CORE"),
            ]
        ),
        // Swift wrapper + CJK tokenizer
        .target(
            name: "CJKSQLite",
            dependencies: ["CSQLite"],
            path: "Sources/CJKSQLite"
        ),
        .testTarget(
            name: "CJKSQLiteTests",
            dependencies: ["CJKSQLite"]
        ),
    ]
)
