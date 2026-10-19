import SwiftUI
import CountriesKit
import CountriesUI

/// A country's page: the flag, its names, the facts, languages and currencies, and the
/// neighbours it shares a land border with, all from the dataset the client keeps in memory.
struct CountryDetailView: View {
    let code: String
    /// The screenshot scene this page reports ready for, if any.
    let scene: ScreenshotScene?

    @Environment(Atlas.self) private var atlas
    @State private var country: Country?
    @State private var borders: [Country]?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let country {
                ScrollView {
                    page(country)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                }
            } else if let errorMessage {
                LoadErrorView(message: errorMessage) {
                    Task { await load() }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationTitle(country?.commonName ?? atlas.listed(code: code)?.commonName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .atlasNavigationBar()
        .task(id: code) {
            await load()
        }
        .signalsScreenshotReady(scene, when: country != nil && borders != nil)
    }

    private func load() async {
        errorMessage = nil
        do {
            let loaded = try await atlas.country(code: code)
            country = loaded
            borders = try await atlas.borders(of: loaded)
            screenshotLog("Loaded \(loaded.commonName) with \(borders?.count ?? 0) neighbours")
        } catch {
            guard !Task.isCancelled else { return }
            screenshotLog("Loading \(code) failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Page

    private func page(_ country: Country) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            hero(country)
            facts(country)
            languagesAndCurrencies(country)
            bordersSection(country)
            DataCredit()
        }
    }

    private func hero(_ country: Country) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            FlagImage(country: country, cornerRadius: 10)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .padding(.top, 12)
            VStack(alignment: .leading, spacing: 4) {
                Text(country.commonName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.primary)
                Text(country.officialName)
                    .font(.headline)
                    .foregroundStyle(Color.secondary)
                ForEach(country.nativeNames.filter { $0.official != country.officialName }) { native in
                    HStack(spacing: 6) {
                        Text(native.official)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                        Text(native.languageCode.uppercased())
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .foregroundStyle(Theme.ocean)
                            .background(Theme.ocean.opacity(0.15), in: Capsule())
                    }
                }
            }
            FlowLayout(spacing: 8) {
                if let region = country.region {
                    tag(region, systemImage: country.regionValue.map(Theme.symbol(for:)) ?? "globe")
                }
                if let subregion = country.subregion {
                    tag(subregion, systemImage: "map")
                }
                let codes = [country.cca2, country.cca3].compactMap { $0 }
                if !codes.isEmpty {
                    tag(codes.joined(separator: " · "), systemImage: "number")
                }
            }
        }
    }

    private func tag(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.surface, in: Capsule())
    }

    private func facts(_ country: Country) -> some View {
        let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            FactTile("Capital", value: country.primaryCapital ?? "None", detail: otherCapitals(country) ?? country.flagEmoji.map { $0 + " " + country.commonName }, systemImage: "building.columns.fill")
            if let area = country.formattedArea() {
                FactTile("Area", value: area, detail: country.landlocked == true ? "Landlocked" : "Coastline", systemImage: "square.dashed")
            }
            if let callingCode = country.primaryCallingCode {
                FactTile("Calling code", value: callingCode, detail: country.tld?.joined(separator: " "), systemImage: "phone.fill")
            }
            if let demonym = country.demonym {
                FactTile("People", value: demonym, detail: country.demonyms?["fra"]?.masculine.map { "French: " + $0 }, systemImage: "person.fill")
            }
            FactTile("Status", value: country.independent == true ? "Independent" : "Territory", detail: country.unMember == true ? "UN member" : "Not a UN member", systemImage: "checkmark.seal.fill")
            if let coordinate = country.coordinate {
                FactTile("Centre", value: coordinate.description, detail: unGroup(country), systemImage: "location.fill")
            }
        }
    }

    /// The country's UN regional group, short enough for a tile.
    private func unGroup(_ country: Country) -> String? {
        switch country.unRegionalGroup {
        case "Western European and Others Group": return "UN group: WEOG"
        case "Latin American and Caribbean Group": return "UN group: GRULAC"
        case "Asia and the Pacific Group": return "UN group: Asia-Pacific"
        case "Eastern European Group": return "UN group: Eastern Europe"
        case "African Group": return "UN group: Africa"
        default: return nil
        }
    }

    /// "+1 more" when a country has several capitals.
    private func otherCapitals(_ country: Country) -> String? {
        let count = (country.capital ?? []).filter { !$0.isEmpty }.count
        return count > 1 ? "+" + String(count - 1) + " more" : nil
    }

    private func languagesAndCurrencies(_ country: Country) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Languages & currencies")
            FlowLayout(spacing: 8) {
                ForEach(country.languageList) { language in
                    tag(language.name, systemImage: "character.bubble.fill")
                }
                ForEach(country.currencyList) { currency in
                    tag(currency.code + " · " + currency.description, systemImage: "banknote.fill")
                }
            }
        }
    }

    private func bordersSection(_ country: Country) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Land borders", count: borders?.count)
            if let borders {
                if borders.isEmpty {
                    Text(country.commonName + " shares no land border.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(borders) { neighbour in
                            NavigationLink(value: CountryRoute(code: neighbour.id)) {
                                CountryChip(country: neighbour)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
    }
}
