//
//  FaceDetectionRetinaFaceOrtTests.swift
//  
//
//  Created by Jakub Dolejs on 12/09/2025.
//

import XCTest
import Accelerate
@testable @_spi(Testing) import FaceDetectionRetinaFaceOrt

final class FaceDetectionRetinaFaceOrtTests: XCTestCase {

    func testSplitImageToRGBPlanes() throws {
        let size = 8
        let testBuffer = try self.makeTestARGB8888Buffer(colour: [0xFF, 0xFF, 0x00, 0x00], size: 8)
        defer {
            free(testBuffer.data)
        }
        let (planes, w, h) = try Preprocessing().rgbPlanesFromARGBBuffer(testBuffer)
        XCTAssertEqual(w, size)
        XCTAssertEqual(h, size)
        let minF: Float = -127.5/128.0
        let maxF: Float = 127.5/128.0
        let planePixelCount = w * h
        XCTAssertTrue(planes[0..<planePixelCount].allSatisfy({ $0.isEqual(to: maxF) }))
        XCTAssertTrue(planes[planePixelCount...].allSatisfy({ $0.isEqual(to: minF) }))
    }
    
    private func makeTestARGB8888Buffer(colour: [UInt8], size: Int) throws -> vImage_Buffer {
        var buffer = try vImage_Buffer(width: size, height: size, bitsPerPixel: 32)
        var fill: [UInt8] = colour
        vImageBufferFill_ARGB8888(&buffer, &fill, vImage_Flags(kvImageNoFlags))
        return buffer
    }
}
