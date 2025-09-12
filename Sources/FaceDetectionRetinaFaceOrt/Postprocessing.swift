//
//  Postprocessing.swift
//
//
//  Created by Jakub Dolejs on 07/07/2025.
//

import Foundation
import CoreGraphics
import VerIDCommonTypes
import Accelerate
import OnnxRuntimeBindings

@_spi(Testing) public struct Postprocessing {
    
    let inputWidth: Int
    let inputHeight: Int
    let strides: [Int] = [8, 16, 32]
    let numAnchors: Int = 2
    let scoreThreshold: Float = 0.3
    
    @_spi(Testing) public init(inputWidth: Int, inputHeight: Int) {
        self.inputWidth = inputWidth
        self.inputHeight = inputHeight
    }
    
    @_spi(Testing) public func decode(scores: [ORTValue], boxes: [ORTValue], landmarks: [ORTValue]) throws -> [DetectionBox] {
        precondition(scores.count == 3 && boxes.count == 3 && landmarks.count == 3, "Expect 3 heads per output")
        
        var detections: [DetectionBox] = []
        detections.reserveCapacity(4000)
        
        for i in 0..<strides.count {
            let stride = strides[i]
            let h = inputHeight / stride
            let w = inputWidth / stride
            let k = h * w * numAnchors
            
            let scoreArray = try floatArray(from: scores[i])          // [k]
            let boxArray = try floatArray(from: boxes[i])             // [k*4]
            let landmarkArray = try floatArray(from: landmarks[i])    // [k*10]
            
            precondition(scoreArray.count == k, "scores[\(i)] count \(scoreArray.count) != \(k)")
            precondition(boxArray.count == k * 4, "boxes[\(i)] count \(boxArray.count) != \(k*4)")
            precondition(landmarkArray.count == k * 10, "landmarks[\(i)] count \(landmarkArray.count) != \(k*10)")
            
            let centers = anchorCenters(height: h, width: w, stride: stride, numAnchors: numAnchors)
            
            // gather indices above threshold
            var kept: [Int] = []
            kept.reserveCapacity(1024)
            for idx in 0..<k where scoreArray[idx] >= scoreThreshold { kept.append(idx) }
            if kept.isEmpty { continue }
            
            // decode distances -> boxes (+ landmarks) in pixel space
            let s = Float(stride)
            for idx in kept {
                let d0 = boxArray[idx*4 + 0] * s
                let d1 = boxArray[idx*4 + 1] * s
                let d2 = boxArray[idx*4 + 2] * s
                let d3 = boxArray[idx*4 + 3] * s
                
                let c = centers[idx]
                let x1 = max(0, c.x - d0)
                let y1 = max(0, c.y - d1)
                let x2 = min(Float(inputWidth),  c.x + d2)
                let y2 = min(Float(inputHeight), c.y + d3)
                
                let rect = CGRect(x: CGFloat(x1),
                                  y: CGFloat(y1),
                                  width:  CGFloat(max(0, x2 - x1)),
                                  height: CGFloat(max(0, y2 - y1)))
                
                var points: [CGPoint] = []
                points.reserveCapacity(5)
                for p in 0..<5 {
                    let lx = landmarkArray[idx*10 + 2*p + 0] * s + c.x
                    let ly = landmarkArray[idx*10 + 2*p + 1] * s + c.y
                    points.append(CGPoint(x: CGFloat(lx), y: CGFloat(ly)))
                }
                
                detections.append(DetectionBox(
                    score: scoreArray[idx],
                    bounds: rect,
                    landmarks: points,
                    angle: EulerAngle(),
                    quality: scoreArray[idx]
                ))
            }
        }
        
        return detections
    }
    
    @_spi(Testing) func nonMaxSuppression(boxes: [DetectionBox], iouThreshold: Float, limit: Int) -> [DetectionBox] {
        var selected: [DetectionBox] = []
        let sorted = boxes.sorted(by: { $0.score > $1.score })
        
        for box in sorted {
            if selected.count >= limit { break }
            if selected.allSatisfy({ iou($0.bounds, box.bounds) < CGFloat(iouThreshold) }) {
                selected.append(box)
            }
        }
        
        return selected
    }
    
