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

open class FaceRecognitionArcFaceCore: FaceRecognition {
    public typealias Version = V24
    public typealias TemplateData = [Float]
    
    public init() throws {
        guard type(of: self) != FaceRecognitionArcFaceCore.self else {
            fatalError("Abstract base class called its initialiser")
        }
    }
    
    public func createFaceRecognitionTemplates(from faces: [Face], in image: Image) async throws -> [FaceTemplate<V24,[Float]>] {
        let alignedFaces = try faces.map { face in
            try FaceAlignment.alignFace(face, image: image)
        }
        return try await self.createFaceRecognitionTemplatesFromAlignedFaces(alignedFaces)
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
            return dotProduct / (challengeNorm * templateNorm)
        }
    }
    
    private func norm(_ template: [Float]) -> Float {
        let n = vDSP_Length(template.count)
        var norm: Float = 0.0
        vDSP_svesq(template, 1, &norm, n)
        return sqrt(norm)
    }
}
