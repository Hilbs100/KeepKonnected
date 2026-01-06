//
//  Created by Samuel Hilbert on 10/17/25.
//  Minimal AI was used to create the constructor and basic variables in this file.
//

import Foundation
import SwiftData
import Contacts
import UserNotifications
import EventKit

enum ContactType: Int, Codable {
    case weekly = 0
    case monthly = 1
}

@Model
final class Contact: Identifiable, Equatable {
    
    // Serial queue to synchronize access to shared static state
    private static let probabilityQueue = DispatchQueue(label: "KeepKonnected.Contact.probabilityQueue")
    
    // Backing stored properties for thread-safe static state
    private static var _Weekdays: [Double]? = nil
    private static var _WeekdayTimes: [[Double]]? = nil
    private static var _didInitProbabilities: Bool = false
    private static var _lastMassNotifUpdate: Date = Date().addingTimeInterval(-100000000)
    
    // Public thread-safe accessors preserving existing API
    static var Weekdays: [Double]? {
        get {
            return probabilityQueue.sync { _Weekdays }
        }
        set {
            probabilityQueue.sync { _Weekdays = newValue }
        }
    }
    
    static var WeekdayTimes: [[Double]]? {
        get {
            return probabilityQueue.sync { _WeekdayTimes }
        }
        set {
            probabilityQueue.sync { _WeekdayTimes = newValue }
        }
    }
    
    static var didInitProbabilities: Bool {
        get {
            return probabilityQueue.sync { _didInitProbabilities }
        }
        set {
            probabilityQueue.sync { _didInitProbabilities = newValue }
        }
    }
    
    static var lastMassNotifUpdate: Date {
        get {
            return probabilityQueue.sync { _lastMassNotifUpdate }
        }
        set {
            probabilityQueue.sync { _lastMassNotifUpdate = newValue }
        }
    }
    
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
    
    // Constants
    private static let sunday = 0
    private static let saturday = 6
    private static let numDays = 7
    private static let startOfDay = 0
    private static let endOfDay = 95
    private static let day = 86400 // seconds in a day
    private static let week = day * 7
    private static let quarterHours = 4 // quarter hours in an hour
    private static let quarterMins  = 15 // Minutes in a quarter hour
    private static let numQuarterHours = 96 // Number of quarter hours (24 * 4)
    
    var id: String { identifier }
    
    var displayName: String {
        let name = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "No Name" : name
    }
    
    static func initProbabilities() {
        Weekdays = Array(repeating: 1.0, count: numDays)
        var normalWeekdayTime = [Double](repeating: 1.0, count: numQuarterHours)
        normalWeekdayTime.replaceSubrange(startOfDay...35, with: [Double](repeating: 0.0, count: 36)) // disable midnight to 9am
        normalWeekdayTime.replaceSubrange((21 * quarterHours) ..< numQuarterHours, with: [Double](repeating: 0.0, count: numQuarterHours - 21 * quarterHours))// disable 9pm to midnight
        WeekdayTimes = Array(repeating: normalWeekdayTime, count: numDays)
        Weekdays = normalize(input: Weekdays!)
        for i in sunday..<numDays {
            WeekdayTimes![i] = normalize(input: WeekdayTimes![i])
        }
        didInitProbabilities = true
    }
    
    static func normalize(input: [Double]) -> [Double] {
        let total = input.reduce(0, +)
        guard total > 0 else { return input }
        return input.map { $0 / total }
    }
    
    /// Filters WeekdayTimes using calendar events to mark busy intervals as zero probability, then normalizes each day.
    /// - Parameter completion: Closure called with the filtered and normalized WeekdayTimes arrays.
    static func filteredWeekdayTimesWithCalendar(completion: (() -> Void)? = nil) {
        let store = EKEventStore()
        store.requestFullAccessToEvents() { granted, error in
            guard granted, error == nil else {
                // If access is denied or error, return original WeekdayTimes or empty default
                print("Error: " + (error?.localizedDescription ?? "Access to calendar events denied"))
                completion?()
                return
            }
            let calendar = Calendar.current
            let now = Date()
            // Find the start of the current week, Sunday = weekday 1 in Gregorian calendar by default
            let weekStart = calendar.startOfDay(for: calendar.date(bySetting: .weekday, value: 1, of: now) ?? now)
            var filtered = WeekdayTimes ?? Array(repeating: Array(repeating: 1.0, count: numQuarterHours), count: numDays)
            
            for weekday in sunday..<numDays {
                let dayStart = calendar.date(byAdding: .day, value: weekday, to: weekStart)!
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                let predicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
                let events = store.events(matching: predicate).filter { !$0.isAllDay && $0.availability == .busy }
                
                // Iterate over each 15-minute interval
                for interval in startOfDay..<numQuarterHours {
                    let intervalStart = calendar.date(byAdding: .minute, value: interval * quarterMins, to: dayStart)!
                    let intervalEnd = calendar.date(byAdding: .minute, value: (interval+1) * quarterMins, to: dayStart)!
                    // Check if interval overlaps any event
                    let busy = events.contains { event in
                        event.startDate < intervalEnd && event.endDate > intervalStart
                    }
                    if busy {
                        filtered[weekday][interval] = 0.0
                    }
                }
                // Normalize after marking busy intervals
                filtered[weekday] = Contact.normalize(input: filtered[weekday])
            }
            Contact.WeekdayTimes = filtered
            completion?()
        }
    }
    
    static func updateProbabilities() {
        let now = Date()
        
        // Get current day
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: now) - 1 //
        
        // Get current time
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentQuarter = currentHour * quarterHours + currentMinute / quarterMins
        
