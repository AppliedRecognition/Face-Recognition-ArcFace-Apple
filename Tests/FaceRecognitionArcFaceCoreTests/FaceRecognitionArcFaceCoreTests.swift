//
//  FaceRecognitionArcFaceCoreTests.swift
//
//
//  Created by Jakub Dolejs on 16/06/2025.
//

import XCTest
import Foundation
import TestSupport
import FaceDetectionRetinaFaceOrt
@testable @_spi(Testing) import FaceRecognitionArcFaceCore

final class FaceRecognitionArcFaceCoreTests: XCTestCase {
    
    var testResources: TestSupportResources!
    // Modify as needed
    let dataSetLoaderURL = URL(string: "http://192.168.1.217:3000/original")!
    
    override func setUp() async throws {
        self.testResources = try await TestSupportResources()
    }
    
    func testAttachAlignedFaceImages() async throws {
        throw XCTSkip()
        for name in ["subject1-01", "subject1-02", "subject2-01"] {
            let (face, image) = try await self.testResources.faceAndImageForSubject(name)
            let aligned = try FaceAlignment.alignFace(face, image: image)
            let attachment = XCTAttachment(image: aligned)
            attachment.lifetime = .keepAlways
            attachment.name = "\(name)-aligned"
            self.add(attachment)
        }
    }
    
    func testDetectFaceRepeatedly() async throws {
        throw XCTSkip("For testing memory pressure")
        for _ in 0..<1000 {
            for name in ["subject1-01", "subject1-02", "subject2-01"] {
                let image = try self.testResources.imageForSubject(name)
                _ = try await self.testResources.faceDetection.detectFacesInImage(image, limit: 1)
            }
        }
    }
    
    func testAlignFaceRepeatedly() async throws {
        throw XCTSkip("For testing memory pressure")
        for _ in 0..<1000 {
            for name in ["subject1-01", "subject1-02", "subject2-01"] {
                let (face, image) = try await self.testResources.faceAndImageForSubject(name)
                _ = try FaceAlignment.alignFace(face, image: image)
            }
        }
    }
    
    func testFaceAlignment() async throws {
        throw XCTSkip()
        let dataSetLoader = DatasetLoader(url: self.dataSetLoaderURL)
        let faceDetection = try await FaceDetectionRetinaFaceOrt()
        var attachmentCount = 0
        let maxAttachmentCount: Int = 10
        for try await (url, image) in dataSetLoader.streamImages() {
            guard let face = try await faceDetection.detectFacesInImage(image, limit: 1).first else {
                continue
            }
            let alignedFaceImage = try FaceAlignment.alignFace(face, image: image)
            let name = String(url.lastPathComponent.split(separator: ".")[0])
            let attachment = XCTAttachment(image: alignedFaceImage)
            attachment.lifetime = .keepAlways
            attachment.name = name
            self.add(attachment)
            attachmentCount += 1
            if attachmentCount > maxAttachmentCount {
                return
            }
        }
    }
}
