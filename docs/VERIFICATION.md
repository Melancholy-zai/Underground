# 线路图例与独立高亮验证（2026-09-28）

版本：0.3.2-line-legend。图例色块、编号、名称和周边空白共用点击区域；2号线和8号线分别高亮，不按贯通运营关系传播选中状态。线路图例、地图线条、线路列表共用选择/取消逻辑，选中信息改为浮层以保持地图视图不变。

- 31项Python、36项JavaScript、22项Swift检查通过，城市包哈希和17个图例对应关系通过。日志 `/tmp/legend-independent-check.log`。第一次运行因沙箱禁止Swift缓存写入中止，获准后同一检查通过。
- 独立高亮回归先在旧代码失败；修改后确认2/8各自的站点和线条分别明暗变化，普通换乘站不点亮其他线路。旧的联动属性不再生成或使用。两段SVG线路在莲塘附近端点一致，未调整线路几何。
- JS验证图例事件、单选状态、取消恢复、拖动/双指缩放不误选、键盘激活及视图不变；选中样式只应用到当前图例，其他图例不淡化。
- iPhone17 / iOS26.5模拟器2项UI测试通过：图例选择/再次点击取消/切换/线路列表同步/空白取消/位置缩放不变，以及地图线路选择后搜索并触摸站点打开详情。结果包 `/tmp/underground-legend-final.xcresult`，xcodebuild exit 0。
- 首次新增UI测试以Button查询图例而失败；界面层级确认WebKit把aria-pressed图例暴露为Switch，调整测试查询后通过，并检查选2号线时2号图例值为1、8号图例值为0。
- 已检查选中图例手机截图，保存于 `screenshots/line-legend`。导出SVG与内置SVG哈希相同，PDF重新渲染查看，静态导出布局保持一致。

双指防误选为JS指针事件回归；未新增真机触感或VoiceOver验收。

---

# 地图显示简化验证（2026-09-28）

版本：0.3.1-clean-map。上方位置关系图、下方横排线路及符号，取消右侧说明栏；主图删除待核实专用斜纹、阴影、问号、短注及分区色块列表。地图页取消资料提示横幅、底部日期/版本与重复说明，资料页保留相关信息。

- 30项Python、20项JavaScript、22项Swift检查通过，包哈希与对象关联检查通过。日志：`/tmp/clean-map-final-check.log`。
- 修改前后逐站对比351站的固定编号、名称、districtIDs、districtNote、lineIDs及amapLocation，全部一致；17条线路站序一致。6处区属仍为空，详情仍保留核验说明。
- 新的回归断言先在旧版斜纹地图失败，再在简化版通过；确认6站仍是普通站名及符号、无额外提示，且都在两个分区的共同示意边界1个坐标单位以内。翰岭仅调整两区共享轮廓经过站点中心，不修改归属。
- iPhone17 / iOS26.5模拟器：首轮5项既有UI流程通过；新增详情/资料页检查因测试使用了不匹配的文字查询失败。改为现有“行政区待核实”文字和LabeledContent组合标签匹配后，新增检查与最终图例聚焦流程2项通过。共6种UI流程已分批通过，结果包 `/tmp/underground-clean-map.xcresult`、`/tmp/underground-clean-map-final.xcresult`。
- 已查看手机的翰岭主图、详情待核实说明、上方位置图及横排线路图例截图。放大图例时显示局部，可横向拖动查看剩余内容。截图位于 `screenshots/clean-map`。
- SVG、PNG与单页矢量PDF已更新；已渲染并查看最终PDF，0个嵌入图片对象、可提取文字。导出SVG与内置SVG哈希一致。日期和版本仍在JSON包中；地图及同版导出图不再显示这些文字。

本次不修改运营范围、导航参数或站点资料核验结论；没有增加真机、高德接收或VoiceOver验收。

---

# 周边地区、独立交界与完整图例验证（2026-09-28）

版本：0.3.0-context；运营截止日期2026-06-28，资料复核日期2026-09-28。

