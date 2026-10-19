import SwiftUI
import CountriesKit

/// A list row: the flag, the common name, the capital and the area.
///
/// ```swift
/// List(countries) { country in
///     CountryRow(country: country)
/// }
/// ```
public struct CountryRow: View {
    private let country: Country
    private let showsArea: Bool

    public init(country: Country, showsArea: Bool = true) {
        self.country = country
        self.showsArea = showsArea
    }

    public var body: some View {
        HStack(spacing: 14) {
            FlagImage(country: country)
                .frame(width: 48, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(country.commonName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                if let capital = country.primaryCapital {
                    Label(capital, systemImage: "building.columns")
                        .labelStyle(CompactLabelStyle())
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if showsArea, let area = country.area, area > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Self.areaText(area))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.primary)
                    Text("km²")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// `783.6K` for Türkiye, `0.44` for Vatican City.
    private static func areaText(_ area: Double) -> String {
        guard area >= 1_000 else {
            return area.formatted(.number.precision(.fractionLength(0...2)))
        }
        return CountryFormat.number(Int(area.rounded()), style: .compact)
    }
}

/// A capsule with a small flag and a name, for borders and other short lists of countries.
public struct CountryChip: View {
    private let country: Country

    public init(country: Country) {
        self.country = country
    }

    public var body: some View {
        HStack(spacing: 8) {
            FlagImage(country: country, cornerRadius: 3)
                .frame(width: 28, height: 20)
            Text(country.commonName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.08), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// An icon and a title, closer together than the default label style.
struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
                .imageScale(.small)
            configuration.title
        }
    }
}
