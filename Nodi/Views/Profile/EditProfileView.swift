import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel: EditProfileViewModel
    @Environment(\.dismiss) private var dismiss

    init(user: NodiUser) {
        _viewModel = StateObject(wrappedValue: EditProfileViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NodiSpacing.lg) {
                    photoSection

                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    VStack(spacing: NodiSpacing.md) {
                        NodiTextField(
                            title: "Username",
                            text: $viewModel.username,
                            autocapitalization: .never,
                            errorMessage: usernameError
                        )
                        .onChange(of: viewModel.username) { _, _ in viewModel.onUsernameChanged() }

                        NodiTextField(title: "Full name", text: $viewModel.displayName)
                        NodiTextField(title: "Bio", text: $viewModel.bio)
                        NodiTextField(title: "Profession", text: $viewModel.profession)
                        NodiTextField(title: "Location", text: $viewModel.location)
                        NodiTextField(title: "School", text: $viewModel.school)
                        NodiTextField(title: "Current Company", text: $viewModel.currentCompany)

                        VStack(alignment: .leading, spacing: NodiSpacing.xs) {
                            Text("AVAILABILITY").font(NodiFont.caption(.semibold)).foregroundStyle(NodiColor.secondaryText)
                            Picker("Availability", selection: $viewModel.availability) {
                                ForEach(AvailabilityStatus.allCases) { status in
                                    Text(status.label).tag(status)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    Divider().overlay(NodiColor.divider)

                    VStack(spacing: NodiSpacing.md) {
                        NodiTextField(title: "Website", text: $viewModel.website, keyboardType: .URL, autocapitalization: .never)
                        NodiTextField(title: "Instagram", text: $viewModel.instagramHandle, autocapitalization: .never)
                        NodiTextField(title: "LinkedIn", text: $viewModel.linkedInHandle, autocapitalization: .never)
                        NodiTextField(title: "Behance", text: $viewModel.behanceHandle, autocapitalization: .never)
                    }

                    Divider().overlay(NodiColor.divider)

                    softwareSection

                    NodiButton(
                        title: "Save Changes",
                        isLoading: viewModel.isSaving,
                        isDisabled: !viewModel.canSave
                    ) {
                        Task {
                            await viewModel.save(session: session)
                            if viewModel.didSave { dismiss() }
                        }
                    }
                }
                .padding(NodiSpacing.lg)
            }
            .background(NodiColor.background)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var photoSection: some View {
        ZStack(alignment: .bottomLeading) {
            NodiPhotoPickerButton(selectedImage: $viewModel.coverImage) {
                ZStack {
                    if let image = viewModel.coverImage {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        RemoteImage(urlString: viewModel.existingCoverImageURL) {
                            NodiColor.secondaryBackground
                        }
                    }
                    Color.black.opacity(0.15)
                    Image(systemName: "photo.badge.plus")
                        .foregroundStyle(.white)
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: NodiRadius.md, style: .continuous))
            }

            NodiPhotoPickerButton(selectedImage: $viewModel.profilePhoto) {
                ZStack {
                    if let image = viewModel.profilePhoto {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        RemoteImage(urlString: viewModel.existingProfilePhotoURL) {
                            NodiColor.secondaryBackground
                        }
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(NodiColor.background, lineWidth: 3))
            }
            .offset(x: NodiSpacing.md, y: 24)
        }
        .padding(.bottom, 24)
    }

    private var usernameError: String? {
        switch viewModel.usernameStatus {
        case .taken: return "That username is taken."
        case .invalid: return "3–20 lowercase letters, numbers, or underscores."
        default: return nil
        }
    }

    private var softwareSection: some View {
        VStack(alignment: .leading, spacing: NodiSpacing.sm) {
            NodiTextField(title: "Add tool", text: $viewModel.softwareInput)
            NodiButton(title: "Add", kind: .secondary, isDisabled: viewModel.softwareInput.trimmingCharacters(in: .whitespaces).isEmpty) {
                viewModel.addSoftware(viewModel.softwareInput)
            }
            FlowLayout(spacing: NodiSpacing.xs) {
                ForEach(viewModel.selectedSoftware, id: \.self) { software in
                    HStack(spacing: NodiSpacing.xxs) {
                        Text(software).font(NodiFont.subheadline())
                        Button { viewModel.removeSoftware(software) } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                        }
                    }
                    .padding(.horizontal, NodiSpacing.sm)
                    .padding(.vertical, NodiSpacing.xxs)
                    .background(NodiColor.accent.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundStyle(NodiColor.accent)
                }
            }
        }
    }
}
