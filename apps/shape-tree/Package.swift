// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "shape-tree",
  platforms: [
    .macOS(.v26),
    .iOS(.v26),
  ],
  products: [
    .library(name: "ShapeTreeClient", targets: ["ShapeTreeClient"]),
    .executable(name: "ShapeTree", targets: ["ShapeTree"]),
    .executable(name: "ShapeTreeWeb", targets: ["ShapeTreeWeb"]),
  ],
  dependencies: [
    .package(url: "https://github.com/zaneenders/lorikeet.git", revision: "31904cb"),
    .package(url: "https://github.com/apple/swift-markdown.git", from: "0.7.0"),
    .package(url: "https://github.com/zaneenders/scribe.git", revision: "a132415"),
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.24.0"),
    .package(url: "https://github.com/hummingbird-project/swift-openapi-hummingbird.git", from: "2.0.1"),
    .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.0.0"),
    .package(url: "https://github.com/swift-server/swift-openapi-async-http-client.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0"),
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.4.0"),
    .package(url: "https://github.com/apple/swift-system.git", from: "1.4.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
  ],
  targets: [
    .target(
      name: "Sit",
      dependencies: [
        .product(name: "Subprocess", package: "swift-subprocess"),
        .product(name: "SystemPackage", package: "swift-system"),
        .product(name: "Logging", package: "swift-log"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
      ]
    ),
    .executableTarget(
      name: "ShapeTree",
      dependencies: [
        "ShapeTreeClient",
        "Sit",
        .product(name: "ScribeCore", package: "scribe"),
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "OpenAPIHummingbird", package: "swift-openapi-hummingbird"),
        .product(name: "Configuration", package: "swift-configuration"),
        .product(name: "JWTKit", package: "jwt-kit"),
        .product(name: "Crypto", package: "swift-crypto"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
      ]
    ),
    .target(
      name: "ShapeTreeClient",
      dependencies: [
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client"),
        .product(name: "JWTKit", package: "jwt-kit"),
        .product(name: "Crypto", package: "swift-crypto"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
      ],
      plugins: [
        .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
      ]
    ),
    .testTarget(
      name: "SitTests",
      dependencies: [
        "Sit",
        .product(name: "Logging", package: "swift-log"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
      ]
    ),
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
      sources: ["Assets.swift"],
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
      name: "ShapeTreeTests",
      dependencies: [
        "ShapeTree",
        "ShapeTreeClient",
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "HummingbirdTesting", package: "hummingbird"),
        .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client"),
        .product(name: "JWTKit", package: "jwt-kit"),
        .product(name: "Crypto", package: "swift-crypto"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
      ]
    ),
  ]
)
