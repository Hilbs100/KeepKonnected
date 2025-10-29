//
//  Item.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/17/25.
//

import Foundation
import SwiftData
import Contacts

enum ContactType: Int, Codable {
    case weekly = 0
    case monthly = 1
}

@Model
final class Contact: Identifiable, Equatable {
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
    
    func refresh () {
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
    
    static func == (lhs: Contact, rhs: Contact) -> Bool {
        lhs.id == rhs.id
    }
}
