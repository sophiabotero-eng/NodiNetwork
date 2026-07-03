import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

enum QRCodeService {
    static func generate(from url: URL, size: CGFloat = 512) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "Q"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = size / outputImage.extent.width
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func connectURL(for user: NodiUser) -> URL? {
        guard let uid = user.id else { return nil }
        return URL(string: "https://nodi.app/connect/\(uid)")
    }
}
