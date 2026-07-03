import SwiftUI

struct EventsView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = EventsViewModel()
    @State private var mode: Mode = .upcoming
    @State private var showingCreateEvent = false
    @State private var selectedEvent: NodiEvent?

    private enum Mode: String, CaseIterable {
        case upcoming = "Upcoming"
        case nearby = "Nearby"
    }

    var body: some View {
        VStack(spacing: NodiSpacing.sm) {
            HStack {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Button {
                    showingCreateEvent = true
                } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(NodiColor.accent)
                }
            }
            .padding(.horizontal, NodiSpacing.lg)

            let events = mode == .upcoming ? viewModel.upcomingEvents : viewModel.nearbyEvents

            if viewModel.isLoading {
                ProgressView().padding(.top, NodiSpacing.xl)
            } else if events.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "No events yet",
                    message: mode == .upcoming ? "Be the first to host a creative meetup." : "No nearby events right now.",
                    actionTitle: "Host an Event"
                ) {
                    showingCreateEvent = true
                }
            } else {
                List(events) { event in
                    EventRow(event: event, isAttending: session.currentUser.map { event.attendeeIds.contains($0.id ?? "") } ?? false)
                        .onTapGesture { selectedEvent = event }
                }
                .listStyle(.plain)
            }
        }
        .padding(.top, NodiSpacing.sm)
        .task {
            await viewModel.loadUpcoming()
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .nearby { Task { await viewModel.loadNearby() } }
        }
        .sheet(isPresented: $showingCreateEvent, onDismiss: {
            Task { await viewModel.loadUpcoming() }
        }) {
            if let user = session.currentUser {
                CreateEventView(host: user)
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event) {
                Task { await viewModel.loadUpcoming() }
            }
        }
    }
}

private struct EventRow: View {
    let event: NodiEvent
    let isAttending: Bool

    var body: some View {
        HStack(spacing: NodiSpacing.sm) {
            RemoteImage(urlString: event.coverImageURL) {
                NodiColor.secondaryBackground
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: NodiRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(NodiFont.headline())
                Text(event.startsAt.formatted(date: .abbreviated, time: .shortened))
                    .font(NodiFont.caption())
                    .foregroundStyle(NodiColor.secondaryText)
                if !event.location.isEmpty {
                    Text(event.location).font(NodiFont.caption()).foregroundStyle(NodiColor.tertiaryText)
                }
            }
            Spacer()
            if isAttending {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(NodiColor.success)
            }
        }
        .padding(.vertical, NodiSpacing.xxs)
    }
}
