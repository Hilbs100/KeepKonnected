//
//  NotificationHandler.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/28/25.
//


// File: `KeepKonnected/NotificationHandler.swift` — notification delegate that updates AppState
import Foundation
import UserNotifications

final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let id = userInfo["contactID"] as? String {
            DispatchQueue.main.async {
                self.appState?.selectedContactID = id
            }
        }
        completionHandler()
    }
        
}
