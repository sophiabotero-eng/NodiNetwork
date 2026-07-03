import Foundation
import CoreLocation

/// Minimal geohash encoder so "nearby creatives" can be queried in
/// Firestore (which has no native geo query) via a prefix range on a
/// string field — the standard workaround documented by Firebase for
/// approximate proximity search without a third-party extension.
enum Geohash {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    static func encode(latitude: Double, longitude: Double, precision: Int = 9) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var hash = ""
        var isEvenBit = true
        var bit = 0
        var char = 0

        while hash.count < precision {
            if isEvenBit {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude >= mid {
                    char = (char << 1) | 1
                    lonRange.0 = mid
                } else {
                    char = char << 1
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude >= mid {
                    char = (char << 1) | 1
                    latRange.0 = mid
                } else {
                    char = char << 1
                    latRange.1 = mid
                }
            }
            isEvenBit.toggle()

            bit += 1
            if bit == 5 {
                hash.append(base32[char])
                bit = 0
                char = 0
            }
        }
        return hash
    }

    /// Geohash prefix length to use for a given search radius, roughly
    /// following the standard geohash precision/cell-size table.
    static func precision(forRadiusKilometers radius: Double) -> Int {
        switch radius {
        case ..<0.15: return 8
        case ..<1.2: return 6
        case ..<5: return 5
        case ..<39: return 4
        case ..<156: return 3
        default: return 2
        }
    }
}
