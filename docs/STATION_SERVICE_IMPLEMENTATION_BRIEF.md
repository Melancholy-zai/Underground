# 深圳站点首末班车与出入口：资料核查及代码修改依据

核查日期：2026-09-28。此文档是实施输入，不是已完成的数据导入或发布验收。此次只新增研究文档、目录对照表和查询审计记录，不修改 App、生成器或内置城市包。

## 1. 结论与实际完成范围

- 官方站点查询页有结构化首末班车和出口资料，可以在开发电脑上整理为本地资料包；App 不需要新增联网或服务器功能。
- 已读取深铁官方目录，对照当前项目完成 **17条编号线路、432个线路内站次、351个不同站点** 的目录匹配。目录完整不代表时刻和出口完整。
- 已按官方网页查询方式抽查 **6个站点详情**：罗湖、莲塘、溪涌、前海湾、李松蓢、坪地六联。不是全网详情采集。
- 当前内置包351站的 `timetables` 与 `exits` 均为空；补齐需要增加可维护的输入文件与转换流程，不能只改详情页面。
- 官方网页的初始静态HTML与加载后的查询结果存在差异。不能直接抓取初始HTML作为当前时刻表。
- 接口可访问不等于获得开放API承诺或数据再分发许可。使用条件另行核实，不能自动填写 `usageRightsConfirmed=true`。

附属产物：

- [432条站点—线路—官方查询编号对照CSV](research/station-services-2026-09-28/station-source-index.csv)
- [目录覆盖与6站查询审计JSON](research/station-services-2026-09-28/source-audit.json)
- [4号线、13号线运营方来源核查](STATION_SERVICE_OPERATOR_SOURCES.md)

CSV中的 `directory_matched_only` 只表示目录对应成功；不能据此判断首末班车、出口或使用条件已核验。

## 2. 已验证的深铁资料入口

| 来源 | URL | 用途与限制 |
| --- | --- | --- |
| 官方站点查询 | https://www.szmc.net/shentieyunying/yunyingfuwu/zhandianchaxun/ | 用户可打开的来源入口；其iframe再动态加载站点资料 |
| 站点目录脚本 | https://www.szmc.net/styles/index/zdWeb/js/xlurlList.js | `zdurl` 提供线路、站名和查询编号，当前目录对账完成 |
| 官方查询脚本 | https://www.szmc.net/styles/index/zdWeb/js/base.js | 明确写出POST方式、`StieCode`参数、返回字段及页面渲染规则 |
| 页面使用的查询地址 | https://www.szmc.net/zdxx | 公开站点页面内部使用；尚未找到第三方开放API文档、稳定性或授权承诺 |
| 初始罗湖HTML | https://www.szmc.net/styles/index/zdWeb/luohu.html | 只用于解释静态/动态差异，不能作为本次正式录入依据 |
| 官网使用声明 | https://www.szmc.net/mianzetiaokuan/ | 网站对内容权利与使用有限制，未发现允许无条件批量再发布的声明 |

查询格式来自官方脚本，本次实际成功执行：

```http
POST https://www.szmc.net/zdxx
Content-Type: application/x-www-form-urlencoded

StieCode=0101
```

`StieCode` 是官网原有拼写，不要“修正”为 `SiteCode`。GET查询未通过本次网页工具验证，实施时按已验证POST方式处理。

页面来源链接可写成 `https://www.szmc.net/shentieyunying/yunyingfuwu/zhandianchaxun/?0101`。官方脚本读取父页面问号后的编号；CSV按这个规则生成各站入口，未逐一在浏览器里点开432个链接。

目录对账只做两类名称规范化：去除首尾空白（观澜湖有尾部制表符）；显式别名“深圳北”→“深圳北站”。使用CSV中项目固定ID，不能重新按拼音生成ID。6号线支线官网目录值为 `66`，映射项目支线ID。换乘站多个查询编号映射同一项目站点ID。

## 3. 实际抽查与需要处理的异常

以下时间仅是本次查询观察值，用于开发样例与核验线索；没有把它们认证为长期有效的出行时刻。

