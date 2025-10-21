//
//  HomeView.swift
//  KeepKonnected
//
//  Created by Samuel Hilbert on 10/21/25.
//

import SwiftUI
import Contacts
import SwiftData

struct HomeView: View {
    @State private var selectedType: ContactType = .weekly

    var body: some View {
        ZStack {
            // Show the ContactView for the selected type
            ContactView(contact_type: selectedType)

            // Bottom nav dock
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
                .padding(.bottom, safeAreaBottomPadding())
            }
            .animation(.default, value: selectedType)
        }
    }

    // Helper to respect safe area on devices with home indicator
    private func safeAreaBottomPadding() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 16
    }
}

#Preview("HomeView") {
    HomeView()
        .modelContainer(for: [Contact.self])
}
