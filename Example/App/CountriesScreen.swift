import SwiftUI
import CountriesKit
import CountriesUI

/// iPhone: the countries of one region, grouped by subregion, with region chips and search.
struct CountriesScreen: View {
    let scene: ScreenshotScene?
    @Binding var path: [CountryRoute]

    @Environment(Atlas.self) private var atlas
    @State private var region: Region = ScreenshotScene.region
    @State private var query = ""

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    RegionPicker(selection: $region)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                content
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Atlas")
            .navigationBarTitleDisplayMode(.inline)
            .atlasNavigationBar()
            .searchable(text: $query, prompt: "Country, capital or code")
            .navigationDestination(for: CountryRoute.self) { route in
                CountryDetailView(code: route.code, scene: scene == .country ? scene : nil)
            }
            .task(id: region) {
                await atlas.load(region)
            }
            .refreshable {
                await atlas.load(region)
            }
        }
        .signalsScreenshotReady(scene == .countries ? scene : nil, when: atlas.regions[region] != nil)
    }

    @ViewBuilder
    private var content: some View {
        if let countries = atlas.regions[region] {
            let shown = countries.matching(query)
            Section {
                RegionSummary(region: region, countries: countries)
                    .listRowBackground(Theme.surface)
            }
            ForEach(shown.groupedBySubregion()) { group in
                Section {
                    ForEach(group.countries) { country in
                        NavigationLink(value: CountryRoute(code: country.id)) {
                            CountryRow(country: country)
                        }
                        .listRowBackground(Theme.surface)
                    }
                } header: {
                    Text(group.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ocean)
                        .textCase(nil)
                }
            }
            if shown.isEmpty {
                ContentUnavailableView.search(text: query)
                    .listRowBackground(Color.clear)
            }
            Section {
                DataCredit()
                    .listRowBackground(Color.clear)
            }
        } else if let error = atlas.regionErrors[region] {
            LoadErrorView(message: error) {
                Task { await atlas.load(region) }
            }
            .listRowBackground(Color.clear)
        } else {
            HStack {
                Spacer()
                ProgressView("Loading " + region.name)
                Spacer()
            }
            .padding(.vertical, 40)
            .listRowBackground(Color.clear)
        }
    }
}

/// Horizontal chips, one per region.
struct RegionPicker: View {
    @Binding var selection: Region

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Region.allCases) { region in
                    let selected = region == selection
                    Button {
                        selection = region
                    } label: {
                        Label(region.name, systemImage: Theme.symbol(for: region))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(selected ? Theme.background : Color.primary)
                            .background(selected ? Theme.ocean : Theme.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }
}

/// "53 countries · 745M people · 23M km²" for a region.
struct RegionSummary: View {
    let region: Region
    let countries: [Country]

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: Theme.symbol(for: region))
                .font(.system(size: 30))
                .foregroundStyle(Theme.ocean)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(region.name)
                    .font(.headline)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var summary: String {
        let subregions = Set(countries.compactMap(\.subregion)).count
        let people = CountryFormat.population(countries.totalPopulation, style: .compact)
        var parts = [String(countries.count) + " countries", people + " people"]
        if subregions > 0 {
            parts.append(String(subregions) + (subregions == 1 ? " subregion" : " subregions"))
        }
        return parts.joined(separator: " · ")
    }
}
