import SwiftUI

struct ConnectView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var viewModel: ConnectViewModel
    @State private var showingScanner = false
    @State private var showingShareSheet = false
    @State private var qrImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: NodiSpacing.lg) {
                if let user = session.currentUser {
                    myCodeCard(user: user)
                }

                VStack(spacing: NodiSpacing.sm) {
                    NodiButton(title: "Scan to Connect", icon: "qrcode.viewfinder") {
                        showingScanner = true
                    }

                    NodiButton(title: "Tap My NFC Tag", kind: .secondary, icon: "wave.3.right") {
                        guard let user = session.currentUser, let url = QRCodeService.connectURL(for: user) else { return }
                        viewModel.nfcService.writeProfileTag(url: url)
                    }

                    NodiButton(title: "Read an NFC Tag", kind: .secondary, icon: "sensor.tag.radiowaves.forward") {
                        viewModel.nfcService.scanTag()
                    }

                    if let user = session.currentUser, let url = QRCodeService.connectURL(for: user) {
                        ShareLink(item: url) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share My Link").font(NodiFont.headline())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(NodiColor.secondaryBackground)
                            .foregroundStyle(NodiColor.primaryText)
                            .clipShape(RoundedRectangle(cornerRadius: NodiRadius.md, style: .continuous))
                        }
                    }
                }

                Text("NFC tap works with a physical Nodi tag or card you've written your profile to — iPhones can't exchange data directly over NFC with each other, so scanning the QR code or sharing your link is the fastest way to connect phone-to-phone.")
                    .font(NodiFont.caption())
                    .foregroundStyle(NodiColor.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, NodiSpacing.md)

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                if let successMessage = viewModel.successMessage {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(NodiColor.success)
                }
            }
            .padding(NodiSpacing.lg)
        }
        .background(NodiColor.background)
        .navigationTitle("Connect")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingScanner) {
            QRScannerScreen { url in
                Task { await viewModel.resolve(url: url, source: .qrCode, currentUserId: session.currentUser?.id) }
            }
        }
    }

    private func myCodeCard(user: NodiUser) -> some View {
        NodiCard {
            VStack(spacing: NodiSpacing.md) {
                if let url = QRCodeService.connectURL(for: user), let image = QRCodeService.generate(from: url) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: NodiRadius.sm, style: .continuous))
                }
                VStack(spacing: 2) {
                    Text(user.displayName).font(NodiFont.headline())
                    Text("@\(user.username)").font(NodiFont.caption()).foregroundStyle(NodiColor.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

