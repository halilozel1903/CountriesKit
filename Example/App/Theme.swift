import SwiftUI
import CountriesKit

/// The look of *Atlas*, the demo app: a night-blue map with an ocean accent.
enum Theme {
    static let background = Color(red: 0.04, green: 0.07, blue: 0.12)
    static let surface = Color(red: 0.09, green: 0.13, blue: 0.20)
    static let ocean = Color(red: 0.33, green: 0.78, blue: 0.94)
    static let gold = Color(red: 0.98, green: 0.78, blue: 0.33)
    static let correct = Color(red: 0.36, green: 0.84, blue: 0.52)
    static let wrong = Color(red: 0.96, green: 0.42, blue: 0.40)
    static let cornerRadius: CGFloat = 18

    /// An SF Symbol for a region.
    static func symbol(for region: Region) -> String {
        switch region {
        case .africa: return "globe.europe.africa.fill"
        case .americas: return "globe.americas.fill"
        case .antarctic: return "snowflake"
        case .asia: return "globe.asia.australia.fill"
        case .europe: return "globe.europe.africa.fill"
        case .oceania: return "water.waves"
        }
    }
}

extension View {
    /// The app's dark, opaque navigation bar. iOS 26 bars are transparent by default, and an
    /// inline title over scrolled content would be unreadable.
    @MainActor
    func atlasNavigationBar() -> some View {
        toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }

    /// A rounded surface behind grouped content.
    @MainActor
    func cardBackground() -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

/// A page the app can push: a country by code.
struct CountryRoute: Hashable {
    let code: String
}

/// A section title with an optional count: "Borders 8".
struct SectionHeader: View {
    let title: String
    let count: Int?

    init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Color.primary)
            if let count {
                Text(String(count))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A small labelled value on a card: "Capital / Ankara".
struct FactTile: View {
    let title: String
    let value: String
    let detail: String?
    let systemImage: String

    init(_ title: String, value: String, detail: String? = nil, systemImage: String) {
        self.title = title
        self.value = value
        self.detail = detail
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ocean)
            Text(value)
                .font(.headline)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardBackground()
        .accessibilityElement(children: .combine)
    }
}

/// Lays its children out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews, width: width)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let usedWidth = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? usedWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, width: bounds.width)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

/// The data credit shown under lists. Verbatim, so the domain is not turned into a link.
struct DataCredit: View {
    var body: some View {
        Text(verbatim: "Data from restcountries.com · flags from flagcdn.com")
            .font(.footnote)
            .foregroundStyle(Color.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }
}

/// A full-screen error with a retry button.
struct LoadErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}
