// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "shape-tree-web",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.25.0"),
    .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.0.0"),
    .package(url: "https://github.com/hummingbird-project/hummingbird-compression.git", from: "2.0.0"),
    .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.101.0"),
    .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.34.0"),
    .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.31.0"),
    .package(url: "https://github.com/apple/swift-nio-imap.git", from: "0.1.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    .package(url: "https://github.com/wendylabsinc/swift-postgres-models.git", from: "0.2.0"),
    .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", revision: "aac702b"),
    .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0"),
    .package(url: "https://github.com/apple/swift-metrics.git", from: "2.5.0"),
    .package(url: "https://github.com/swift-server/swift-prometheus.git", from: "2.0.0"),
    .package(
      url: "https://github.com/swift-otel/swift-otel.git", exact: "1.2.1",
      traits: ["OTLPHTTP"]),
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
      name: "ShapeTreeEmail",
      dependencies: [
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
        .product(name: "NIOExtras", package: "swift-nio-extras"),
        .product(name: "NIOFoundationCompat", package: "swift-nio"),
        .product(name: "NIOIMAP", package: "swift-nio-imap"),
        .product(name: "NIOSSL", package: "swift-nio-ssl"),
        .product(name: "Configuration", package: "swift-configuration"),
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
      name: "shape-tree-add-user",
      dependencies: [
        "ShapeTreeWebAuth",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .target(
      name: "ShapeTreeWebAuth",
      dependencies: [
        "ShapeTreeEmail",
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
        .product(name: "PostgresNIO", package: "postgres-nio"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOSSL", package: "swift-nio-ssl"),
        .product(name: "Crypto", package: "swift-crypto"),
        .product(name: "Configuration", package: "swift-configuration"),
      ],
      plugins: [
        .plugin(name: "PostgresModelsPlugin", package: "swift-postgres-models")
      ]
    ),
    .executableTarget(
      name: "ShapeTreeWeb",
      dependencies: [
        "ShapeTreeWebBuilder",
        "ShapeTreeConfig",
        "ShapeTreeMarkdown",
        "ShapeTreeWebAuth",
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdCompression", package: "hummingbird-compression"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "Metrics", package: "swift-metrics"),
        .product(name: "Prometheus", package: "swift-prometheus"),
        .product(name: "OTel", package: "swift-otel"),
      ]
    ),
    .testTarget(
      name: "ShapeTreeEmailTests",
      dependencies: ["ShapeTreeEmail"]
    ),
    .testTarget(
      name: "ShapeTreeWebTests",
      dependencies: [
        "ShapeTreeWeb",
        "ShapeTreeWebAuth",
        "ShapeTreeEmail",
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdTesting", package: "hummingbird"),
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
        .product(name: "PostgresNIO", package: "postgres-nio"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "Configuration", package: "swift-configuration"),
      ]
    ),
  ]
)
