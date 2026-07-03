import Foundation
import CoreLocation

struct DiscoveryFilters: Equatable {
    var profession = ""
    var location = ""
    var school = ""
    var company = ""
    var software = ""
    var availability: AvailabilityStatus?

    var isEmpty: Bool {
        profession.isEmpty && location.isEmpty && school.isEmpty && company.isEmpty && software.isEmpty && availability == nil
    }
}

@MainActor
final class DiscoveryViewModel: ObservableObject {

    @Published var searchQuery = ""
    @Published var filters = DiscoveryFilters()
    @Published var searchResults: [NodiUser] = []
    @Published var nearbyUsers: [NodiUser] = []
    @Published var isLoading = false
    @Published var isLoadingNearby = false
    @Published var errorMessage: String?
    @Published var showingFilters = false

    private var currentUserId: String?
    private var searchTask: Task<Void, Never>?

    func onSearchQueryChanged(currentUserId: String?) {
        self.currentUserId = currentUserId
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await runSearch()
        }
    }

    func runSearch() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var results: [NodiUser]
            if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                results = try await UserRepository.shared.searchUsers(matching: searchQuery)
            } else if !filters.isEmpty {
                results = try await UserRepository.shared.fetchDiscoveryPool()
            } else {
                results = []
            }

            results = apply(filters: filters, to: results)
            searchResults = results.filter { $0.id != currentUserId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadNearby(currentUserId: String?) async {
        self.currentUserId = currentUserId
        isLoadingNearby = true
        defer { isLoadingNearby = false }

        LocationService.shared.requestPermission()
        guard let location = try? await LocationService.shared.requestOneShotLocation() else {
            errorMessage = "Turn on location access to discover nearby creatives."
            return
        }

        if let uid = currentUserId {
            await LocationService.shared.updateUserLocation(uid: uid)
        }

        do {
            let precision = Geohash.precision(forRadiusKilometers: 25)
            let prefix = Geohash.encode(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, precision: precision)
            var results = try await UserRepository.shared.fetchUsers(geohashPrefix: prefix)
            results = results.filter { $0.id != currentUserId }
            results.sort { lhs, rhs in
                distance(from: location, to: lhs) < distance(from: location, to: rhs)
            }
            nearbyUsers = results
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func distance(from location: CLLocation, to user: NodiUser) -> CLLocationDistance {
        guard let lat = user.latitude, let lon = user.longitude else { return .greatestFiniteMagnitude }
        return location.distance(from: CLLocation(latitude: lat, longitude: lon))
    }

    private func apply(filters: DiscoveryFilters, to users: [NodiUser]) -> [NodiUser] {
        users.filter { user in
            if !filters.profession.isEmpty, !user.profession.localizedCaseInsensitiveContains(filters.profession) { return false }
            if !filters.location.isEmpty, !user.location.localizedCaseInsensitiveContains(filters.location) { return false }
            if !filters.school.isEmpty, !user.school.localizedCaseInsensitiveContains(filters.school) { return false }
            if !filters.company.isEmpty, !user.currentCompany.localizedCaseInsensitiveContains(filters.company) { return false }
            if !filters.software.isEmpty, !user.softwareUsed.contains(where: { $0.localizedCaseInsensitiveContains(filters.software) }) { return false }
            if let availability = filters.availability, user.availability != availability { return false }
            return true
        }
    }
}
