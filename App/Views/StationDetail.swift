import SwiftUI

struct StationDetail: View {
    let station: Station
    let repository: CityRepository
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(station.name).font(.largeTitle.bold()).foregroundStyle(Color.metroInk)
                        Label(repository.districtName(for: station), systemImage: "map").font(.subheadline).foregroundStyle(.secondary)
                        if let note = station.districtNote { Text(note).font(.caption).foregroundStyle(.secondary) }
                        ViewThatFits(in: .horizontal) {
                            HStack { ForEach(repository.lines(at: station.id)) { LineBadge(line: $0) } }
                            VStack(alignment: .leading) { ForEach(repository.lines(at: station.id)) { LineBadge(line: $0) } }
                        }
                        if station.lineIDs.count > 1 { Text("可换乘以上线路；部分站需站外换乘，以现场指引为准。").font(.caption).foregroundStyle(.secondary) }
                        if let note = station.note { Text(note).font(.caption).foregroundStyle(Color.metroGreen) }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                    HStack(spacing: 12) {
                        Button { model.setOrigin(station) } label: { Label("设为起点", systemImage: "circle").frame(maxWidth: .infinity) }.buttonStyle(.bordered).accessibilityIdentifier("setOrigin")
                        Button { model.setDestination(station) } label: { Label("设为终点", systemImage: "mappin").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).accessibilityIdentifier("setDestination")
                    }.controlSize(.large)
                    Button { model.walkTo(station) } label: { Label("从当前位置步行到本站", systemImage: "figure.walk").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.large)
                    if repository.pack.isSample { SampleNotice() }
                    else if repository.pack.needsMetadata { NetworkNotice() }
                    InfoCard(title: "本站首末班车", icon: "clock") {
                        ForEach(repository.lines(at: station.id)) { line in
                            VStack(alignment: .leading, spacing: 16) {
                                LineBadge(line: line)
                                let times = station.timetables.filter { $0.lineID == line.id }
                                if times.isEmpty { Text("暂无已核实的本站时刻").font(.subheadline).foregroundStyle(.secondary) }
                                ForEach(Array(Set(times.map(\.direction))).sorted(), id: \.self) { direction in
                                    directionTable(direction, times: TimetablePresentation.rows(times.filter { $0.direction == direction }))
                                }
                            }
                            if line.id != station.lineIDs.last { Divider().padding(.vertical, 4) }
                        }
                        if station.serviceReview?.timetableStatus == .conflict {
                            Text("部分方向或时刻仍待核实，有冲突的时刻暂不展示。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if station.lineIDs.contains("l2") || station.lineIDs.contains("l8") {
                            Text("2、8号线贯通运营；方向名称沿用原资料，不代表列车最终终点。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("节假日时刻仅供参考，具体日期以专项公告为准。")
                            .font(.caption).foregroundStyle(.secondary)
                        if let notices = station.serviceNotices, !notices.isEmpty {
                            DisclosureGroup("特殊日期安排") {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(notices) { notice in
                                        VStack(alignment: .leading, spacing: 6) {
                                            if !notice.serviceDates.isEmpty {
                                                Text(notice.serviceDates.joined(separator: "、")).font(.caption).foregroundStyle(Color.metroGreen)
                                            }
                                            if let start = notice.validFrom { Text("自 \(start) 起").font(.caption).foregroundStyle(Color.metroGreen) }
                                            if let end = notice.validThrough { Text("至 \(end)").font(.caption).foregroundStyle(Color.metroGreen) }
                                            Text(notice.text).font(.subheadline)
                                        }
                                        .accessibilityIdentifier("service-notice-\(notice.id)")
                                    }
                                }.padding(.top, 8)
                            }.font(.subheadline)
                        }
                    }.accessibilityElement(children: .contain).accessibilityIdentifier("stationTimetables")
                    InfoCard(title: "出入口", icon: "door.left.hand.open") {
                        serviceStatus("出口", status: station.serviceReview?.exitStatus, note: station.serviceReview?.exitNote)
                        Text("已收录 \(station.exits.count) 个出入口；不代表全部出口。").font(.caption).foregroundStyle(.secondary)
                        if station.exits.isEmpty { Text("暂无资料。未收录不代表该站没有出入口。").font(.subheadline).foregroundStyle(.secondary) }
                        ForEach(station.exits.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { exit in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(exit.name).font(.headline)
                                Text(exit.description ?? "道路／地标暂无资料").font(.subheadline)
                                sourceList(exit.sourceIDs, updated: exit.updatedAt, verified: exit.verifiedAt)
                                if exit.coordinate != nil {
                                    Button { model.walkTo(station, exit: exit) } label: { Label("步行到此出口", systemImage: "location") }
                                        .accessibilityIdentifier("navigate-exit-\(exit.id)")
                                } else {
                                    Text("暂无已核实出口坐标，暂不提供精确出口导航。").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Divider()
                        }
                        Text("不提供出口实时开放状态。").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(20)
            }.accessibilityIdentifier("stationDetailScroll")
                .background(Color.metroPaper).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.accessibilityIdentifier("closeDetail") } }
        }.tint(Color.metroGreen)
    }
    private func directionTable(_ direction: String, times: [Timetable]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(direction)方向").font(.subheadline.bold())
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("日期").frame(maxWidth: .infinity, alignment: .leading)
                    Text("首班").frame(width: 88, alignment: .leading)
                    Text("末班").frame(width: 88, alignment: .leading)
                }.font(.caption).foregroundStyle(.secondary)
                ForEach(times) { time in
                    GridRow(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(TimetablePresentation.dayLabel(time))
                            if let start = time.validFrom { Text("自 \(start)").font(.caption2).foregroundStyle(.secondary) }
                            if let end = time.validThrough { Text("至 \(end)").font(.caption2).foregroundStyle(.secondary) }
                            if time.isExpired() { Text("已过期").font(.caption2).foregroundStyle(.orange) }
                        }
                        Text(time.first?.display ?? "—").monospacedDigit().fixedSize(horizontal: true, vertical: false)
                            .frame(width: 88, alignment: .leading)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(time.last?.display ?? "—").monospacedDigit().fixedSize(horizontal: true, vertical: false)
                            if let label = time.serviceLabel, label != "全程" {
                                Text(label == "半程加班车" ? "半程" : label).font(.caption).foregroundStyle(Color.metroGreen)
                                if let destination = time.lastDestination {
                                    Text("至\(destination)").font(.caption).foregroundStyle(Color.metroGreen)
                                }
                            } else if let destination = time.lastDestination, destination != time.direction {
                                Text("至\(destination)").font(.caption).foregroundStyle(Color.metroGreen)
                            }
                        }.frame(width: 88, alignment: .leading)
                    }.font(.subheadline)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("timetable-row-\(time.id)")
                }
            }
        }
    }

    private func serviceStatus(_ title: String, status: ServiceReviewStatus?, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(title)资料状态：\(status?.display ?? "核验状态未知")")
                .font(.subheadline).foregroundStyle(Color.metroGreen)
                .accessibilityIdentifier(title == "时刻" ? "timetableReviewStatus" : "exitReviewStatus")
            if let note { Text(note).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func sourceList(_ ids: [String], updated: String?, verified: String? = nil, showsLocalUpdate: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if showsLocalUpdate { Text("本地整理：\(updated ?? "未记录")").font(.caption2).foregroundStyle(.secondary) }
            Text("核验日期：\(verified ?? "未记录")").font(.caption2).foregroundStyle(.secondary)
            ForEach(repository.sources(ids)) { source in
                if let raw = source.url, !source.id.hasPrefix("szmc-service-"), let url = URL(string: raw), url.scheme == "https" {
                    Link(source.title, destination: url).font(.caption)
                } else { Text(source.title).font(.caption).foregroundStyle(.secondary) }
                Text("来源发布：\(source.sourcePublishedAt ?? "未注明") · 访问：\(source.accessedAt)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