| 站点／编号 | 本次观察 | 对实施的要求 |
| --- | --- | --- |
| 罗湖／0101 | 动态工作日往机场东06:20—23:00；初始HTML首班06:30。动态返回8条出口 | 以动态结果作为候选，保留来源与核验状态，禁止导入静态旧表 |
| 莲塘／0232 | 工作日有2号线、8号线两组记录；2号线某方向标“莲塘”，8号线方向标“梧桐山南／溪涌”；返回3条出口 | 与项目莲塘仅属 `l2` 冲突；隔离待核对，不能为了通过校验而给地图加8号线归属或修改高亮 |
| 溪涌／0812 | 返回8号线资料、4条出口；西行方向标签仍为“梧桐山南” | 不直接把标签当列车实际终点，也不能未经核验改写为赤湾 |
| 前海湾／0122 | 一个响应含1、5、11号线时刻；11号线工作日往红岭南末班00:17；返回2条出口 | 展开多线路；本次常规日间首班后的00:17应表达为下一服务日凌晨，不能显示为当天首班前 |
| 李松蓢／1326 | 工作日往深圳湾口岸06:30—23:00；`outAndText=[]` | 时刻与出口分开计覆盖，出口空不代表不存在；优先补查运营方车站页 |
| 坪地六联／0338 | 工作日往福保06:00—23:00，返回4条出口 | 新开通站已有候选资料，但尚需有效期与公告交叉核验 |

罗湖出口还出现 `outt=D出入口`、`textt=无`。处理应为“来源列出此出口，但道路／地标说明未提供”，不能展示成“没有D出口”，更不能当实时关闭。

运营方图片补充已完成目视抽查（详见附属来源笔记）：

