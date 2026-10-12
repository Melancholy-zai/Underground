import SwiftUI

struct AboutScreen: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        if let repo = model.repository {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 15) {
                            Image(systemName: "tram.fill").font(.system(size: 30)).foregroundStyle(.white).frame(width: 70, height: 70).background(Color.metroGreen, in: RoundedRectangle(cornerRadius: 22))
                            VStack(alignment: .leading, spacing: 5) { Text("深铁分区图").font(.title2.bold()); Text("一张图，读懂城市的连接。").font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical, 12)
                        if repo.pack.isSample { SampleNotice() }
                        else if repo.pack.needsMetadata { NetworkNotice() }
                        InfoCard(title: "当前城市资料", icon: "shippingbox") {
                            LabeledContent("城市", value: repo.pack.cityName)
                            LabeledContent("资料版本", value: repo.pack.version)
                            LabeledContent("资料截止", value: repo.pack.dataAsOf ?? "尚未核实")
                            LabeledContent("包生成日期", value: repo.pack.generatedAt)
                            if let context = repo.pack.mapContext {
                                LabeledContent("周边资料复核", value: context.reviewedAt)
                                Text(context.note).font(.caption).foregroundStyle(.secondary)
                            }
                            LabeledContent("收录规模", value: "\(repo.pack.lines.count) 条线 / \(repo.pack.stations.count) 站")
                            Text(repo.pack.coverageNote).font(.caption).foregroundStyle(.secondary)
                        }
                        InfoCard(title: "离线与隐私", icon: "hand.raised") {
                            Text("地图、搜索、站点资料均从手机本地读取。没有账户、广告 SDK、分析统计或自建后端。")
                            Text("仅在你使用当前位置功能时获取一次位置，不保存位置记录。选择外部地图后，起终点会传递给所选 App，由它提供在线规划。")
                            Text("资料更新方式：开发电脑替换完整城市资料包后重新构建安装。")
                        }.font(.subheadline)
                        InfoCard(title: "来源与使用说明", icon: "doc.text") {
                            ForEach(repo.pack.sources) { source in
                                VStack(alignment: .leading, spacing: 8) {
                                    if let raw = source.url, let url = URL(string: raw), url.scheme == "https" { Link(source.title, destination: url).font(.subheadline.bold()) }
                                    else { Text(source.title).font(.subheadline.bold()) }
                                    Text(source.note).font(.caption).foregroundStyle(.secondary)
                                    Text("使用条件：\(source.license)").font(.caption).foregroundStyle(.secondary)
                                    Text("来源发布：\(source.sourcePublishedAt ?? "未注明") · 访问日期：\(source.accessedAt)").font(.caption2).foregroundStyle(.secondary)
                                }
                                if source.id != repo.pack.sources.last?.id { Divider() }
                            }
                        }
                        Text(repo.pack.disclaimer).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                        Text("APP 1.0 · 为 iPhone 设计").font(.caption2.monospaced()).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.bottom)
                    }.padding(20)
                }.background(Color.metroPaper).navigationTitle("资料与说明").navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
