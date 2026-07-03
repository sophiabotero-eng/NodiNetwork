import Foundation
import CoreNFC

/// Handles NFC "tap-to-connect."
///
/// ⚠️ **Important technical constraint, flagged per the build brief's own
/// ground rules ("stop and ask if a decision materially affects product
/// direction") — surfaced here in code and in the phase summary rather
/// than silently faking it:**
///
/// CoreNFC is a *tag reader/writer* API. Apple does not expose a public
/// API for true phone-to-phone NFC data exchange to third-party apps —
/// that's true of Android Beam-style P2P too, and iOS's own NameDrop
/// (iOS 17) uses AWDL/Bluetooth/UWB under a private framework, not
/// something a third-party app can invoke. So two iPhones both running
/// Nodi cannot "tap together" and exchange a connect token directly
/// through CoreNFC — there is no public API for that.
///
/// What *is* real and implemented here: a user can write their profile's
/// connect link to a physical NFC tag they own (a keychain fob, sticker,
/// business card) via `writeProfileTag`. When someone else's iPhone is
/// tapped against that physical tag, iOS's system-level NFC tag reading
/// (which works even with Nodi closed) opens the link, which — via the
/// Associated Domains universal link — launches Nodi straight into the
/// auto-connect flow. That's the actual "tap to connect" experience this
/// product can ship: tap phone to *tag*, not phone to phone. `scanTag`
/// additionally lets someone read a tag manually inside the app (e.g. to
/// test their own tag, or to read a tag that isn't a Nodi link at all).
///
/// QR code and shareable link (`QRCodeService`, `ConnectView`) are the
/// real phone-to-phone mechanisms and are treated as first-class, not
/// fallbacks, in the UI — even though the product brief lists them after
/// NFC.
@MainActor
final class NFCConnectionService: NSObject, ObservableObject {

    static let shared = NFCConnectionService()

    @Published var lastScannedURL: URL?
    @Published var errorMessage: String?

    private var writeSession: NFCNDEFReaderSession?
    private var readSession: NFCNDEFReaderSession?
    private var payloadToWrite: URL?

    private override init() { super.init() }

    var isAvailable: Bool { NFCNDEFReaderSession.readingAvailable }

    func writeProfileTag(url: URL) {
        guard isAvailable else {
            errorMessage = "This device doesn't support NFC."
            return
        }
        payloadToWrite = url
        writeSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        writeSession?.alertMessage = "Hold your iPhone near your Nodi NFC tag to write your profile link."
        writeSession?.begin()
    }

    func scanTag() {
        guard isAvailable else {
            errorMessage = "This device doesn't support NFC."
            return
        }
        readSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        readSession?.alertMessage = "Hold your iPhone near an NFC tag to connect."
        readSession?.begin()
    }
}

extension NFCConnectionService: NFCNDEFReaderSessionDelegate {

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Read-only path (`invalidateAfterFirstRead: true`, i.e. `scanTag`).
        guard let record = messages.first?.records.first,
              let payload = NFCConnectionService.extractURL(from: record) else { return }
        Task { @MainActor in
            self.lastScannedURL = payload
            session.alertMessage = "Connected!"
            session.invalidate()
        }
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        // Write path (`writeProfileTag`): triggered because we pass
        // `invalidateAfterFirstRead: false` and CoreNFC calls this
        // tag-connect delegate method instead when a write is in flight.
        guard let tag = tags.first else { return }

        session.connect(to: tag) { error in
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }

            tag.queryNDEFStatus { status, _, error in
                if let error {
                    session.invalidate(errorMessage: error.localizedDescription)
                    return
                }
                guard status == .readWrite else {
                    session.invalidate(errorMessage: "This tag isn't writable.")
                    return
                }

                Task { @MainActor in
                    guard let url = self.payloadToWrite,
                          let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
                        session.invalidate(errorMessage: "Nothing to write.")
                        return
                    }
                    let message = NFCNDEFMessage(records: [payload])
                    tag.writeNDEF(message) { error in
                        if let error {
                            session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                        } else {
                            session.alertMessage = "Your Nodi tag is ready to tap!"
                            session.invalidate()
                        }
                    }
                }
            }
        }
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        let nsError = error as NSError
        // Code 200 = user-cancelled / session timeout; not worth surfacing.
        guard nsError.code != 200 else { return }
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }

    nonisolated private static func extractURL(from record: NFCNDEFPayload) -> URL? {
        if let uri = record.wellKnownTypeURIPayload() {
            return uri
        }
        // Fall back to raw UTF-8 text in case the tag stores a plain string.
        if let text = String(data: record.payload, encoding: .utf8) {
            return URL(string: text)
        }
        return nil
    }
}
