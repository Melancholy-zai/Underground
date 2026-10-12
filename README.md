# 深铁分区图 · Underground

已补齐主图外围城市、独立市界/深港界线、海岸水域和完整图例。手机可一键放大周边或图例。见 [横向地图说明](docs/MAP_CONTEXT.md)、[SVG](output/maps/shenzhen-metro-context.svg) 和 [矢量PDF](output/maps/shenzhen-metro-context.pdf)。


面向 iPhone 的离线地铁资料 App，使用 SwiftUI、WebKit、CoreLocation 和 Python 标准库。无第三方依赖、无服务端、无需 API Key。工程最低支持 iOS 17。

**已内置完整线网：17 条编号线路、351 个不同站点、68 个多线站。** 以官方 2026-06-28 运营范围为基准，2026-09-24 核对官方票价表、站名表和线路图；包含 13 号线至李松蓢、8 号线至溪涌等延伸段。2/8 号线保持贯通，不将编号交界误算为换乘。

目前是“线网核对完成、服务资料待补”的开发版本：**已恢复10个浅色分区（含大鹏新区）、区名与示意区界**，按公开站址人工对应站点归属，6处边界或资料疑点局部标为待核实。351站已补齐高德导航位置；出入口、首末班车和通用WGS84坐标尚未补齐。地图参考官方公开 PDF 重建为可点击的本地 SVG，仅供个人非商业开发；保留来源，未声明商业再分发许可。见 [分区说明](docs/DISTRICT_RESEARCH.md)、[线网核对记录](docs/NETWORK_RESEARCH.md) 与 [资料格式](docs/DATA_FORMAT.md)。

## 直接运行

1. 用 Xcode 打开本目录的 `Underground.xcodeproj`（不要把 `Package.swift` 当作 iPhone App 工程打开）。
2. Scheme 选择 **Underground**，运行目标选择一个 iPhone 模拟器。
3. 按 **⌘R**。初次构建不需要下载任何包，也不需要启动服务器。
4. 地图页可搜索 `前海湾`、`qianhaiwan` 或 `qhw`；点详情中的“设为终点”，到路线页手动选择起点，再交换两站。

真机：在 Underground target 的 Signing & Capabilities 中选择你的 Team，并将 Bundle Identifier 改成你个人唯一的值。连接 iPhone、按设备提示开启开发者模式和信任，再运行。无需 App Store 上架。个人免费账号的签名有效期和安装限制以 Xcode 提示为准，过期后重新签名安装；本次保留现有 Team 和 Bundle ID；完整线网的真机显示仍需你重新运行检查。

已提供 Xcode 工程。只有新增/删除 Swift 文件或需要重新生成工程时，才运行：

```bash
python3 tools/generate_project.py
```

该脚本会重建 `project.pbxproj` 和共享 Scheme，**会覆盖手工修改的构建配置**。需要长期保留的 Team/Bundle ID 等设置可写进脚本的配置字典，或生成后再配置。

## 已实现功能

| 功能 | 实现 |
|---|---|
| 离线地图 | 本地结构化 SVG，17 线/351 站、线路色、换乘站、周边方位小图；10个浅色分区、区名与示意区界 |
| 地图操作 | 单指拖动、双指捏合、缩放按钮、恢复全图、点线高亮、空白取消 |
| 站点点选 | 站点优先于线路；触点附近选择最近站点；拖动不当成点击 |
| 搜索 | 中文、拼音、首字母、资料包 aliases；结果居中并显示站点卡 |
| 线路列表 | 显示区段端点、收录站数和覆盖说明，点击高亮 |
| 站点详情 | 行政区、线路/换乘、出口、本站分方向首末班、适用条件、有效期、来源和更新时间 |
| 时间表达 | 区分当天/次日，支持不同服务日、实际末班终到站、过期提示 |
| 路线页 | 当前位置/手选站起点、手选终点、站点卡带入、交换、同站提示 |
| 外部地图 | 高德/百度 URL Scheme、公交/步行、安装检测、打开失败提示 |
| 定位 | 使用时授权，一次请求，20 秒超时；修改路线/离开路线页取消请求 |
| 一致性 | JSON/SVG 固定 ID、生成时关联检查、manifest 哈希，App 加载失败提示 |
| 数据更新 | 本地资料包替换、重新构建；没有在线下载或导入页面 |

当前351站均有高德公开地铁图的POI编号和GCJ02位置。手动选站交给高德时同时发送编号与坐标（`dev=0`），缺少可靠起点位置时提示错误。当前位置仍发送系统WGS84定位（`dev=1`），终点用高德POI编号解析，避免混用坐标系。百度暂按“深圳 + 站名 + 地铁站”匹配。**具体出口只在存在真实坐标时提供导航按钮；高德遇到起终点坐标系不一致且无匹配位置时提示改选车站。** 详见 [高德修复记录](docs/AMAP_NAVIGATION.md)。

