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
    @StateObject private var introState = IntroState()
    

    var body: some Scene {
        WindowGroup {
            Group {
                if introState.value == 4 {
                    // Main app
                    ContactView()
                        .modelContainer(for: [Contact.self])
                        .environmentObject(introState)
                } else {
                    // Show the appropriate intro page(s)
                    IntroRoot()
                        .environmentObject(introState)
                }
            }
            .environmentObject(introState).onAppear {
                introState.enableIntro()
            }
        }
    }
}
