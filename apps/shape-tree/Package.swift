// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "shape-tree",
  platforms: [
    .macOS(.v26),
    .iOS(.v26),
  ],
  products: [
    .library(name: "ShapeTreeClient", targets: ["ShapeTreeClient"])
  ],
  dependencies: [
    .package(url: "https://github.com/zaneenders/scribe.git", revision: "0718ddb"),
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.0.0"),
    .package(url: "https://github.com/swift-server/swift-openapi-async-http-client.git", from: "1.0.0"),
  ],
  targets: [
    .executableTarget(
      name: "ShapeTree",
      dependencies: [
        .product(name: "ScribeCore", package: "scribe"),
        .product(name: "ScribeLLM", package: "scribe"),
        .product(name: "Hummingbird", package: "hummingbird"),
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
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ],
      plugins: [
        .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
      ]
    ),
    .executableTarget(
      name: "ShapeTreeClientCLI",
      dependencies: [
        "ShapeTreeClient"
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
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ]
    ),
  ]
)
