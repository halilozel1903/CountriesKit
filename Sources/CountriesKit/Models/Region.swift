import Foundation

/// The regions REST Countries groups countries in, as its `region` field spells them.
public enum Region: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case africa = "Africa"
    case americas = "Americas"
    case antarctic = "Antarctic"
    case asia = "Asia"
    case europe = "Europe"
    case oceania = "Oceania"

    public var id: Self { self }

    /// The display name, such as `Europe`.
    public var name: String { rawValue }

    /// The path segment for `/region/{region}`.
    var pathValue: String { rawValue.lowercased() }

    /// The region named `name`, ignoring case.
    public init?(named name: String) {
        let match = Region.allCases.first {
            $0.rawValue.caseInsensitiveCompare(name.trimmingCharacters(in: .whitespaces)) == .orderedSame
        }
        guard let match else { return nil }
        self = match
    }
}

/// A position on Earth.
public struct Coordinate: Hashable, Sendable, CustomStringConvertible {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// From the API's `[latitude, longitude]`; `nil` unless there are two numbers.
    public init?(_ latlng: [Double]?) {
        guard let latlng, latlng.count >= 2 else { return nil }
        self.init(latitude: latlng[0], longitude: latlng[1])
    }

    /// The great-circle distance to `other` in kilometres (haversine, mean Earth radius).
    public func distance(to other: Coordinate) -> Double {
        let radius = 6_371.0088
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * atan2(a.squareRoot(), (1 - a).squareRoot())
    }

    /// `39.0° N, 35.0° E`.
    public var description: String {
        let lat = String(format: "%.1f", abs(latitude)) + (latitude >= 0 ? "° N" : "° S")
        let lon = String(format: "%.1f", abs(longitude)) + (longitude >= 0 ? "° E" : "° W")
        return lat + ", " + lon
    }
}
