//
//  DatasetLoader.swift
//  FaceRecognitionArcFace
//
//  Created by Jakub Dolejs on 27/10/2025.
//

import Foundation
import UIKit
import VerIDCommonTypes

class DatasetLoader {
    
    let url: URL
    private let urlSession: URLSession = URLSession(configuration: .ephemeral)
    
    init(url: URL) {
        self.url = url
    }
    
    func loadDataset() async throws -> [URL] {
        var request = URLRequest(url: self.url)
        request.setValue("text/plain", forHTTPHeaderField: "Accept")
        let (data, response) = try await self.urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DatasetLoaderError("Invalid response from server")
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        let paths = text.split(separator: "\n").map(String.init)
        return paths.map { path in
            self.url.appendingPathComponent(path)
        }
    }
    
    func loadImage(at url: URL) async throws -> Image {
        let (data, _) = try await self.urlSession.data(from: url)
        guard let image = UIImage(data: data) else {
            throw DatasetLoaderError("Failed to load image from data")
        }
        return try image.toVerIDImage()
    }
    
    func streamImages() -> AsyncThrowingStream<(URL,Image), Error> {
        AsyncThrowingStream { continuation in
            Task {
                let urls = try await self.loadDataset()
                for url in urls {
                    let image = try await self.loadImage(at: url)
                    continuation.yield((url,image))
                }
                continuation.finish()
            }
        }
    }
}

struct DatasetLoaderError: LocalizedError {
    var errorDescription: String?
    
    init(_ errorDescription: String? = nil) {
        self.errorDescription = errorDescription
    }
}
