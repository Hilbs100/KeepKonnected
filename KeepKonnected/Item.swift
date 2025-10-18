//
//  Item.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/17/25.
//

import Foundation
import SwiftData

@Model
final class Contact: Identifiable {
    // the CNContact.identifier is stable and we keep it so we can dedupe imports
    var identifier: String
    var givenName: String
    var familyName: String
    var phoneNumbers: [String]
    var emailAddresses: [String]
    var thumbnailData: Data?

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
         thumbnailData: Data? = nil) {
        self.identifier = identifier
        self.givenName = givenName
        self.familyName = familyName
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.thumbnailData = thumbnailData
    }
}
