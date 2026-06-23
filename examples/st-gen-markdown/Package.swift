// swift-tools-version: 6.3
//
// This manifest is managed by BuildPage (Sources/BuildPage/BuildPage.swift).
// Per-page executable targets are appended automatically when you run
// `BuildPage <file.md>`; you should not normally edit the targets array by hand.

import PackageDescription

let package = Package(
  name: "STGenMarkdown",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.55.0"),
    .package(url: "https://github.com/apple/swift-markdown.git", from: "0.5.0"),
  ],
  targets: [
    .executableTarget(
      name: "BuildPage",
      dependencies: [
        .product(name: "Markdown", package: "swift-markdown"),
      ]
    ),
      .executableTarget(
        name: "Page_Home",
        dependencies: [.product(name: "JavaScriptKit", package: "JavaScriptKit")],
        path: "Sources/Pages",
        sources: ["Page_Home.swift"],
        swiftSettings: [
          .enableExperimentalFeature("Extern"),
          .swiftLanguageMode(.v5),
          .unsafeFlags(["-Osize"], .when(configuration: .release)),
        ]
      ),
      .executableTarget(
        name: "Page_Private_2025_06_15_draft",
        dependencies: [.product(name: "JavaScriptKit", package: "JavaScriptKit")],
        path: "Sources/Pages",
        sources: ["Page_Private_2025_06_15_draft.swift"],
        swiftSettings: [
          .enableExperimentalFeature("Extern"),
          .swiftLanguageMode(.v5),
          .unsafeFlags(["-Osize"], .when(configuration: .release)),
        ]
      ),
      .executableTarget(
        name: "Page_fragments_2025_06_08_ascii_sketch",
        dependencies: [.product(name: "JavaScriptKit", package: "JavaScriptKit")],
        path: "Sources/Pages",
        sources: ["Page_fragments_2025_06_08_ascii_sketch.swift"],
        swiftSettings: [
          .enableExperimentalFeature("Extern"),
          .swiftLanguageMode(.v5),
          .unsafeFlags(["-Osize"], .when(configuration: .release)),
        ]
      ),
      .executableTarget(
        name: "Page_guides_2025_06_12_getting_started",
        dependencies: [.product(name: "JavaScriptKit", package: "JavaScriptKit")],
        path: "Sources/Pages",
        sources: ["Page_guides_2025_06_12_getting_started.swift"],
        swiftSettings: [
          .enableExperimentalFeature("Extern"),
          .swiftLanguageMode(.v5),
          .unsafeFlags(["-Osize"], .when(configuration: .release)),
        ]
      ),
      .executableTarget(
        name: "Page_notes_2025_06_10_morning_pages",
        dependencies: [.product(name: "JavaScriptKit", package: "JavaScriptKit")],
        path: "Sources/Pages",
        sources: ["Page_notes_2025_06_10_morning_pages.swift"],
        swiftSettings: [
          .enableExperimentalFeature("Extern"),
          .swiftLanguageMode(.v5),
          .unsafeFlags(["-Osize"], .when(configuration: .release)),
        ]
      ),
      .executableTarget(
        name: "Page_notes_2025_06_14_field_notes",
        dependencies: [.product(name: "JavaScriptKit", package: "JavaScriptKit")],
        path: "Sources/Pages",
        sources: ["Page_notes_2025_06_14_field_notes.swift"],
        swiftSettings: [
          .enableExperimentalFeature("Extern"),
          .swiftLanguageMode(.v5),
          .unsafeFlags(["-Osize"], .when(configuration: .release)),
        ]
      ),
      .executableTarget(
        name: "Page_style_guide",
        dependencies: [.product(name: "JavaScriptKit", package: "JavaScriptKit")],
        path: "Sources/Pages",
        sources: ["Page_style_guide.swift"],
        swiftSettings: [
          .enableExperimentalFeature("Extern"),
          .swiftLanguageMode(.v5),
          .unsafeFlags(["-Osize"], .when(configuration: .release)),
        ]
      ),
  ]
)
