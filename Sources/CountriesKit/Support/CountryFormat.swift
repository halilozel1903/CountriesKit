import Foundation

/// How ``CountryFormat/population(_:style:locale:)`` writes a number of people.
public enum PopulationStyle: Sendable, Hashable {
    /// `84.3M`, `1.4B`, `12.3K`; numbers under 1,000 in full.
    case compact
    /// `84.3 million`.
    case words
    /// `84,339,067`.
    case full
}

/// Formatting for the numbers a country page shows.
public enum CountryFormat {
    /// A population: `84.3M` (compact), `84.3 million` (words) or `84,339,067` (full).
    public static func population(_ value: Int, style: PopulationStyle = .compact, locale: Locale = .current) -> String {
        switch style {
        case .full:
            return value.formatted(.number.locale(locale))
        case .compact:
            return scaled(value, words: false, locale: locale)
        case .words:
            return scaled(value, words: true, locale: locale)
        }
    }

    /// An area in square kilometres: `783,562 km²`, `0.44 km²`.
    public static func area(_ squareKilometres: Double, locale: Locale = .current) -> String {
        let digits = squareKilometres < 10 ? 0...2 : 0...0
        return squareKilometres.formatted(.number.precision(.fractionLength(digits)).locale(locale)) + " km²"
    }

    /// People per square kilometre: `108 per km²`.
    public static func density(_ perSquareKilometre: Double, locale: Locale = .current) -> String {
        let digits = perSquareKilometre < 10 ? 0...1 : 0...0
        return perSquareKilometre.formatted(.number.precision(.fractionLength(digits)).locale(locale)) + " per km²"
    }

    /// A Gini index: `41.9 (2019)`.
    public static func gini(_ index: GiniIndex, locale: Locale = .current) -> String {
        index.value.formatted(.number.precision(.fractionLength(1)).locale(locale)) + " (" + String(index.year) + ")"
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

    private static func scaled(_ value: Int, words: Bool, locale: Locale) -> String {
        let magnitude = Double(value.magnitude)
        guard magnitude >= 1_000 else {
            return value.formatted(.number.locale(locale))
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
    /// ``population`` formatted, such as `84.3M`; `nil` when unknown.
    public func formattedPopulation(_ style: PopulationStyle = .compact, locale: Locale = .current) -> String? {
        population.map { CountryFormat.population($0, style: style, locale: locale) }
    }

    /// ``area`` formatted, such as `783,562 km²`; `nil` when unknown.
    public func formattedArea(locale: Locale = .current) -> String? {
        guard let area, area > 0 else { return nil }
        return CountryFormat.area(area, locale: locale)
    }
}