## 目录与修改入口

```text
Underground.xcodeproj/       iPhone App 工程与共享 Scheme
App/
  UndergroundApp.swift      三个 Tab、全局错误与站点详情入口
  AppModel.swift            页面状态、路线编辑、定位请求生命周期
  Views/                    地图、路线、详情、资料页、原生组件
  Services/
    CityPackLoader.swift    文件哈希校验与加载
    LocationService.swift   一次性定位、超时与取消
  Resources/
    CityPack/               city.json + map.svg + manifest.json
    Web/                    无网络依赖的地图 HTML/JavaScript
  Info.plist                定位用途、可查询的外部地图 Scheme
  PrivacyInfo.xcprivacy     无追踪、无应用采集记录
Sources/MetroCore/           纯 Foundation 模型、搜索、路线和 URL 构造
Tests/MetroCoreTests/        Mac 上运行的核心业务单元测试
UITests/                    iPhone 模拟器端到端测试
Package.swift               仅用于共享核心模块与单元测试
data/shenzhen/source.json   由收集脚本生成的完整线网资料
data/shenzhen/references/   官方票价表、PDF、站序与示意位置转录
tools/collect_shenzhen.py   从固定版本参考资料离线生成351站数据
tools/citypack.py            校验、SVG 生成、SHA-256 配套打包
tools/tests/                Python 与 JavaScript 地图回归检查
tools/generate_project.py    无依赖工程生成器
scripts/check.sh             本地检查入口
docs/                       设计、数据格式、来源与验收说明
```

## 验证与构建命令

在项目目录执行：

```bash
bash scripts/check.sh
```

这会执行 Python 检查、资料包配套检查、JavaScript 地图交互检查和 Swift 核心测试。需要已安装 Xcode；不需要 npm、CocoaPods 或 Swift 第三方包。

单独编译 iPhone 模拟器：

```bash
xcodebuild -project Underground.xcodeproj -scheme Underground \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/underground-build CODE_SIGNING_ALLOWED=NO build
```

运行 UI 测试：先 `xcrun simctl list devices available` 找到本机的 iPhone 模拟器 UDID，再执行（将占位值换成实际 UDID）：

```bash
xcodebuild -project Underground.xcodeproj -scheme Underground \
  -destination 'platform=iOS Simulator,id=你的模拟器UDID' \
  -derivedDataPath /tmp/underground-build CODE_SIGNING_ALLOWED=NO test
```

模拟器可验证本地交互及“地图未安装”路径，但不能替代高德/百度真机接收验证。参见 [真机验收清单](docs/DEVICE_CHECKLIST.md) 和 [实际验证记录](docs/VERIFICATION.md)。

## 更新城市资料

维护 `data/shenzhen/references/` 中的来源与示意位置，运行 `python3 tools/collect_shenzhen.py`，然后执行：

```bash
python3 tools/citypack.py validate data/shenzhen/source.json
python3 tools/citypack.py build data/shenzhen/source.json App/Resources/CityPack
python3 tools/citypack.py verify App/Resources/CityPack
```

生成的是配套的三个文件。不要只替换 JSON 或 SVG；哈希校验会阻止加载不一致资料。正式资料使用 `--production` 校验；线网核对版可凭 `networkReview` 加载，但界面保留资料缺口提示；没有核验记录时，仅改 `isSample=false` 仍会被拒绝。程序能验证结构与关联，不能自动证明数据真实、版权许可或全线网覆盖正确，仍需要人工依据记录。

加入其他城市时沿用固定 cityID/lineID/stationID 与相同资料格式。本版 UI 固定读取一个内置 CityPack；多城市切换器不在第一版范围内。

## 尚未完成的产品验收

- 6处区属疑点与站体/出入口精确边界核验；现有底图已按公开站址恢复，几何为示意。
- 真实出口、分方向/分适用日期的本站首末班、可靠导航坐标与使用条件。
- 真机定位授权/拒绝/超时及高德、百度实际接收参数。
- 全线网的真机缩放性能、不同屏幕尺寸与辅助功能体验；已检查模拟器整图和典型放大区域。

这些是正式上线前的数据与设备验证工作，不应被线网对账或单元测试的通过结果替代。

## 模拟器截图

[完整线网](docs/screenshots/full-network/map.png) · [岗厦北放大图](docs/screenshots/full-network/hub.png) · [13号线新增终点](docs/screenshots/full-network/extension.png) · [路线页](docs/screenshots/full-network/route.png)
