//
//  ManagedImageBuffer.swift
//  FaceRecognitionArcFace
//
//  Created by Jakub Dolejs on 23/10/2025.
//

import Foundation
import Accelerate

final class ManagedImageBuffer {
    var buffer: vImage_Buffer
    init(width: Int, height: Int, bitsPerPixel: UInt32) throws {
        buffer = try vImage_Buffer(width: width, height: height, bitsPerPixel: bitsPerPixel)
    }
    deinit {
        buffer.free()
    }
}
