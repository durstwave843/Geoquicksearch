//
//  SpatialIndex.swift
//  GeoQuickSearch
//
//  Created by Edmunds Durst on 5/14/25.
//


import SwiftUI
import MapKit
import CoreLocation

// MARK: - Spatial Index
class SpatialIndex {
    struct BoundingBox {
        let minLat, minLng, maxLat, maxLng: Double
        
        func contains(point: CLLocationCoordinate2D) -> Bool {
            return point.latitude >= minLat && point.latitude <= maxLat &&
                   point.longitude >= minLng && point.longitude <= maxLng
        }
    }
    
    struct IndexedShape {
        let shape: KMLShape
        let boundingBox: BoundingBox
    }
    
    private var indexedShapes: [IndexedShape] = []
    
    func addShape(_ shape: KMLShape) {
        var minLat = Double.infinity
        var maxLat = -Double.infinity
        var minLng = Double.infinity
        var maxLng = -Double.infinity
        
        for coordinate in shape.coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLng = min(minLng, coordinate.longitude)
            maxLng = max(maxLng, coordinate.longitude)
        }
        
        let boundingBox = BoundingBox(minLat: minLat, minLng: minLng, maxLat: maxLat, maxLng: maxLng)
        indexedShapes.append(IndexedShape(shape: shape, boundingBox: boundingBox))
    }
    
    func potentialShapesContaining(point: CLLocationCoordinate2D) -> [KMLShape] {
        return indexedShapes
            .filter { $0.boundingBox.contains(point: point) }
            .map { $0.shape }
    }
    
    var count: Int {
        return indexedShapes.count
    }
}

// MARK: - Optimized KML Parser
class OptimizedKMLParser: NSObject, XMLParserDelegate {
    private var shapes: [KMLShape] = []
    private var currentElement = ""
    private var currentPlacemarkName = ""
    private var currentDescription = ""
    private var currentProperties: [String: String] = [:]
    private var currentCoordinates: [CLLocationCoordinate2D] = []
    private var inPlacemark = false
    private var inPolygon = false
    private var inOuterBoundary = false
    private var inInnerBoundary = false
    private var inLinearRing = false
    private var inCoordinates = false
    private var coordinatesBuffer = ""
    private var inExtendedData = false
    private var currentDataName = ""
    private var buffer = ""
    private var shapeCount = 0
    private var progressCallback: ((Double, Int) -> Void)?
    
    func parseKMLFile(at url: URL, progressCallback: @escaping (Double, Int) -> Void) -> [KMLShape] {
        self.progressCallback = progressCallback
        shapes = []
        shapeCount = 0
        
        print("Starting to parse KML file at: \(url.path)")
        
        guard let parser = XMLParser(contentsOf: url) else {
            print("Failed to create XML parser for file")
            return []
        }
        
        parser.delegate = self
        
        let startTime = Date()
        if parser.parse() {
            let duration = Date().timeIntervalSince(startTime)
            print("Successfully parsed KML file with \(shapes.count) shapes in \(duration) seconds")
            return shapes
        } else {
            if let error = parser.parserError {
                print("Failed to parse KML file: \(error.localizedDescription) at line \(parser.lineNumber)")
            } else {
                print("Failed to parse KML file with unknown error")
            }
            return []
        }
    }
    
    // MARK: XMLParserDelegate methods
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        buffer = ""
        
