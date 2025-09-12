//
//  TestSupport.swift
//
//
//  Created by Jakub Dolejs on 16/06/2025.
//

import Foundation
import UIKit
import VerIDCommonTypes
import FaceDetectionRetinaFaceOrt

public class TestSupportResources {
    
    public let faceDetection: FaceDetectionRetinaFaceOrt
    
    public init() throws {
        self.faceDetection = try FaceDetectionRetinaFaceOrt()
    }
    
    public static let bundle: Bundle = .module
    
    public func faceAndImageForSubject(_ subject: String) async throws -> (Face, Image) {
        let image = try await self.imageForSubject(subject)
        let face = try await self.faceInImage(image)
        return (face, image)
    }
    
    public func faceForSubject(_ subject: String) async throws -> Face {
        let image = try await self.imageForSubject(subject)
        guard let face = try await self.faceDetection.detectFacesInImage(image, limit: 1).first else {
            throw TestSupportError("Failed to detect a face in image \(subject).jpg")
        }
        return face
    }
    
    public func imageForSubject(_ subject: String) async throws -> Image {
        guard let url = Bundle.module.url(forResource: subject, withExtension: "jpg") else {
            throw TestSupportError("Failed to get a URL for \(subject).jpg")
        }
        let data = try Data(contentsOf: url)
        guard let uiImage = UIImage(data: data) else {
            throw TestSupportError("Failed to decode image data")
        }
        let orientation: CGImagePropertyOrientation
        switch uiImage.imageOrientation {
        case .up:
            orientation = .up
        case .down:
            orientation = .down
        case .left:
            orientation = .left
        case .right:
            orientation = .right
        case .upMirrored:
            orientation = .upMirrored
        case .downMirrored:
            orientation = .downMirrored
        case .leftMirrored:
            orientation = .leftMirrored
        case .rightMirrored:
            orientation = .rightMirrored
        default:
            orientation = .up
        }
        guard let cgImage = uiImage.cgImage else {
            throw TestSupportError("Failed to convert image to CGImage")
        }
        guard let image = Image(cgImage: cgImage, orientation: orientation) else {
            throw TestSupportError("Failed to convert CGImage to Ver-ID image")
        }
        return image
    }
    
    public func faceTemplateForSubject(_ subject: String) -> [Float]? {
        guard let url = Bundle.module.url(forResource: "\(subject)-aligned.png-template", withExtension: "json") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        guard let faceTemplate = try? JSONDecoder().decode([Float].self, from: data) else {
            return nil
        }
        return faceTemplate
    }
    
    public func faceInImage(_ image: Image) async throws -> Face {
        guard let face = try await self.faceDetection.detectFacesInImage(image, limit: 1).first else {
            throw TestSupportError("Failed to detect a face in image")
        }
        return face
    }
}
