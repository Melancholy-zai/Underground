# 城市资料包制作指南

数据源为 UTF-8 JSON，当前 schemaVersion=2，兼容读取 v1。所有字段结构以 `Sources/MetroCore/Models.swift` 为客户端定义，`tools/citypack.py` 为生成校验器。当前包已收录站点服务资料，保留逐项缺口与冲突；生成日不是运营资料截止日。

## 三个生成文件

- `city.json`：城市、线网、站点、行政区与资料来源。
- `map.svg`：由资料源的示意坐标与区块生成，包含独立可识别对象。
- `manifest.json`：schemaVersion/cityID/version 以及前两个文件的 SHA-256。

App 在加载前验证哈希和版本，然后验证站点、线路、换乘、行政区与来源的引用。Python `verify` 还解析 SVG，逐项检查 `data-station`、`data-line`、`data-district` 集合是否与 JSON 一一对应。只能整体替换资料包；不要在新 App 包内混用两个版本的文件。

## 城市字段

| 字段 | 说明 |
|---|---|
| schemaVersion | 当前为2，兼容读取1；manifest必须与city一致 |
| cityID / cityName | 稳定城市编号与展示名，例如 shenzhen / 深圳 |
| version | 自行维护的资料版本，如 1.0.0；样本采用 0.1.0-sample |
| dataAsOf | 运营资料截止日 YYYY-MM-DD；尚未核实则 null |
| generatedAt | 此资料包生成日；不能冒充所有资料的更新时间 |
| isSample | true 表示开发样本，界面持续提示；false 要求线网核对记录或完整发布核验记录 |
| coverageNote | 人能读懂的范围、遗漏与状态说明 |
| disclaimer | 示意距离/区界及临时信息限制 |
| map | width、height，示意坐标的画布尺寸 |
| districts / lines / stations / sources | 下述实体数组 |
| coverageReview | 正式资料人工核验记录，样本可省略 |

编号必须符合 `[a-z][a-z0-9_-]*`。同一实体类别不能重复；编号不随站名修改而变化。

## 行政区与地图几何

每个 district 含 id/name/color/polygon/label/note。`color` 为六位 HEX 浅色；`polygon` 为至少三点的 `{x,y}` 数组；`label` 为区名所在点；`note` 可为 null。特殊边界站可关联多个 districtID，或使用空数组配合 districtNote 写明待核实，不能强行划给某一区。

站点 `diagram:{x,y}` 是示意坐标，只用于显示和命中测试；`labelOffset:{x,y}` 是站名字体相对站点的偏移。默认负 x 表示站名向左对齐；可用 labelAnchor=start/end/middle 显式指定。所有站点应在画布范围内，文字和区块仍需视觉检查。

有 `diagramPath` 时按其 SVG M/L/C/Z 曲线路径绘制；无此字段时按 `stationIDs` 顺序连接站点产生折线。路径只接受几何命令，不接受任意 XML。`badgePosition` 指定线路编号位置；`diagramMarkerPath` 保存换乘站图形（包含多站位）；这些都只用于示意图。需要在资料编辑时人工安排示意坐标与 labelOffset，避免站名重叠。工具不会把真实坐标直接当成示意坐标，也不会自动解决完整线网的布图问题。

SVG 合约：

```xml
<g id="line-l1" data-line="l1">…</g>
<g id="station-qianhaiwan" data-station="qianhaiwan"
   data-lines="l1 l5 l11" data-x="580" data-y="500">…</g>
<g id="district-nanshan" data-district="nanshan">…</g>
```

主图只包括所收录的地铁网络；不自动添加规划、在建、城际、国铁或有轨电车。

## 线路

字段：id/name/shortName/color/stationIDs/termini/sourceIDs/coverageNote。

- stationIDs 是依次经过的站点，至少两个；同一线路对象内不重复。
- termini 是两个展示端点名称。**正式包填写运营终点；样本区段必须在 coverageNote 明确标注“展示区段端点”。**
- line.stationIDs 与 station.lineIDs 必须互相一致，换乘站只建一个 station 对象。
- color 应有可追溯的官方依据，样本颜色不得被描述为已核验正式色值。

## 站点

必备字段：id/name/aliases/districtIDs/districtNote/lineIDs/diagram/labelOffset/coordinate/coordinateSourceIDs/exits/timetables/sourceIDs/updatedAt/note。没有资料的可选值填写 null，数组用 `[]`，不要塞占位的“正常运营”记录。

