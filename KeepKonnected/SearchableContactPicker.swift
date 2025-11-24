//
//  SearchableContactPicker.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/23/25.
//  AI Usage: Largely written by AI
//
import SwiftUI
import Contacts
import UIKit

struct SearchableContactPicker: View {
    var onSelect: ([CNContact]) -> Void
    @Environment(\.presentationMode) private var presentationMode

    @State private var allItems: [ContactItem] = []
    @State private var filteredItems: [ContactItem] = []
    @State private var searchText: String = ""
    @State private var selectedIDs = Set<String>()
    @State private var isLoading = true
    private let store = CNContactStore()

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading Contacts…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            HStack(spacing: 12) {
                                if selectedIDs.contains(item.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                }
                                if let img = item.thumbnailImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .frame(width: 44, height: 44)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                        .overlay(Text(String(item.displayName.prefix(1))).font(.headline))
                                }

                                VStack(alignment: .leading) {
                                    Text(item.displayName).font(.body)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(id: item.id)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
                    .onChange(of: searchText) { _ in filter() }
                }
            }
            .navigationTitle("Import Contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                        onSelect([])
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let selected = allItems.filter { selectedIDs.contains($0.id) }.map { $0.contact }
                        presentationMode.wrappedValue.dismiss()
                        onSelect(selected)
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
            .onAppear(perform: fetchContacts)
        }
    }

    private func toggleSelection(id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func fetchContacts() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let keys: [CNKeyDescriptor] = [
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor
            ]

            var results: [CNContact] = []
            let request = CNContactFetchRequest(keysToFetch: keys)
            request.sortOrder = .userDefault

            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    results.append(contact)
                }
            } catch {
                print("Contact fetch error: \(error)")
            }

            let items = results.map { ContactItem(contact: $0) }

            DispatchQueue.main.async {
                self.allItems = items
                self.filteredItems = items
                self.isLoading = false
            }
        }
    }

    private func filter() {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            filteredItems = allItems
            return
        }
        let lower = text.lowercased()
        filteredItems = allItems.filter { item in
            if item.displayName.lowercased().contains(lower) { return true }
            if let phone = item.contact.phoneNumbers.first?.value.stringValue.lowercased(), phone.contains(lower) { return true }
            if item.contact.emailAddresses.contains(where: { String($0.value).lowercased().contains(lower) }) { return true }
            return false
        }
    }
}
