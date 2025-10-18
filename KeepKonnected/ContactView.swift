import SwiftUI
import SwiftData
import Contacts
import ContactsUI
import UIKit

struct ContactView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Contact.givenName)]) private var contacts: [Contact]

    @State private var alertMessage: AlertMessage?
    @State private var showingPicker = false

    var body: some View {
        NavigationView {
            List {
                if contacts.isEmpty {
                    Text("No contacts imported yet. Tap \"Import from Phone\" to import from your device's contacts.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(contacts) { c in
                        HStack {
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
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("Friends and Family")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingPicker = true }) {
                        Label("Import from Phone", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingPicker) {
                ContactPicker { selected in
                    showingPicker = false
                    importContacts(selected)
                }
            }
            .alert(item: $alertMessage) { msg in
                Alert(title: Text("Import"), message: Text(msg.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    // MARK: - import logic (unchanged)
    private func importContacts(_ cnContacts: [CNContact]) {
        guard !cnContacts.isEmpty else { return }

        var imported = 0
        for cn in cnContacts {
            // dedupe by identifier
            if contacts.contains(where: { $0.identifier == cn.identifier }) { continue }

            let phones = cn.phoneNumbers.map { $0.value.stringValue }
            let emails = cn.emailAddresses.map { String($0.value) }
            let thumbnail = cn.thumbnailImageData

            let contact = Contact(identifier: cn.identifier,
                                  givenName: cn.givenName,
                                  familyName: cn.familyName,
                                  phoneNumbers: phones,
                                  emailAddresses: emails,
                                  thumbnailData: thumbnail)
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

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let c = contacts[index]
            modelContext.delete(c)
        }
        do { try modelContext.save() } catch { print("Delete save error: \(error)") }
    }
}

// MARK: - AlertMessage

fileprivate struct AlertMessage: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - ContactPicker (wrap CNContactPickerViewController)

struct ContactPicker: UIViewControllerRepresentable {
    var onSelect: ([CNContact]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // show relevant keys
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

struct ContactView_Previews: PreviewProvider {
    static var previews: some View {
        ContactView()
            .modelContainer(for: [Contact.self])
    }
}
