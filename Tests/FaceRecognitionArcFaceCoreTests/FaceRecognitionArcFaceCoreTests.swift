//
//  FaceRecognitionArcFaceCoreTests.swift
//
//
//  Created by Jakub Dolejs on 16/06/2025.
//

import XCTest
import Foundation
import TestSupport
@testable @_spi(Testing) import FaceRecognitionArcFaceCore

final class FaceRecognitionArcFaceCoreTests: XCTestCase {
    
    var testResources: TestSupportResources!
    
    override func setUpWithError() throws {
        self.testResources = try TestSupportResources()
    }
    
    func testAttachAlignedFaceImages() async throws {
        for name in ["subject1-01", "subject1-02", "subject2-01"] {
            let (face, image) = try await self.testResources.faceAndImageForSubject(name)
            let aligned = try FaceAlignment.alignFace(face, image: image)
            let attachment = XCTAttachment(image: aligned)
            attachment.lifetime = .keepAlways
            attachment.name = "\(name)-aligned"
            self.add(attachment)
        }
    }
}
