// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "stratum_ui",
  // The floors of webview_flutter_wkwebview, so an app needs no higher one.
  platforms: [
    .iOS("13.0"),
    .macOS("10.15"),
  ],
  products: [
    .library(name: "stratum-ui", targets: ["stratum_ui"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
  ],
  targets: [
    .target(
      name: "stratum_ui",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
      ]
    )
  ]
)
