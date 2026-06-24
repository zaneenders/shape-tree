// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "ShapeTreeCore",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .library(name: "ShapeTreeKit", targets: ["ShapeTreeKit"]),
    .executable(name: "ShapeTreeCore", targets: ["ShapeTreeCore"]),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.55.0"),
    .package(url: "https://github.com/zaneenders/lorikeet.git", revision: "2c178eb"),
  ],
  targets: [
    .target(
      name: "ShapeTreeKit",
      dependencies: [
        .product(name: "JavaScriptKit", package: "JavaScriptKit")
      ],
      swiftSettings: [
        .enableExperimentalFeature("Extern"),
        .swiftLanguageMode(.v6),
      ],
      plugins: [
        .plugin(name: "BridgeJS", package: "JavaScriptKit")
      ]
    ),
    .executableTarget(
      name: "ShapeTreeCore",
      dependencies: [
        "ShapeTreeKit",
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        .product(name: "HTML", package: "Lorikeet"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("Extern"),
        .swiftLanguageMode(.v6),
        .unsafeFlags(["-Osize"], .when(configuration: .release)),
      ],
      linkerSettings: [
        .unsafeFlags(["-Xlinker", "-lswiftUnicodeDataTables"])
      ],
      plugins: [
        .plugin(name: "BridgeJS", package: "JavaScriptKit")
      ]
    ),
  ]
)
