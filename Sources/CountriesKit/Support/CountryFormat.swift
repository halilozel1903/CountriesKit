import Foundation

/// How ``CountryFormat`` writes a large number.
public enum NumberStyle: Sendable, Hashable {
    /// `783.6K`, `1.4M`; numbers under 1,000 in full.
    case compact
    /// `783.6 thousand`.
    case words
    /// `783,562`.
    case full
}

/// Formatting for the numbers a country page shows.
public enum CountryFormat {
    /// A count, such as `250` or, compact, `17.1M`.
    public static func number(_ value: Int, style: NumberStyle = .full, locale: Locale = .current) -> String {
        switch style {
        case .full:
            return value.formatted(.number.locale(locale))
        case .compact:
            return scaled(Double(value), words: false, locale: locale)
        case .words:
            return scaled(Double(value), words: true, locale: locale)
        }
    }

    /// An area in square kilometres: `783,562 km²`, `0.44 km²`, or compact `783.6K km²`.
    public static func area(_ squareKilometres: Double, style: NumberStyle = .full, locale: Locale = .current) -> String {
        switch style {
        case .full:
            let digits = squareKilometres < 10 ? 0...2 : 0...0
            return squareKilometres.formatted(.number.precision(.fractionLength(digits)).locale(locale)) + " km²"
        case .compact, .words:
            guard squareKilometres >= 1_000 else { return area(squareKilometres, style: .full, locale: locale) }
            return scaled(squareKilometres, words: style == .words, locale: locale) + " km²"
        }
    }

    /// A distance: `1,234 km`.
    public static func distance(_ kilometres: Double, locale: Locale = .current) -> String {
        kilometres.formatted(.number.precision(.fractionLength(0)).locale(locale)) + " km"
    }

    private static let units: [(divisor: Double, short: String, word: String)] = [
        (1_000_000_000, "B", " billion"),
        (1_000_000, "M", " million"),
        (1_000, "K", " thousand"),
    ]

    private static func scaled(_ value: Double, words: Bool, locale: Locale) -> String {
        let magnitude = value.magnitude
        guard magnitude >= 1_000 else {
            return value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
        }
        let sign = value < 0 ? "-" : ""
        var index = units.firstIndex { magnitude >= $0.divisor } ?? units.count - 1
        var rounded = (magnitude / units[index].divisor * 10).rounded() / 10
        // 999,950 rounds to 1,000.0K: say 1M instead.
        if rounded >= 1_000, index > 0 {
            index -= 1
            rounded = (magnitude / units[index].divisor * 10).rounded() / 10
        }
        let number = rounded.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
        return sign + number + (words ? units[index].word : units[index].short)
    }
}

extension Country {
    /// ``area`` formatted, such as `783,562 km²` or, compact, `783.6K km²`; `nil` when unknown.
    public func formattedArea(_ style: NumberStyle = .full, locale: Locale = .current) -> String? {
        guard let area, area > 0 else { return nil }
        return CountryFormat.area(area, style: style, locale: locale)
    }
}