        switch elementName {
        case "Placemark":
            inPlacemark = true
            currentPlacemarkName = ""
            currentDescription = ""
            currentProperties = [:]
        case "Polygon":
            inPolygon = true
        case "outerBoundaryIs":
            inOuterBoundary = true
            currentCoordinates = []
        case "innerBoundaryIs":
            inInnerBoundary = true
            currentCoordinates = []
        case "LinearRing":
            inLinearRing = true
        case "coordinates":
            inCoordinates = true
            coordinatesBuffer = ""
        case "ExtendedData":
            inExtendedData = true
        case "Data":
            if let name = attributeDict["name"] {
                currentDataName = name
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "Placemark":
            inPlacemark = false
            
        case "Polygon":
            inPolygon = false
            
        case "outerBoundaryIs":
            inOuterBoundary = false
            if !currentCoordinates.isEmpty {
                let shapeName = currentPlacemarkName.isEmpty ?
                    "Outer Boundary \(shapeCount)" : currentPlacemarkName
                
                let shape = KMLShape(
                    name: shapeName,
                    properties: currentProperties,
                    coordinates: currentCoordinates
                )
                shapes.append(shape)
                shapeCount += 1
                
                if shapeCount % 50 == 0 {
                    let progress = Double(parser.lineNumber) / Double(2_000_000) // Rough estimate
                    progressCallback?(progress, shapeCount)
                }
            }
            
        case "innerBoundaryIs":
            inInnerBoundary = false
            if !currentCoordinates.isEmpty {
                let shapeName = currentPlacemarkName.isEmpty ?
                    "Inner Boundary \(shapeCount)" : "\(currentPlacemarkName) - Inner"
                
                let shape = KMLShape(
                    name: shapeName,
                    properties: currentProperties,
                    coordinates: currentCoordinates
                )
                shapes.append(shape)
                shapeCount += 1
                
                if shapeCount % 50 == 0 {
                    let progress = Double(parser.lineNumber) / Double(2_000_000)
                    progressCallback?(progress, shapeCount)
                }
            }
            
        case "LinearRing":
            inLinearRing = false
            
        case "coordinates":
            inCoordinates = false
            if inLinearRing {
                currentCoordinates = parseCoordinatesString(coordinatesBuffer)
                
                // If we're not in explicit boundary tags and directly in a polygon, create a shape
                if !inInnerBoundary && !inOuterBoundary && inPolygon && !currentCoordinates.isEmpty {
                    let shapeName = currentPlacemarkName.isEmpty ?
                        "Polygon \(shapeCount)" : currentPlacemarkName
                    
                    let shape = KMLShape(
                        name: shapeName,
                        properties: currentProperties,
                        coordinates: currentCoordinates
                    )
                    shapes.append(shape)
                    shapeCount += 1
                    
                    if shapeCount % 50 == 0 {
                        let progress = Double(parser.lineNumber) / Double(2_000_000)
                        progressCallback?(progress, shapeCount)
                    }
                }
            }
            
        case "ExtendedData":
            inExtendedData = false
            
        case "Data":
            currentDataName = ""
            
        case "name":
            if inPlacemark {
                currentPlacemarkName = buffer
            }
            
        case "description":
            if inPlacemark {
                currentDescription = buffer
                if !currentDescription.isEmpty {
                    currentProperties["description"] = currentDescription
                }
            }
            
        case "value":
            if !currentDataName.isEmpty && inExtendedData {
                currentProperties[currentDataName] = buffer
            }
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
        if inCoordinates {
            coordinatesBuffer += string
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("XML Parse error at line \(parser.lineNumber), column \(parser.columnNumber): \(parseError.localizedDescription)")
    }
    
    private func parseCoordinatesString(_ coordinatesString: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        
        // Handle the specific format in the KML file with excessive whitespace
        let trimmed = coordinatesString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        trimmed.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .filter { !$0.isEmpty }
            .forEach { coordString in
                let components = coordString.split(separator: ",")
                if components.count >= 2,
                   let longitude = Double(components[0]),
                   let latitude = Double(components[1]) {
                    coordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                }
            }
        
        return coordinates
    }
}

// MARK: - Optimized View Model
class OptimizedPolygonViewModel: ObservableObject {
    @Published var testPoint = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903) // Denver
    @Published var results: [KMLResult] = []
    @Published var isLoading = false
    @Published var loadingProgress: Double = 0
    @Published var shapesCount: Int = 0
    @Published var processingTimeMs: Int = 0
    @Published var statusMessage: String = "Ready to load KML"
    
    private var shapes: [KMLShape] = []
    private var spatialIndex = SpatialIndex()
    private let processingQueue = DispatchQueue(label: "com.app.polygonProcessing", qos: .userInitiated)
    private let pointCheckQueue = DispatchQueue(label: "com.app.pointChecking", qos: .userInteractive)
    
    func loadKMLFile() {
        guard !isLoading else { return }
        
        isLoading = true
        loadingProgress = 0
        shapesCount = 0
        statusMessage = "Starting KML loading..."
        
        // First prompt the user to select a KML file
        DispatchQueue.main.async { [weak self] in
            self?.promptForKMLFile { fileURL in
                guard let fileURL = fileURL else {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.statusMessage = "KML file selection cancelled"
                    }
                    return
                }
                
                self?.processKMLFile(at: fileURL)
            }
        }
    }
    
    private func processKMLFile(at url: URL) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let startTime = Date()
            
            let parser = OptimizedKMLParser()
            let shapes = parser.parseKMLFile(at: url) { [weak self] progress, count in
                DispatchQueue.main.async {
                    self?.loadingProgress = progress
                    self?.shapesCount = count
                    self?.statusMessage = "Loading KML... \(count) shapes found"
                }
            }
            
            // Build spatial index
            DispatchQueue.main.async {
                self.statusMessage = "Building spatial index..."
            }
            
            let spatialIndex = SpatialIndex()
            for shape in shapes {
                spatialIndex.addShape(shape)
            }
            
            let endTime = Date()
            let totalTime = endTime.timeIntervalSince(startTime)
            
