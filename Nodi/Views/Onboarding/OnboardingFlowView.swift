import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = OnboardingViewModel()
    @FocusState private var focusedField: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                OnboardingProgressBar(step: viewModel.step)
                    .padding(.horizontal, NodiSpacing.lg)
                    .padding(.top, NodiSpacing.sm)

                ScrollView {
                    VStack(alignment: .leading, spacing: NodiSpacing.lg) {
                        Text(viewModel.step.title)
                            .font(NodiFont.title())
                            .foregroundStyle(NodiColor.primaryText)
                            .padding(.top, NodiSpacing.lg)

                        stepContent

                        if let errorMessage = viewModel.errorMessage {
                            ErrorBanner(message: errorMessage)
                        }
                    }
                    .padding(NodiSpacing.lg)
                }

                bottomBar
            }
            .background(NodiColor.background)
            .toolbar {
                if viewModel.step != .username {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            viewModel.goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .username:
            UsernameStepView(viewModel: viewModel)
        case .identity:
            IdentityStepView(viewModel: viewModel)
        case .photo:
            PhotoStepView(viewModel: viewModel)
        case .profession:
            ProfessionStepView(viewModel: viewModel)
        case .links:
            LinksStepView(viewModel: viewModel)
        case .software:
            SoftwareStepView(viewModel: viewModel)
        }
    }

    private var bottomBar: some View {
        VStack {
            if viewModel.step == .software {
                NodiButton(
                    title: "Finish setting up",
                    isLoading: viewModel.isSubmitting,
                    isDisabled: viewModel.isSubmitting
                ) {
                    Task { _ = await viewModel.submit(session: session) }
                }
            } else {
                NodiButton(
                    title: "Continue",
                    isDisabled: !viewModel.canAdvance
                ) {
                    viewModel.advance()
                }
            }
        }
        .padding(NodiSpacing.lg)
        .background(NodiColor.background)
    }
}

private struct OnboardingProgressBar: View {
    let step: OnboardingViewModel.Step

    var body: some View {
        HStack(spacing: NodiSpacing.xxs) {
            ForEach(OnboardingViewModel.Step.allCases, id: \.rawValue) { candidate in
                Capsule()
                    .fill(candidate.rawValue <= step.rawValue ? NodiColor.accent : NodiColor.divider)
                    .frame(height: 4)
            }
        }
        .animation(NodiAnimation.quickSpring, value: step)
    }
}

// MARK: - Steps

private struct UsernameStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: NodiSpacing.xs) {
            NodiTextField(
                title: "Username",
                text: $viewModel.username,
                placeholder: "yourname",
                autocapitalization: .never,
                errorMessage: errorText
            )
            .onChange(of: viewModel.username) { _, _ in viewModel.onUsernameChanged() }

            statusLabel
            Text("Lowercase letters, numbers, and underscores. 3–20 characters.")
                .font(NodiFont.caption())
                .foregroundStyle(NodiColor.tertiaryText)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch viewModel.usernameStatus {
        case .checking:
            Label("Checking availability…", systemImage: "clock")
                .font(NodiFont.caption())
                .foregroundStyle(NodiColor.secondaryText)
        case .available:
            Label("Available", systemImage: "checkmark.circle.fill")
                .font(NodiFont.caption())
                .foregroundStyle(NodiColor.success)
        case .taken:
            EmptyView()
        case .invalid, .idle:
            EmptyView()
        }
    }

    private var errorText: String? {
        switch viewModel.usernameStatus {
        case .taken: return "That username is taken."
        case .invalid: return "3–20 lowercase letters, numbers, or underscores."
        default: return nil
        }
    }
}

private struct IdentityStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: NodiSpacing.md) {
            NodiTextField(title: "Full name", text: $viewModel.displayName, placeholder: "Ada Lovelace")
            NodiTextField(title: "Bio", text: $viewModel.bio, placeholder: "A short line about what you do")
        }
    }
}

