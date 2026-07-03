import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var recorder = VoiceRecorderService()

    init(conversationId: String, currentUserId: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationId: conversationId, currentUserId: currentUserId))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: NodiSpacing.xs) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message, isMine: message.senderId == viewModel.currentUserId, isRead: isRead(message))
                                .id(message.id)
                        }
                        if viewModel.isOtherTyping {
                            TypingIndicatorBubble()
                        }
                    }
                    .padding(NodiSpacing.md)
                }
                .onChange(of: viewModel.messages) { _, messages in
                    guard let lastId = messages.last?.id else { return }
                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                ErrorBanner(message: errorMessage).padding(.horizontal, NodiSpacing.md)
            }

            inputBar
        }
        .background(NodiColor.background)
        .navigationTitle(viewModel.conversation?.other(than: viewModel.currentUserId)?.displayName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.startObserving() }
        .onDisappear { viewModel.stopObserving() }
    }

    private func isRead(_ message: ChatMessage) -> Bool {
        guard message.senderId == viewModel.currentUserId, let otherId = viewModel.conversation?.otherId(than: viewModel.currentUserId) else { return false }
        return message.readBy.contains(otherId)
    }

    private var inputBar: some View {
        HStack(spacing: NodiSpacing.sm) {
            if recorder.isRecording {
                HStack {
                    Image(systemName: "waveform").foregroundStyle(NodiColor.danger)
                    Text(String(format: "%.1fs", recorder.elapsedSeconds)).font(NodiFont.subheadline())
                    Spacer()
                    Button("Cancel") { recorder.cancel() }
                        .font(NodiFont.caption())
                }
                .padding(.horizontal, NodiSpacing.sm)
                .padding(.vertical, 10)
                .background(NodiColor.secondaryBackground)
                .clipShape(Capsule())
            } else {
                TextField("Message…", text: $viewModel.draftText, axis: .vertical)
                    .padding(.horizontal, NodiSpacing.sm)
                    .padding(.vertical, 10)
                    .background(NodiColor.secondaryBackground)
                    .clipShape(Capsule())
                    .onChange(of: viewModel.draftText) { _, _ in viewModel.onDraftChanged() }
            }

            if viewModel.draftText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    if recorder.isRecording {
                        if let result = recorder.stop() {
                            Task { await viewModel.sendVoiceMessage(url: result.url, duration: result.duration) }
                        }
                    } else {
                        Task { await recorder.requestPermissionAndStart() }
                    }
                } label: {
                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(recorder.isRecording ? NodiColor.danger : NodiColor.accent)
                }
            } else {
                Button {
                    Task { await viewModel.sendText() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(NodiColor.accent)
                }
            }
        }
        .padding(NodiSpacing.sm)
        .background(NodiColor.background)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let isRead: Bool
    @StateObject private var player = VoiceMessagePlayer()

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                Group {
                    if message.type == .text {
                        Text(message.text ?? "")
                            .font(NodiFont.body())
                    } else {
                        voiceBubble
                    }
                }
                .padding(.horizontal, NodiSpacing.sm)
                .padding(.vertical, 10)
                .background(isMine ? NodiColor.accent : NodiColor.secondaryBackground)
                .foregroundStyle(isMine ? .white : NodiColor.primaryText)
                .clipShape(RoundedRectangle(cornerRadius: NodiRadius.md, style: .continuous))

                if isMine {
                    Text(isRead ? "Read" : "Delivered")
                        .font(NodiFont.caption())
                        .foregroundStyle(NodiColor.tertiaryText)
                }
            }

            if !isMine { Spacer(minLength: 40) }
        }
    }

    private var voiceBubble: some View {
        HStack(spacing: NodiSpacing.xs) {
            Button {
                guard let urlString = message.voiceURL, let url = URL(string: urlString) else { return }
                if player.isPlaying {
                    player.stop()
                } else {
                    player.play(url: url)
                }
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
            }
            ProgressView(value: player.progress)
                .frame(width: 80)
            if let duration = message.voiceDurationSeconds {
                Text(String(format: "%.0fs", duration)).font(NodiFont.caption())
            }
        }
    }
}

private struct TypingIndicatorBubble: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(NodiColor.tertiaryText)
                    .frame(width: 6, height: 6)
                    .opacity(animate ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: animate)
            }
        }
        .padding(.horizontal, NodiSpacing.sm)
        .padding(.vertical, 10)
        .background(NodiColor.secondaryBackground)
        .clipShape(Capsule())
        .onAppear { animate = true }
    }
}
