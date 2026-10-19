import Foundation

extension Country {
    /// The neighbours of this country found in `countries`, in the order of ``borders``. The
    /// client's ``CountriesClient/borders(of:)`` does the same with the whole dataset.
    public func borderCountries(in countries: some Sequence<Country>) -> [Country] {
        guard let borders, !borders.isEmpty else { return [] }
        let index = countries.indexedByCode()
        var seen = Set<String>()
        return borders.compactMap { code in
            guard let country = index[code.uppercased()], seen.insert(country.id).inserted else { return nil }
            return country
        }
    }

    /// Whether the two countries share a land border, from either side's ``borders``.
    public func sharesBorder(with other: Country) -> Bool {
        let mine = Set((borders ?? []).map { $0.uppercased() })
        let theirs = Set((other.borders ?? []).map { $0.uppercased() })
        return other.codes.contains { mine.contains($0.uppercased()) }
            || codes.contains { theirs.contains($0.uppercased()) }
    }
}

/// The countries of one subregion, for sectioned lists.
public struct SubregionGroup: Identifiable, Hashable, Sendable {
    /// The subregion, such as `Western Europe`; the region, or `Other`, for countries without one.
    public var name: String
    public var countries: [Country]

    public init(name: String, countries: [Country]) {
        self.name = name
        self.countries = countries
    }

    public var id: String { name }
}

extension Sequence where Element == Country {
    /// Every country by each of its codes (cca2, cca3, ccn3 and cioc, upper-cased).
    public func indexedByCode() -> [String: Country] {
        var index: [String: Country] = [:]
        for country in self {
            for code in country.codes where index[code.uppercased()] == nil {
                index[code.uppercased()] = country
            }
        }
        return index
    }

    /// Sorted by common name, ignoring case and accents, so Åland Islands sorts with the A's.
    public func sortedByName() -> [Country] {
        sorted { lhs, rhs in
            let order = lhs.commonName.compare(rhs.commonName, options: [.caseInsensitive, .diacriticInsensitive])
            return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
        }
    }

    /// Sections by subregion, sorted by name, each sorted by country name.
    public func groupedBySubregion() -> [SubregionGroup] {
        let groups = Dictionary(grouping: self) { country -> String in
            if let subregion = country.subregion, !subregion.isEmpty { return subregion }
            if let region = country.region, !region.isEmpty { return region }
            return "Other"
        }
        return groups
            .map { SubregionGroup(name: $0.key, countries: $0.value.sortedByName()) }
            .sorted { $0.name < $1.name }
    }

    /// The countries whose common or official name, capital or code contains `query`, ignoring
    /// case and accents ("turkiye" finds Türkiye). A blank query keeps every country.
    public func matching(_ query: String) -> [Country] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Array(self) }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return filter { country in
            let names = [country.commonName, country.officialName] + (country.capital ?? []) + (country.altSpellings ?? [])
            if names.contains(where: { $0.range(of: query, options: options) != nil }) { return true }
            return country.codes.contains { $0.caseInsensitiveCompare(query) == .orderedSame }
        }
    }

    /// The sum of every known area, in square kilometres.
    public var totalArea: Double {
        reduce(0) { $0 + max(0, $1.area ?? 0) }
    }
}
