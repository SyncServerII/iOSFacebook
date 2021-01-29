// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iOSFacebook",
    platforms: [
        // This package depends on iOSSignIn-- which needs at least iOS 13.
        .iOS(.v13),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "iOSFacebook",
            targets: ["iOSFacebook"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SyncServerII/iOSSignIn.git", from: "0.0.2"),
        .package(url: "https://github.com/SyncServerII/ServerShared.git", from: "0.0.4"),
        .package(url: "https://github.com/SyncServerII/iOSShared.git", from: "0.0.2"),
        
        // Not referencing the latest-- 6.5.2 because as of 5/3/20, https://developers.facebook.com/docs/ios/getting-started seems to indicate that version 6 isn't suitable.
        //.package(url: "https://github.com/facebook/facebook-ios-sdk.git", from: "5.10.0"),

        .package(url: "https://github.com/facebook/facebook-ios-sdk.git", from: "8.2.0"),

        // .package(url: "https://github.com/SyncServerII/iOSSignIn.git", from: "0.0.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "iOSFacebook",
            dependencies: [
                "iOSSignIn", "ServerShared", "iOSShared",
                "FacebookLogin", "FacebookCore", "FacebookShare"
            ]),
        .testTarget(
            name: "iOSFacebookTests",
            dependencies: ["iOSFacebook", "iOSShared"]),
    ]
)
