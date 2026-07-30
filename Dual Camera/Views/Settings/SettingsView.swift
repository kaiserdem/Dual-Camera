//
//  SettingsView.swift
//  Dual Camera
//

import SwiftUI

struct SettingsView: View {
    private let rateURL = URL(string: "https://apps.apple.com/app/id000000000")!
    private let privacyURL = URL(string: "https://example.com/privacy")!
    private let termsURL = URL(string: "https://example.com/terms")!
    private let contactURL = URL(string: "mailto:support@example.com")!
    private let shareText = "Check out Dual Camera — shoot with front and back cameras at once!"

    var body: some View {
        List {
            Section("Feedback") {
                Link(destination: rateURL) {
                    Label("Rate App", systemImage: "star.fill")
                }

                ShareLink(item: shareText) {
                    Label("Share App", systemImage: "square.and.arrow.up")
                }

                Link(destination: contactURL) {
                    Label("Contact Us", systemImage: "envelope.fill")
                }
            }

            Section("Legal") {
                Link(destination: privacyURL) {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                }

                Link(destination: termsURL) {
                    Label("Terms of Use", systemImage: "doc.text.fill")
                }

                LabeledContent("Version", value: "1.0")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
