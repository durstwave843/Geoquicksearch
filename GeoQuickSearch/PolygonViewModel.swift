//
//  PolygonViewModel.swift
//  GeoQuickSearch
//
//  Created by Edmunds Durst on 5/14/25.
//


// PointInPolygonTest.swift
import SwiftUI
import MapKit

class PolygonViewModel: ObservableObject {
    @Published var shapes = TestKMLData.getTestShapes()
    @Published var testPoint = CLLocationCoordinate2D(latitude: 37.775, longitude: -122.410)
    @Published var results: [KMLResult] = []
    
    func checkPointInPolygons() {
        results = []
        
        for shape in shapes {
            if pointInPolygon(point: testPoint, polygon: shape.coordinates) {
                results.append(KMLResult(
                    zoneName: shape.name,
                    properties: shape.properties
                ))
            }
        }
        
        print("Found point in \(results.count) polygons")
        for result in results {
            print("- In zone: \(result.zoneName)")
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
}

struct PointInPolygonTest: View {
    @StateObject private var viewModel = PolygonViewModel()
    @State private var latitudeText = "37.775"
    @State private var longitudeText = "-122.410"
    
    var body: some View {
        VStack {
            Text("Point in Polygon Test")
                .font(.headline)
            
            HStack {
                Text("Latitude:")
                TextField("Latitude", text: $latitudeText)
                    .frame(width: 100)
                
                Text("Longitude:")
                TextField("Longitude", text: $longitudeText)
                    .frame(width: 100)
            }
            .padding()
            
            Button("Check Polygons") {
                if let lat = Double(latitudeText), let lng = Double(longitudeText) {
                    viewModel.testPoint = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    viewModel.checkPointInPolygons()
                }
            }
            .padding()
            
            if viewModel.results.isEmpty {
                Text("Point is not in any polygon")
                    .foregroundColor(.red)
                    .padding()
            } else {
                Text("Point is inside \(viewModel.results.count) polygons:")
                    .padding(.top)
                
                List {
                    ForEach(viewModel.results, id: \.zoneName) { result in
                        VStack(alignment: .leading) {
                            Text(result.zoneName)
                                .font(.headline)
                            
                            ForEach(Array(result.properties.keys.sorted()), id: \.self) { key in
                                if let value = result.properties[key] {
                                    Text("\(key): \(value)")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(height: 150)
            }
            
            // Map showing polygons and test point
            PolygonMapView(shapes: viewModel.shapes, testPoint: viewModel.testPoint)
                .frame(width: 400, height: 300)
                .padding()
        }
        .frame(width: 500, height: 600)
    }
}

struct PolygonMapView: NSViewRepresentable {
    var shapes: [KMLShape]
    var testPoint: CLLocationCoordinate2D
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateNSView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        // Add polygons
        for shape in shapes {
            let points = shape.coordinates.map { $0 }
            let polygon = MKPolygon(coordinates: points, count: points.count)
            polygon.title = shape.name
            mapView.addOverlay(polygon)
        }
        
        // Add point annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = testPoint
        annotation.title = "Test Point"
        mapView.addAnnotation(annotation)
        
        // Set region to show everything
        mapView.setRegion(regionForShapes(shapes + [KMLShape(name: "Point", properties: [:], coordinates: [testPoint])]), animated: true)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: PolygonMapView
        
        init(_ parent: PolygonMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = NSColor.blue.withAlphaComponent(0.2)
                renderer.strokeColor = NSColor.blue
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
    
    // Helper to calculate a region that shows all shapes
    func regionForShapes(_ shapes: [KMLShape]) -> MKCoordinateRegion {
        var minLat = Double.infinity
        var maxLat = -Double.infinity
        var minLng = Double.infinity
        var maxLng = -Double.infinity
        
        for shape in shapes {
            for coordinate in shape.coordinates {
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLng = min(minLng, coordinate.longitude)
                maxLng = max(maxLng, coordinate.longitude)
            }
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2,
            longitudeDelta: (maxLng - minLng) * 1.2
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
}