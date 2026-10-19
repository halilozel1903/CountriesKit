import Foundation

/// Flag images on [flagcdn.com](https://flagcdn.com), a free CDN that needs no key. Flags are
/// looked up by ISO 3166-1 alpha-2 code (``Country/cca2``), lower-cased.
public enum FlagCDN {
    /// The host the images are served from.
    public static let baseURL = URL(string: "https://flagcdn.com")!

    /// The PNG widths flagcdn.com serves, in pixels.
    public static let widths = [20, 40, 80, 160, 320, 640, 1280, 2560]

    /// A PNG flag, `https://flagcdn.com/w320/tr.png`, in the smallest served width at or above
    /// `width`. `nil` unless `regionCode` is two letters.
    public static func pngURL(regionCode: String, width: Int = 320) -> URL? {
        guard let code = normalized(regionCode) else { return nil }
        let chosen = widths.first(where: { $0 >= width }) ?? widths[widths.count - 1]
        return baseURL.appendingPathComponent("w" + String(chosen)).appendingPathComponent(code + ".png")
    }

    /// An SVG flag, `https://flagcdn.com/tr.svg`.
    public static func svgURL(regionCode: String) -> URL? {
        guard let code = normalized(regionCode) else { return nil }
        return baseURL.appendingPathComponent(code + ".svg")
    }

    private static func normalized(_ regionCode: String) -> String? {
        let code = regionCode.trimmingCharacters(in: .whitespaces).lowercased()
        guard code.count == 2, code.unicodeScalars.allSatisfy({ ("a"..."z").contains($0) }) else { return nil }
        return code
    }
}
