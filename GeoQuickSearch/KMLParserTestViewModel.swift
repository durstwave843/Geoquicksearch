//
//  KMLParserTestViewModel.swift
//  GeoQuickSearch
//
//  Created by Edmunds Durst on 5/14/25.
//


// KMLParserTest.swift
import SwiftUI
import CoreLocation

class KMLParserTestViewModel: ObservableObject {
    @Published var parsedShapes: [KMLShape] = []
    @Published var errorMessage: String?
    
    func testParseKML() {
        // Create a test KML string (simplified KML)
        let testKML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2">
          <Document>
            <Placemark>
              <name>Test Shape 1</name>
              <description>This is test shape 1</description>
              <ExtendedData>
                <Data name="zoneType">
                  <value>Residential</value>
                </Data>
              </ExtendedData>
              <Polygon>
                <outerBoundaryIs>
                  <LinearRing>
                    <coordinates>
                      -122.42,37.78 -122.40,37.78 -122.40,37.76 -122.42,37.76 -122.42,37.78
                    </coordinates>
                  </LinearRing>
                </outerBoundaryIs>
              </Polygon>
            </Placemark>
          </Document>
        </kml>
        """
        
        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent("test.kml")
        
        do {
            try testKML.write(to: tempFileURL, atomically: true, encoding: .utf8)
            print("Test KML file created at: \(tempFileURL.path)")
            
            // Parse the test file
            let parser = KMLTestParser()
            if let shapes = parser.parseKMLFile(at: tempFileURL) {
                self.parsedShapes = shapes
                self.errorMessage = nil
                print("Successfully parsed \(shapes.count) shapes")
            } else {
                self.errorMessage = "Failed to parse KML"
                print("Failed to parse KML")
            }
            
            // Clean up
            try FileManager.default.removeItem(at: tempFileURL)
        } catch {
            self.errorMessage = "Error: \(error.localizedDescription)"
            print("Error: \(error.localizedDescription)")
        }
    }
}

class KMLTestParser {
    func parseKMLFile(at url: URL) -> [KMLShape]? {
        guard let xmlData = try? Data(contentsOf: url) else {
            print("Failed to load KML file")
            return nil
        }
        
        let parser = XMLParser(data: xmlData)
        let kmlDelegate = KMLParserDelegate()
        parser.delegate = kmlDelegate
        
        if parser.parse() {
            return kmlDelegate.shapes
        } else {
            print("Failed to parse KML file: \(parser.parserError?.localizedDescription ?? "Unknown error")")
            return nil
        }
    }
}

class KMLParserDelegate: NSObject, XMLParserDelegate {
    var shapes: [KMLShape] = []
    
    private var currentElement = ""
    private var currentName = ""
    private var currentDescription = ""
    private var currentProperties: [String: String] = [:]
    private var currentCoordinatesString = ""
    private var inExtendedData = false
    private var currentDataName = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        
        if elementName == "Placemark" {
            // Reset for new placemark
            currentName = ""
            currentDescription = ""
            currentProperties = [:]
            currentCoordinatesString = ""
        } else if elementName == "ExtendedData" {
            inExtendedData = true
        } else if elementName == "Data" && inExtendedData {
            if let name = attributeDict["name"] {
                currentDataName = name
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "Placemark" {
            if !currentCoordinatesString.isEmpty {
                let coordinates = parseCoordinatesString(currentCoordinatesString)
                
                if !coordinates.isEmpty {
                    var properties = currentProperties
                    properties["description"] = currentDescription
                    
                    let shape = KMLShape(
                        name: currentName,
                        properties: properties,
                        coordinates: coordinates
                    )
                    
                    shapes.append(shape)
                    print("Added shape: \(currentName) with \(coordinates.count) points")
                }
            }
        } else if elementName == "ExtendedData" {
            inExtendedData = false
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let data = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !data.isEmpty {
            switch currentElement {
            case "name":
                currentName += data
            case "description":
                currentDescription += data
            case "coordinates":
                currentCoordinatesString += data
            case "value" where inExtendedData && !currentDataName.isEmpty:
                currentProperties[currentDataName] = data
            default:
                break
            }
        }
    }
    
    private func parseCoordinatesString(_ coordinatesString: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        
        let coordinateTuples = coordinatesString
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        print("Parsing coordinates: \(coordinatesString)")
        print("Found \(coordinateTuples.count) coordinate tuples")
        
        for tuple in coordinateTuples {
            let components = tuple.components(separatedBy: ",")
            if components.count >= 2,
               let longitude = Double(components[0]),
               let latitude = Double(components[1]) {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                coordinates.append(coordinate)
                print("Added coordinate: \(latitude), \(longitude)")
            }
        }
        
        return coordinates
    }
}

struct KMLParserTest: View {
    @StateObject private var viewModel = KMLParserTestViewModel()
    
    var body: some View {
        VStack {
            Text("KML Parser Test")
                .font(.headline)
            
            Button("Test KML Parser") {
                viewModel.testParseKML()
            }
            .padding()
            
            if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            if !viewModel.parsedShapes.isEmpty {
                Text("Successfully parsed \(viewModel.parsedShapes.count) shapes:")
                    .padding()
                
                List {
                    ForEach(viewModel.parsedShapes, id: \.id) { shape in
                        VStack(alignment: .leading) {
                            Text(shape.name)
                                .font(.headline)
                            Text("Points: \(shape.coordinates.count)")
                            
                            ForEach(Array(shape.properties.keys.sorted()), id: \.self) { key in
                                if let value = shape.properties[key] {
                                    Text("\(key): \(value)")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(height: 200)
            }
        }
        .frame(width: 400, height: 400)
    }
}