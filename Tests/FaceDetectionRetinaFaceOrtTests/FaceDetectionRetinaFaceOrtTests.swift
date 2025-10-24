//
//  FaceDetectionRetinaFaceOrtTests.swift
//  
//
//  Created by Jakub Dolejs on 12/09/2025.
//

import XCTest
import Accelerate
import CoreVideo
@testable @_spi(Testing) import FaceDetectionRetinaFaceOrt

final class FaceDetectionRetinaFaceOrtTests: XCTestCase {

    func testSplitImageToRGBPlanes() throws {
        let size = 8
        let testBuffer = try self.makeTestARGB8888Buffer(colour: [0xFF, 0xFF, 0x00, 0x00], size: 8)
        defer {
            testBuffer.free()
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
    
    func testOrtTensorFromPixelBuffer() throws {
        throw XCTSkip()
        let preproc = Preprocessing()
        let targetSize = CGSize(width: 640, height: 640)
        for _ in 0..<10000 {
            let pixelBuffer = self.makeRandomPixelBuffer(width: 1200, height: 1600)
            XCTAssertNoThrow(try preproc.ortTensorFromPixelBuffer(pixelBuffer, scaledToSize: targetSize))
        }
    }
    
    private func makeTestARGB8888Buffer(colour: [UInt8], size: Int) throws -> vImage_Buffer {
        var buffer = try vImage_Buffer(width: size, height: size, bitsPerPixel: 32)
        var fill: [UInt8] = colour
        vImageBufferFill_ARGB8888(&buffer, &fill, vImage_Flags(kvImageNoFlags))
        return buffer
    }
    

    func makeRandomPixelBuffer(width: Int, height: Int, pixelFormat: OSType = kCVPixelFormatType_32BGRA) -> CVPixelBuffer {
        precondition(width > 0 && height > 0)
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         pixelFormat,
                                         attrs as CFDictionary,
                                         &pixelBuffer)
        precondition(status == kCVReturnSuccess && pixelBuffer != nil, "Failed to create CVPixelBuffer")
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer!, []) }
        
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer!)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer!)
        let totalBytes = bytesPerRow * height
        
        // Fill with random bytes
        let bufferPointer = baseAddress.bindMemory(to: UInt8.self, capacity: totalBytes)
        for i in 0..<totalBytes {
            bufferPointer.advanced(by: i).pointee = UInt8.random(in: 0...255)
        }
        
        return pixelBuffer!
    }
}
