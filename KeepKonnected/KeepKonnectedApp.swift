//
//  KeepKonnectedApp.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/17/25.
//

import SwiftUI
import SwiftData
import UIKit
import UserNotifications

@main
struct KeepKonnectedApp: App {
    @StateObject private var introState = IntroState()
    @StateObject private var appState = AppState()
    private let notificationHandler: NotificationHandler

    init() {
        UITableView.appearance().backgroundColor = .clear
        let appStateInstance = AppState()
        
        // initialize the StateObject backing storage with that instance
        _appState = StateObject(wrappedValue: appStateInstance)
        
        // create and retain the notification handler using the same instance
        let handler = NotificationHandler(appState: appStateInstance)
        self.notificationHandler = handler
        UNUserNotificationCenter.current().delegate = handler
    }
    

    var body: some Scene {
        WindowGroup {
            Group {
                if introState.value == 4 {
                    // Main app
                    HomeView()
                        .environmentObject(appState)
                        .modelContainer(for: [Contact.self])
                } else {
                    // Show the appropriate intro page(s)
                    IntroRoot()
                        .environmentObject(introState)
                }
            }
//            .environmentObject(introState).onAppear {
//                introState.enableIntro()
//            }
        }
    }
}
