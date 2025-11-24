//
//  Item.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/17/25.
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
        
        // Use Weekday and Time probabilities to schedule notification time
        if !Contact.didInitProbabilities {
            Contact.initProbabilities()
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
        print("Notification Started for contact \(self.displayName)")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if granted {
                    print("Notification permission granted")
                } else if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                }
            }

            let content = UNMutableNotificationContent()
            content.title = "Call \(self.displayName)"
            content.body = "Here is your reminder to Keep Konnected with \(self.givenName)!"
            content.sound = .default
            // include the contact identifier so the app knows which contact to show
            content.userInfo = ["contactID": self.identifier]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 20.0, repeats: false)
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
