import SwiftUI
import Contacts
import SwiftData

struct HomeView: View {
    @State private var selectedType: ContactType = .weekly
    @EnvironmentObject var appState: AppState

    // Drive the NavigationStack programmatically
    @State private var path = NavigationPath()

    // Needed to resolve an id -> Contact for navigationDestination
    @Query(sort: [
        SortDescriptor(\Contact.order, order: .forward),
        SortDescriptor(\Contact.givenName, order: .forward)
    ]) private var contacts: [Contact]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // Contacts list (value-based navigation)
                ContactsView(contact_type: selectedType)

                // Bottom nav dock — hidden when a contact is selected (detail pushed)
                if appState.selectedContactID == nil {
                    VStack {
                        Spacer()
                        HStack(spacing: 100) {
                            // Weekly button
                            Button(action: { selectedType = .weekly }) {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Image(systemName: "line.horizontal.3")
                                            .font(.system(size: 32, weight: .semibold))
                                    }
                                    Text("Weekly")
                                        .font(.footnote)
                                }
                                .foregroundColor(selectedType == .weekly ? .accentColor : .secondary)
                            }
                            .accessibilityLabel("Weekly contacts")

                            // Monthly button
                            Button(action: { selectedType = .monthly }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 32, weight: .semibold))
                                    Text("Monthly")
                                        .font(.footnote)
                                }
                                .foregroundColor(selectedType == .monthly ? .accentColor : .secondary)
                            }
                            .accessibilityLabel("Monthly contacts")
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 60)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                    }
                    .animation(.default, value: selectedType)
                }
            }
            .padding(.bottom, safeAreaBottomPadding())

            // Map a contact id (String) to the detail view
            .navigationDestination(for: String.self) { id in
                if let contact = contacts.first(where: { $0.identifier == id }) {
                    ContactDetailView(contact: contact)
                } else {
                    Text("Contact not found")
                }
            }
            // When the appState id changes (e.g. notification tapped), reset and push the id
            .onChange(of: appState.selectedContactID) { id in
                if let id = id {
                    // Reset path so we override current detail stack, then push target id
                    path = NavigationPath()
                    path.append(id)
                } else {
                    // clear navigation when selection cleared
                    path = NavigationPath()
                }
            }
        }
    }

    // Helper to respect safe area on devices with home indicator
    private func safeAreaBottomPadding() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? scenes.first?.windows.first

        let inset = window?.safeAreaInsets.bottom ?? 0
        return max(inset, 32)
    }
}

#Preview("HomeView") {
    HomeView()
        .environmentObject(AppState())
        .modelContainer(for: [Contact.self])
}
