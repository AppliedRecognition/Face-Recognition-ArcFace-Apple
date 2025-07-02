// The Swift Programming Language
// https://docs.swift.org/swift-book

import VerIDCommonTypes
import FaceRecognitionArcFaceCore
import UIKit

public class FaceRecognitionArcFace: FaceRecognitionArcFaceCore {
    
    let apiKey: String
    let url: URL
    
    public init(apiKey: String, url: URL) {
        self.apiKey = apiKey
        self.url = url
        try! super.init()
    }
    
    public override func createFaceRecognitionTemplatesFromAlignedFaces(_ alignedFaces: [UIImage]) async throws -> [FaceTemplate<V24,[Float]>] {
        let body = try self.requestBodyFromFaceImages(alignedFaces)
        var request = URLRequest(url: self.url)
        request.httpMethod = "POST"
        request.addValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode < 400 else {
            throw FaceRecognitionError.faceTemplateExtractionFailed
        }
        return try JSONDecoder().decode([FaceTemplate<V24,[Float]>].self, from: data)
    }
    
    private func requestBodyFromFaceImages(_ images: [UIImage]) throws -> Data {
        let encodedImages = try images.map { image in
            guard let jpeg = image.jpegData(compressionQuality: 1.0) else {
                throw FaceRecognitionError.imageEncodingFailure
            }
            return jpeg
        }
        return try JSONEncoder().encode(RequestBody(images: encodedImages))
    }
    
    private func multipartBodyFromFaceImages(_ images: [UIImage], boundary: String) -> Data {
        var body = Data()
        let fieldName = "faces"
        let mimeType = "image/png"
        for (index, image) in images.enumerated() {
            guard let png = image.pngData() else {
                continue
            }
            let fileName = "image\(index + 1).png"
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(png)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}

fileprivate struct RequestBody: Encodable {
    let images: [Data]
}
