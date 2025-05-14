//
//  KMLShape.swift
//  GeoQuickSearch
//
//  Created by Edmunds Durst on 5/14/25.
//


// KMLModels.swift
import Foundation
import CoreLocation

struct KMLShape {
    let id: UUID = UUID()
    let name: String
    let properties: [String: String]
    let coordinates: [CLLocationCoordinate2D]
}

struct KMLResult {
    let zoneName: String
    let properties: [String: String]
}

// Test data generator
class TestKMLData {
    static func getTestShapes() -> [KMLShape] {
        return [
            // San Francisco downtown area (approximate)
            KMLShape(
                name: "Downtown SF",
                properties: [
                    "description": "Downtown San Francisco area",
                    "zoneType": "Commercial",
                    "density": "High"
                ],
                coordinates: [
                    CLLocationCoordinate2D(latitude: 37.789, longitude: -122.419),
                    CLLocationCoordinate2D(latitude: 37.789, longitude: -122.399),
                    CLLocationCoordinate2D(latitude: 37.769, longitude: -122.399),
                    CLLocationCoordinate2D(latitude: 37.769, longitude: -122.419),
                    CLLocationCoordinate2D(latitude: 37.789, longitude: -122.419)
                ]
            ),
            // Mission District (approximate)
            KMLShape(
                name: "Mission District",
                properties: [
                    "description": "Mission District area",
                    "zoneType": "Mixed Use",
                    "density": "Medium"
                ],
                coordinates: [
                    CLLocationCoordinate2D(latitude: 37.765, longitude: -122.430),
                    CLLocationCoordinate2D(latitude: 37.765, longitude: -122.400),
                    CLLocationCoordinate2D(latitude: 37.748, longitude: -122.400),
                    CLLocationCoordinate2D(latitude: 37.748, longitude: -122.430),
                    CLLocationCoordinate2D(latitude: 37.765, longitude: -122.430)
                ]
            )
        ]
    }
}