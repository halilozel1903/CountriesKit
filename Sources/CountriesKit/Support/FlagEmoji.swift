import Foundation

/// Flag emoji from ISO 3166-1 alpha-2 codes, made of two regional indicator symbols.
public enum FlagEmoji {
    /// The flag for a two-letter code: `"TR"` gives 🇹🇷. `nil` unless the code is two ASCII
    /// letters (any case).
    public static func emoji(forRegionCode code: String) -> String? {
        let letters = Array(code.trimmingCharacters(in: .whitespaces).uppercased().unicodeScalars)
        guard letters.count == 2, letters.allSatisfy({ $0.value >= 65 && $0.value <= 90 }) else {
            return nil
        }
        var scalars = String.UnicodeScalarView()
        for letter in letters {
            guard let indicator = Unicode.Scalar(0x1F1E6 + letter.value - 65) else { return nil }
            scalars.append(indicator)
        }
        return String(scalars)
    }

    /// The two-letter code of a flag emoji: 🇹🇷 gives `"TR"`.
    public static func regionCode(forEmoji emoji: String) -> String? {
        let scalars = Array(emoji.unicodeScalars)
        guard scalars.count == 2, scalars.allSatisfy({ (0x1F1E6...0x1F1FF).contains($0.value) }) else {
            return nil
        }
        var letters = String.UnicodeScalarView()
        for scalar in scalars {
            guard let letter = Unicode.Scalar(scalar.value - 0x1F1E6 + 65) else { return nil }
            letters.append(letter)
        }
        return String(letters)
    }
}
