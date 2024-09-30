// swift-tools-version: 5.5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AmmerSmartCards",
  platforms: [
    .iOS(.v13)
  ],
  products: [
    .library(
      name: "AmmerSmartCards",
      targets: ["AmmerSmartCards"]),
  ],
  dependencies: [
      .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.3")
  ],
  targets: [
    .target(
      name: "AmmerSmartCards",
      dependencies: [
          .product(name: "CryptoSwift", package: "CryptoSwift")
      ],
      path: "Sources"),
    .testTarget(
      name: "AmmerSmartCardsTests",
      dependencies: ["AmmerSmartCards"]),
  ]
)
