//
//  ResultsViewModel.swift
//  GeoQuickSearch
//
//  Created by Edmunds Durst on 5/14/25.
//


//
//  ResultsDisplayTest.swift
//  GeoQuickSearch
//
//  Created by Edmunds Durst on 5/14/25.
//

import SwiftUI

class ResultsViewModel: ObservableObject {
    @Published var results: [KMLResult] = []
    
    init() {
        // Initialize with sample results
        results = [
            KMLResult(
                zoneName: "Downtown Area",
                properties: [
                    "description": "Central business district",
                    "zoneType": "Commercial",
                    "density": "High"
                ]
            ),
            KMLResult(
                zoneName: "Mixed-Use Zone",
                properties: [
                    "description": "Combined residential and commercial",
                    "zoneType": "Mixed",
                    "density": "Medium"
                ]
            )
        ]
    }
    
    func copyResultsToClipboard() {
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
        
        print("Copied to clipboard:\n\(textToCopy)")
    }
}

struct ResultsDisplayTest: View {
    @StateObject private var viewModel = ResultsViewModel()
    
    var body: some View {
        VStack {
            Text("Results Display Test")
                .font(.headline)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.results, id: \.zoneName) { result in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.zoneName)
                                .font(.headline)
                            
                            ForEach(Array(result.properties.keys.sorted()), id: \.self) { key in
                                if let value = result.properties[key] {
                                    HStack(alignment: .top) {
                                        Text("\(key):")
                                            .fontWeight(.medium)
                                            .frame(width: 80, alignment: .leading)
                                        
                                        Text(value)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 8)
                        
                        if result.zoneName != viewModel.results.last?.zoneName {
                            Divider()
                        }
                    }
                }
                .padding()
            }
            .frame(height: 200)
            .border(Color.gray.opacity(0.3))
            
            Button(action: viewModel.copyResultsToClipboard) {
                HStack {
                    Image(systemName: "doc.on.clipboard")
                    Text("Copy Results")
                }
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }
}