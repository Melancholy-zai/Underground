import SwiftUI

struct MapScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var showLines = false
    @State private var mapError: String?
    @State private var mapIdentity = UUID()
    var body: some View {
        if let city = model.city {
            let repo = city.repository
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("SHENZHEN / METRO ATLAS").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(Color.metroGreen)
                            Text(repo.pack.districts.isEmpty ? "深圳，完整地铁图" : "深圳，分区看地铁").font(.title2.bold()).foregroundStyle(Color.metroInk)
                        }
                        Spacer()
                        Button { showLines = true } label: {
                            Image(systemName: "list.bullet").font(.title3).frame(width: 44, height: 44)
                                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        }.accessibilityLabel("线路列表").accessibilityIdentifier("lineList")
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.metroGreen)
                        TextField("搜索地铁站 · 支持拼音", text: $query).autocorrectionDisabled()
                            .textInputAutocapitalization(.never).submitLabel(.search).accessibilityIdentifier("mapSearch")
                        if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.accessibilityLabel("清除搜索") }
                    }.padding(13).background(.white, in: RoundedRectangle(cornerRadius: 16))
                    if repo.pack.isSample { SampleNotice(compact: true) }
                    if let context = repo.pack.mapContext {
                        HStack(spacing: 12) {
                            Button {
                                model.command = AppModel.MapCommand(kind: "area", target: "surroundings")
                                query = ""; hideKeyboard()
                            } label: {
                                Label("周边方位", systemImage: "map")
                            }.accessibilityIdentifier("showSurroundings")
                            Menu {
                                ForEach(context.focusAreas.filter { $0.id != "surroundings" }) { area in
                                    Button(area.title) {
                                        model.command = AppModel.MapCommand(kind: "area", target: area.id)
                                        query = ""; hideKeyboard()
                                    }.accessibilityIdentifier("focus-\(area.id)")
                                }
                            } label: {
                                Label("地图图例", systemImage: "info.circle")
                            }.accessibilityIdentifier("mapLegend")
                            Spacer(minLength: 0)
                        }.font(.subheadline).buttonStyle(.bordered)
                    }
                }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 14)
                ZStack(alignment: .top) {
                    WebMetroMap(svg: city.svg, lineID: model.selectedLineID, stationID: model.selectedStationID, command: model.command) { type, id in
                        switch type {
                        case "station": if let station = repo.station(id) { model.selectStation(station) }
                        case "line": model.toggleLine(id)
                        case "blank": model.selectedLineID = nil
                        default: break
                        }
                    } onError: { mapError = $0 }.id(mapIdentity)
                    if let mapError {
                        VStack(spacing: 12) {
                            Text("地图暂不可用").font(.headline)
                            Text(mapError).font(.caption)
                            Button("重新加载") { self.mapError = nil; mapIdentity = UUID() }.buttonStyle(.borderedProminent)
                        }.padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)).padding(24)
                    }
                    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                let results = repo.search(query)
                                if results.isEmpty { ContentUnavailableView.search(text: query) }
                                ForEach(results) { station in
                                    Button { model.selectStation(station, focus: true); query = ""; hideKeyboard() } label: {
                                        StationRow(station: station, repository: repo).padding(.horizontal, 14).padding(.vertical, 8)
                                    }.accessibilityIdentifier("search-\(station.id)")
                                    Divider().padding(.leading, 60)
                                }
                            }
                        }.frame(maxHeight: 320).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18)).padding(.horizontal, 20)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 1) {
                        control("plus", label: "放大地图", kind: "in")
                        Divider().frame(height: 24)
                        control("minus", label: "缩小地图", kind: "out")
                        Divider().frame(height: 24)
                        control("arrow.up.left.and.arrow.down.right", label: "恢复全图", kind: "reset")
                    }.background(.white, in: RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.07), radius: 12, y: 3).padding(16)
                }
                .overlay(alignment: .bottom) { footer(repo).padding(.bottom, 80) }
            }.background(Color.metroPaper)
            .sheet(isPresented: $showLines) { lineList(repo) }
        }
    }
    private func control(_ icon: String, label: String, kind: String) -> some View {
        Button { model.command = AppModel.MapCommand(kind: kind) } label: {
            Image(systemName: icon).font(.body.weight(.medium)).frame(width: 46, height: 46)
        }.accessibilityLabel(label)
    }
    @ViewBuilder
    private func footer(_ repo: CityRepository) -> some View {
        if let id = model.selectedLineID, let line = repo.line(id) {
            VStack(alignment: .leading, spacing: 9) {
                HStack { LineBadge(line: line); Text(line.termini.joined(separator: " ↔ ")).font(.caption); Spacer(); Button("取消") { model.selectedLineID = nil }.font(.caption) }
                if repo.pack.isSample { Text("以上为样本区段端点").font(.caption2).foregroundStyle(.secondary) }
                if let note = line.coverageNote { Text(note).font(.caption2).foregroundStyle(.secondary) }
            }.padding(.horizontal, 20).padding(.vertical, 13).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.94))
        }
    }
    private func lineList(_ repo: CityRepository) -> some View {
        NavigationStack {
            List {
                if repo.pack.isSample { SampleNotice() }
                        else if repo.pack.needsMetadata { NetworkNotice() }
                ForEach(repo.pack.lines) { line in
                    Button {
                        model.toggleLine(line.id); showLines = false
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack { LineBadge(line: line); Spacer(); Text("\(line.stationIDs.count) 站").font(.caption).foregroundStyle(.secondary) }
                            Text(line.termini.joined(separator: " ↔ ")).font(.subheadline).foregroundStyle(Color.metroInk)
                            if let note = line.coverageNote { Text(note).font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical, 5)
                    }.accessibilityIdentifier("line-\(line.id)")
                }
            }.navigationTitle("线路列表").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showLines = false } } }
        }.presentationDetents([.medium, .large])
    }
    private func hideKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
}
