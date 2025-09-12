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
    
    @_spi(Testing) public init() {}
    
    @_spi(Testing) public func ortTensorFromPixelBuffer(_ pixelBuffer: CVPixelBuffer, scaledToSize size: CGSize) throws -> (ORTValue, CGFloat) {
        let argbBuffer = try self.argbBufferFromPixelBuffer(pixelBuffer)
        var (scaledBuffer, scale) = try self.argbBuffer(srcARGB: argbBuffer, scaledToFit: size)
        let (nchw, width, height) = try self.rgbPlanesFromARGBBuffer(scaledBuffer)
        let shape: [NSNumber] = [1, 3, NSNumber(value: height), NSNumber(value: width)]
        let mutableData: NSMutableData = nchw.withUnsafeBufferPointer { ptr in
            NSMutableData(bytes: ptr.baseAddress!, length: ptr.count * MemoryLayout<Float>.stride)
        }
        let tensor = try ORTValue(tensorData: mutableData, elementType: .float, shape: shape)
        return (tensor, scale)
    }
    
    @_spi(Testing) public func rgbPlanesFromARGBBuffer(_ buffer: vImage_Buffer) throws -> (buffer: [Float], width: Int, height:Int) {
        var scaledBuffer = buffer
        let width = Int(scaledBuffer.width)
        let height = Int(scaledBuffer.height)
        let pixelCount = width * height
        let totalCount = pixelCount * 3
        var contiguous: [UInt8] = Array(repeating: 0, count: totalCount)
        try contiguous.withUnsafeMutableBufferPointer { buf in
            let rowBytes = width
            var a = try vImage_Buffer(size: CGSize(width: width, height: height), bitsPerPixel: 8)
            var r = vImage_Buffer(data: buf.baseAddress!, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
            var g = vImage_Buffer(data: buf.baseAddress!.advanced(by: pixelCount), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
            var b = vImage_Buffer(data: buf.baseAddress!.advanced(by: pixelCount * 2), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
            guard vImageConvert_ARGB8888toPlanar8(&scaledBuffer, &a, &r, &g, &b, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
                throw FaceDetectionRetinaFaceError.imageResizingError
            }
        }
        var contiguousF = [Float](repeating: 0, count: totalCount)
        vDSP_vfltu8(&contiguous, 1, &contiguousF, 1, vDSP_Length(totalCount))
        let minF: Float = -127.5/128.0
        let maxF: Float = 127.5/128.0
        var scale = (maxF - minF) / 255.0
        var offset = minF
        contiguousF.withUnsafeMutableBufferPointer { buf in
            let ptr = buf.baseAddress!
            vDSP_vsmsa(ptr, 1, &scale, &offset, ptr, 1, vDSP_Length(totalCount))
        }
        return (contiguousF, width, height)
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