    @_spi(Testing) func calculateFaceAngle(leftEye: CGPoint, rightEye: CGPoint, noseTip: CGPoint, leftMouth: CGPoint, rightMouth: CGPoint) -> EulerAngle<Float> {
        let dx = rightEye.x - leftEye.x
        let dy = rightEye.y - leftEye.y
        let roll = atan2(dy, dx).degrees
        
        let eyeCenter = CGPoint(x: (leftEye.x + rightEye.x) / 2, y: (leftEye.y + rightEye.y) / 2)
        let mouthCenter = CGPoint(x: (leftMouth.x + rightMouth.x) / 2, y: (leftMouth.y + rightMouth.y) / 2)
        
        let interocular = rightEye.x - leftEye.x
        let noseOffset = noseTip.x - eyeCenter.x
        let yaw = atan2(noseOffset, interocular).degrees * 1.2
        
        let verticalFaceLength = mouthCenter.y - eyeCenter.y
        let verticalNoseOffset = noseTip.y - eyeCenter.y
        let pitchRatio = verticalNoseOffset / verticalFaceLength
        let pitch = (0.5 - pitchRatio) * 90
        
        return EulerAngle(yaw: yaw.asFloat, pitch: 0 - pitch.asFloat, roll: roll.asFloat)
    }
    
    // MARK: - Helpers
    
    private func anchorCenters(height: Int, width: Int, stride: Int, numAnchors: Int) -> [SIMD2<Float>] {
        var out = [SIMD2<Float>]()
        out.reserveCapacity(height * width * numAnchors)
        for i in 0..<height {
            let cy = Float(i * stride)
            for j in 0..<width {
                let cx = Float(j * stride)
                if numAnchors == 1 {
                    out.append(SIMD2<Float>(cx, cy))
                } else {
                    for _ in 0..<numAnchors {
                        out.append(SIMD2<Float>(cx, cy))
                    }
                }
            }
        }
        return out
    }
    
    private func floatArray(from value: ORTValue) throws -> [Float] {
        let data = try value.tensorData() as Data
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
    
    private func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let inter = a.intersection(b)
        let interArea = inter.width * inter.height
        guard interArea > 0, interArea > CGFloat.ulpOfOne else { return 0 }
        let union = a.width * a.height + b.width * b.height - interArea
        return interArea / union
    }
}

@_spi(Testing) public struct DetectionBox: Encodable {
    @_spi(Testing) public let score: Float
    @_spi(Testing) public let bounds: CGRect
    @_spi(Testing) public let landmarks: [CGPoint]
    @_spi(Testing) public let angle: EulerAngle<Float>
    @_spi(Testing) public let quality: Float
    
    enum CodingKeys: CodingKey {
        case bounds, landmarks
    }
    
    enum BoundsCodingKeys: CodingKey {
        case x, y, width, height
    }
    
    @_spi(Testing) public func applyingTransform(_ transform: CGAffineTransform) -> DetectionBox {
        return DetectionBox(score: self.score, bounds: self.bounds.applying(transform), landmarks: self.landmarks.map { $0.applying(transform) }, angle: self.angle, quality: self.quality)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var boundsContainer = container.nestedContainer(keyedBy: BoundsCodingKeys.self, forKey: .bounds)
        try boundsContainer.encode(self.bounds.minX, forKey: .x)
        try boundsContainer.encode(self.bounds.minY, forKey: .y)
        try boundsContainer.encode(self.bounds.width, forKey: .width)
        try boundsContainer.encode(self.bounds.height, forKey: .height)
        try container.encode(self.landmarks.map({ EncodablePoint(point: $0) }), forKey: .landmarks)
    }
}

fileprivate struct EncodablePoint: Encodable {
    let x: CGFloat
    let y: CGFloat
    init(point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
}

fileprivate struct Priors {
    let minSizes: [[Int]]
    let steps: [Int]
    let clip: Bool
    let imageWidth: Int
    let imageHeight: Int
    
    func generate() -> [[Float]] {
        var anchors: [[Float]] = [
            [Float](),[Float](),[Float](),[Float]()
        ]
        
        for (k, step) in steps.enumerated() {
            let minSizesForStep = minSizes[k]
            let featureMapHeight = Int(ceil(Float(imageHeight) / Float(step)))
            let featureMapWidth = Int(ceil(Float(imageWidth) / Float(step)))
            
            for i in 0..<featureMapHeight {
                for j in 0..<featureMapWidth {
                    for minSize in minSizesForStep {
                        let s_kx = Float(minSize) / Float(imageWidth)
                        let s_ky = Float(minSize) / Float(imageHeight)
                        let cx = (Float(j) + 0.5) * Float(step) / Float(imageWidth)
                        let cy = (Float(i) + 0.5) * Float(step) / Float(imageHeight)
                        
                        var anchor: [Float] = [cx, cy, s_kx, s_ky]
                        if clip {
                            anchor = anchor.map { max(0, min(1, $0)) }
                        }
                        anchors[0].append(cx)
                        anchors[1].append(cy)
                        anchors[2].append(s_kx)
                        anchors[3].append(s_ky)
                    }
                }
            }
        }
        
        return anchors
    }
}

fileprivate extension CGFloat {
    
    var asFloat: Float {
        return Float(self)
    }
    
    var degrees: CGFloat {
        return self * 180 / .pi
    }
}

fileprivate extension Float {
    
    var degrees: Float {
        return self * 180 / .pi
    }
}