`aliases` 用于别名与拼音检索，可包含旧名。客户端另用系统汉字转写生成拼音和首字母，存在多音字时可通过 aliases 补充正确读音。

`coordinate` 第一版仅接受：

```json
{"latitude": 22.5, "longitude": 113.9, "system": "wgs84"}
```

以上数字只是字段格式示例，**不是任何站点的真实位置**。坐标必须带非空 coordinateSourceIDs。正式包所有车站必须有经核验坐标；样本可以 null，使用外部地图按城市和站名确认。GCJ02/BD09 不能只把 system 改成 wgs84，应重新取得匹配坐标或通过有据可查的资料整理流程转换。

### 高德站点导航位置

可选 `amapLocation` 包含 `poiID/latitude/longitude/system/sourceIDs/updatedAt`，其中 `system` 只接受 `gcj02`。它是高德专用位置，与通用 `coordinate`（WGS84）和 `diagram`（示意坐标）分开存储。旧资料可缺省此字段；当前深圳生成器要求351站全部匹配。

高德手动起点优先使用此位置，发送 `sid/slat/slon`，站点终点发送 `did/dlat/dlon`，`dev=0`。系统定位起点使用WGS84、`dev=1`，终点通过POI编号解析；不把GCJ02终点坐标混入同一请求。手动起点既无高德位置也无WGS84坐标时拒绝调起。百度不读取此字段。

## 出入口

v2新增 `station.serviceReview`，分别记录时刻与出口的 `notCollected/partial/reviewed/conflict` 状态，以及 `timetableNote/exitNote/verifiedAt/note`。`reviewed`只表示已收录材料经过核对，不表示完整或实时。

可选 `station.serviceNotices` 保存日期公告：`id/text/serviceDates/validFrom/validThrough/sourceIDs/verifiedAt`。离散日期必须合法、排序且唯一；日期数组非空或validFrom至少一个。约、不早于等文字不转成精确时刻，不自动判断今天适用。来源可选 `sourcePublishedAt` 仅表示发布日期。完整流程见 [STATION_SERVICES.md](STATION_SERVICES.md)。

每条 exit 包含 id/name/description/coordinate/sourceIDs/updatedAt/verifiedAt。id 在本站唯一。description 只写有来源的道路、地标，不推断当前开放；v2允许null并显示“道路／地标暂无资料”。coordinate 可为 null；不为空时外部导航按钮才出现。sourceIDs 必填；updatedAt为本地整理日，verifiedAt为核对日。

## 本站首末班车

每条 timetable 包含：

- id：本站唯一记录编号。
- lineID：必须经过本站。
- direction：来源行驶方向标签，不自动等同每班实际终点。
- serviceDays：工作日、休息日、指定日期或经核实的季节方案；不可预设所有线都有冬夏表。
- validFrom / validThrough：生效日期与可选截止日。v2允许生效日期未知时为null，不得以采集、核验或发布日代填。
- first / last：其中至少一个有可靠资料；不能用全线运营时间填本站记录。
- lastDestination：如果末班终到不同，填写实际终到站；否则 null。
- note / sourceIDs / updatedAt / verifiedAt：备注、来源、本地整理日与核对日。serviceLabel区分全程、半程服务，不按最晚时间合并。

时间结构：

```json
{"clock": "00:12", "dayOffset": 1}
```

界面显示“次日 00:12”。`clock` 只能是 00:00–23:59，`dayOffset` 只能是 0 或 1。末班的总分钟数不能小于首班；不能用 24:12 代替次日表示。上例只用于解释结构，不是深圳任一站的时刻。

同一线路两方向、不同服务日或不同有效期分别录入记录；界面全部按适用条件展示，不自动判断节假日历，也不将过期记录当作今天的确认时刻。没有任何可靠记录时该线路显示“暂无资料”。

## 来源

每条 source 含 id/title/url/accessedAt/license/note。url 为 HTTPS 或 null；license 写实际使用条件，不能因为网页可访问就推断可以自由再发布。note 说明该来源支持什么事实，以及是否只是后续核验入口。

建议按“事实层级”单独引用：站名及换乘、行政区、坐标、某出口、某方向时刻分别使用对应来源编号。更新时间不等于访问网站的日期。

## 正式包门槛

完整发布包（`--production`）强制要求 dataAsOf、所有车站坐标、行政区归属，以及以下人工记录：