- `bash scripts/check.sh`：30项Python、20项JavaScript、22项Swift检查通过；城市包哈希与JSON/SVG对象关联检查通过。日志：`/tmp/context-final-check.log`。
- 最新构建在iPhone17 / iOS26.5模拟器上完整运行5项UI测试，全部通过：分区/站点详情、延伸线与多音字搜索、线路选择与地图触摸站点、手动路线与交换、周边/三组图例/恢复/再搜索。结果包：`/tmp/underground-context-delivery.xcresult`，xcodebuild exit 0。
- 核对官方现行站序和9月运营公告，保留17条编号线路、351个唯一站点与432站次。未发现6月28日后新增运营区段的明确证据，因此没有仅按制作日期提升运营截止日。来源与归一差异见 [周边与线网核验](SURROUNDINGS_RESEARCH.md)。
- 校验独立市界/深港界线/海岸线、来源引用、聚焦框和6处站点说明；测试确认原线网仅整体平移，站序、固定编号与高德导航坐标保留。
- 修正龙华—罗湖共界和福田—龙岗错误相邻；抽样检查分区拼接没有缝隙或重叠，全部已确认站点与底色一致。抽样不等同于地籍测绘核验。
- 手机截图已检查周边位置图、线路/分区/符号三组图例；加大图例文字后再次查看，内容没有在卡片内被裁切。截图位于 `screenshots/context/readability-ui`。
- 原先直接对SVG辅助功能元素调用 `.tap()` 的界面测试失败。站点组的框同时包含标记、文字与中间空白，不能把其中心当作标记位置。改为搜索放大后直接触摸视图中心的站点标记，详情成功打开；独立复测1项通过，结果包 `/tmp/underground-context-acceptance.xcresult`。这项结果不代表已完成VoiceOver验收。
- 导出单页700×450mm横向PDF、SVG和PNG。PDF使用矢量绘制，检查到0个嵌入图片对象，文字可提取；已渲染并查看整页。导出SVG与应用内SVG的SHA-256一致。
- 独立只读审查检查了边界、站点位置、装饰层命中、离线来源和对象关联，未发现需修复的P1/P2问题；随后扩大手机图例字号并复测。

保留6处局部区属待核实，不强行归区。大鹏已有溪涌站，地图只对未直达目的地作说明；深汕作为独立位置图展示。本次未验收真机双指手感、VoiceOver或高德App实际接收页面；此前手动起点修复的真机验证限制仍适用。代码和产物说明见 [地图说明](MAP_CONTEXT.md)。

---

# 高德手动起点修复验证（2026-09-28）

版本：0.2.2-navigation；运营截止日期仍为2026-06-28。

- 24项Python、11项JavaScript、20项Swift检查通过；资料包哈希与对象关联检查通过。
- iPhone17 / iOS26.5模拟器的手动选站、交换、未安装地图提示UI测试通过（1项）。
- 真机Debug构建成功；高德17.00.2页面探测因iOS启用UI自动化超时而未执行，实际接收结果待复测。
- 回归范围、数据来源与边界见 [高德导航修复记录](AMAP_NAVIGATION.md)。

---

# 分区底色修复验证（2026-09-28）

版本：0.2.1-districts；运营截止日期仍为2026-06-28。

- 根因复现：内置SVG无任何 `data-district`，生成器将分区固定清空；新增测试先失败后通过。
- Python：22项通过，含分区再生成、跨区站点归属、局部待核实遮罩、站点底色校验与两处区界重叠回归。
- JavaScriptCore：11项地图交互检查通过。
- Swift：14项核心测试通过，包含内置资料包加载与搜索。
- 资料包：哈希及JSON/SVG对象集合一致；生成器输出与源文件、内置JSON一致。
- 与修改前备份逐字段对比：17条线路与351站的固定编号、站名、线路成员、站点/线路示意几何保持一致。
- iPhone17 / iOS26.5：4项UI测试通过，涵盖分区显示、站点区属、搜索定位、线路高亮、地图点选与手动路线；结果包 `/tmp/underground-district-ui.xcresult`。
- 最终排版和提示文字调整后，分区UI测试再次通过（1项），结果包 `/tmp/underground-district-delivery-ui.xcresult`，截图见 `screenshots/districts/ios-final`。
- 视觉检查：查看完整SVG及罗湖/盐田区界放大截图，调整宝安、南山区名避开线路和站名；底图在线路下方，站名白色描边保留。
- 只读代码审查复现了龙华折返重边与坪山边缘细长重叠，均已修复，并先运行失败测试再验证通过。

全图见 [分区预览](screenshots/districts/map-overview.png)。资料依据及6处疑点见 [分区说明](DISTRICT_RESEARCH.md)。这些验证不能代替站体/出入口地籍核验；没有进行真机测试。

沙箱内运行整套脚本时，Swift缓存目录写入被拒；允许访问缓存后重新运行完成。不是测试断言失败。

---

# 完整线网版实际验证记录

日期：2026-09-24；版本 0.2.0-network。运营范围截止2026-06-28；核验351站、17条编号线、432站次、68多线站。

