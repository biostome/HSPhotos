//
//  PhotoTag.swift
//  HSPhotos
//
//  Created by Hans on 2026/3/14.
//

import Foundation

struct PhotoTag: Codable, Equatable {
    let id: String
    var name: String
    var assetIdentifiers: [String]
    var lastUsedAt: Date?
    let createdAt: Date

    init(name: String) {
        self.id = UUID().uuidString
        self.name = name
        self.assetIdentifiers = []
        self.lastUsedAt = nil
        self.createdAt = Date()
    }
}

// MARK: - TagFilterState

struct TagFilterState: Equatable {
    var selectedTagIDs: Set<String> = []
    var matchRule: MatchRule = .any

    var isActive: Bool { !selectedTagIDs.isEmpty }

    enum MatchRule: String, Codable {
        case any
        case all
    }
}
