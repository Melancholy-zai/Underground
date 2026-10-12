import SwiftUI

struct RouteScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var picker: PickerRole?
    enum PickerRole: String, Identifiable { case origin, destination; var id: String { rawValue } }
    var body: some View {
        if let repo = model.repository {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("下一站，去哪里？").font(.title.bold()).foregroundStyle(Color.metroInk)
                            Text("选好起终点，在熟悉的地图里继续出发。").font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.top, 10)
                        VStack(spacing: 0) {
                            endpointRow(title: "起点", value: model.originTitle(), color: .metroGreen, id: "chooseOrigin") { picker = .origin }
                            HStack {
                                Rectangle().fill(Color.metroGreen.opacity(0.25)).frame(width: 2, height: 24).padding(.leading, 26)
                                Spacer()
                                Button { model.route.swap() } label: { Label("交换", systemImage: "arrow.up.arrow.down").font(.caption.bold()) }
                                    .disabled(!model.route.canSwap).accessibilityIdentifier("swapRoute")
                            }.padding(.trailing, 20)
                            endpointRow(title: "终点", value: model.destinationTitle(), color: Color(hex: "BD7B38"), id: "chooseDestination") { picker = .destination }
                        }.padding(.vertical, 8).background(.white, in: RoundedRectangle(cornerRadius: 24))
                        Picker("出行方式", selection: $model.route.mode) {
                            ForEach(TravelMode.allCases, id: \.self) { mode in Text(mode.title).tag(mode) }
                        }.pickerStyle(.segmented)
                        if model.route.origin == .currentLocation {
                            InfoCard(title: "按需定位", icon: "location") {
                                Text(model.locationStatus).font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("locationStatus")
                                Text("点击下方地图或获取位置时才请求定位；不持续追踪、不在后台定位。").font(.caption).foregroundStyle(.secondary)
                                HStack {
                                    if model.locating {
                                        ProgressView()
                                        Button("取消定位") { model.cancelNavigation() }
                                    } else {
                                        Button("获取当前位置") { model.locateOnly() }.accessibilityIdentifier("requestLocation")
                                    }
                                    Spacer()
                                    Button("手动选站") { picker = .origin }
                                }.font(.subheadline)
                            }
                        }
                        if case .station(let start) = model.route.origin, start == model.route.destination?.stationID {
                            Label("起终点相同，请重新选择", systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(.orange).accessibilityIdentifier("sameStationWarning")
                        }
                        InfoCard(title: "选择地图继续", icon: "arrow.up.forward.app") {
                            VStack(spacing: 12) {
                                ForEach(MapProvider.allCases) { provider in
                                    Button { model.openMap(provider) } label: {
                                        HStack {
                                            Image(systemName: provider == .amap ? "location.north.circle.fill" : "map.circle.fill").font(.title2)
                                            Text("在\(provider.name)中规划").font(.body.weight(.semibold))
                                            Spacer(); Image(systemName: "arrow.up.right").font(.caption.bold())
                                        }.padding(15).frame(maxWidth: .infinity).background(provider == .amap ? Color.metroGreen : Color.metroGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
                                            .foregroundStyle(provider == .amap ? .white : Color.metroGreen)
                                    }.disabled(model.locating || model.route.destination == nil).opacity(model.route.destination == nil ? 0.5 : 1)
                                        .accessibilityIdentifier("open-\(provider.rawValue)")
                                }
                            }
                            Text("高德按已核实的站点位置接收手动起点。百度暂无坐标时按站名匹配，请核对起终点。规划结果在外部地图中显示。").font(.caption).foregroundStyle(.secondary)
                        }
                        if repo.pack.isSample { SampleNotice() }
                        else if repo.pack.needsMetadata { NetworkNotice() }
                    }.padding(20)
                }.background(Color.metroPaper).navigationTitle("路线").navigationBarTitleDisplayMode(.inline)
                    .sheet(item: $picker) { role in
                        StationPicker(title: role == .origin ? "选择起点" : "选择终点", repository: repo, allowsLocation: role == .origin) { station in
                            if role == .origin { model.route.origin = station.map { .station($0.id) } ?? .currentLocation }
                            else if let station { model.route.destination = .station(station.id) }
                        }
                    }
            }
            .onDisappear { model.cancelNavigation() }
        }
    }
    private func endpointRow(title: String, value: String, color: Color, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Circle().stroke(color, lineWidth: 3).frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(value).font(.title3.weight(.semibold)).foregroundStyle(Color.metroInk).multilineTextAlignment(.leading)
                }
                Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).padding(.vertical, 14)
        }.accessibilityIdentifier(id)
    }
}
