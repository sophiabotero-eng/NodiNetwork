import SwiftUI

struct CreateEventView: View {
    let host: NodiUser
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var startsAt = Date().addingTimeInterval(3600)
    @State private var coverImage: UIImage?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NodiSpacing.lg) {
                    NodiPhotoPickerButton(selectedImage: $coverImage) {
                        ZStack {
                            if let coverImage {
                                Image(uiImage: coverImage).resizable().aspectRatio(contentMode: .fill)
                            } else {
                                RoundedRectangle(cornerRadius: NodiRadius.md)
                                    .fill(NodiColor.secondaryBackground)
                                    .overlay(Image(systemName: "photo.badge.plus").foregroundStyle(NodiColor.tertiaryText))
                            }
                        }
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: NodiRadius.md, style: .continuous))
                    }

                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    NodiTextField(title: "Title", text: $title, placeholder: "Creative meetup")
                    NodiTextField(title: "Description", text: $description, placeholder: "What's happening?")
                    NodiTextField(title: "Location", text: $location, placeholder: "Studio address or venue")

                    DatePicker("Starts", selection: $startsAt)
                        .font(NodiFont.body())

                    NodiButton(title: "Host Event", isLoading: isSaving, isDisabled: title.trimmingCharacters(in: .whitespaces).isEmpty) {
                        Task { await save() }
                    }
                }
                .padding(NodiSpacing.lg)
            }
            .background(NodiColor.background)
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() async {
        guard let hostId = host.id else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            var coverImageURL: String?
            if let coverImage {
                coverImageURL = try await StorageService.shared.uploadImage(coverImage, kind: .coverImage, ownerId: hostId).absoluteString
            }

            var geohash: String?
            var latitude: Double?
            var longitude: Double?
            if let location = try? await LocationService.shared.requestOneShotLocation() {
                latitude = location.coordinate.latitude
                longitude = location.coordinate.longitude
                geohash = Geohash.encode(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            }

            let event = NodiEvent(
                title: title,
                eventDescription: description,
                coverImageURL: coverImageURL,
                hostId: hostId,
                hostDisplayName: host.displayName,
                hostPhotoURL: host.profilePhotoURL,
                location: location,
                geohash: geohash,
                latitude: latitude,
                longitude: longitude,
                startsAt: startsAt,
                endsAt: nil,
                attendeeIds: [hostId],
                createdAt: Date()
            )
            try await EventRepository.shared.create(event)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
