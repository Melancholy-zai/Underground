import SwiftUI

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x315e4f
        self.init(.sRGB, red: Double((value >> 16) & 255)/255, green: Double((value >> 8) & 255)/255, blue: Double(value & 255)/255, opacity: 1)
    }
    static let metroInk = Color(hex: "183F35")
    static let metroGreen = Color(hex: "237760")
    static let metroPaper = Color(hex: "F5F7F0")
}

struct LineBadge: View {
    let line: MetroLine
    var body: some View {
        Text(line.name).font(.caption.bold()).foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color(hex: line.color), in: Capsule())
    }
}

struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(Color.metroInk)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct SampleNotice: View {
    var compact = false
    var body: some View {
        Label(compact ? "局部开发样本 · 非完整运营线网" : "当前为局部开发资料，不能作为完整出行依据。", systemImage: "info.circle")
            .font(.caption).foregroundStyle(Color(hex: "805F26"))
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "FFF2D8"), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct NetworkNotice: View {
    var body: some View {
        Label("区界为示意 · 部分区属待核实", systemImage: "info.circle")
            .font(.caption).foregroundStyle(Color(hex: "805F26"))
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "FFF2D8"), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct StationRow: View {
    let station: Station
    let repository: CityRepository
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: station.lineIDs.count > 1 ? "arrow.triangle.branch" : "tram.fill")
                .frame(width: 34, height: 34).foregroundStyle(Color.metroGreen)
                .background(Color.metroGreen.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text(station.name).font(.body.weight(.semibold)).foregroundStyle(Color.metroInk)
                Text(repository.districtName(for: station)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            HStack(spacing: 4) {
                ForEach(repository.lines(at: station.id)) { line in
                    Text(line.shortName).font(.caption2.bold()).foregroundStyle(.white)
                        .frame(minWidth: 23, minHeight: 23).background(Color(hex: line.color), in: Circle())
                }
            }
        }.padding(.vertical, 4)
    }
}

struct StationPicker: View {
    let title: String
    let repository: CityRepository
    var allowsLocation = false
    let onSelect: (Station?) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if allowsLocation {
                    Button { onSelect(nil); dismiss() } label: {
                        Label("使用当前位置", systemImage: "location.fill").foregroundStyle(Color.metroGreen)
                    }.accessibilityIdentifier("useCurrentLocation")
                }
                let results = repository.search(query)
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(results) { station in
                        Button { onSelect(station); dismiss() } label: { StationRow(station: station, repository: repository) }
                            .accessibilityIdentifier("pick-\(station.id)")
                    }
                }
            }
            .searchable(text: $query, prompt: "站名、拼音或首字母")
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}
