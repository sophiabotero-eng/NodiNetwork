import SwiftUI
import AuthenticationServices

struct AuthWelcomeView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showingEmailSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                NodiColor.background.ignoresSafeArea()

                VStack(spacing: NodiSpacing.xl) {
                    Spacer()

                    VStack(spacing: NodiSpacing.md) {
                        NodiLogoMark(size: 72)
                        Text("Nodi")
                            .font(NodiFont.largeTitle())
                            .foregroundStyle(NodiColor.primaryText)
                        Text("Your creative network,\nvisualized.")
                            .font(NodiFont.body())
                            .foregroundStyle(NodiColor.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    VStack(spacing: NodiSpacing.sm) {
                        if let errorMessage = viewModel.errorMessage {
                            ErrorBanner(message: errorMessage)
                        }

                        SignInWithAppleButton(.continue) { request in
                            viewModel.prepareAppleRequest(request)
                        } onCompletion: { result in
                            Task { await viewModel.handleAppleCompletion(result) }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: NodiRadius.md, style: .continuous))

                        NodiButton(
                            title: "Continue with Google",
                            kind: .secondary,
                            isLoading: viewModel.isLoading,
                            icon: "globe"
                        ) {
                            Task { await viewModel.signInWithGoogle() }
                        }

                        NodiButton(title: "Continue with Email", kind: .plain) {
                            showingEmailSheet = true
                        }
                    }

                    Text("By continuing you agree to Nodi's Terms of Service and Privacy Policy.")
                        .font(NodiFont.caption())
                        .foregroundStyle(NodiColor.tertiaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, NodiSpacing.lg)
                }
                .padding(NodiSpacing.lg)
            }
            .sheet(isPresented: $showingEmailSheet) {
                EmailAuthView()
            }
        }
    }
}

#Preview {
    AuthWelcomeView()
}
