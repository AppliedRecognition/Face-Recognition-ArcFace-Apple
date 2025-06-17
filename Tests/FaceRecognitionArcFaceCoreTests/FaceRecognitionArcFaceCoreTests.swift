//
//  FaceRecognitionArcFaceCoreTests.swift
//
//
//  Created by Jakub Dolejs on 16/06/2025.
//

import XCTest
import Foundation
import TestSupport
@testable import FaceRecognitionArcFaceCore

final class FaceRecognitionArcFaceCoreTests: XCTestCase {
    
    let testResources = TestSupportResources()
    
    func testFaceAlignment() throws {
        guard let (face, image) = self.testResources.faceAndImageForSubject("subject1-01") else {
            XCTFail()
            return
        }
        let alignedImage = try FaceAlignment.alignFace(face, image: image)
        let att = XCTAttachment(image: alignedImage)
        att.lifetime = .keepAlways
        self.add(att)
    }
    
    func testAttachAlignedFaceImages() throws {
        try ["subject1-01", "subject1-02", "subject2-01"].forEach { name in
            guard let (face, image) = self.testResources.faceAndImageForSubject(name) else {
                XCTFail()
                return
            }
            let aligned = try FaceAlignment.alignFace(face, image: image)
            let attachment = XCTAttachment(image: aligned)
            attachment.lifetime = .keepAlways
            attachment.name = "\(name)-aligned"
            self.add(attachment)
        }
    }
}
