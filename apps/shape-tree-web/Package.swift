// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "shape-tree-web",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "ShapeTreeWeb", targets: ["ShapeTreeWeb"])
  ],
  dependencies: [
    .package(url: "https://github.com/zaneenders/lorikeet.git", revision: "30702f6"),
    .package(url: "https://github.com/apple/swift-markdown.git", from: "0.7.0"),
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.24.0"),
    .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.0.0"),
    .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.100.0"),
    .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.34.0"),
    .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.31.0"),
    .package(url: "https://github.com/apple/swift-nio-imap.git", from: "0.1.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    .package(url: "https://github.com/zaneenders/swift-postgres-models.git", revision: "93c458e"),
    .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-metrics.git", from: "2.5.0"),
    .package(url: "https://github.com/swift-server/swift-prometheus.git", from: "2.0.0"),
    .package(
      url: "https://github.com/swift-otel/swift-otel.git", exact: "1.2.1",
      traits: ["OTLPHTTP"]),
  ],
  targets: [
    .target(
      name: "ShapeTreeWebCore",
      dependencies: [
        .product(name: "Markdown", package: "swift-markdown")
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
      ]
    ),
    .target(
      name: "ShapeTreeWebEmail",
      dependencies: [
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
        .product(name: "NIOExtras", package: "swift-nio-extras"),
        .product(name: "NIOFoundationCompat", package: "swift-nio"),
        .product(name: "NIOIMAP", package: "swift-nio-imap"),
        .product(name: "NIOSSL", package: "swift-nio-ssl"),
        .product(name: "Configuration", package: "swift-configuration"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
      ]
    ),
    .target(
      name: "ShapeTreeWebAuth",
      dependencies: [
        "ShapeTreeWebCore",
        "ShapeTreeWebEmail",
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
        .product(name: "PostgresNIO", package: "postgres-nio"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOSSL", package: "swift-nio-ssl"),
        .product(name: "Crypto", package: "swift-crypto"),
        .product(name: "Configuration", package: "swift-configuration"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
      ],
      plugins: [
        .plugin(name: "PostgresModelsPlugin", package: "swift-postgres-models")
      ]
    ),
    .executableTarget(
      name: "ShapeTreeWeb",
      dependencies: [
        "ShapeTreeWebCore",
        "ShapeTreeWebAssets",
        "ShapeTreeWebAuth",
        .product(name: "HTML", package: "Lorikeet"),
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "Configuration", package: "swift-configuration"),
        .product(name: "Metrics", package: "swift-metrics"),
        .product(name: "Prometheus", package: "swift-prometheus"),
        .product(name: "OTel", package: "swift-otel"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
      ]
    ),
    .target(
      name: "ShapeTreeWebAssets",
      path: "Sources/ShapeTreeWebAssets",
      exclude: ["client"],
      sources: ["Assets.swift", "ClientAssetCatalog.swift", "NavWasm.swift", "PostWasmAsset.swift"],
      resources: [.copy("WASMNav.wasm"), .copy("WasmPosts")],
      plugins: [
        .plugin(name: "EmbedWebAssets", package: "Lorikeet")
      ]
    ),
    .testTarget(
      name: "ShapeTreeWebCoreTests",
      dependencies: ["ShapeTreeWebCore"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
      ]
    ),
    .testTarget(
      name: "ShapeTreeWebTests",
      dependencies: [
        "ShapeTreeWeb",
        "ShapeTreeWebCore",
        "ShapeTreeWebAssets",
        "ShapeTreeWebAuth",
        "ShapeTreeWebEmail",
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdTesting", package: "hummingbird"),
        .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
        .product(name: "PostgresNIO", package: "postgres-nio"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "Configuration", package: "swift-configuration"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
      ]
    ),
  ]
)
