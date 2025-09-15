//
//  Errors.swift
//
//
//  Created by Jakub Dolejs on 09/07/2025.
//

import Foundation

public enum FaceDetectionRetinaFaceError: LocalizedError {
    case missingExpectedModelOutputs
    case imageResizingError
    case modelNotFound(String)
    case postProcessingError
    
    public var errorDescription: String? {
        switch self {
        case .missingExpectedModelOutputs:
            return NSLocalizedString("Missing expected model outputs", comment: "")
        case .imageResizingError:
            return NSLocalizedString("Failed to resize input image", comment: "")
        case .modelNotFound(let name):
            return NSLocalizedString("Model file \(name) not found", comment: "")
        case .postProcessingError:
            return NSLocalizedString("Model output post-processing failed", comment: "")
        }
    }
}
