//
//  FaceRecognitionArcFaceCore.swift
//
//
//  Created by Jakub Dolejs on 09/06/2025.
//

import Foundation
import VerIDCommonTypes
import UIKit
import Accelerate
import FaceDetectionRetinaFaceOrt

open class FaceRecognitionArcFaceCore: FaceRecognition {

    public var defaultThreshold: Float = 0.8
    
    public typealias Version = V24
    public typealias TemplateData = [Float]
    
    let faceDetection: FaceDetectionRetinaFaceOrt
    
    public init() throws {
        guard type(of: self) != FaceRecognitionArcFaceCore.self else {
            fatalError("Abstract base class called its initialiser")
        }
        self.faceDetection = try FaceDetectionRetinaFaceOrt()
    }
    
    public func createFaceRecognitionTemplates(from faces: [Face], in image: Image) async throws -> [FaceTemplate<V24,[Float]>] {
        let refinedFaces = try await self.refineFaces(faces, inImage: image)
        let alignedFaces = try refinedFaces.map { face in
            try FaceAlignment.alignFace(face, image: image)
        }
        let templates = try await self.createFaceRecognitionTemplatesFromAlignedFaces(alignedFaces)
        return templates.map { template in
            var data = template.data
            self.normalize(&data)
            return FaceTemplate(data: data)
        }
    }
    
    open func createFaceRecognitionTemplatesFromAlignedFaces(_ alignedFaces: [UIImage]) async throws -> [FaceTemplate<V24,[Float]>] {
        fatalError("Method not implemented")
    }
    
    public func compareFaceRecognitionTemplates(_ faceRecognitionTemplates: [FaceTemplate<V24,[Float]>], to template: FaceTemplate<V24,[Float]>) async throws -> [Float] {
        let challengeNorm: Float = self.norm(template.data)
        let n = vDSP_Length(template.data.count)
        return faceRecognitionTemplates.map { t in
            var dotProduct: Float = 0.0
            vDSP_dotpr(template.data, 1, t.data, 1, &dotProduct, n)
            let templateNorm = self.norm(t.data)
            let cosine = dotProduct / (challengeNorm * templateNorm)
            let similarity = (cosine + 1.0) * 0.5
            return min(max(similarity, 0.0), 1.0)
        }
    }
    
    private func norm(_ template: [Float]) -> Float {
        let n = vDSP_Length(template.count)
        var norm: Float = 0.0
        vDSP_svesq(template, 1, &norm, n)
        return sqrt(norm)
    }
    
    @_spi(Testing) public func normalize(_ x: inout [Float]) {
        let n = norm(x)
        if n > 0 {
            let inv = 1/n
            vDSP_vsmul(x, 1, [inv], &x, 1, vDSP_Length(x.count))
        }
    }
    
    @_spi(Testing) public func refineFaces(_ faces: [Face], inImage image: Image) async throws -> [Face] {
        let detectedFaces = try await self.faceDetection.detectFacesInImage(image, limit: faces.count)
        guard detectedFaces.count == faces.count else {
            throw FaceRecognitionError.faceDetectionFailure
        }
        let refinedFaces: [Face] = faces.compactMap { originalFace in
            return detectedFaces.min { a, b in
                return a.eyeCentre.distance(to: originalFace.eyeCentre) < b.eyeCentre.distance(to: originalFace.eyeCentre)
            }
        }
        guard refinedFaces.count == faces.count else {
            throw FaceRecognitionError.faceDetectionFailure
        }
        return refinedFaces
    }
}

fileprivate extension CGPoint {
    
    func distance(to other: CGPoint) -> CGFloat {
        return hypot(other.y - self.y, other.x - self.x)
    }
}

fileprivate extension Face {
    
    var eyeCentre: CGPoint {
        CGPoint(x: (self.rightEye.x + self.leftEye.x) * 0.5, y: (self.rightEye.y + self.leftEye.y) * 0.5)
    }
}
