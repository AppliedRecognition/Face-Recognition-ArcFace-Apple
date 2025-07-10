//
//  Errors.swift
//
//
//  Created by Jakub Dolejs on 16/06/2025.
//

import Foundation

public enum FaceRecognitionError: LocalizedError {
    case faceTemplateExtractionFailed
    case imageEncodingFailure
    case imageConversionFailure
    case faceMissingNoseTipLandmark
    case faceMissingMouthLandmarks
    case faceAlignmentFailure
    
    public var errorDescription: String? {
        switch self {
        case .faceTemplateExtractionFailed:
            return NSLocalizedString("Face template extraction failed", comment: "")
        case .imageEncodingFailure:
            return NSLocalizedString("Image encoding failed", comment: "")
        case .imageConversionFailure:
            return NSLocalizedString("Image conversion failed", comment: "")
        case .faceMissingNoseTipLandmark:
            return NSLocalizedString("Input face is missing a nose tip landmark", comment: "")
        case .faceMissingMouthLandmarks:
            return NSLocalizedString("Input face is missing mouth landmarks", comment: "")
        case .faceAlignmentFailure:
            return NSLocalizedString("Face alignment failed", comment: "")
        }
    }
}
