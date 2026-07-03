import SwiftUI

struct NodiAvatarView: View {
    let urlString: String?
    var size: CGFloat = 44
    var showsOnlineIndicator: Bool = false
    var isOnline: Bool = false
    var isVerified: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RemoteImage(urlString: urlString) {
                Circle()
                    .fill(NodiColor.secondaryBackground)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(NodiColor.tertiaryText)
                            .font(.system(size: size * 0.4))
                    )
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(NodiColor.divider, lineWidth: 0.5))

            if showsOnlineIndicator {
                Circle()
                    .fill(isOnline ? NodiColor.success : NodiColor.tertiaryText)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().stroke(NodiColor.background, lineWidth: 2))
            }

            if isVerified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: size * 0.26))
                    .foregroundStyle(NodiColor.accent)
                    .background(Circle().fill(NodiColor.background).frame(width: size * 0.3, height: size * 0.3))
                    .offset(x: 2, y: showsOnlineIndicator ? -(size * 0.3) : 2)
            }
        }
    }
}

/// A minimal, dependency-free async image loader with an in-memory cache.
/// Swapping this for `AsyncImage` alone would re-fetch on every scroll
/// recycle; this keeps decoded images around for the session.
struct RemoteImage<Placeholder: View>: View {
    let urlString: String?
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .task(id: urlString) {
            await load()
        }
    }

    private func load() async {
        guard let urlString, let url = URL(string: urlString) else {
            image = nil
            return
        }
        if let cached = ImageMemoryCache.shared.image(for: urlString) {
            image = cached
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let downloaded = UIImage(data: data) else { return }
            ImageMemoryCache.shared.insert(downloaded, for: urlString)
            image = downloaded
        } catch {
            // Leave placeholder showing; caller can retry via `.task(id:)`
            // re-running when `urlString` changes.
        }
    }
}

final class ImageMemoryCache {
    static let shared = ImageMemoryCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 256 * 1024 * 1024
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}