            DispatchQueue.main.async {
                self.shapes = shapes
                self.spatialIndex = spatialIndex
                self.isLoading = false
                self.loadingProgress = 1.0
                self.statusMessage = "Loaded \(shapes.count) shapes in \(String(format: "%.2f", totalTime)) seconds. Spatial index built with \(spatialIndex.count) entries."
                print("KML loaded: \(shapes.count) shapes, index: \(spatialIndex.count) entries")
            }
        }
    }
    
    func checkPointInPolygons() {
        guard !isLoading && !shapes.isEmpty else { return }
        
        isLoading = true
        statusMessage = "Checking point location..."
        
        pointCheckQueue.async { [weak self] in
            guard let self = self else { return }
            
            let startTime = Date()
            
            // First use the spatial index to get potential matches
            let potentialMatches = self.spatialIndex.potentialShapesContaining(point: self.testPoint)
            
            print("Narrowed down from \(self.shapes.count) shapes to \(potentialMatches.count) potential matches")
            
            // Then do the actual point-in-polygon test only on potential matches
            var results: [KMLResult] = []
            for shape in potentialMatches {
                if self.pointInPolygon(point: self.testPoint, polygon: shape.coordinates) {
                    results.append(KMLResult(
                        zoneName: shape.name,
                        properties: shape.properties
                    ))
                }
            }
            
            let endTime = Date()
            let elapsedTime = endTime.timeIntervalSince(startTime) * 1000 // Convert to milliseconds
            
            DispatchQueue.main.async {
                self.results = results
                self.isLoading = false
                self.processingTimeMs = Int(elapsedTime)
                
                if results.isEmpty {
                    self.statusMessage = "Point is not in any polygon. Check took \(self.processingTimeMs) ms."
                } else {
                    self.statusMessage = "Found point in \(results.count) polygons. Check took \(self.processingTimeMs) ms."
                }
                
                print("Found point in \(results.count) polygons")
                for result in results {
                    print("- In zone: \(result.zoneName)")
                }
            }
        }
    }
    
    func pointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count > 3 else { return false }
        
        var isInside = false
        var j = polygon.count - 1
        
        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]
            
            if ((pi.longitude > point.longitude) != (pj.longitude > point.longitude)) &&
                (point.latitude < (pj.latitude - pi.latitude) * (point.longitude - pi.longitude) /
                 (pj.longitude - pi.longitude) + pi.latitude) {
                isInside = !isInside
            }
            
            j = i
        }
        
        return isInside
    }
    
    // Helper to prompt for KML file
    func promptForKMLFile(completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedFileTypes = ["kml"]
        openPanel.message = "Select a KML file"
        openPanel.prompt = "Open"
        
        openPanel.begin { response in
            if response == .OK, let fileURL = openPanel.url {
                completion(fileURL)
            } else {
                completion(nil)
            }
        }
    }
}

// MARK: - View
struct OptimizedPointInPolygonTest: View {
    @StateObject private var viewModel = OptimizedPolygonViewModel()
    @State private var latitudeText = "39.7392" // Denver
    @State private var longitudeText = "-104.9903" // Denver
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Colorado Municipal Boundaries Test")
                .font(.headline)
            
            // Status message
            Text(viewModel.statusMessage)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            // Progress indicator during loading
            if viewModel.isLoading {
                ProgressView(value: viewModel.loadingProgress, total: 1.0)
                    .padding(.horizontal)
                
                if viewModel.shapesCount > 0 {
                    Text("Found \(viewModel.shapesCount) shapes so far")
                        .font(.caption)
                }
            }
            
            // Controls section
            VStack(spacing: 12) {
                HStack {
                    Button("Load KML File") {
                        viewModel.loadKMLFile()
                    }
                    .disabled(viewModel.isLoading)
                    
                    Spacer()
                    
                    Text("Shapes: \(viewModel.shapesCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Coordinate input
                HStack {
                    Text("Latitude:")
                    TextField("Latitude", text: $latitudeText)
                        .frame(width: 100)
                    
                    Text("Longitude:")
                    TextField("Longitude", text: $longitudeText)
                        .frame(width: 100)
                    
                    Button("Check Location") {
                        if let lat = Double(latitudeText), let lng = Double(longitudeText) {
                            viewModel.testPoint = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                            viewModel.checkPointInPolygons()
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.shapesCount == 0)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Results section
            if !viewModel.results.isEmpty {
                VStack(alignment: .leading) {
                    Text("Point is inside \(viewModel.results.count) boundaries:")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    if viewModel.processingTimeMs > 0 {
                        Text("Processing time: \(viewModel.processingTimeMs) ms")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                    }
                    
                    List {
                        ForEach(viewModel.results, id: \.zoneName) { result in
                            VStack(alignment: .leading) {
                                Text(result.zoneName)
                                    .font(.headline)
                                
                                ForEach(Array(result.properties.keys.sorted()), id: \.self) { key in
                                    if let value = result.properties[key] {
                                        HStack(alignment: .top) {
                                            Text("\(key):")
                                                .fontWeight(.medium)
                                                .frame(width: 100, alignment: .leading)
                                            
                                            Text(value)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Button("Copy Results") {
                        copyResultsToClipboard(viewModel.results)
                    }
                    .padding(.vertical, 8)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
            } else if !viewModel.isLoading && viewModel.shapesCount > 0 && viewModel.processingTimeMs > 0 {
                Text("Point is not in any Colorado municipality")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(width: 600, height: 700)
        .padding()
    }
    
    func copyResultsToClipboard(_ results: [KMLResult]) {
        var textToCopy = ""
        
        if results.isEmpty {
            textToCopy = "Address not found in any defined zones."
        } else {
            for result in results {
                textToCopy += "Zone: \(result.zoneName)\n"
                for (key, value) in result.properties {
                    textToCopy += "  \(key): \(value)\n"
                }
                textToCopy += "\n"
            }
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)
        
        print("Results copied to clipboard")
    }
}
