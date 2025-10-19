//
//  KeepKonnectedApp.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/17/25.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct KeepKonnectedApp: App {
    @StateObject private var introState = IntroState()
    init () {
        UITableView.appearance().backgroundColor = .clear
    }
    

    var body: some Scene {
        WindowGroup {
            Group {
                if introState.value == 4 {
                    // Main app
                    ContactView(contact_type: .highPriority)
                        .modelContainer(for: [Contact.self])
                        .environmentObject(introState)
                    ContactView(contact_type: .regularPriority)
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