- [4号线时刻表](https://www.mtrsz.com.cn/frontend/default/src/channel/operation_timetable_4line.html)区分全程与半程末班。观澜湖往福田口岸全程末班23:02，另有往龙华的半程末班23:32；两者必须并列保留，不能取较晚值覆盖前者。表中“开站／关站”不能当“首班／末班”。
- [13号线时刻表](https://www.mtrsz.com.cn/frontend/default/src/channel/operation_timetable_13line.html)的李松蓢往深圳湾口岸06:30—23:00，与深铁抽查一致；下村往李松蓢末班为次日00:02。该图没有明确工作日分类，不能套用深铁响应分组反过来替图片补造适用条件。
- [李松蓢运营方车站页](https://www.mtrsz.com.cn/frontend/default/src/channel/site_detail.html?id=13518&hcc=13hx&cc=13hx&pc=operation)有出口索引图，可补深铁响应的出口缺口。例如A口关联玉荔社区健康服务中心。图中网格编号不是经纬度。

对4、13号线优先以运营方对应服务资料作为候选主来源，深铁查询用于交叉检查；相互冲突时按明确适用日期和范围复核，而非按网站域名或请求先后自动覆盖。OCR只产出候选，分钟数、次日、出口号必须逐项对图检查。

审计JSON保存查询参数、响应字段、计数、响应SHA-256；哈希用于比对响应，不能独立证明来源真实性。此次原始响应在开发电脑临时目录，未随App打包；正式采集应在适用使用条件下建立持久原始记录、时间戳和核验日志。

## 4. 原始字段到项目字段的映射

| 官方响应 | 项目字段／处理 |
| --- | --- |
| `siteCode` | 来源查询编号，保留在研究/资料输入中；不能替换项目 `Station.id` |
| `siteName` | 核对站名，谨慎去除末尾“站”后再按显式映射匹配 |
| `workDay[]` | `serviceDays=工作日`，不是自动套用每个周一至周五 |
| `dayoff[]` | `serviceDays=休息日`，不擅自转成只适用周六日 |
| `holidays[]` | 标为“来源节假日参考表，具体日期未注明”，不能承诺今天适用 |
| `suoshuluxian` | 显式线路名称映射到 `lineID`，并验证该线经过本站 |
| `xinshifangxiang / shoubanche / mobanche` | 展开为第一个方向的 `direction / first / last` |
| `xinshifangxiangxia / shoubanchexia / mobanchexia` | 展开为第二个方向，不可漏掉带 `xia` 的字段 |
| `outAndText[].outt` | `StationExit.name`；稳定出口ID依据站点+编号建立 |
| `outAndText[].textt` | `description`，去除HTML并按纯文本显示，保留原文以便核对 |
| `gaofenjiange / pingjunjiange` | 本轮不导入倒计时，也不由它们推算首末班 |
| `busInof` | 公交接驳，排除本轮范围；不能用它推导地铁出口总数 |
| 响应无生效日期、修改日期 | 不得用抓取日期伪造 `validFrom` 或运营方更新时间 |
| 响应无出口坐标 | `coordinate=null`，不显示出口精确导航按钮 |

同一个查询结果可能包含多条线路，按响应中的线路字段拆分，而不是把所有时刻写成查询编号所属线路。一个换乘站从不同编号返回资料可能重复或冲突：对比来源再合并，禁止“最后请求覆盖前面结果”。出口合并按站点+出口编号，不按所属线路复制多份。

## 5. 必须先定清楚的数据语义

### 日期与核验

目前 `Timetable.validFrom` 是非空String，而实际来源没有提供这个日期。建议改为可空，并同时修改Python校验及UI；未知时显示“生效日期未注明”。

- `source.accessedAt`：实际访问日期。
- 新增 `verifiedAt`：实际完成核验日期；未完成可空。
- 新增 `sourcePublishedAt`：来源明确提供的发布时间，可空。网站栏目发布日不一定是时刻生效日。
- `validFrom/validThrough`：资料明确适用的运营日期，可空。
- 旧 `updatedAt` 不再以“运营资料更新”笼统呈现；迁移时明确它是本地整理/核验日期，未知的历史含义不能强行改成已核验。
- 包的 `generatedAt` 与线网 `dataAsOf` 保持各自语义，不因补出口把线网截止日直接改成今天。

### 缺失和无发车

- `--`、空字符串不能转成00:00。
- 双向字段都为空时，不生成“首末均null”的假时刻记录；原始行及原因保留在核验报告。
- `--`并不自动等于“该方向无发车”，需结合终点性质和来源说明核实。建议单独的方向资料状态表达 `unknown / notApplicable / available`。
- 出口编号可靠但说明为“无”时，可以保留编号并显示“道路／地标暂无资料”。不要为满足非空校验编造地点。
- 状态应分到时刻、出口两类，至少区分 `notCollected / partial / reviewed / conflict`；这些是资料工作状态，不是车站运营状态。

### 时间、末班和临时公告

- 标准时间使用现有 `{clock,dayOffset}`。显式24:xx转换为00:xx、dayOffset=1，保留原始值。
- 对“白天首班、凌晨末班”这种已确认服务日语义进行次日转换；不能对所有无法排序的数字一律加一天掩盖错误。仅末班、无法确定服务日或其他歧义进入待核验。
- 方向与实际终点分开；半程末班与全程末班按独立记录和明确标签表达，必要时增加 `serviceLabel`，不要覆盖全程末班。
- 若原文是“不早于01:00”“约00:00”，它不是精确时刻，不能转换为 `last.clock=01:00/00:00`。本轮用带日期的说明保留，不新增假精确记录。
- 不自动判断“今天是节假日”。本轮显示来源给出的适用条件；未来若做“今日时刻”还需要调休日历和公告优先规则。

实际例证：[深圳交通运输局2026-09-24公告](https://jtys.sz.gov.cn/jtzx/wycx/dtcx/cxtx/content/post_12999802.html)只针对若干指定日期，排除20号线，并包含半程末班和“不早于”的时间。它可支持条件说明，不能推算所有站的准确末班分钟。

### 2／8号线

保留地图、图例的独立高亮和已有站点线路归属。`throughServices` 表达运营连接，不用于修正原始数据。莲塘的额外线路行与溪涌的方向标签进入人工覆盖表；每条覆盖必须写原始值、调整值、依据URL及核验人/日期。没有证据时保留待核验，不能只是把“梧桐山南”全局替换成“赤湾”。

## 6. 建议修改的文件与任务

下列均为待实施，不表示本次已经修改。

| 文件 | 具体修改 |
| --- | --- |
| 新建 `data/shenzhen/references/station-services/` | 保存来源索引、原始候选资料、核验后的时刻/出口、人工覆盖及缺口报告；与线网几何分开 |
| 新建 `tools/collect_station_services.py` | 仅在开发电脑执行；读取明确站点映射，限速、缓存、失败记录、断点续采；不在App启动时联网，不绕过验证码/登录限制 |
| 新建 `tools/normalize_station_services.py` | 原始资料→候选记录→人工确认输入；拆方向、线路、日期；输出重复/冲突/缺失报告，拒绝静默补值 |
| `tools/collect_shenzhen.py:46` | 将固定 `exits=[] / timetables=[]` 改成按稳定站点ID合并核验输入；核验资料文件缺失应报错，不能悄悄清空旧资料 |
| `Sources/MetroCore/Models.swift:128` | 出口支持“编号已知、描述未提供”；时刻支持未知生效日期、核验元信息、特殊服务标签及资料状态 |
| `Sources/MetroCore/CityRepository.swift:136` | 校验日期、来源、站内ID、线路归属；保持未知/无发车区别；不能放宽线路关联来吞掉莲塘冲突 |
| `tools/citypack.py:100` 与 `:213` | 与Swift同步字段和验证规则；输出时刻/出口覆盖率；首末至少一个有效，日期可空时不比较空值 |
| `App/Views/StationDetail.swift:30` | 按线路、方向、适用条件分组；显示特殊末班；未知日期不拼成假的有效期；出口缺描述有明确提示 |
| `App/Views/StationDetail.swift:85` | 把来源发布日期、核验日、访问日分清楚；按记录显示来源；修正已有高德位置却提示无坐标的说明 |
| `App/Views/Components.swift`、`Models.swift` 的 `needsMetadata` | 不再用整包 `coverageReview==nil` 代替某站时刻/出口是否完整；区属疑点与服务资料缺口分开提示 |
| `App/Services/CityPackLoader.swift:21` | 若按下面建议升级格式，同步兼容支持的版本，并校验manifest和JSON的schemaVersion一致 |
| `docs/DATA_FORMAT.md`、`docs/SOURCES.md` | 更新字段语义、来源范围、许可实际状态和维护方式 |
| `tools/tests/`、`Tests/MetroCoreTests/`、`UITests/` | 覆盖下节真实异常，勿仅测试字段存在 |

格式建议：此次会允许旧格式不接受的 `validFrom=null` 和缺出口说明，建议新包使用 `schemaVersion=2`。生成器、manifest、加载器、Swift验证必须一起调整；当前 `citypack.build` 把manifest版本固定成1，应改为输出与资料一致的版本。新版客户端可兼容旧v1样本（缺新增字段按未知处理），旧客户端不承诺加载v2；第一版仍通过重新构建整包更新。不能只把JSON版本号改成2。

建议将v2最小字段约定固定如下，避免Python与Swift分别猜测：

| 对象 | 字段约定 |
| --- | --- |
| Timetable | 现有 `validFrom` 改 `String?`；增加 `serviceLabel: String?`、`verifiedAt: String?`；`updatedAt`保留为本地记录整理日期，不再冒充来源更新日；`direction`与 `lastDestination`保持现有职责 |
| StationExit | `description`改 `String?`，`name`仍必填；增加 `verifiedAt: String?`；`coordinate=null`合法，未知描述不得变成空的“已核验地点” |
| DataSource | 增加 `sourcePublishedAt: String?`；`accessedAt`继续必填，接口响应没有发布日期时为null |
| Station | 增加可选 `serviceReview`，包含 `timetableStatus`、`exitStatus`、`note`、`verifiedAt`；前两项取 `notCollected / partial / reviewed / conflict`；其余可空。旧包缺省为unknown展示，不能默认为reviewed |
| 人工核验输入 | 单独记录方向状态 `unknown / notApplicable / available`、原始字段定位、来源编号及依据；未确定无发车的行不生成运营事实。若App要展示明确的“该方向不提供上车服务”，再将这类经核验的方向状态输出，不用双null时刻记录表达 |

`reviewed`表示按现有来源核验过已收录资料，不自动等于全部出口或全部特殊班次已收录；完整性另看覆盖报告和来源范围说明。所有新增日期均用YYYY-MM-DD或null；时间戳/原始发布字符串可留研究输入，不能塞入日期字段。首末方向ID与出口ID要稳定，修正一个时间不能产生新记录并留下旧记录并列。

不要为服务资料补齐重生成Xcode工程；保留已有签名配置。不要修改线网几何、分区背景、站点固定ID及2／8高亮规则。

## 7. 一个可对照的转换样例

以下为“待核验的中间记录”示意，不是当前v1 `city.json` 可直接导入的对象。样例数字来自本次罗湖动态查询；reviewStatus明确不代表核验通过。

```json
{
  "stationID": "s_b1dbfb916409",
  "sourceStationCode": "0101",
  "sourcePath": "workDay[0]",
  "lineID": "l1",
  "direction": "机场东",
  "serviceDays": "工作日",
  "first": {"clock": "06:20", "dayOffset": 0},
  "last": {"clock": "23:00", "dayOffset": 0},
  "validFrom": null,
  "validThrough": null,
  "sourcePublishedAt": null,
  "accessedAt": "2026-09-28",
  "verifiedAt": null,
  "reviewStatus": "candidate",
  "sourceURL": "https://www.szmc.net/shentieyunying/yunyingfuwu/zhandianchaxun/?0101"
}
```

正式对象仍需要稳定的记录ID、有效sourceIDs引用和本地整理日期等完整字段；中间层的candidate/conflict记录默认不进入对外展示的正式时刻数组。核验标准是与官网实际展示、现行运营范围和相关调整公告一致；无第二来源时明确记录核验限度，不虚构交叉证据。

## 8. 分批实施与验收

1. 先明确资料使用方式和来源索引；读取现有CSV作为映射起点，不把432条目录误当432份已核验详情。
2. 用6站抽查案例跑通转换与详情展示，并补充4号线、13号线运营方样例。方向冲突未解决的记录仍留在候选层。
3. 经使用条件确认后按线路整理，使用缓存与受控请求；换乘站复用已有结果。不能从一次抽查成功推断所有请求稳定可用。
4. 每批输出：每站每线路的时刻状态、两个方向/服务日覆盖、出口条数与完整性、冲突、未获取原因。出口数量只能写“已收录”，没有完整清单依据不能宣称“全部”。
5. 在临时目录生成并验证城市包，然后整体替换三个文件；不手改最终JSON绕过生成流程。
6. 补完后执行 `bash scripts/check.sh`，并完成针对站点详情的模拟器与离线真机抽查。签名、导航参数和地图交互保持现状。

需要新增的回归：

- 罗湖静态06:30不会被当成动态查询首班；不存在默认采用初始HTML的回退。
- 前海湾多线路完整展开，00:17标“次日”，重复查询不产生重复时刻/出口。
- `--`不是00:00；未知不是“无发车”；罗湖D出口描述“无”不代表出口不存在。
- 李松蓢时刻已取得、出口空，显示两个不同的资料状态。
- 莲塘冲突被隔离，站点lineIDs和2／8独立高亮不被采集修改。
- 无生效日期可加载并显示“未注明”，访问日不能成为生效日。
- 节假日参考表不自动成为指定节假日的精确安排；不早于/约几点不转成精确末班。
- 缺描述出口不显示假地标；缺坐标出口不显示精确导航。
- 重新生成不丢失已核验资料；v1兼容、v2整包校验和哈希失配拒绝加载。

完成标准是全网逐项查验、已可靠取得的资料入包、剩余缺口明确。不能以单元测试通过或数组非空替代真实性与全网覆盖核验。

## 9. 本轮证据边界

已执行：官方来源读取、6站POST只读查询、官方目录与项目逐线路对账、代码/模型/校验器阅读、研究文件结构检查。

未执行：全网站点详情下载、全网首末班与出口人工核验、运营方授权申请、业务代码修改、城市包更新、App构建和真机测试。临时公告只核实了一个当前实例，不是公告全量监测。
