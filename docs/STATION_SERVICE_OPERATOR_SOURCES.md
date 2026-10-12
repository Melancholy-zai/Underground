# 深圳4号线、13号线站点服务资料来源核查

核查日期：2026-09-28。本文件仅记录研究事实和后续录入建议；未修改 App、采集脚本或城市资料包。

## 结论

港铁深圳官网提供两条线路的首末班时刻表及站点周边/出口资料，13号线覆盖北延至李松蓢的新站。主要内容以图片呈现，需要逐图人工核对或 OCR 后复核，不能把 HTML 正文为空视为没有资料，也不能把目录存在视为所有字段已核实。

本次实际读取了官方公开网站的目录及正文 JSON，并通过浏览器截图核读了4号线时刻表、13号线时刻表、李松蓢站周边图及出口索引图。其余站点尚未逐图核读。

## 1. 稳定的人类可读入口

| 内容 | 官方链接 |
|---|---|
| 4号线介绍与站点目录 | [4号线](https://www.mtrsz.com.cn/frontend/default/src/channel/line_introduce_4Line.html) |
| 13号线介绍与站点目录 | [13号线](https://www.mtrsz.com.cn/frontend/default/src/channel/line_introduce_13Line.html) |
| 4号线首末班 | [4号线运营时刻表](https://www.mtrsz.com.cn/frontend/default/src/channel/operation_timetable_4line.html) |
| 13号线首末班 | [13号线运营时刻表](https://www.mtrsz.com.cn/frontend/default/src/channel/operation_timetable_13line.html) |
| 李松蓢站详情 | [李松蓢](https://www.mtrsz.com.cn/frontend/default/src/channel/site_detail.html?id=13518&hcc=13hx&cc=13hx&pc=operation) |
| 下村站详情 | [下村](https://www.mtrsz.com.cn/frontend/default/src/channel/site_detail.html?id=13517&hcc=13hx&cc=13hx&pc=operation) |
| 观澜湖站详情 | [观澜湖](https://www.mtrsz.com.cn/frontend/default/src/channel/site_detail.html?id=9700&hcc=4hx&cc=4hx&pc=operation) |

线路范围另由[港铁集团13号线介绍](https://www.mtr.com.hk/ch/corporate/consultancy/szmtr-l13.html)交叉核对：北延于2026-06-28投入服务，西丽高铁站不在一期已投入服务站点中。不能将工程站数直接当作开放站数。

## 2. 已验证的公开内容结构

官网自己使用的[前端数据脚本](https://www.mtrsz.com.cn/frontend/default/js/api/common/index.js)和站点详情页面显示：公开内容通过 `server-front/front` 请求取得。它们是网站实现接口，不是已获承诺的第三方开发者 API；这里只用于研究和后续电脑端资料整理，不建议让 App 运行时依赖它，也尚未核实批量复用条件。

- [4号线站点目录](https://www.mtrsz.com.cn/server-front/front/content/page?channelIdStr=7590&pageSize=100&orderBy=0)：返回23个站点，另有“车站无障碍设施”文章，不能把后者当站点。
- [13号线站点目录](https://www.mtrsz.com.cn/server-front/front/content/page?channelIdStr=7591&pageSize=100&orderBy=0)：返回26个运营站点，另有无障碍设施文章；含红坳公园、光明城、德雅路、凤凰城、月亮路、将围、新庄、公明广场、上村、下村、李松蓢。
- [4号线时刻表正文](https://www.mtrsz.com.cn/server-front/front/content/detail?id=9115)：`publishTime=2026-02-05 18:18:59`。
- [13号线时刻表正文](https://www.mtrsz.com.cn/server-front/front/content/detail?id=9116)：`publishTime=2026-06-26 19:26:29`。
- [李松蓢站正文](https://www.mtrsz.com.cn/server-front/front/content/detail?id=13518)：`publishTime=2026-06-27 22:27:01`。
- [下村站正文](https://www.mtrsz.com.cn/server-front/front/content/detail?id=13517)：`publishTime=2026-09-23 16:33:29`，周边资料中确有一张路径日期为2026-09-23的图片；尚未核读该图片变更内容。

以上是实际响应字段值。`publishTime` 表示内容发布元数据，不保证是整张时刻表的生效日期；目录与正文时间有1秒差异，记录字段来源即可，不能据此制造业务版本差异。

站点详情的 `instance.instanceItems[field=contents].value` 映射为：

| 原始键 | 官网显示栏目 | 使用建议 |
|---|---|---|
| `正文` | 站内设施 | 不要当作出口列表；也可能含时刻/车站设施图片，逐图识别 |
| `content1` | 车站周边 | 周边图与地点—出口索引，是出口文字的主要候选来源 |
| `content2` | 票价信息 | 不在本次功能范围，不误录成首末班 |

## 3. 已目视核读的首末班样例

### 4号线

[官方时刻表原图](https://www.mtrsz.com.cn/u/cms/www/2026/02/05/2019355009911611395.jpg)标题注明“平日和周末”，同时列出开站、关站、两个方向首末班、两个方向半程加班车。不能把开站时间写成首班车，也不能把“平日和周末”自行扩展成所有节假日。

少量录入样例：观澜湖站，往福田口岸首班06:25、末班23:02；另有往龙华的半程末班23:32。往牛湖首班06:56、末班次日00:05。

因此同一行驶方向可以有多个末班目的地。时间模型需要保存实际终到站及短线服务标记，不能用单个 `lastTrain` 覆盖所有情况。关站时间另存或本轮不展示。

### 13号线

[官方时刻表原图](https://www.mtrsz.com.cn/u/cms/www/2026/06/26/2070468680607526913.jpg)实际列出李松蓢至深圳湾口岸的26站。图中没有明确工作日/周末分类标题，也没有清晰列出表格生效日，应保留“来源未注明”而非推定。

少量核读样例：

| 本站 | 方向/终到站 | 首班 | 末班 |
|---|---|---|---|
| 李松蓢 | 深圳湾口岸 | 06:30 | 23:00 |
| 下村 | 李松蓢 | 06:45 | 次日00:02 |
| 下村 | 深圳湾口岸 | 06:32 | 23:02 |

终点站朝本站终到方向在此表用横线表示，不能生成一个可乘车的反方向时刻。两张表均有末班开出前至少5分钟可能不能入闸的提示，可在资料说明中准确转述；这与末班车时间不同。

## 4. 出口资料确实可补，但要从图中整理

已核读[李松蓢周边地图](https://www.mtrsz.com.cn/u/cms/www/2026/06/25/2070114743123636226.jpg)及[李松蓢地点—出口索引](https://www.mtrsz.com.cn/u/cms/www/2026/06/25/2070114792255713282.jpg)：地图标有A/B/C/D出口，索引可核对具体出口对应的地点。少量事实样例：A出口关联玉荔社区健康服务中心；D出口关联深圳青少年足球训练基地、李松蓢学校。

索引中的 `X4`、`U3/V3` 等是该周边图的网格索引，**不是经纬度**。不能把它转换成未经核实的精确出口坐标。公交路线也不属于本次出口文字补齐范围。

建议将入口号与道路/地标拆开整理，每条备注关联来源图片和人工核验状态。不能据这些静态图片声称某出口当前开放。

## 5. 建议交付给实现者的规则

1. 以项目现有稳定站点ID、线路ID关联，另外保存运营方文章ID；不能用目录排序推算站点ID。
2. 时刻的小时分钟与跨日偏移分开保存，例如00:02配 `dayOffset=1`。未知时间、无此方向、资料尚未采集是不同状态。
3. 主方向与实际末班目的地分别保存，以支持4号线半程末班。
4. `sourcePublishedAt`、`retrievedAt`、`verifiedAt`、`validFrom/validTo` 分开；有效日期未公布则留空。
5. 图片OCR只生成候选，不直接进入正式资料包。首末班数字、出口号、站名、日期必须人工复核。
6. 4号线23站、13号线26站可作为本次目录覆盖断言；出口和时刻字段覆盖度另行统计，不能因为目录齐全就计为资料全完成。
7. 调整公告优先于旧表，但需只在公告适用日期和范围内覆盖；不把国庆/中秋延时写成年常态时刻。

## 6. 本次没有确认的事项

- 未逐站逐项核读全部出口/时刻内容，因此不是全网已核验资料表；本次目视核读和摘录样例的范围以上文为准。
- 尚未确认全部站点出口编号完整性及当前开放状态。
- 未做节假日最新调整公告的穷尽检查。
- 未核实网站资料批量复制与 App 随包分发的使用条件；公开可访问不等于开放数据授权。
- 网页检索工具曾对动态HTML返回空正文、部分图片返回不可访问；随后用公开HTML/CMS定位原图，并在浏览器成功查看上述4张图。不能把最初抓取失败写成官网没有资料。
