//
//  NotificationScheduler.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 12/31/25.
//

import BackgroundTasks
import SwiftData
import OSLog

struct NotificationScheduler {
    static var modelContext: ModelContext?
    private static let logger = Logger(subsystem: "KeepKonnected", category: "Background")

    
    static func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    static func scheduleBackgroundTask() {
        
        let request = BGAppRefreshTaskRequest(identifier: "com.SamHilbert.KeepKonnected.refresh")
        let calendar = Calendar.current
        
        // Schedule to run every Saturday at 12 PM
        if let nextSaturday12PM = calendar.nextDate(after: Date(), matching: DateComponents(hour: 12, minute: 0, weekday: 7), matchingPolicy: .nextTime) {
            request.earliestBeginDate = nextSaturday12PM
        } else {
            request.earliestBeginDate = Date() //.addingTimeInterval(60 * 60 * 24 * 7) // Fallback to one week later
        }
        
        do {
            try BGTaskScheduler.shared.submit(request)
            NotificationScheduler.logger.log("Scheduled task successfully.")
        } catch {
            NotificationScheduler.logger.log("Could not schedule contact refresh: \(error)")
        }
    }
    
    static func performWeeklyNotifications(completion: @escaping (Bool) -> Void) {
        logger.log("NotificationScheduler: performWeeklyNotifications started.")
        guard let context = NotificationScheduler.modelContext else {
            NotificationScheduler.logger.log("No ModelContext available for background work.")
            completion(false)
            return
        }

        do {
            let contacts = try context.fetch(FetchDescriptor<Contact>())
            // Pass the fetched contacts into the Contact scheduling logic
            NotificationScheduler.logger.log("NotificationScheduler: fetched \(contacts.count) contacts.")
            Contact.weeklyNotifications(contacts: contacts)

            // Persist any updates made to contacts (e.g. notifDate changes)
            try context.save()
            completion(true)
        } catch {
            logger.log("KeepKonnectedBGHandler: error fetching or saving contacts: \(error)")
            completion(false)
        }
    }
    
    static func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundTask() // reschedule immediately
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let op = BlockOperation {
            let group = DispatchGroup()
            group.enter()
            performWeeklyNotifications { success in
                task.setTaskCompleted(success: success)
                group.leave()
            }
            _ = group.wait(timeout: .now() + 25)
        }
        
        task.expirationHandler = {
            logger.error("BG task expired")
            op.cancel()
        }
        
        op.completionBlock = {
            if op.isCancelled {
                task.setTaskCompleted(success: false)
            }
        }
        
        queue.addOperation(op)
    }
}
