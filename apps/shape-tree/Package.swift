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
  ],
  dependencies: [
    // Pinned by full 40-char commit hash so the dependency cannot silently move
    // (a short revision is resolved as a *branch* by SwiftPM if a same-named
    // branch exists upstream — see audit finding M4).
    .package(
      url: "https://github.com/zaneenders/scribe.git",
      revision: "a13241595eaa55b343b268fb8a78a1d90bf9dd8a"),
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    .package(
      url: "https://github.com/hummingbird-project/swift-openapi-hummingbird.git",
      revision: "c464db1afe2c886083fd60e38f281150ac7e73e5"),
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
        .swiftLanguageMode(.v6)
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
        .swiftLanguageMode(.v6)
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
        .swiftLanguageMode(.v6)
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
        .swiftLanguageMode(.v6)
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
        .swiftLanguageMode(.v6)
      ]
    ),
  ]
)
