import XCTest
import OHHTTPStubs
import OHHTTPStubsSwift
import VerIDCommonTypes
import FaceRecognitionArcFaceCore
import TestSupport
import UniformTypeIdentifiers
import FaceDetectionRetinaFaceOrt
@testable import FaceRecognitionArcFaceCloud

final class FaceRecognitionArcFaceCloudTests: XCTestCase {
    
    var testResources: TestSupportResources!
    var recognition: FaceRecognitionArcFace!
    var faceDetection: FaceDetectionRetinaFaceOrt!
    
    override func setUp() async throws {
        try await super.setUp()
        HTTPStubs.setEnabled(true)
        HTTPStubs.removeAllStubs()
        self.testResources = try await TestSupportResources()
        self.recognition = try await self.createFaceRecognition()
        self.faceDetection = try await FaceDetectionRetinaFaceOrt()
    }
    
    override func tearDown() {
        super.tearDown()
        HTTPStubs.removeAllStubs()
        HTTPStubs.setEnabled(false)
    }
    
    func testCreateFaceTemplate() async throws {
        let subject = "subject1-01"
        stub(condition: isPath("/face_templates") && isMethodPOST()) { _ in
            guard let faceTemplateData = self.testResources.faceTemplateForSubject(subject) else {
                return HTTPStubsResponse(data: Data(), statusCode: 500, headers: nil)
            }
            let faceTemplate = FaceTemplate<V24,[Float]>(data: faceTemplateData)
            do {
                let data = try JSONEncoder().encode([faceTemplate])
                return HTTPStubsResponse(data: data, statusCode: 200, headers: nil)
            } catch {
                return HTTPStubsResponse(error: error)
            }
        }
        let (face, image) = try await self.testResources.faceAndImageForSubject(subject)
        let faceRecognition = await FaceRecognitionArcFace(apiKey: "", url: URL(string: "http://api.ver-id.com/face_templates")!)
        let templates = try await faceRecognition.createFaceRecognitionTemplates(from: [face], in: image)
        XCTAssertEqual(templates.count, 1)
    }
    
    func testCreateFaceTemplateInCloud() async throws {
        let subject = "subject1-01"
        let (face, image) = try await self.testResources.faceAndImageForSubject(subject)
        let faceRecognition = try await self.createFaceRecognition()
        let templates = try await faceRecognition.createFaceRecognitionTemplates(from: [face], in: image)
        XCTAssertEqual(templates.count, 1)
    }
    
    func testCompareSubjects() async throws {
        let faceRecognition = try await self.createFaceRecognition()
        var templates: [FaceTemplate<V24,[Float]>] = []
        for subject in ["subject1-01", "subject1-02", "subject2-01"] {
            let (face, image) = try await self.testResources.faceAndImageForSubject(subject)
            guard let template = try await faceRecognition.createFaceRecognitionTemplates(from: [face], in: image).first else {
                throw XCTSkip()
            }
            templates.append(template)
        }
        let scoreSame = try await faceRecognition.compareFaceRecognitionTemplates([templates[0]], to: templates[1]).first!
        let scoreDifferent = try await faceRecognition.compareFaceRecognitionTemplates([templates[0]], to: templates[2]).first!
        let threshold: Float = faceRecognition.defaultThreshold
        XCTAssertGreaterThanOrEqual(scoreSame, threshold)
        XCTAssertLessThan(scoreDifferent, threshold)
    }
    
    private func createFaceRecognition() async throws -> FaceRecognitionArcFace {
        guard let configUrl = Bundle.module.url(forResource: "config", withExtension: "json") else {
            throw XCTSkip()
        }
        guard let configData = try? Data(contentsOf: configUrl) else {
            throw XCTSkip()
        }
        guard let config = try? JSONDecoder().decode(Config.self, from: configData) else {
            throw XCTSkip()
        }
        guard let url = URL(string: config.url) else {
            throw XCTSkip()
        }
        return await FaceRecognitionArcFace(apiKey: config.apiKey, url: url)
    }
    
    private func image(_ image: Image, croppedToFace face: CGRect) -> UIImage {
        let uiImage = UIImage(cgImage: image.toCGImage()!)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: face.size, format: format).image { context in
            uiImage.draw(at: CGPoint(x: 0-face.minX, y: 0-face.minY))
        }
    }
    
    private func imageAndFaceFromResource(_ resource: String) async throws -> ImageFacePackage {
        guard let url = Bundle.module.url(forResource: resource, withExtension: nil) else {
            throw TestError("Failed to get resource \(resource)")
        }
        guard let imageData = try? Data(contentsOf: url) else {
            throw TestError("Failed to read image from \(url)")
        }
        guard let uiImage = UIImage(data: imageData), let cgImage = uiImage.cgImage else {
            throw TestError("Failed to convert image")
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
        guard let image = Image(cgImage: cgImage, orientation: orientation) else {
            throw TestError("Failed to decode image from CGImage")
        }
        guard let face = try await self.faceDetection.detectFacesInImage(image, limit: 1).first else {
            throw TestError("Failed to detect face in image \(url)")
        }
        let faceImage = self.image(image, croppedToFace: face.bounds)
        let width: CGFloat = 100
        let height = width / faceImage.size.width * faceImage.size.height
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let scaledFaceImage = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            faceImage.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let template = try await self.recognition.createFaceRecognitionTemplates(from: [face], in: image).first else {
            throw TestError("Face template extraction failed")
        }
        return ImageFacePackage(template: template, faceImage: scaledFaceImage)
    }
}

fileprivate struct Config: Decodable {
    
    let apiKey: String
    let url: String
    
}

fileprivate struct ImageFacePackage {
    
    let template: FaceTemplate<V24, [Float]>
    let faceImage: UIImage
}

fileprivate struct TestError: LocalizedError {
    
    private let desc: String
    
    init(_ errorDescription: String) {
        self.desc = errorDescription
    }
    
    var errorDescription: String? {
        self.desc
    }
}
