//
//  Item.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/17/25.
//  Minimal AI was used to create the constructor and basic variables in this file.
//

import Foundation
import SwiftData
import Contacts
import UserNotifications

enum ContactType: Int, Codable {
    case weekly = 0
    case monthly = 1
}

@Model
final class Contact: Identifiable, Equatable {
    static var Weekdays: [Double]? = nil
    static var WeekdayTimes: [[Double]]? = nil
    static var didInitProbabilities: Bool = false
    // the CNContact.identifier is stable and we keep it so we can dedupe imports
    var identifier: String
    var givenName: String
    var familyName: String
    var phoneNumbers: [String]
    var emailAddresses: [String]
    var contact_type: ContactType
    var thumbnailData: Data?
    var order: Int
    var notifDate: Date = Date().addingTimeInterval(-100)
    
    var id: String { identifier }
    
    var displayName: String {
        let name = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "No Name" : name
    }
    
    static func initProbabilities() {
        Weekdays = Array(repeating: 1.0, count: 7)
        let numQuarterHours = 24 * 4
        var normalWeekdayTime = [Double](repeating: 1.0, count: numQuarterHours)
        normalWeekdayTime.replaceSubrange(0...35, with: [Double](repeating: 0.0, count: 36)) // disable midnight to 9am
        normalWeekdayTime.replaceSubrange((21*4)..<numQuarterHours, with: [Double](repeating: 0.0, count: numQuarterHours-21*4))// disable 9pm to midnight
        WeekdayTimes = Array(repeating: normalWeekdayTime, count: 7)
        Weekdays = normalize(input: Weekdays!)
        for i in 0..<7 {
            WeekdayTimes![i] = normalize(input: WeekdayTimes![i])
        }
        didInitProbabilities = true
    }
    
    static func normalize(input: [Double]) -> [Double] {
        let total = input.reduce(0, +)
        guard total > 0 else { return input }
        return input.map { $0 / total }
    }
    
    init(identifier: String = UUID().uuidString,
         givenName: String = "",
         familyName: String = "",
         phoneNumbers: [String] = [],
         emailAddresses: [String] = [],
         thumbnailData: Data? = nil,
         type: ContactType = .monthly,
         order: Int = 0)
    {
        self.identifier = identifier
        self.givenName = givenName
        self.familyName = familyName
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.thumbnailData = thumbnailData
        self.contact_type = type
        self.order = order
    }
    
    func refresh() {
        let contactStore = CNContactStore()
        
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactThumbnailImageDataKey
        ]
        
        do {
            let cn = try contactStore.unifiedContact(withIdentifier: self.identifier, keysToFetch: keysToFetch as [CNKeyDescriptor])
            self.givenName = cn.givenName
            self.familyName = cn.familyName
            self.phoneNumbers = cn.phoneNumbers.map { $0.value.stringValue }
            self.emailAddresses = cn.emailAddresses.map { String($0.value) }
            self.thumbnailData = cn.thumbnailImageData
        }
        catch {
            print("Failed to fetch contact: \(error)")
            return
        }
        
    }
    
    func createNotification() {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        // Use Weekday and Time probabilities to schedule notification time
        if !Contact.didInitProbabilities {
            Contact.initProbabilities()
        }
        
        print("Current Notif Date: \(dateFormatter.string(from: notifDate)) for contact \(self.displayName)")
        print("Current Date is: \(dateFormatter.string(from: Date()))")
        
        if notifDate > Date().addingTimeInterval(60 * 30) { // 30 minute buffer
            // Date has not yet passed, skip scheduling
            print("Notification date has not yet passed for contact \(self.displayName), skipping scheduling.")
            return
        }
        
        // Sample from Weekdays:
        let randNum = Double.random(in: 0..<1)
        var cumulative = 0.0
        var selectedDay = 0
        for (i, prob) in Contact.Weekdays!.enumerated() {
            cumulative += prob
            if randNum < cumulative {
                selectedDay = i
                break
            }
        }
        let randNumTime = Double.random(in: 0..<1)
        cumulative = 0.0
        var selectedTime = 0
        for (i, prob) in Contact.WeekdayTimes![selectedDay].enumerated() {
            cumulative += prob
            if randNumTime < cumulative {
                selectedTime = i
                break
            }
        }
        
        
        print("Notification Started for contact \(self.displayName)")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        
        var dateComponents = DateComponents()
        dateComponents.hour = selectedTime / 4
        dateComponents.minute = selectedTime % 4 * 15 + Int.random(in: 0..<15)
        dateComponents.weekday = selectedDay + 1 // Sunday = 1, Saturday = 7
                
        guard let nextDate = Calendar.current.nextDate(
            after: Date(),
            matching: dateComponents,
            matchingPolicy: .nextTime, // Finds the next exact match
        ) else {
            print("Could not find a valid next date.")
            return
        }
        
        print("Next notification date for contact \(self.displayName): \(dateFormatter.string(from: nextDate))")
        self.notifDate = nextDate
        
        let content = UNMutableNotificationContent()
        content.title = "Call \(self.displayName)"
        content.body = "Here is your reminder to Keep Konnected with \(self.givenName)!"
        content.sound = .default
        // include the contact identifier so the app knows which contact to show
        content.userInfo = ["contactID": self.identifier]
        
        let triggerDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "sh.KeepKonnected.\(self.identifier)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    static func == (lhs: Contact, rhs: Contact) -> Bool {
        lhs.id == rhs.id
    }
}
