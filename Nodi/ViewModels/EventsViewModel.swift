import Foundation

@MainActor
final class EventsViewModel: ObservableObject {
    @Published var upcomingEvents: [NodiEvent] = []
    @Published var nearbyEvents: [NodiEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadUpcoming() async {
        isLoading = true
        defer { isLoading = false }
        do {
            upcomingEvents = try await EventRepository.shared.fetchUpcoming()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadNearby() async {
        isLoading = true
        defer { isLoading = false }
        LocationService.shared.requestPermission()
        guard let location = try? await LocationService.shared.requestOneShotLocation() else {
            errorMessage = "Turn on location access to discover nearby events."
            return
        }
        do {
            let precision = Geohash.precision(forRadiusKilometers: 40)
            let prefix = Geohash.encode(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, precision: precision)
            nearbyEvents = try await EventRepository.shared.fetchNearby(geohashPrefix: prefix)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleAttendance(_ event: NodiEvent, uid: String) async {
        guard let id = event.id else { return }
        let attending = event.attendeeIds.contains(uid)
        try? await EventRepository.shared.toggleAttendance(eventId: id, uid: uid, attending: !attending)
        await loadUpcoming()
    }
}
