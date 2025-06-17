import XCTest
import OHHTTPStubs
import OHHTTPStubsSwift
import VerIDCommonTypes
import FaceRecognitionArcFaceCore
import TestSupport
@testable import FaceRecognitionArcFaceCloud

final class FaceRecognitionArcFaceCloudTests: XCTestCase {
    
    let testResources = TestSupportResources()
    
    override func setUp() {
        super.setUp()
        HTTPStubs.setEnabled(true)
        HTTPStubs.removeAllStubs()
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
        guard let (face, image) = self.testResources.faceAndImageForSubject(subject) else {
            XCTFail("Failed to get face for subject \(subject)")
            return
        }
        let faceRecognition = FaceRecognitionArcFace(apiKey: "", url: URL(string: "http://api.ver-id.com/face_templates")!)
        let templates = try await faceRecognition.createFaceRecognitionTemplates(from: [face], in: image)
        XCTAssertEqual(templates.count, 1)
    }
    
    func testCreateFaceTemplateInCloud() async throws {
        let subject = "subject1-01"
        guard let (face, image) = self.testResources.faceAndImageForSubject(subject) else {
            XCTFail("Failed to get face for subject \(subject)")
            return
        }
        let faceRecognition = try self.createFaceRecognition()
        let templates = try await faceRecognition.createFaceRecognitionTemplates(from: [face], in: image)
        XCTAssertEqual(templates.count, 1)
    }
    
    func testCompareSubjects() async throws {
        let faceRecognition = try self.createFaceRecognition()
        var templates: [FaceTemplate<V24,[Float]>] = []
        for subject in ["subject1-01", "subject1-02", "subject2-01"] {
            guard let (face, image) = self.testResources.faceAndImageForSubject(subject) else {
                throw XCTSkip()
            }
            guard let template = try await faceRecognition.createFaceRecognitionTemplates(from: [face], in: image).first else {
                throw XCTSkip()
            }
            templates.append(template)
        }
        let scoreSame = try await faceRecognition.compareFaceRecognitionTemplates([templates[0]], to: templates[1]).first!
        let scoreDifferent = try await faceRecognition.compareFaceRecognitionTemplates([templates[0]], to: templates[2]).first!
        let threshold: Float = 0.5
        XCTAssertGreaterThanOrEqual(scoreSame, threshold)
        XCTAssertLessThan(scoreDifferent, threshold)
    }
    
    private func createFaceRecognition() throws -> FaceRecognitionArcFace {
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
        return FaceRecognitionArcFace(apiKey: config.apiKey, url: url)
    }
}

fileprivate struct Config: Decodable {
    
    let apiKey: String
    let url: String
    
}
