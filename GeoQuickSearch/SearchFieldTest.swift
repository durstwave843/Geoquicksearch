//
//  SearchFieldTest.swift
//  GeoQuickSearch
//
//  Created by Edmunds Durst on 5/14/25.
//


// SearchFieldTest.swift
import SwiftUI

struct SearchFieldTest: View {
    @State private var searchText = ""
    
    var body: some View {
        VStack {
            Text("Search Test")
                .font(.headline)
            
            TextField("Enter an address", text: $searchText, onCommit: {
                print("Search submitted: \(searchText)")
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding()
            
            Text("You entered: \(searchText)")
                .padding()
        }
        .frame(width: 400, height: 200)
    }
}