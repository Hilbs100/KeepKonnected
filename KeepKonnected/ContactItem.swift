//
//  ContactItem.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/23/25.
//  No AI was used for this
//

import Contacts
import UIKit

struct ContactItem: Identifiable {
    let contact: CNContact
    var id: String { contact.identifier }

    var displayName: String {
        let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "No Name" : name
    }

    var firstPhoneOrEmail: String? {
        if let phone = contact.phoneNumbers.first?.value.stringValue { return phone }
        if let email = contact.emailAddresses.first?.value as String? { return email }
        return nil
    }

    var thumbnailImage: UIImage? {
        guard let data = contact.thumbnailImageData else { return nil }
        return UIImage(data: data)
    }
}
