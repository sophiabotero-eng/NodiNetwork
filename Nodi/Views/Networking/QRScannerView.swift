import SwiftUI
import VisionKit

/// Thin wrapper around VisionKit's `DataScannerViewController` — chosen
/// over hand-rolled `AVCaptureSession` + `AVCaptureMetadataOutput` because
/// it's a system-maintained, robust QR/barcode reader with none of the
/// manual camera-session lifecycle bugs a custom implementation would risk
/// getting wrong without being able to test on-device here.
struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (URL) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (URL) -> Void

        init(onScan: @escaping (URL) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue, let url = URL(string: payload) {
                    onScan(url)
                    return
                }
            }
        }
    }
}

struct QRScannerScreen: View {
    let onScan: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            QRScannerView { url in
                onScan(url)
                dismiss()
            }
            .ignoresSafeArea()
            .navigationTitle("Scan to Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
