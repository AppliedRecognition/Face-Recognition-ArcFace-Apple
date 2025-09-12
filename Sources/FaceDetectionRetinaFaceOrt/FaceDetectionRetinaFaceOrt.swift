// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Vision
import Accelerate
import VerIDCommonTypes
import UIKit
import OnnxRuntimeBindings

/// Face detection implementation using RetinaFace model
public final class FaceDetectionRetinaFaceOrt: FaceDetection {
    private let inputSize = CGSize(width: 640, height: 640)
    private let modelInputPrep = Preprocessing()
    private let postProcessing: Postprocessing
    private let session: ORTSession
    
    /// Initializer
    /// - Throws: Exception of ML model initialization fails
    public init() throws {
        let env = try ORTEnv(loggingLevel: .error)
        guard let modelPath = Bundle.module.path(forResource: "det_500m", ofType: "onnx") else {
            throw FaceDetectionRetinaFaceError.modelNotFound("det_500m.onnx")
        }
        let sessionOptions = try ORTSessionOptions()
        let coreMLOptions = ORTCoreMLExecutionProviderOptions()
        /**
         Leave options default if: you just want it to work, minimal code, broad device support, dynamic shapes, or you haven’t profiled yet.
         Set useCPUOnly = true only for debugging or to compare CoreML vs CPU performance/stability.
         Set useCPUAndGPU = true if you see CoreML skipping ANE and you still want GPU usage; measure if it actually helps—sometimes it doesn’t.
         Set onlyEnableForDevicesWithANE = true if you’d rather skip CoreML entirely on non-ANE devices (to avoid marginal GPU wins); expect big perf drop on those devices (CPU fallback).
         Set onlyAllowStaticInputShapes = true only if your inputs are fixed and you want to bias CoreML to compile/optimize aggressively. If your shapes vary, this will bite you.
         Set createMLProgram = true if you’ve tested that your model runs faster/more completely via ML Program on your device set. It can help, but isn’t universally better.
         */
        do {
            try sessionOptions.appendCoreMLExecutionProvider(with: coreMLOptions)
        } catch {
            NSLog("Using ONNX Runtime without CoreML execution provider")
        }
        self.postProcessing = Postprocessing(inputWidth: Int(self.inputSize.width), inputHeight: Int(self.inputSize.height))
        self.session = try ORTSession(env: env, modelPath: modelPath, sessionOptions: sessionOptions)
    }
    
    /// Detect faces in image
    /// - Parameters:
    ///   - image: Image in which to detect faces
    ///   - limit: Maximum number of faces to detect
    /// - Returns: Array of detected faces
    public func detectFacesInImage(_ image: Image, limit: Int) async throws -> [Face] {
        let (input, scale) = try self.modelInputPrep.ortTensorFromPixelBuffer(image.videoBuffer, scaledToSize: self.inputSize)
        let output = try self.session.run(withInputs: ["input.1": input], outputNames: ["443", "468", "493", "446", "471", "496", "449", "474", "499"], runOptions: nil)
        guard let scores32 = output["493"], let scores16 = output["468"], let scores8 = output["443"] else {
            throw FaceDetectionRetinaFaceError.postProcessingError
        }
        guard let boxes32 = output["496"], let boxes16 = output["471"], let boxes8 = output["446"] else {
            throw FaceDetectionRetinaFaceError.postProcessingError
        }
        guard let landmarks32 = output["499"], let landmarks16 = output["474"], let landmarks8 = output["449"] else {
            throw FaceDetectionRetinaFaceError.postProcessingError
        }
        var boxes = try self.postProcessing.decode(scores: [scores8, scores16, scores32], boxes: [boxes8, boxes16, boxes32], landmarks: [landmarks8, landmarks16, landmarks32])
        boxes = self.postProcessing.nonMaxSuppression(boxes: boxes, iouThreshold: 0.4, limit: limit)
        let transform = CGAffineTransform(scaleX: 1 / scale, y: 1 / scale)
        boxes = boxes.map { $0.applyingTransform(transform) }
        let faces = boxes.map {
            let angle = postProcessing.calculateFaceAngle(leftEye: $0.landmarks[0], rightEye: $0.landmarks[1], noseTip: $0.landmarks[2], leftMouth: $0.landmarks[3], rightMouth: $0.landmarks[4])
            return Face(
                bounds: $0.bounds,
                angle: angle,
                quality: $0.quality,
                landmarks: $0.landmarks,
                leftEye: $0.landmarks[0],
                rightEye: $0.landmarks[1],
                noseTip: $0.landmarks[2],
                mouthLeftCorner: $0.landmarks[3],
                mouthRightCorner: $0.landmarks[4]
            )
        }
        return Array(faces.prefix(limit))
    }
}