        // Increase probability for current day and time
        if var weekday_times = Contact.WeekdayTimes {
            weekday_times[currentWeekday][currentQuarter] *= 1.5
            Contact.WeekdayTimes![currentWeekday] = Contact.normalize(input: weekday_times[currentWeekday])
        }
        
        if var weekdays = Contact.Weekdays {
            weekdays[currentWeekday] *= 1.05
            Contact.Weekdays = Contact.normalize(input: weekdays)
        }
    }
    
    static func weeklyNotifications(contacts: [Contact] = []) {
        if !Contact.didInitProbabilities {
            Contact.initProbabilities()
        }
        
        // Create copy of contact probabilities for weekdays
        guard let weekdays = Contact.Weekdays,
              let weekdayTimes = Contact.WeekdayTimes else {
            return
        }
        
        // Create copy of contact probabilities for weekdays
        let temp_weekdays = weekdays
        let temp_weekday_times = weekdayTimes.map { $0.map { $0 } }
        
        // Instead of directly copying WeekdayTimes, filter it based on calendar events asynchronously
        filteredWeekdayTimesWithCalendar() {
            let calendar = Calendar.current
            let now = Date()
            
            // Find the start of the current week, Sunday = weekday 1 in Gregorian calendar by default
            let weekStart = calendar.startOfDay(for: calendar.date(bySetting: .weekday, value: 1, of: now) ?? now)
            
            if Contact.lastMassNotifUpdate < Date().addingTimeInterval(-TimeInterval(day * 3)) {
                for contact in contacts {
                    contact.createNotification(now: weekStart, inBatch: true)
                }
                Contact.lastMassNotifUpdate = Date()
            }
            
            // Restore probabilities
            Contact.Weekdays = temp_weekdays
            Contact.WeekdayTimes = temp_weekday_times
        }
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
    
    func getNotifDate() -> String {
        let formatter = DateFormatter()
        
        // 3. Set the desired date format (using UTS Unicode Technical Standard patterns)
        formatter.dateFormat = "MMM dd yyyy @ h:mm a"
        
        // Optional: Set the locale for consistent formatting, especially with fixed formats
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        // 4. Convert the Date to a String
        let dateString = formatter.string(from: self.notifDate)
        
        return dateString
    }
    
    func createNotification(now: Date = Date(), inBatch: Bool = false) {
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
        
        if notifDate > Date().addingTimeInterval(60 * 30) { // 30 minute buffer
            // Date has not yet passed, skip scheduling
            print("Notification date has not yet passed for contact \(self.displayName), skipping scheduling.")
            return
        }
        
        if self.contact_type == .monthly {
            let sinceNotif = Date().timeIntervalSince(self.notifDate)
            var chance = 0.0
            if sinceNotif < Double(Contact.week) {
                chance = 0.0
            }
            else {
                chance = Double(sinceNotif) / Double(Contact.week * 5) // max chance after 5 weeks
            }
            if Double.random(in: 0..<1) > chance {
                print("Skipping monthly notification scheduling for contact \(self.displayName) based on probability.")
                return
            }
        }
        
        var selectedDay = Contact.sunday
        var selectedTime = Contact.startOfDay
        
        // Sample from Weekdays:
        var remAttempts = Contact.numDays
        while remAttempts > 0 {
            remAttempts -= 1
            let randNum = Double.random(in: 0..<1)
            var cumulative = 0.0
            selectedDay = Contact.sunday
            for (i, prob) in Contact.Weekdays!.enumerated() {
                cumulative += prob
                if randNum < cumulative {
                    selectedDay = i
                    break
                }
            }
            if Contact.WeekdayTimes![selectedDay].reduce(0, +) < 1.0 {
                Contact.Weekdays![selectedDay] = 0.0
                Contact.Weekdays = Contact.normalize(input: Contact.Weekdays!)
                continue
            }
            
            let randNumTime = Double.random(in: 0..<1)
            cumulative = 0.0
            selectedTime = Contact.startOfDay
            for (i, prob) in Contact.WeekdayTimes![selectedDay].enumerated() {
                cumulative += prob
                if randNumTime < cumulative {
                    selectedTime = i
                    break
                }
            }
            break
        }
        
        if remAttempts == 0 {
            print("Failed to select a valid notification time for contact \(self.displayName) after multiple attempts.")
            return
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
        dateComponents.hour = selectedTime / Contact.quarterHours
        dateComponents.minute = selectedTime % Contact.quarterHours * Contact.quarterMins + Int.random(in: Contact.startOfDay..<Contact.quarterMins)
        dateComponents.weekday = selectedDay + 1 // Sunday = 1, Saturday = 7 for dates
        
        guard let nextDate = Calendar.current.nextDate(
            after: now,
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
        let request = UNNotificationRequest(identifier: "SamHilbert.KeepKonnected.\(self.identifier)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
        
        // Modify temporary probabilities to avoid scheduling too close next time
        if (inBatch) {
            Contact.Weekdays![selectedDay] *= 0.5
            Contact.WeekdayTimes![selectedDay][max(Contact.startOfDay, selectedTime-3) ... min(selectedTime + 3, Contact.endOfDay)] = Array.SubSequence(repeating: 0.0, count: min(selectedTime + 3, Contact.endOfDay) - max(Contact.startOfDay, selectedTime-3) + 1)
            Contact.Weekdays = Contact.normalize(input: Contact.Weekdays!)
            Contact.WeekdayTimes![selectedDay] = Contact.normalize(input: Contact.WeekdayTimes![selectedDay])
        }
    }
    
    func createTestNotif() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Test Call \(self.displayName)"
        content.body = "This is a test reminder to Keep Konnected with \(self.givenName)!"
        content.sound = .default
        content.userInfo = ["contactID": self.identifier]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
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

