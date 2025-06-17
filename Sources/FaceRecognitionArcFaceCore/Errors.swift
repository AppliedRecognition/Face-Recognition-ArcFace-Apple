//
//  Errors.swift
//
//
//  Created by Jakub Dolejs on 16/06/2025.
//

import Foundation

public enum FaceRecognitionError: LocalizedError {
    case faceTemplateExtractionFailed
    
    public var errorDescription: String? {
        switch self {
        case .faceTemplateExtractionFailed:
            return NSLocalizedString("Face template extraction failed", comment: "")
        }
    }
}
