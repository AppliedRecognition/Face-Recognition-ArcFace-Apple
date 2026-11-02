//
//  Errors.swift
//
//
//  Created by Jakub Dolejs on 16/06/2025.
//

import Foundation

/// Errors raised by face recognition and face alignment.
///
/// Moved here with ``FaceAlignment`` so that the alignment target has no face
/// detection dependency, and so that the errors alignment throws keep their
/// existing names for callers.
public enum FaceRecognitionError: LocalizedError {
    case faceTemplateExtractionFailed
    case imageEncodingFailure
    case imageConversionFailure
    case faceMissingNoseTipLandmark
    case faceMissingMouthLandmarks
    case faceAlignmentFailure
    case faceDetectionFailure

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
        case .faceDetectionFailure:
            return NSLocalizedString("Face detection failed", comment: "")
        }
    }
}
