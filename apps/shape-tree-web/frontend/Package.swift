// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "ShapeTreeFrontend",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.55.0"),
    .package(url: "https://github.com/zaneenders/swift-fit.git", branch: "lifetimes"),
  ],
  targets: [
    .target(
      name: "ShapeTreeDOM",
      dependencies: ["JavaScriptKit"],
      swiftSettings: [
        .enableExperimentalFeature("Extern"),
        .swiftLanguageMode(.v6),
      ]
    ),
    .executableTarget(
      name: "Entry",
      dependencies: [
        "ShapeTreeDOM",
        "JavaScriptKit",
        .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("Extern"),
        .swiftLanguageMode(.v6),
        .unsafeFlags(["-Osize"], .when(configuration: .release)),
      ],
      linkerSettings: [
        .unsafeFlags(["-Xlinker", "-lswiftUnicodeDataTables"])  // Better string suppport
      ],
      plugins: [
        .plugin(name: "BridgeJS", package: "JavaScriptKit")
      ]
    ),
    .executableTarget(
      name: "FitViewer",
      dependencies: [
        "ShapeTreeDOM",
        "JavaScriptKit",
        .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
        .product(name: "SwiftFit", package: "swift-fit"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("Extern"),
        .swiftLanguageMode(.v6),
        .unsafeFlags(["-Osize"], .when(configuration: .release)),
      ],
      linkerSettings: [
        .unsafeFlags(["-Xlinker", "-lswiftUnicodeDataTables"])  // Better string suppport
      ],
      plugins: [
        .plugin(name: "BridgeJS", package: "JavaScriptKit")
      ]
    ),
    .executableTarget(
      name: "ArticleViewer",
      dependencies: [
        "ShapeTreeDOM",
        "JavaScriptKit",
        .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
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
