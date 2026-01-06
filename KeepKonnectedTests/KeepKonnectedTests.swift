//
//  KeepKonnectedTests.swift
//  KeepKonnectedTests
//
//  Created by Samuel Hilbert on 10/17/25.
//

import Testing
import SwiftData
import Foundation
import BackgroundTasks
@testable import KeepKonnected

struct KeepKonnectedTests {
    
    func makeIsolatedContainer() throws -> ModelContainer {
        let schema = Schema([Contact.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true) // ensures isolation
        return try ModelContainer(for: schema, configurations: [config])
    }
    
    func registerTestBGTaskHandler() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.SamHilbert.KeepKonnected.refresh", using: nil) { task in
            // Immediately mark complete to avoid retries
            task.setTaskCompleted(success: true)
        }
    }
    
    @Test func addAndDeleteContact() async throws {
        // create an in-memory model container for the Contact model
        let container = try makeIsolatedContainer()
        let context = ModelContext(container)
        
        // initial count
        let initial = try context.fetch(FetchDescriptor<Contact>()).count
        
        // create and insert a contact
        let contact = Contact(
            givenName: "Test",
            familyName: "User",
            phoneNumbers: ["555-555-5555"],
            emailAddresses: ["test@example.com"],
            type: .weekly,
            order: 0
        )
        context.insert(contact)
        try context.save()
        
        // verify contact was added
        let afterAdd = try context.fetch(FetchDescriptor<Contact>())
        #expect(afterAdd.count == initial + 1)
        #expect(afterAdd.contains(where: { $0.identifier == contact.identifier }))
        
        // delete the contact
        if let toDelete = afterAdd.first(where: { $0.identifier == contact.identifier }) {
            context.delete(toDelete)
            try context.save()
        } else {
            // fail the test if the contact wasn't found to delete
            #expect(Bool(false), "Contact to delete not found")
        }
        
        // verify contact was removed
        let afterDelete = try context.fetch(FetchDescriptor<Contact>())
        #expect(afterDelete.count == initial)
        #expect(!afterDelete.contains(where: { $0.identifier == contact.identifier }))
        
    }
    
    @Test func testBackgroundTask() async throws {
        // create an in-memory model container for the Contact model
        let container = try makeIsolatedContainer()
        let context = ModelContext(container)
        
        // create and insert a contact
        let contact = Contact(
            givenName: "Test",
            familyName: "User",
            phoneNumbers: ["555-555-5555"],
            emailAddresses: ["test@example.com"],
            type: .weekly,
            order: 0
        )
        context.insert(contact)
        try context.save()
        
        let afterAdd = try context.fetch(FetchDescriptor<Contact>())
        
        // Set the model context for NotificationScheduler
        await NotificationScheduler.setModelContext(context)
        // Perform the background task
        await NotificationScheduler.performWeeklyNotifications { success in
            #expect(success == true, "Background task failed")
        }
        
        // delete the contact
        if let toDelete = afterAdd.first(where: { $0.identifier == contact.identifier }) {
            context.delete(toDelete)
            try context.save()
        } else {
            // fail the test if the contact wasn't found to delete
            #expect(Bool(false), "Contact to delete not found")
        }
        
        // verify contact was removed
        let afterDelete = try context.fetch(FetchDescriptor<Contact>())
        #expect(!afterDelete.contains(where: { $0.identifier == contact.identifier }))
    }
    
    @Test func testNotification() async throws {
        // create an in-memory model container for the Contact model
        let container = try makeIsolatedContainer()
        let context = ModelContext(container)
        
        // create and insert a contact
        let contact = Contact(
            givenName: "Test",
            familyName: "User",
            phoneNumbers: ["555-555-5555"],
            emailAddresses: ["test@example.com"],
            type: .weekly,
            order: 0
        )
        context.insert(contact)
        try context.save()
        
        let afterAdd = try context.fetch(FetchDescriptor<Contact>())
        
        // Schedule notifications
        contact.createNotification()
        #expect(contact.notifDate > Date(), "Notification date was not set")
        #expect(contact.notifDate < Date().addingTimeInterval(3600 * 24 * 8), "Notification date is not within 1 week")
        
        // delete the contact
        if let toDelete = afterAdd.first(where: { $0.identifier == contact.identifier }) {
            context.delete(toDelete)
            try context.save()
        } else {
            // fail the test if the contact wasn't found to delete
            #expect(Bool(false), "Contact to delete not found")
        }
        
        // verify contact was removed
        let afterDelete = try context.fetch(FetchDescriptor<Contact>())
        #expect(!afterDelete.contains(where: { $0.identifier == contact.identifier }))
    }
    
    @Test func testUpdateProbability() async throws {
        let container = try makeIsolatedContainer()
        let context = ModelContext(container)
        
        let contact = Contact(
            givenName: "Test",
            familyName: "User",
            phoneNumbers: ["555-555-5555"],
            type: .weekly,
            order: 0
        )
        
        context.insert(contact)
        try context.save()
        
        let afterAdd = try context.fetch(FetchDescriptor<Contact>())
        let origWeekdays = Contact.Weekdays!
        let origWeekdayTimes = Contact.WeekdayTimes!.map { $0.map { $0 } }
        
        Contact.updateProbabilities()
        #expect(Contact.Weekdays != origWeekdays, "Weekdays did not update")
        // Check to make sure one value is different
        var changed = false
        var lastProb = Contact.Weekdays![0]
        for i in 0..<Contact.Weekdays!.count {
            if Contact.Weekdays![i] != lastProb {
                changed = true
                break
            }
            lastProb = Contact.Weekdays![i]
        }
        print(Contact.Weekdays!)
        #expect(changed, "Weekdays did not change values")
        #expect(Contact.WeekdayTimes != origWeekdayTimes, "WeekdayTimes did not update")
        
        Contact.Weekdays = origWeekdays
        Contact.WeekdayTimes = origWeekdayTimes
        
        // delete the contact
        if let toDelete = afterAdd.first(where: { $0.identifier == contact.identifier }) {
            context.delete(toDelete)
            try context.save()
        } else {
            // fail the test if the contact wasn't found to delete
            #expect(Bool(false), "Contact to delete not found")
        }
        
        // verify contact was removed
        let afterDelete = try context.fetch(FetchDescriptor<Contact>())
        #expect(!afterDelete.contains(where: { $0.identifier == contact.identifier }))
    }
    
}
