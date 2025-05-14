//
//  MapDisplayTest.swift
//  GeoQuickSearch
//
//  Created by Edmunds Durst on 5/14/25.
//


// MapDisplayTest.swift
import SwiftUI
import MapKit

struct MapDisplayTest: View {
    @State private var address = "Apple Park, Cupertino, CA"
    @State private var coordinate = CLLocationCoordinate2D(
        latitude: 37.334900, longitude: -122.009020) // Default to Apple Park
    
    var body: some View {
        VStack {
            Text("Map Display Test")
                .font(.headline)
            
            TextField("Enter address", text: $address)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button("Show Location") {
                geocodeAddress()
            }
            .padding(.bottom)
            
            MapViewTest(coordinate: coordinate)
                .frame(width: 400, height: 400)
        }
        .frame(width: 400, height: 500)
    }
    
    func geocodeAddress() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                return
            }
            
            if let location = placemarks?.first?.location?.coordinate {
                self.coordinate = location
                print("Geocoded \(address) to \(location.latitude), \(location.longitude)")
            }
        }
    }
}

struct MapViewTest: NSViewRepresentable {
    var coordinate: CLLocationCoordinate2D
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateNSView(_ mapView: MKMapView, context: Context) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: true)
        
        // Remove existing annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // Add pin at the location
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewTest
        
        init(_ parent: MapViewTest) {
            self.parent = parent
        }
    }
}