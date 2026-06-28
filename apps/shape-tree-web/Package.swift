// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "shape-tree-web",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.25.0"),
    .package(url: "https://github.com/hummingbird-project/hummingbird-compression.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.101.0"),
    .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0"),
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", revision: "aac702b"),
    .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0"),
  ],
  targets: [
    .target(
      name: "ShapeTreeConfig",
      dependencies: [
        .product(name: "Configuration", package: "swift-configuration")
      ]
    ),
    .target(
      name: "ShapeTreeMarkdown",
      dependencies: [
        .product(name: "Markdown", package: "swift-markdown")
      ]
    ),
    .target(
      name: "ShapeTreeWebBuilder",
      dependencies: [
        "ShapeTreeConfig",
        .product(name: "_NIOFileSystem", package: "swift-nio"),
        .product(name: "Subprocess", package: "swift-subprocess"),
      ]
    ),
    .executableTarget(
      name: "shape-tree-web-builder",
      dependencies: ["ShapeTreeConfig", "ShapeTreeWebBuilder"]
    ),
    .executableTarget(
      name: "ShapeTreeWeb",
      dependencies: [
        "ShapeTreeWebBuilder",
        "ShapeTreeConfig",
        "ShapeTreeMarkdown",
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdCompression", package: "hummingbird-compression"),
      ]
    ),
  ]
)
