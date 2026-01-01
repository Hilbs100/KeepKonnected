// swift
//  ContactDetailView.swift
//  AI Usage: This page was drafted largely with AI, other than minor UI tweaks.
import SwiftUI
import UIKit

struct ContactDetailView: View {
    let contact: Contact
    @Environment(\.dismiss) private var dismiss

    private var primaryPhone: String? { contact.phoneNumbers.first }
    private func sanitizedPhone(_ s: String) -> String {
        String(s.filter { "+0123456789".contains($0) })
    }
    private func call(phone: String) {
        let tel = "tel://\(sanitizedPhone(phone))"
        if let url = URL(string: tel), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 12) {
                    if let data = contact.thumbnailData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .overlay(Text(String(contact.displayName.prefix(1))).font(.largeTitle))
                    }

                    Text(contact.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top, 24)

                // Details
                VStack(alignment: .leading, spacing: 12) {
                    if !contact.phoneNumbers.isEmpty {
                        Text("Phone").font(.headline)
                        ForEach(contact.phoneNumbers, id: \.self) { number in
                            HStack {
                                Text(number)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Button(action: { call(phone: number) }) {
                                    Image(systemName: "phone.fill")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Circle().fill(Color.accentColor))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Call \(contact.displayName)")
                            }
                        }
                    }

                    if !contact.emailAddresses.isEmpty {
                        Divider()
                        Text("Email").font(.headline)
                        ForEach(contact.emailAddresses, id: \.self) { email in
                            HStack {
                                Text(email).foregroundStyle(.primary)
                                Spacer()
                                Button(action: {
                                    if let url = URL(string: "mailto:\(email)") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Circle().fill(Color.accentColor))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Email \(contact.displayName)")
                            }
                        }
                    }
                    if contact.notifDate > Date() {
                        Divider()
                        Text("Upcoming Reminder").font(.headline)
                        Text(contact.getNotifDate())
                            .foregroundStyle(.primary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

                Spacer()

                // Call button centered at bottom spanning 3/5 of width
                if let phone = primaryPhone, !sanitizedPhone(phone).isEmpty {
                    Button(action: { call(phone: phone) }) {
                        Text("Call")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: geo.size.width * 0.6, height: 52)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
                    }
                    // safe area bottom padding so button sits above home indicator
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 16))
                    .accessibilityLabel("Call \(contact.displayName)")
                } else {
                    // disabled placeholder when no phone present
                    Text("No phone number")
                        .foregroundStyle(.secondary)
                        .frame(width: geo.size.width * 0.6, height: 52)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5)))
                    // safe area bottom padding so button sits above home indicator
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 16))
                }

                
            }
            .navigationTitle(contact.displayName)
            .navigationBarTitleDisplayMode(.inline)
        }
        // .onAppear(perform: contact.createNotification)
    }
}
