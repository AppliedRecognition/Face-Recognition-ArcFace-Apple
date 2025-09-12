// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FaceRecognitionArcFace",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FaceRecognitionArcFaceCloud",
            targets: ["FaceRecognitionArcFaceCloud"]),
        .library(
            name: "FaceRecognitionArcFaceCore",
            targets: ["FaceRecognitionArcFaceCore"]),
        .library(
            name: "FaceDetectionRetinaFaceOrt",
            targets: ["FaceDetectionRetinaFaceOrt"])
    ],
    dependencies: [
        .package(url: "https://github.com/AppliedRecognition/Ver-ID-Common-Types-Apple.git", .upToNextMajor(from: "3.0.0")),
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs.git", .upToNextMajor(from: "9.1.0")),
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager.git", .upToNextMajor(from: "1.20.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FaceRecognitionArcFaceCloud",
            dependencies: [
                "FaceRecognitionArcFaceCore"
            ]),
        .target(
            name: "FaceRecognitionArcFaceCore",
            dependencies: [
                "FaceDetectionRetinaFaceOrt",
                .product(name: "VerIDCommonTypes", package: "Ver-ID-Common-Types-Apple")
            ]),
        .target(
            name: "TestSupport",
            dependencies: [
                "FaceDetectionRetinaFaceOrt",
                .product(name: "VerIDCommonTypes", package: "Ver-ID-Common-Types-Apple")
            ],
            resources: [
                .process("Resources")
            ]),
        .target(
            name: "FaceDetectionRetinaFaceOrt",
            dependencies: [
                .product(name: "VerIDCommonTypes", package: "Ver-ID-Common-Types-Apple"),
                .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager")
            ],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "FaceRecognitionArcFaceCloudTests",
            dependencies: [
                "FaceRecognitionArcFaceCloud",
                "FaceDetectionRetinaFaceOrt",
                "TestSupport",
                .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs")
            ],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "FaceRecognitionArcFaceCoreTests",
            dependencies: [
                "FaceRecognitionArcFaceCore",
                "FaceDetectionRetinaFaceOrt",
                "TestSupport"
            ])
    ]
)
