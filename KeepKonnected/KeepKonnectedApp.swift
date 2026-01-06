//
//  KeepKonnectedApp.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/17/25.
//  AI Usage: Largely for init(), otherewise written by me
//

import SwiftUI
import SwiftData
import BackgroundTasks
import OSLog
import UIKit
import UserNotifications

@main
struct KeepKonnectedApp: App {
    @StateObject private var introState = IntroState()
    @StateObject private var appState = AppState()
    
    @Query(sort: [
        SortDescriptor(\Contact.order, order: .forward),
        SortDescriptor(\Contact.givenName, order: .forward)
    ]) private var contacts: [Contact]
    private let notificationHandler: NotificationHandler

    init() {
        let logger = Logger(subsystem: "KeepKonnected", category: "Background")
        UITableView.appearance().backgroundColor = .clear
        let appStateInstance = AppState()
        
        // initialize the StateObject backing storage with that instance
        _appState = StateObject(wrappedValue: appStateInstance)
        
        // create and retain the notification handler using the same instance
        let handler = NotificationHandler(appState: appStateInstance)
        self.notificationHandler = handler
        UNUserNotificationCenter.current().delegate = handler
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.SamHilbert.KeepKonnected.refresh", using: nil)
        { task in
            logger.log("Handling background task")
            NotificationScheduler.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
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
