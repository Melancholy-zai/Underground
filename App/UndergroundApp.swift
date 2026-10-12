import SwiftUI

@main
struct UndergroundApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            Group {
                if model.city != nil {
                    TabView(selection: $model.tab) {
                        MapScreen().tabItem { Label("线网图", systemImage: "map") }.tag(AppModel.Tab.map)
                        RouteScreen().tabItem { Label("路线", systemImage: "arrow.triangle.turn.up.right.diamond") }.tag(AppModel.Tab.route)
                        AboutScreen().tabItem { Label("资料", systemImage: "info.circle") }.tag(AppModel.Tab.about)
                    }
                } else {
                    ContentUnavailableView {
                        Label("城市资料暂不可用", systemImage: "shippingbox.and.arrow.backward")
                    } description: { Text(model.loadError ?? "未知资料错误") }
                    actions: { Button("重新读取") { model.reload() }.buttonStyle(.borderedProminent) }
                }
            }
            .environmentObject(model).tint(Color.metroGreen)
            .preferredColorScheme(.light)
            .sheet(item: $model.detailStation) { station in
                if let repo = model.repository { StationDetail(station: station, repository: repo).environmentObject(model).presentationDetents([.large]).presentationDragIndicator(.visible) }
            }
            .alert(item: $model.alert) { message in Alert(title: Text("暂时无法继续"), message: Text(message.text), dismissButton: .default(Text("知道了"))) }
        }
    }
}
