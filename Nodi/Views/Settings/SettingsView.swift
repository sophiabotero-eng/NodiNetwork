import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showingSignOutConfirm = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: Binding(
                        get: { themeManager.preference },
                        set: { themeManager.preference = $0 }
                    )) {
                        ForEach(ColorSchemePreference.allCases) { preference in
                            Text(preference.label).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Account") {
                    LabeledContent("Email", value: session.currentUser?.email ?? "")
                    LabeledContent("Username", value: "@\(session.currentUser?.username ?? "")")
                    NavigationLink("Blocked Accounts") {
                        EmptyStateView(
                            icon: "hand.raised",
                            title: "No blocked accounts",
                            message: "Accounts you block will show up here."
                        )
                    }
                }

                Section("Notifications") {
                    NavigationLink("Notification Preferences") {
                        NotificationPreferencesView()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.appVersionString)
                    Link("Terms of Service", destination: URL(string: "https://nodi.app/terms")!)
                    Link("Privacy Policy", destination: URL(string: "https://nodi.app/privacy")!)
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        showingSignOutConfirm = true
                    }
                }

                Section {
                    Button("Delete Account", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                } footer: {
                    Text("Deleting your account permanently removes your profile, portfolio, and connections. This can't be undone.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Sign out of Nodi?", isPresented: $showingSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    session.signOut()
                    dismiss()
                }
            }
            .alert("Delete your account?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        if await viewModel.deleteAccount(session: session) {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("This permanently deletes your account. This can't be undone.")
            }
        }
    }
}

private struct NotificationPreferencesView: View {
    @AppStorage("nodi.notify.connections") private var notifyConnections = true
    @AppStorage("nodi.notify.followers") private var notifyFollowers = true
    @AppStorage("nodi.notify.messages") private var notifyMessages = true
    @AppStorage("nodi.notify.recommendations") private var notifyRecommendations = true

    var body: some View {
        Form {
            Toggle("New connection requests", isOn: $notifyConnections)
            Toggle("New followers", isOn: $notifyFollowers)
            Toggle("Messages", isOn: $notifyMessages)
            Toggle("Suggested connections", isOn: $notifyRecommendations)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await NotificationService.shared.requestAuthorization()
        }
    }
}

extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .environmentObject(SessionStore())
        .environmentObject(ThemeManager())
}
