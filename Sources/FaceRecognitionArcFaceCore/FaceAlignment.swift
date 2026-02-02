//
//  Alignment.swift
//
//
//  Created by Jakub Dolejs on 18/03/2025.
//

import Foundation
import Accelerate
import UIKit
import VerIDCommonTypes

class LinearRegression {
    private var data: [[Double]] = []
    private var results: [Double] = []
    
    func add(result: Double, x: Double, y: Double, a: Double, b: Double) {
        data.append([x, y, a, b])
        results.append(result)
    }
    
    func compute() -> [Double] {
        let rowCount = data.count
        let colCount = 4
        
        guard rowCount >= colCount else {
            return [] // Least squares needs at least as many rows as columns
        }
        
        // Convert to a column-major order matrix (LAPACK expects this)
        var A = [Double](repeating: 0.0, count: rowCount * colCount)
        for row in 0..<rowCount {
            for col in 0..<colCount {
                A[col * rowCount + row] = data[row][col] // Transpose manually
            }
        }
        
        var B = results
        var singularValues = [Double](repeating: 0.0, count: colCount)
        var workSize: Int32 = -1
        var info: Int32 = 0
        
        var m = __CLPK_integer(rowCount)
        var n = __CLPK_integer(colCount)
        var nrhs = __CLPK_integer(1)
        var lda = m
        var ldb = m
        var rank: __CLPK_integer = 0
        var rcond: Double = -1.0 // Default threshold
        
        var queryWork = [Double](repeating: 0.0, count: 1)
        var iwork = [__CLPK_integer](repeating: 0, count: 8 * colCount)
        
        // Query optimal workspace size
        dgelsd_(&m, &n, &nrhs, &A, &lda, &B, &ldb, &singularValues, &rcond, &rank, &queryWork, &workSize, &iwork, &info)
        
        workSize = Int32(queryWork[0])
        var work = [Double](repeating: 0.0, count: Int(workSize))
        
        // Solve least squares problem
        dgelsd_(&m, &n, &nrhs, &A, &lda, &B, &ldb, &singularValues, &rcond, &rank, &work, &workSize, &iwork, &info)
        
        return info == 0 ? Array(B.prefix(colCount)) : []
    }
}


struct RotatedBox {
    let center: CGPoint
    let angle: Double
    let width: Double
    let height: Double
}

@_spi(Testing)
public class FaceAlignment {
    
    private init() {}
    
    @_spi(Testing) public static func alignFace(_ face: Face, image: Image, scale: Double = 2.85, verticalOffset: Double = 0.4) throws -> UIImage {
        guard let noseTip = face.noseTip else {
            throw FaceRecognitionError.faceMissingNoseTipLandmark
        }
        var landmarks: [CGPoint] = [
            face.leftEye,
            face.rightEye,
            noseTip
        ]
        if let mouthLeftCorner = face.mouthLeftCorner, let mouthRightCorner = face.mouthRightCorner {
            landmarks.append(mouthLeftCorner)
            landmarks.append(mouthRightCorner)
        } else if let mouthCentre = face.mouthCentre {
            landmarks.append(mouthCentre)
        } else {
            throw FaceRecognitionError.faceMissingMouthLandmarks
        }
        let alignedBox = try FaceAlignment.alignFace(pts: landmarks, scale: scale, verticalOffset: verticalOffset)
        return try FaceAlignment.cropFace(in: image, to: alignedBox)
    }
    
    static func alignFace(pts: [CGPoint], scale: Double = 2.85, verticalOffset: Double = 0.4) throws -> RotatedBox {
        let reg = LinearRegression()
        
        let y0 = verticalOffset - 0.5
        let y1 = verticalOffset + 0.04
        let y2 = verticalOffset + 0.5
        
        reg.add(result: pts[0].x, x: -0.46, y: -y0, a: 1.0, b: 0.0)
        reg.add(result: pts[0].y, x: y0, y: -0.46, a: 0.0, b: 1.0)
        
        reg.add(result: pts[1].x, x: 0.46, y: -y0, a: 1.0, b: 0.0)
        reg.add(result: pts[1].y, x: y0, y: 0.46, a: 0.0, b: 1.0)
        
        reg.add(result: pts[2].x, x: 0.0, y: -y1, a: 1.0, b: 0.0)
        reg.add(result: pts[2].y, x: y1, y: 0.0, a: 0.0, b: 1.0)
        
        if pts.count == 4 {
            reg.add(result: pts[3].x, x: 0.0, y: -y2, a: 1.0, b: 0.0)
            reg.add(result: pts[3].y, x: y2, y: 0.0, a: 0.0, b: 1.0)
        } else {
            reg.add(result: pts[3].x, x: -0.39, y: -y2, a: 1.0, b: 0.0)
            reg.add(result: pts[3].y, x: y2, y: -0.39, a: 0.0, b: 1.0)
            
            reg.add(result: pts[4].x, x: 0.39, y: -y2, a: 1.0, b: 0.0)
            reg.add(result: pts[4].y, x: y2, y: 0.39, a: 0.0, b: 1.0)
        }
        
        let c = reg.compute()
        guard c.count == 4 else {
            throw FaceRecognitionError.faceAlignmentFailure
        }
        
        let centerX = c[2]
        let centerY = c[3]
        let angle = atan2(c[1], c[0])
        let widthHeight = scale * sqrt(c[0] * c[0] + c[1] * c[1])
        
        return RotatedBox(center: CGPoint(x: centerX, y: centerY), angle: angle, width: widthHeight, height: widthHeight)
    }
    
    private static func cropFace(in image: Image, to rotatedBox: RotatedBox, targetSize: CGSize = CGSize(width: 112, height: 112)) throws -> UIImage {
        return try autoreleasepool {
            guard let uiImage = image.toUIImage() else {
                throw FaceRecognitionError.imageConversionFailure
            }
            let scale = targetSize.width / rotatedBox.width
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            return UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
                let cgContext = context.cgContext
                cgContext.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
                cgContext.rotate(by: -rotatedBox.angle)
                cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
                cgContext.translateBy(x: -rotatedBox.center.x, y: -rotatedBox.center.y)
                uiImage.draw(at: .zero)
            }
        }
    }
}
