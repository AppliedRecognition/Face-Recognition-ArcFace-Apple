//
//  Preprocessing.swift
//
//
//  Created by Jakub Dolejs on 07/07/2025.
//

import UIKit
import CoreML
import Accelerate
import OnnxRuntimeBindings

@_spi(Testing) public struct Preprocessing {
    
    @_spi(Testing) public func ortTensorFromPixelBuffer(_ pixelBuffer: CVPixelBuffer, scaledToSize size: CGSize) throws -> (ORTValue, CGFloat) {
        let argbBuffer = try self.argbBufferFromPixelBuffer(pixelBuffer)
        var (scaledBuffer, scale) = try self.argbBuffer(srcARGB: argbBuffer, scaledToFit: size)
        let width = Int(scaledBuffer.width)
        let height = Int(scaledBuffer.height)
        let pixelCount = width * height
        var nchw = [Float](repeating: 0, count: pixelCount * 3)
        var alpha = try vImage_Buffer(width: width, height: height, bitsPerPixel: UInt32(32))
        defer { alpha.free() }
        try nchw.withUnsafeMutableBufferPointer { buf in
            let nchwBase = buf.baseAddress!
            let rowBytes = width * MemoryLayout<Float>.stride
            var red = vImage_Buffer(data: nchwBase, height: scaledBuffer.height, width: scaledBuffer.width, rowBytes: rowBytes)
            var green = vImage_Buffer(data: nchwBase.advanced(by: pixelCount), height: scaledBuffer.height, width: scaledBuffer.width, rowBytes: rowBytes)
            var blue = vImage_Buffer(data: nchwBase.advanced(by: pixelCount * 2), height: scaledBuffer.height, width: scaledBuffer.width, rowBytes: rowBytes)
            var minF: Float = -127.5/128.0
            var maxF: Float = 127.5/128.0
            let err = vImageConvert_ARGB8888toPlanarF(&scaledBuffer, &alpha, &red, &green, &blue, &maxF, &minF, vImage_Flags(kvImageNoFlags))
            guard err == kvImageNoError else {
                throw FaceDetectionRetinaFaceError.imageResizingError
            }
        }
        let shape: [NSNumber] = [1, 3, NSNumber(value: height), NSNumber(value: width)]
        let mutableData: NSMutableData = nchw.withUnsafeBufferPointer { ptr in
            NSMutableData(bytes: ptr.baseAddress!, length: ptr.count * MemoryLayout<Float>.stride)
        }
        let tensor = try ORTValue(tensorData: mutableData, elementType: .float, shape: shape)
        return (tensor, scale)
    }
    
    func argbBufferFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) throws -> vImage_Buffer {
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let supportedFormats = [kCVPixelFormatType_32ABGR, kCVPixelFormatType_32ARGB, kCVPixelFormatType_32BGRA, kCVPixelFormatType_32RGBA]
        if !supportedFormats.contains(format) {
            throw FaceDetectionRetinaFaceError.imageResizingError
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw FaceDetectionRetinaFaceError.imageResizingError
        }
        var src = vImage_Buffer(data: base, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
        var dst = try vImage_Buffer(width: width, height: height, bitsPerPixel: 32)
        guard var permuteMap = try self.argbPermuteMapFromFormat(format) else {
            if vImageCopyBuffer(&src, &dst, 4, vImage_Flags(kvImageNoFlags)) == kvImageNoError {
                return dst
            } else {
                throw FaceDetectionRetinaFaceError.imageResizingError
            }
        }
        guard vImagePermuteChannels_ARGB8888(&src, &dst, &permuteMap, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            throw FaceDetectionRetinaFaceError.imageResizingError
        }
        return dst
    }
    
    private func argbPermuteMapFromFormat(_ format: OSType) throws -> [UInt8]? {
        switch format {
        case kCVPixelFormatType_32ABGR:
            return [0,3,2,1]
        case kCVPixelFormatType_32ARGB:
            return nil
        case kCVPixelFormatType_32BGRA:
            return [3,2,1,0]
        case kCVPixelFormatType_32RGBA:
            return [3,0,1,2]
        default:
            throw FaceDetectionRetinaFaceError.imageResizingError
        }
    }
    
    func argbBuffer(srcARGB: vImage_Buffer, scaledToFit size: CGSize) throws -> (vImage_Buffer, CGFloat) {
        let outW = Int(size.width)
        let outH = Int(size.height)
        let srcW = Int(srcARGB.width), srcH = Int(srcARGB.height)
        let imRatio = Double(srcH) / Double(srcW)
        let modelRatio = Double(outH) / Double(outW)
        
        let newW: Int
        let newH: Int
        if imRatio > modelRatio {
            newH = outH
            newW = Int(round(Double(newH) / imRatio))
        } else {
            newW = outW
            newH = Int(round(Double(newW) * imRatio))
        }
        let scale = CGFloat(Double(newH) / Double(srcH))
        
        // Create canvas (ARGB8888), clear to 0
        var canvas = try vImage_Buffer(width: outW, height: outH, bitsPerPixel: 32)
        vImageBufferFill_ARGB8888(&canvas, [0, 0, 0, 0], vImage_Flags(kvImageNoFlags))
        
        // Make a ROI view into the top-left of the canvas
        var roi = vImage_Buffer(data: canvas.data,
                                height: vImagePixelCount(newH),
                                width:  vImagePixelCount(newW),
                                rowBytes: canvas.rowBytes)
        
        // Scale source → ROI view (high quality)
        var src = srcARGB // vImage APIs take inout
        let err = vImageScale_ARGB8888(&src, &roi, nil, vImage_Flags(kvImageHighQualityResampling))
        guard err == kvImageNoError else { throw FaceDetectionRetinaFaceError.imageResizingError }
        
        return (canvas, scale)
    }
}
