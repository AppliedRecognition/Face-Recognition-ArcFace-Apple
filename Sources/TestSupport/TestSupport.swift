//
//  TestSupport.swift
//
//
//  Created by Jakub Dolejs on 16/06/2025.
//

import Foundation
import UIKit
import VerIDCommonTypes

public class TestSupportResources {
    
    public init() {}
    
    public static let bundle: Bundle = .module
    
    public func faceAndImageForSubject(_ subject: String) -> (Face, Image)? {
        guard let face = self.faceForSubject(subject) else {
            return nil
        }
        guard let image = self.imageForSubject(subject) else {
            return nil
        }
        return (face, image)
    }
    
    public func faceForSubject(_ subject: String) -> Face? {
        guard let url = Bundle.module.url(forResource: subject, withExtension: "json") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        guard let face = try? JSONDecoder().decode(Face.self, from: data) else {
            return nil
        }
        return face
    }
    
    public func imageForSubject(_ subject: String) -> Image? {
        guard let url = Bundle.module.url(forResource: subject, withExtension: "jpg") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        guard let cgImage = UIImage(data: data)?.cgImage else {
            return nil
        }
        return Image(cgImage: cgImage)
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
    
}
