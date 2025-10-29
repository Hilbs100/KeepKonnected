import SwiftUI
import Contacts
import SwiftData

struct HomeView: View {
    @State private var selectedType: ContactType = .weekly
    @State private var selectedContactID: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // Show the ContactView for the selected type (no internal NavigationStack)
                ContactsView(contact_type: selectedType, selection: $selectedContactID)

                // Bottom nav dock — hidden when a contact is selected (detail pushed)
                if selectedContactID == nil {
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
        .modelContainer(for: [Contact.self])
}