| 已执行检查 | 结果与范围 |
|---|---|
| 官方数据对账 | 票价XLSX全部站序与官方网页归一后逐线一致；SVG与JSON全部351个站点、17条线一一对应 |
| Python unittest | 17/17通过，含全量站序、2/8贯通无虚假换乘、未开通站剔除、状态分层、SVG非法/残缺路径、字段类型保护 |
| Swift核心测试 | 14/14通过，含351站搜索、多音字读音别名、贯通端点与核验计数检查，以及原导航/路线回归 |
| JavaScriptCore | 11项通过；增加全图搜索后继续放大不得反向缩小的回归 |
| 资料包verify | 通过；哈希、版本、引用和SVG对象集合一致 |
| --production | 按预期拒绝：缺少完整发布核验记录（不等同于本次networkReview） |
| Xcode模拟器构建 | Debug编译成功，用户现有签名配置保留 |
| iPhone17 / iOS26.5 UI测试 | 3/3通过：搜索/手动路线/交换/未安装回退；线路高亮/站点点击；岗厦北及李松蓢搜索与定位 |
| 视觉检查 | 已查看完整地图、岗厦北密集换乘区和李松蓢终点放大；放大站名可读，搜索选中高亮与站点对应 |
| 固定编号再生成 | station-ids.json注册表生成结果与已测资料包一致，防止未来改名重新生成ID |

最终UI结果包：`/tmp/underground-network-final-ui.xcresult`，xcodebuild exit 0；截图已导出至 docs/screenshots/full-network。首次全线网2项UI测试也通过，后补多音字检索回归后执行最终3项。

审查复现并修复：throughServices.note类型错误仍能打包；diagramPath仅有M或缺参数仍能通过。均先新增失败测试，再修复生成前检查。实际UI检索发现Foundation将“厦”转写为sha，官方标注的岗厦/岗厦北/石厦/松元厦现有明确xia别名。

边界：本次没有测量帧率、做系统飞行模式实验或完成真机全网验收；不能把模拟器测试当作硬件触感及性能证明。行政区归属/底色、真实坐标、出口、首末班尚未补齐，显示待核实/暂无资料；高德百度真机接收及真实定位仍待实测。本次未签名安装真机、未提交Git、未上架。

---

# 早期17站样本验证记录（历史）

日期：2026-09-24。开发环境：macOS，Xcode 26.6 (17F113)，Swift 6.3.3，项目使用 Swift 5 语言模式，最低 iOS 17。此页只记录已执行检查；未执行项另列。

## 已执行

| 检查 | 结果 | 范围 |
|---|---|---|
| Swift 核心测试 | 13 / 13 通过 | 中文 URL 编码、手选起点、坐标参数、同站、交换、次日时间、本地搜索、引用校验、样本标志保护、旧请求取消隔离 |
| Python unittest | 11 / 11 通过 | 必填字段/类型、重复与未知编号、线路成员关系、坐标系、SVG 对应、文本转义、时间、哈希与正式资料门槛 |
| JavaScriptCore 地图检查 | 10 / 10 通过 | 搜索缩放、尺寸变化保留中心、缩放按钮、命令幂等、恢复全图、拖动不点站、站点优先和空白事件 |
| 内置包 verify | 通过 | manifest SHA-256、版本、JSON 引用与 SVG 对象集合 |
| 开发样本以 --production 校验 | 按预期拒绝，exit 1 | 提示“示例资料不能作为正式全线网发布” |
| plist 语法检查 | 通过 | Info.plist、PrivacyInfo.xcprivacy、project.pbxproj |
| 模拟器 Debug 构建 | 通过 | 首轮 generic simulator 构建，包括 arm64 与 x86_64 |
| iPhone 真机目标 Release 构建 | 通过（未签名） | generic iOS / iphoneos SDK；未安装真机 |
| iPhone 17 / iOS 26.5 UI 测试 | 2 / 2 通过 | 本地搜索→详情→终点→手选起点→交换→未安装高德提示；线路选择→恢复→SVG 站点点击 |
| 截图检查 | 已检查地图与路线页 | 截图位于 docs/screenshots；修复了缩放控制遮挡小插图的问题 |

Swift 测试命令：`swift test --scratch-path /tmp/underground-spm`。
Python：`python3 -m unittest discover -s tools/tests -v`。
JavaScript：`/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc tools/tests/map_tests.js`。
UI 测试结果包：`/tmp/underground-ui-run2.xcresult`（本机临时文件，不是交付依赖）。

首轮 UI 测试中，SVG 根节点使用 role=img，导致站点被辅助功能树隐藏；该测试失败。修改为 role=group 后，同一测试通过。独立审查发现的必填字段遗漏、样本标志绕过、resize 清除聚焦均先用测试复现，再修复并复测。定位服务追加请求令牌与不同 CLLocationManager 实例的回调隔离，消除了本工程的 CoreLocation 并发编译警告。