private struct PhotoStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: NodiSpacing.lg) {
            NodiPhotoPickerButton(selectedImage: $viewModel.profilePhoto) {
                ZStack {
                    if let image = viewModel.profilePhoto {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Circle()
                            .fill(NodiColor.secondaryBackground)
                            .overlay(Image(systemName: "camera.fill").foregroundStyle(NodiColor.tertiaryText))
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
            }
            .frame(maxWidth: .infinity)

            NodiPhotoPickerButton(selectedImage: $viewModel.coverImage) {
                ZStack {
                    if let image = viewModel.coverImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: NodiRadius.md)
                            .fill(NodiColor.secondaryBackground)
                            .overlay(
                                VStack(spacing: NodiSpacing.xxs) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Add a cover image").font(NodiFont.caption())
                                }
                                .foregroundStyle(NodiColor.tertiaryText)
                            )
                    }
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: NodiRadius.md, style: .continuous))
            }

            Text("Optional — you can always add these later from Edit Profile.")
                .font(NodiFont.caption())
                .foregroundStyle(NodiColor.tertiaryText)
        }
    }
}

private struct ProfessionStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: NodiSpacing.md) {
            NodiTextField(title: "Profession", text: $viewModel.profession, placeholder: "Motion Designer")
            NodiTextField(title: "Location", text: $viewModel.location, placeholder: "Los Angeles, CA")

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
    }
}

private struct LinksStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: NodiSpacing.md) {
            NodiTextField(title: "Website", text: $viewModel.website, placeholder: "yourdomain.com", keyboardType: .URL, autocapitalization: .never)
            NodiTextField(title: "Instagram", text: $viewModel.instagramHandle, placeholder: "@handle", autocapitalization: .never)
            NodiTextField(title: "LinkedIn", text: $viewModel.linkedInHandle, placeholder: "in/handle", autocapitalization: .never)
            NodiTextField(title: "Behance", text: $viewModel.behanceHandle, placeholder: "behance.net/handle", autocapitalization: .never)
            Text("All optional — add what's relevant to your work.")
                .font(NodiFont.caption())
                .foregroundStyle(NodiColor.tertiaryText)
        }
    }
}

private struct SoftwareStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: NodiSpacing.xs)]

    var body: some View {
        VStack(alignment: .leading, spacing: NodiSpacing.md) {
            NodiTextField(title: "Add tool", text: $viewModel.softwareInput, placeholder: "Type and tap add")
            NodiButton(title: "Add", kind: .secondary, isDisabled: viewModel.softwareInput.trimmingCharacters(in: .whitespaces).isEmpty) {
                viewModel.addSoftware(viewModel.softwareInput)
            }

            if !viewModel.selectedSoftware.isEmpty {
                FlowLayout(spacing: NodiSpacing.xs) {
                    ForEach(viewModel.selectedSoftware, id: \.self) { software in
                        SoftwareChip(name: software) {
                            viewModel.removeSoftware(software)
                        }
                    }
                }
            }

            Text("SUGGESTIONS").font(NodiFont.caption(.semibold)).foregroundStyle(NodiColor.secondaryText)
            FlowLayout(spacing: NodiSpacing.xs) {
                ForEach(OnboardingViewModel.suggestedSoftware.filter { !viewModel.selectedSoftware.contains($0) }, id: \.self) { software in
                    Button {
                        viewModel.addSoftware(software)
                    } label: {
                        Text(software)
                            .font(NodiFont.subheadline())
                            .padding(.horizontal, NodiSpacing.sm)
                            .padding(.vertical, NodiSpacing.xxs)
                            .background(NodiColor.secondaryBackground)
                            .clipShape(Capsule())
                            .foregroundStyle(NodiColor.primaryText)
                    }
                }
            }
        }
    }
}

private struct SoftwareChip: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: NodiSpacing.xxs) {
            Text(name).font(NodiFont.subheadline())
            Button(action: onRemove) {
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

#Preview {
    OnboardingFlowView()
        .environmentObject(SessionStore())
}
