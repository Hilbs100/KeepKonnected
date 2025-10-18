//
//  KeepKonnectedApp.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/17/25.
//

import SwiftUI
import SwiftData

@main
struct KeepKonnectedApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Contact.self])
        }
    }
}