```json
{
  "coverageReview": {
    "reviewer": "实际核验人员姓名或内部编号",
    "completeNetwork": true,
    "usageRightsConfirmed": true,
    "districtsReviewed": true,
    "reviewedAt": "2026-09-24",
    "sourceIDs": ["实际存在的来源编号"]
  }
}
```

日期是结构示例，不要照抄为未执行工作的核验日期。只有实际完成核验才能设 true；布尔值本身不是证明。缺出口或时刻仍可显示“暂无资料”，但必须人工评估这些缺口能否满足发布目标。

```bash
python3 tools/citypack.py validate data/shenzhen/source.json --production
```

当前线网核对版执行此命令应失败，这是预期保护。准备替换资料时先输出到新的临时目录、执行 verify 和人工视觉检查，再将三个文件一起放入 App/Resources/CityPack，重新构建。第一版未实现手机端在线或文件导入更新。


## 线网核对版（0.2.0-network）

`isSample=false` + `networkReview` 表示已核对完整站序，但不等于资料完全可发布。记录包含 `reviewedAt`、`sourceIDs`、`lineCount`、`stationCount`、`membershipCount`；Swift/Python 都检查计数与数据、来源引用一致。界面持续显示服务资料缺口。仅将样本的 isSample 改为 false，缺少核对记录时仍会被拒绝。

本次 `networkReview` 为 17 / 351 / 432；其中 432 是线路内站次（换乘站会多次出现），不是不同站点数。深圳生成器必须加载 `references/district-layout.json` 的非空分区底图与完整固定编号对应表。站点 `districtIDs=[]` 搭配具体 `districtNote` 表示局部待核实，SVG 只绘制普通站点符号及站名，不绘制待核实标记；原始区属状态和说明仍在详情展示，不按示意底色反推站点区属。全线网打包还会检查已赋区属站点的底色及区名位置是否与分区匹配。`--production` 不会因为存在 networkReview 而跳过原有严格门槛。

`throughServices` 显式记录两条线路的贯通端点：`fromStationID`、`toStationID`、两项 `lineIDs` 与 `note`。必须分别对应两条线的端点。本次莲塘属于 2 号线，梧桐山南属于 8 号线；图形中8号线路径从莲塘继续相连，两个端点不增加虚假的线路归属。

重新生成当前版本（不联网）：

```bash
python3 tools/collect_shenzhen.py
python3 tools/citypack.py build data/shenzhen/source.json App/Resources/CityPack
python3 tools/citypack.py verify App/Resources/CityPack
```

参考输入包括官方 XLSX、从中提取的站序，以及从官方 PDF 转录并逐站匹配的 schematic-layout.json。固定编号保存在 references/station-ids.json；站名更改时更新名称键但保留其原编号，并同步更新布局映射。脚本要求站序与布局站点集合完全一致；不得把图形坐标当作经纬度。原17站样本保存在 tools/tests/fixtures/sample-city.json，供兼容性和发布门槛测试。


## 周边地图资料（可选 mapContext）

`mapContext`含`reviewedAt/note/sourceIDs/networkFrame`及以下数组：

| 字段 | 内容 |
| --- | --- |
| areas | 区域id/name/kind/polygon/label/note/sourceIDs；类型neighbor/water/home/acrossWater |
| boundaries | 独立边界id/kind/points/sides/label/note/sourceIDs；类型city/region/coast，sides恰为两侧名称 |
| insets | id/title/note/frame/areas/sourceIDs；内部坐标相对于插图内容区，主图与插图不共享地理比例 |
| annotations | id/text/position/fontSize/sourceIDs；地区未直达等有依据的文字说明 |
| focusAreas | id/title/frame；SVG输出data-map-focus与框坐标，Web通过area命令聚焦 |
| stationNotes | stationID/marker/text/sourceIDs；引用已有站点，保留配套核验说明与来源；marker是历史说明编号，当前地图不显示 |

frame/networkFrame为x/y/width/height，须正尺寸且在画布内。mapContext本次复核日期独立于dataAsOf和generatedAt。装饰图例不得使用data-station/data-line，避免污染业务对象和点击；区域、独立边界、插图、聚焦框也参与JSON/SVG集合一致性校验。

线路图例对象使用 `data-legend-line` 引用线路ID；每条线路恰好一项。它与用于线路几何的 `data-line` 分开校验。图例通过 `aria-pressed` 反映同一个单选状态；`throughServices` 只表达运营关系，不决定高亮范围。
