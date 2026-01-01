// swift
// File: `KeepKonnected/ContactsView.swift`
// AI Usage: AI was used to create most of the code in this file with some modifications afterward by the author.
// These changes included the move(), refresh(), and delete() functions, as well as various UI tweaks and adjustments.


import SwiftUI
import SwiftData
import Contacts
import ContactsUI
import UIKit

struct ContactsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
            SortDescriptor(\Contact.order, order: .forward),
            SortDescriptor(\Contact.givenName, order: .forward)
        ]) private var contacts: [Contact]
    let contact_type: ContactType

    @State private var alertMessage: AlertMessage?
    @State private var showingPicker = false

    private var title: String {
        switch contact_type {
        case .weekly: return "Weekly Contacts"
        case .monthly: return "Monthly Contacts"
        }
    }

    private var emptyMessage: String {
        switch contact_type {
        case .weekly:
            return "Insert contacts you want to be reminded to contact approximately weekly."
        case .monthly:
            return "Insert contacts you want to be reminded to contact approximately monthly."
        }
    }

    var body: some View {
        ZStack {            
            List {
                let visibleContacts = contacts.filter { $0.contact_type == contact_type }
                
                if visibleContacts.isEmpty {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visibleContacts) { c in
                        // Use a NavigationLink as the row label directly (no hidden link)
                        NavigationLink(value: c.id) {
                            HStack (spacing: 12) {
                                // order number (1-based)
                                Text("\(c.order + 1)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .trailing)
                                if let data = c.thumbnailData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .frame(width: 44, height: 44)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                        .overlay(Text(String(c.displayName.prefix(1))).font(.headline))
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(c.displayName).font(.headline)
                                    if let firstPhone = c.phoneNumbers.first {
                                        Text(firstPhone).font(.subheadline).foregroundStyle(.secondary)
                                    } else if let firstEmail = c.emailAddresses.first {
                                        Text(firstEmail).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(c.displayName)
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                    .onAppear(perform: refreshContacts)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingPicker = true }) {
                    Label("Import from Phone", systemImage: "person.crop.circle.badge.plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingPicker) {
            SearchableContactPicker { selected in
                showingPicker = false
                importContacts(selected)
            }
        }
        .alert(item: $alertMessage) { msg in
            Alert(title: Text("Import"), message: Text(msg.message), dismissButton: .default(Text("OK")))
        }
        // navigation destination resolves the contact id to the actual Contact object
        .navigationDestination(for: String.self) { id in
            if let contact = contacts.first(where: { $0.id == id }) {
                ContactDetailView(contact: contact)
            } else {
                EmptyView()
            }
        }
        
    }

    // MARK: - import & delete logic (unchanged)
    private func importContacts(_ cnContacts: [CNContact]) {
        guard !cnContacts.isEmpty else { return }
        
        // find current max order for this contact_type
        let maxOrder = contacts.filter { $0.contact_type == contact_type }.map { $0.order }.max() ?? -1
        var nextOrder = maxOrder + 1
        
        var imported = 0
        for cn in cnContacts {
            let phones = cn.phoneNumbers.map { $0.value.stringValue }
            let emails = cn.emailAddresses.map { String($0.value) }
            let thumbnail = cn.thumbnailImageData
            
            let alreadyExists = contacts.contains { existing in
                if existing.identifier == cn.identifier { return true }
                if !Set(existing.phoneNumbers).isDisjoint(with: Set(phones)) { return true }
                if !Set(existing.emailAddresses).isDisjoint(with: Set(emails)) { return true }
                return false
            }
            if alreadyExists { continue }
            
            let contact = Contact(identifier: cn.identifier,
                                  givenName: cn.givenName,
                                  familyName: cn.familyName,
                                  phoneNumbers: phones,
                                  emailAddresses: emails,
                                  thumbnailData: thumbnail,
                                  type: contact_type,
                                  order: nextOrder)
            nextOrder += 1
            
            modelContext.insert(contact)
            imported += 1
        }
        
        do {
            try modelContext.save()
            let message = imported == 0 ? "No new contacts were imported." : "Imported \(imported) contact\(imported == 1 ? "" : "s")."
            alertMessage = AlertMessage(message: message)
        } catch {
            alertMessage = AlertMessage(message: "Failed to save contacts: \(error.localizedDescription)")
        }
    }
    
    private func refreshContacts() {
        for contact in contacts {
            contact.refresh()
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to refresh contacts: \(error)")
        }
    }
    
    private func move(from source: IndexSet, to destination: Int) {
        // build visible array (mutable)
        var visible = contacts.filter { $0.contact_type == contact_type }
        
        // apply move on the local array
        visible.move(fromOffsets: source, toOffset: destination)
        
        // assign new order values (0..n-1) and save
        for (index, contact) in visible.enumerated() {
            // only update if changed to avoid unnecessary saves
            if contact.order != index {
                contact.order = index
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed saving contact order: \(error)")
        }
    }
    
    private func delete(at offsets: IndexSet) {
        let visible = contacts.filter { $0.contact_type == contact_type }
        let idsToDelete = offsets.compactMap { idx -> String? in
            guard idx < visible.count else { return nil }
            return visible[idx].identifier
        }
        
        for id in idsToDelete {
            if let match = contacts.first(where: { $0.identifier == id }) {
                modelContext.delete(match)
            }
        }
        
        do {
            try modelContext.save()
            // renormalize order after deletion
            let remaining = contacts.filter { $0.contact_type == contact_type }.sorted { $0.order < $1.order }
            for (i, c) in remaining.enumerated() {
                if c.order != i { c.order = i }
            }
            try modelContext.save()
        } catch {
            print("Delete/save error: \(error)")
        }
    }


    // MARK: - AlertMessage & ContactPicker (unchanged)
    fileprivate struct AlertMessage: Identifiable {
        let id = UUID()
        let message: String
    }

    struct ContactPicker: UIViewControllerRepresentable {
        var onSelect: ([CNContact]) -> Void

        func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

        func makeUIViewController(context: Context) -> CNContactPickerViewController {
            let picker = CNContactPickerViewController()
            picker.delegate = context.coordinator
            picker.displayedPropertyKeys = [
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactPhoneNumbersKey,
                CNContactEmailAddressesKey,
                CNContactThumbnailImageDataKey
            ]
            return picker
        }

        func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

        class Coordinator: NSObject, CNContactPickerDelegate {
            var onSelect: ([CNContact]) -> Void
            init(onSelect: @escaping ([CNContact]) -> Void) { self.onSelect = onSelect }

            func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
                onSelect([contact])
            }

            func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
                onSelect(contacts)
            }

            func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
                onSelect([])
            }
        }
    }
}

//#Preview("ContactView - Weekly") {
//    ContactsView(contact_type: .weekly)
//        .modelContainer(for: Contact.self)
//}
//
//#Preview("ContactView - Monthly") {
//    ContactsView(contact_type: .monthly)
//        .modelContainer(for: Contact.self)
//}
//
//#Preview("ContactView - Weekly (Dark)") {
//    ContactsView(contact_type: .weekly)
//        .modelContainer(for: Contact.self)
//        .preferredColorScheme(.dark)
//}
//
//#Preview("ContactView - Monthly (Dark)") {
//    ContactsView(contact_type: .monthly)
//        .modelContainer(for: Contact.self)
//        .preferredColorScheme(.dark)
//}