Xcode 仍输出 `Metadata extraction skipped. No AppIntents.framework dependency found.`，因为本工程没有 App Intents；这不是构建失败。

## 验证边界

- 这次没有飞行模式断网切换实验；验证的是全部本地资源和无远程请求代码路径，不能把测试名称中的 Offline 当成实测系统断网。
- JavaScriptCore 使用模拟 DOM 验证交互数学与事件逻辑；UI 测试在真实 WebKit 模拟器里验证了站点按钮与原生消息桥，但未测真实双指硬件触感。
- 请求令牌的单元测试证明过期令牌不能完成新请求；真实 CoreLocation 权限、超时、回调竞态仍需设备复测。
- 没有安装高德/百度真机 App，不能声称外部平台已接收并展示正确路线。只有 URL 构造与未安装回退通过。
- 没有数百站全线网性能测试。内置 17 站样本不构成完整线网验收。
- 首末班与出口的数据结构、显示代码已实现；样本为空，真实数据展示仍需正式资料包验收。
- 没有签名、真机安装、App Store 上传、服务器部署、Git 提交或推送。
# 2026-09-28 首末班车详情精简

- 首末班车改为按线路、方向分组的日期／首班／末班表格；隐藏收录数量、整理与核验时间、来源跳转，删除底部资料说明。特殊日期默认收起，半程终点和次日标记保留。出口内容保持，深铁动态查询标题改为普通文字。
- `swift test --scratch-path /tmp/underground-spm`：34项通过，含3项显示合并测试，覆盖半程、未知适用日、缺一类日期、不同时间及生效日期不合并。日志 `/tmp/underground-compact-core.log`。
- 模拟器构建与4项详情UI测试通过：新版表格／删除资料说明、半程末班、跨午夜、出口缺说明。结果 `/tmp/underground-compact-ui.xcresult`。截图发现跨午夜列间距偏紧后统一列宽，受影响两项复测通过：`/tmp/underground-compact-alignment.xcresult`。
- 最终表格截图已经目视检查，无首末班文字相贴；截图目录 `docs/screenshots/compact-timetable/`。
- 比较服务资料与城市包的既有SHA-256，均未变化；Xcode工程文件逐字节未变化。没有真机验证。

# 2026-09-28 站点服务资料验证

已实际执行：

- `bash scripts/check.sh`：46项Python、36项地图交互、31项Swift测试通过，资料包verify通过。日志 `/tmp/underground-service-check.log`。首次执行因Swift缓存写入沙箱限制失败，经授权重跑成功。
- 完整离线重建：运营方摘录→服务资料归一化→深圳源文件→city/SVG/manifest。比较全部输出SHA-256均一致，没有丢失服务资料。哈希记录 `/tmp/underground-service-rebuild.json`。
- 与实施前快照比较，地图SVG逐字节一致；线路、地图几何、行政区、固定站点编号、线路归属、导航坐标、Xcode工程文件均未变化。2／8独立高亮由既有36项地图测试继续覆盖。
- iPhone17／iOS26.5模拟器4项新增详情测试通过：李松蓢资料状态和导航提示、观澜湖全程／半程末班、前海湾未知生效日期及次日00:17、罗湖D出口缺描述且无精确出口导航。结果包 `/tmp/underground-service-ui.xcresult`，日志 `/tmp/underground-service-ui.log`。
- 截图检查发现首末班横列间距偏紧，已改为等宽两列、16pt间距；受影响的半程与次日两项再次通过。结果 `/tmp/underground-service-ui-spacing.xcresult`。截图位于 `docs/screenshots/station-services/`。
- App已为模拟器成功编译。模型测试覆盖schema1兼容、schema2未知字段日期语义、manifest版本／哈希不符拒绝、日期公告及部分资料。未重新生成Xcode工程。
- 离线依赖检查：CityPackLoader只读取Bundle内三件套；地图HTML、JS、SVG全部内嵌且WebView仅允许about:blank。模拟器测试从内置资料打开详情；没有进行飞行模式切换，因此不将其描述为断网实机验证。仅主动打开来源链接或外部导航才需要外部服务。
- 未执行本轮真机安装或真机交互测试。检测到已连接iPhone15仅是设备发现，不能算真机验证。

资料质量与软件验证分开：432个查询全部取得响应；港铁101张原图已核读；全网动态资料完成原文结构、重复和冲突检查，不代表每条运营事实独立交叉验证完成。7站疑点、41个出口描述缺失以及科学馆6号线结构化时刻缺口详见 [STATION_SERVICES.md](STATION_SERVICES.md) 和资料目录内 `GAPS.md`。
