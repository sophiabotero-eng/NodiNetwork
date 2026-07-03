import SwiftUI

struct EmailAuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NodiSpacing.md) {
                    Picker("Mode", selection: $viewModel.mode) {
                        Text("Sign In").tag(AuthViewModel.Mode.signIn)
                        Text("Create Account").tag(AuthViewModel.Mode.signUp)
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, NodiSpacing.sm)

                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    NodiTextField(
                        title: "Email",
                        text: $viewModel.email,
                        placeholder: "you@example.com",
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        autocapitalization: .never
                    )

                    NodiTextField(
                        title: "Password",
                        text: $viewModel.password,
                        placeholder: "At least 8 characters",
                        isSecure: true,
                        textContentType: viewModel.mode == .signUp ? .newPassword : .password
                    )

                    if viewModel.mode == .signUp {
                        NodiTextField(
                            title: "Confirm Password",
                            text: $viewModel.confirmPassword,
                            placeholder: "Re-enter your password",
                            isSecure: true,
                            textContentType: .newPassword
                        )
                    }

                    if viewModel.mode == .signIn {
                        Button("Forgot password?") {
                            Task { await viewModel.sendPasswordReset() }
                        }
                        .font(NodiFont.subheadline())
                        .foregroundStyle(NodiColor.accent)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    NodiButton(
                        title: viewModel.mode == .signIn ? "Sign In" : "Create Account",
                        isLoading: viewModel.isLoading,
                        isDisabled: !viewModel.isFormValid
                    ) {
                        Task { await viewModel.submitEmailForm() }
                    }
                    .padding(.top, NodiSpacing.xs)
                }
                .padding(NodiSpacing.lg)
            }
            .background(NodiColor.background)
            .navigationTitle(viewModel.mode == .signIn ? "Sign In" : "Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    EmailAuthView()
}
