//
//  IntegrationViewModel.swift
//  GeoQuickSearch
//
//  Created by Edmunds Durst on 5/14/25.
//


// SearchMapIntegrationTest.swift
import SwiftUI
import MapKit
import CoreLocation

class IntegrationViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchText = ""
    @Published var searchCompletions: [MKLocalSearchCompletion] = []
    @Published var selectedLocation: CLLocationCoordinate2D?
    @Published var isLoading = false
    @Published var showSatelliteView = true // Default to satellite view
    
    private let searchCompleter = MKLocalSearchCompleter()
    private let geocoder = CLGeocoder()
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = .address
    }
    
    func updateSearchText(_ text: String) {
        searchText = text
        searchCompleter.queryFragment = text
    }
    
    func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        searchText = suggestion.title
        performSearch()
    }
    
    func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isLoading = true
        
        geocoder.geocodeAddressString(searchText) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    return
                }
                
                if let location = placemarks?.first?.location?.coordinate {
                    self.selectedLocation = location
                    print("Located at: \(location.latitude), \(location.longitude)")
                }
            }
        }
    }
}


    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchCompletions = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }


struct SearchMapIntegrationTest: View {
    @StateObject private var viewModel = IntegrationViewModel()
    @State private var showSuggestions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search section
            VStack {
                Text("Address Search & Map Test")
                    .font(.headline)
                    .padding(.top)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search for an address", text: $viewModel.searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: viewModel.searchText) { newValue in
                            viewModel.updateSearchText(newValue)
                            showSuggestions = !newValue.isEmpty
                        }
                        .onSubmit {
                            viewModel.performSearch()
                            showSuggestions = false
                        }
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                            showSuggestions = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
            
            // Suggestions dropdown
            if showSuggestions && !viewModel.searchCompletions.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.searchCompletions, id: \.self) { suggestion in
                            Button(action: {
                                viewModel.selectSuggestion(suggestion)
                                showSuggestions = false
                            }) {
                                VStack(alignment: .leading) {
                                    Text(suggestion.title)
                                        .foregroundColor(.primary)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                        }
                    }
                }
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.2), radius: 4)
                .frame(height: min(CGFloat(viewModel.searchCompletions.count * 50), 200))
                .padding(.horizontal)
            }
            
            // Map type toggle
            HStack {
                Text("Map Type:")
                    .font(.caption)
                
                Toggle("Satellite View", isOn: $viewModel.showSatelliteView)
                    .toggleStyle(SwitchToggleStyle())
                    .labelsHidden()
                
                Text(viewModel.showSatelliteView ? "Satellite" : "Standard")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
            
            // Map display
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                    Text("Searching...")
                        .font(.caption)
                        .padding(.top)
                }
                .frame(width: 400, height: 400)
            } else if let location = viewModel.selectedLocation {
                IntegrationMapView(
                    coordinate: location,
                    title: viewModel.searchText,
                    mapType: viewModel.showSatelliteView ? .satellite : .standard
                )
                .frame(width: 400, height: 400)
            } else {
                VStack {
                    Image(systemName: "map")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("Search for an address to display the map")
                        .foregroundColor(.gray)
                        .padding(.top)
                }
                .frame(width: 400, height: 400)
            }
            
            // Coordinate display
            if let location = viewModel.selectedLocation {
                HStack {
                    Text("Lat: \(String(format: "%.6f", location.latitude))")
                    Spacer()
                    Text("Long: \(String(format: "%.6f", location.longitude))")
                }
                .font(.caption)
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
        .frame(width: 400, height: 600)
    }
}

struct IntegrationMapView: NSViewRepresentable {
    var coordinate: CLLocationCoordinate2D
    var title: String
    var mapType: MKMapType
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Set map type (satellite or standard)
        mapView.mapType = mapType
        
        // Set region
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: true)
        
        // Clear existing annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // Add annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = title
        mapView.addAnnotation(annotation)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: IntegrationMapView
        
        init(_ parent: IntegrationMapView) {
            self.parent = parent
        }
        
        // Custom annotation view if needed
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "SearchLocationPin"
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
    }
}
