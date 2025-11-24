//
//  KeepKonnectedTests.swift
//  KeepKonnectedTests
//
//  Created by Samuel Hilbert on 10/17/25.
//

import Testing
import SwiftData
@testable import KeepKonnected

struct KeepKonnectedTests {

    @Test func addAndDeleteContact() async throws {
        // create an in-memory model container for the Contact model
                let container = try ModelContainer(for: Contact.self)
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
                    #expect(false)
                }

                // verify contact was removed
                let afterDelete = try context.fetch(FetchDescriptor<Contact>())
                #expect(afterDelete.count == initial)
                #expect(!afterDelete.contains(where: { $0.identifier == contact.identifier }))
        
    }

}
