//
//  TestSupportError.swift
//
//
//  Created by Jakub Dolejs on 09/09/2025.
//

import Foundation

public struct TestSupportError: LocalizedError {
    public var errorDescription: String?
    public init(_ errorDescription: String? = nil) {
        self.errorDescription = errorDescription
    }
}
