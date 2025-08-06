//
//  TagModels.swift
//  TagTrail
//
//  Created by Priyanshu Rastogi on 2025-06-25.
//

import Foundation
import CoreLocation
import GRDB

enum TagType: String, Codable, DatabaseValueConvertible {
    case text
    case image
    case voice
}

struct Tag: Identifiable, Codable, FetchableRecord, PersistableRecord {
    let id: UUID
    var title: String
    var type: TagType
    var content: String
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var colorHex: String = "#FF9500"

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(id: UUID = UUID(), title: String, type: TagType, content: String, coordinate: CLLocationCoordinate2D, timestamp: Date = Date(), colorHex: String = "#FF9500") {
        self.id = id
        self.title = title
        self.type = type
        self.content = content
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.timestamp = timestamp
        self.colorHex = colorHex
    }
}

// mock data
let mockTags: [Tag] = [
    Tag(title: "Grocery Reminder", type: .text, content: "Buy milk and eggs", coordinate: CLLocationCoordinate2D(latitude: 53.5461, longitude: -113.4938)),
    Tag(title: "Park Photo", type: .image, content: "park_photo.jpg", coordinate: CLLocationCoordinate2D(latitude: 53.5465, longitude: -113.4940)),
    Tag(title: "Voice Note", type: .voice, content: "voice_note.m4a", coordinate: CLLocationCoordinate2D(latitude: 53.5463, longitude: -113.4935))
]
