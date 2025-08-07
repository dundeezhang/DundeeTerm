//
//  ContentView.swift
//  DundeeTerm
//
//  Created by Dundee Zhang on 2025-08-07.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TerminalView()
            .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}