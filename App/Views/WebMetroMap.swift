import SwiftUI
import WebKit

struct WebMetroMap: UIViewRepresentable {
    let svg: String
    let lineID: String?
    let stationID: String?
    let command: AppModel.MapCommand
    let onEvent: (String, String) -> Void
    let onError: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(context.coordinator, name: "metro")
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = UIColor(Color.metroPaper)
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.scrollView.pinchGestureRecognizer?.isEnabled = false
        web.accessibilityIdentifier = "metroMap"
        context.coordinator.web = web
        context.coordinator.load()
        return web
    }
    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.push()
    }
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "metro")
        uiView.navigationDelegate = nil
    }
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebMetroMap
        weak var web: WKWebView?
        private var ready = false
        init(parent: WebMetroMap) { self.parent = parent }
        func load() {
            ready = false
            do {
                guard let folder = Bundle.main.url(forResource: "Web", withExtension: nil) else { throw MetroError.invalidData("缺少地图交互资源") }
                let template = try String(contentsOf: folder.appendingPathComponent("map.html"), encoding: .utf8)
                let script = try String(contentsOf: folder.appendingPathComponent("map.js"), encoding: .utf8)
                let html = template.replacingOccurrences(of: "<!--METRO_SVG-->", with: parent.svg)
                    .replacingOccurrences(of: "/*METRO_SCRIPT*/", with: script)
                web?.loadHTMLString(html, baseURL: nil)
            } catch { parent.onError(error.localizedDescription) }
        }
        func push() {
            guard ready else { return }
            struct State: Encodable { let line: String?; let station: String?; let command: AppModel.MapCommand }
            guard let data = try? JSONEncoder().encode(State(line: parent.lineID, station: parent.stationID, command: parent.command)),
                  let json = String(data: data, encoding: .utf8) else { return }
            web?.evaluateJavaScript("window.metro.update(\(json))") { [weak self] _, error in
                if let error { self?.parent.onError("地图交互失败：\(error.localizedDescription)") }
            }
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let body = message.body as? [String: String], let type = body["type"] else { return }
            if type == "ready" { ready = true; push(); return }
            guard ["station", "line", "blank"].contains(type) else { return }
            parent.onEvent(type, body["id"] ?? "")
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(action.request.url?.absoluteString == "about:blank" ? .allow : .cancel)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { parent.onError(error.localizedDescription) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { parent.onError(error.localizedDescription) }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { load() }
    }
}
