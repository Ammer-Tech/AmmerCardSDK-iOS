// swift-tools-version: 5.5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AmmerSmartCardsSDK",
  platforms: [
    .iOS(.v13)
  ],
  products: [
    .library(
      name: "AmmerSmartCardsSDK",
      targets: ["AmmerSmartCardsSDK"]),
  ],
  dependencies: [
      
  ],
  targets: [
    .target(
      name: "AmmerSmartCardsSDK",
      dependencies: [],
      path: "Sources"),
    .testTarget(
      name: "AmmerSmartCardsSDKTests",
      dependencies: ["AmmerSmartCardsSDK"]),
  ]
)
