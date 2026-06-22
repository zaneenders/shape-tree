// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "ContentGenerator",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/apple/swift-markdown.git", from: "0.5.0")
  ],
  targets: [
    .executableTarget(
      name: "ContentGenerator",
      dependencies: [
        .product(name: "Markdown", package: "swift-markdown")
      ]
    )
  ]
)
