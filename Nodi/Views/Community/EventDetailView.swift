import SwiftUI

struct EventDetailView: View {
    @EnvironmentObject private var session: SessionStore
    let event: NodiEvent
    let onChange: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isUpdating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NodiSpacing.md) {
                    RemoteImage(urlString: event.coverImageURL) {
                        LinearGradient(colors: [NodiColor.accent.opacity(0.5), NodiColor.secondaryBackground], startPoint: .top, endPoint: .bottom)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: NodiRadius.md, style: .continuous))

                    Text(event.title).font(NodiFont.title())

                    Label(event.startsAt.formatted(date: .complete, time: .shortened), systemImage: "calendar")
                    if !event.location.isEmpty {
                        Label(event.location, systemImage: "mappin.and.ellipse")
                    }
                    Label("Hosted by \(event.hostDisplayName)", systemImage: "person")
                    Label("\(event.attendeeIds.count) attending", systemImage: "person.2")

                    if !event.eventDescription.isEmpty {
                        Text(event.eventDescription).font(NodiFont.body())
                    }

                    if let uid = session.currentUser?.id {
                        NodiButton(
                            title: event.attendeeIds.contains(uid) ? "I'm Attending" : "Attend",
                            kind: event.attendeeIds.contains(uid) ? .secondary : .primary,
                            isLoading: isUpdating
                        ) {
                            Task { await toggleAttendance(uid: uid) }
                        }
                    }
                }
                .font(NodiFont.subheadline())
                .foregroundStyle(NodiColor.secondaryText)
                .padding(NodiSpacing.lg)
            }
            .background(NodiColor.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func toggleAttendance(uid: String) async {
        guard let id = event.id else { return }
        isUpdating = true
        defer { isUpdating = false }
        let attending = event.attendeeIds.contains(uid)
        try? await EventRepository.shared.toggleAttendance(eventId: id, uid: uid, attending: !attending)
        onChange()
        dismiss()
    }
}
