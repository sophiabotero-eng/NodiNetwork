import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ProjectEditorView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel: ProjectEditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var videoPickerItem: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var showingDeleteConfirm = false

    init(owner: NodiUser, existing: PortfolioProject?) {
        _viewModel = StateObject(wrappedValue: ProjectEditorViewModel(owner: owner, existing: existing))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NodiSpacing.lg) {
                    mediaSection

                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    NodiTextField(title: "Title", text: $viewModel.title, placeholder: "Project title")
                    NodiTextField(title: "Description", text: $viewModel.projectDescription, placeholder: "What is this project about?")

                    Stepper("Year: \(String(viewModel.year))", value: $viewModel.year, in: 1990...2100)
                        .font(NodiFont.body())

                    chipInputSection(
                        title: "Tags",
                        input: $viewModel.tagInput,
                        items: viewModel.tags,
                        onAdd: viewModel.addTag,
                        onRemove: viewModel.removeTag
                    )

                    chipInputSection(
                        title: "Software Used",
                        input: $viewModel.softwareInput,
                        items: viewModel.softwareUsed,
                        onAdd: viewModel.addSoftware,
                        onRemove: viewModel.removeSoftware
                    )

                    collaboratorsSection

                    VStack(spacing: NodiSpacing.sm) {
                        NodiButton(title: "Save as Draft", kind: .secondary, isLoading: viewModel.isSaving) {
                            Task {
                                await viewModel.saveDraft(session: session)
                                if viewModel.didSave { dismiss() }
                            }
                        }
                        NodiButton(title: "Publish", isLoading: viewModel.isSaving, isDisabled: !viewModel.canPublish) {
                            Task {
                                await viewModel.publish(session: session)
                                if viewModel.didSave { dismiss() }
                            }
                        }
                        if viewModel.isEditingExisting {
                            NodiButton(title: "Delete Project", kind: .destructive) {
                                showingDeleteConfirm = true
                            }
                        }
                    }
                    .padding(.top, NodiSpacing.sm)
                }
                .padding(NodiSpacing.lg)
            }
            .background(NodiColor.background)
            .navigationTitle(viewModel.isEditingExisting ? "Edit Project" : "New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Delete this project?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.delete()
                        if viewModel.didDelete { dismiss() }
                    }
                }
            } message: {
                Text("This can't be undone.")
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf]) { result in
                if case .success(let url) = result {
                    Task { await viewModel.addPDF(fileURL: url) }
                }
            }
            .onChange(of: photoPickerItems) { _, items in
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                            await viewModel.addImage(image)
                        }
                    }
                    photoPickerItems = []
                }
            }
            .onChange(of: videoPickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let video = try? await item.loadTransferable(type: VideoTransferable.self) {
                        await viewModel.addVideo(fileURL: video.url)
                    }
                    videoPickerItem = nil
                }
            }
        }
    }

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: NodiSpacing.sm) {
            Text("Media").font(NodiFont.headline())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NodiSpacing.sm) {
                    ForEach(viewModel.mediaItems) { item in
                        MediaThumbnailTile(item: item, isCover: item.url == viewModel.coverImageURL) {
                            viewModel.setCover(item)
                        } onRemove: {
                            viewModel.removeMedia(item)
                        }
                    }

                    if viewModel.isUploadingMedia {
                        ZStack {
                            NodiColor.secondaryBackground
                            ProgressView(value: viewModel.uploadProgress)
                                .frame(width: 60)
                        }
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: NodiRadius.sm, style: .continuous))
                    }
                }
            }

            HStack(spacing: NodiSpacing.sm) {
                PhotosPicker(selection: $photoPickerItems, maxSelectionCount: 10, matching: .images) {
                    MediaAddButton(icon: "photo.on.rectangle.angled", label: "Photos")
                }
                PhotosPicker(selection: $videoPickerItem, matching: .videos) {
                    MediaAddButton(icon: "video", label: "Video")
                }
                Button {
                    showingFileImporter = true
                } label: {
                    MediaAddButton(icon: "doc.richtext", label: "PDF")
                }
            }
        }
    }

    private func chipInputSection(
        title: String,
        input: Binding<String>,
        items: [String],
        onAdd: @escaping (String) -> Void,
        onRemove: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: NodiSpacing.xs) {
            Text(title).font(NodiFont.headline())
            HStack {
                NodiTextField(title: "", text: input, placeholder: "Add \(title.lowercased())")
                NodiButton(title: "Add", kind: .secondary, isDisabled: input.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty) {
                    onAdd(input.wrappedValue)
                }
                .fixedSize()
            }
            FlowLayout(spacing: NodiSpacing.xs) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: NodiSpacing.xxs) {
                        Text(item).font(NodiFont.subheadline())
                        Button { onRemove(item) } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                        }
                    }
                    .padding(.horizontal, NodiSpacing.sm)
                    .padding(.vertical, NodiSpacing.xxs)
                    .background(NodiColor.secondaryBackground)
                    .clipShape(Capsule())
                    .foregroundStyle(NodiColor.primaryText)
                }
            }
        }
    }

    private var collaboratorsSection: some View {
        VStack(alignment: .leading, spacing: NodiSpacing.xs) {
            Text("Collaborators").font(NodiFont.headline())
            NodiTextField(title: "", text: $viewModel.collaboratorSearchQuery, placeholder: "Search by name or username")
                .onChange(of: viewModel.collaboratorSearchQuery) { _, _ in
                    Task { await viewModel.searchCollaborators() }
                }

            if !viewModel.collaboratorResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.collaboratorResults) { user in
                        Button {
                            viewModel.addCollaborator(user)
                        } label: {
                            HStack {
                                NodiAvatarView(urlString: user.profilePhotoURL, size: 32)
                                Text(user.displayName).foregroundStyle(NodiColor.primaryText)
                                Spacer()
                            }
                            .padding(.vertical, NodiSpacing.xxs)
                        }
                    }
                }
            }

            FlowLayout(spacing: NodiSpacing.xs) {
                ForEach(viewModel.collaborators) { collaborator in
                    HStack(spacing: NodiSpacing.xxs) {
                        Text(collaborator.name).font(NodiFont.subheadline())
                        Button { viewModel.removeCollaborator(collaborator) } label: {
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

private struct MediaAddButton: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
            Text(label).font(NodiFont.caption())
        }
        .foregroundStyle(NodiColor.accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, NodiSpacing.sm)
        .background(NodiColor.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: NodiRadius.sm, style: .continuous))
    }
}

private struct MediaThumbnailTile: View {
    let item: ProjectMediaItem
    let isCover: Bool
    let onSetCover: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RemoteImage(urlString: item.thumbnailURL ?? item.url) {
                NodiColor.secondaryBackground
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: NodiRadius.sm, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                if item.kind != .image {
                    Image(systemName: item.kind == .video ? "play.fill" : "doc.fill")
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
            .overlay {
                if isCover {
                    RoundedRectangle(cornerRadius: NodiRadius.sm, style: .continuous)
                        .strokeBorder(NodiColor.accent, lineWidth: 3)
                }
            }
            .onTapGesture(perform: onSetCover)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .padding(4)
            }
        }
    }
}
