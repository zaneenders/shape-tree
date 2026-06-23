// swift-tools-version: 6.3
//
// This manifest is static. BuildPage creates a throwaway package in
// .build/ at build time — no per-page targets live here.

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
  ]
)
