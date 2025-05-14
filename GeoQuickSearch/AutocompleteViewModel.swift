//
//  AutocompleteViewModel.swift
//  GeoQuickSearch
//
//  Created by Edmunds Durst on 5/14/25.
//


// AutocompleteTest.swift
import SwiftUI
import MapKit

class AutocompleteViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchText = ""
    @Published var suggestions: [MKLocalSearchCompletion] = []
    
    private let completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }
    
    func updateSearchText(_ text: String) {
        searchText = text
        completer.queryFragment = text
    }
    
    // MKLocalSearchCompleterDelegate methods
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
        print("Got \(suggestions.count) suggestions")
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Autocomplete error: \(error.localizedDescription)")
    }
}

struct AutocompleteTest: View {
    @StateObject private var viewModel = AutocompleteViewModel()
    @State private var selectedSuggestion = ""
    
    var body: some View {
        VStack {
            Text("Address Autocomplete Test")
                .font(.headline)
            
            TextField("Search address", text: $viewModel.searchText, onEditingChanged: { isEditing in
                if isEditing {
                    viewModel.updateSearchText(viewModel.searchText)
                }
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .onChange(of: viewModel.searchText) { newValue in
                viewModel.updateSearchText(newValue)
            }
            .padding()
            
            if !viewModel.suggestions.isEmpty {
                List {
                    ForEach(viewModel.suggestions, id: \.self) { suggestion in
                        Button(action: {
                            selectedSuggestion = "\(suggestion.title), \(suggestion.subtitle)"
                            viewModel.searchText = suggestion.title
                            viewModel.suggestions = []
                        }) {
                            VStack(alignment: .leading) {
                                Text(suggestion.title)
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(height: min(CGFloat(viewModel.suggestions.count * 50), 200))
            }
            
            if !selectedSuggestion.isEmpty {
                Text("Selected: \(selectedSuggestion)")
                    .padding()
            }
        }
        .frame(width: 400, height: 400)
    }
}