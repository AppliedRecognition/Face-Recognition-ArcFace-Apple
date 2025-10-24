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
        let image = try self.imageForSubject(subject)
        let face = try await self.faceInImage(image)
        return (face, image)
    }
    
    public func faceForSubject(_ subject: String) async throws -> Face {
        let image = try self.imageForSubject(subject)
        guard let face = try await self.faceDetection.detectFacesInImage(image, limit: 1).first else {
            throw TestSupportError("Failed to detect a face in image \(subject).jpg")
        }
        return face
    }
    
    public func imageForSubject(_ subject: String) throws -> Image {
        return try autoreleasepool {
            guard let url = Bundle.module.url(forResource: subject, withExtension: "jpg") else {
                throw TestSupportError("Failed to get a URL for \(subject).jpg")
            }
            let data = try Data(contentsOf: url)
            guard let uiImage = UIImage(data: data) else {
                throw TestSupportError("Failed to decode image data")
            }
            guard let image = Image(uiImage: uiImage) else {
                throw TestSupportError("Failed to convert UIImage to Image")
            }
            return image
        }
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
