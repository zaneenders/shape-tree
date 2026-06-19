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
    .package(url: "https://github.com/zaneenders/lorikeet.git", revision: "31904cb"),
    .package(url: "https://github.com/apple/swift-markdown.git", from: "0.7.0"),
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.24.0"),
    .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0"),
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
    .executableTarget(
      name: "ShapeTreeWeb",
      dependencies: [
        "ShapeTreeWebCore",
        "ShapeTreeWebAssets",
        .product(name: "HTML", package: "Lorikeet"),
        .product(name: "HTMX", package: "Lorikeet"),
        .product(name: "HTMXExtras", package: "Lorikeet"),
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "Configuration", package: "swift-configuration"),
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
      sources: ["Assets.swift", "ClientAssetCatalog.swift", "ClientWasm.swift"],
      resources: [.copy("ClientWasm.wasm")],
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
  ]
)
