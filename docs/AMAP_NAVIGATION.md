# 高德手动起点交接修复（2026-09-28）

## 问题与修正

用户反馈手选起点后，高德仍使用当前位置。代码检查确认手动选择没有被定位回调覆盖；旧包351站的通用坐标均为空，旧链接只有起终点名称，没有站点编号或起点坐标。旧测试仅断言名称存在，不能证明高德实际接收到了该站。

现在使用高德公开站点编号和位置生成链接。手动起点发送 `sid/slat/slon/sname`；站点终点发送 `did/dlat/dlon/dname`，`dev=0`。起点既无高德位置也无WGS84坐标时提示错误。当前位置仍发送取得的WGS84坐标、`dev=1`，站点终点通过 `did` 解析，避免在单一 `dev` 下混入GCJ02。手动起点不触发定位。百度原有交接方式保留。

如将来录入仅有WGS84坐标的出口，而手动站点起点只有GCJ02位置，当前会明确提示改选车站；不能把不同坐标系塞进同一个高德请求。当前内置包没有已核实出口，因此不影响现有可选路线。

## 资料与协议依据

- [高德公开深圳地铁图](https://map.amap.com/subway/index.html)：其公开数据接口为 [深圳地铁数据](https://map.amap.com/service/subway?srhdata=4403_drw_shenzhen.json)。2026-09-28读取；按现有351站的站名精确匹配，排除接口中其余站点；换乘站重复条目的POI及坐标一致。仅提取名称、POI编号与位置，保存至 `data/shenzhen/references/amap-station-navigation.json` 并关联现有固定编号。
- [高德坐标说明](https://lbs.amap.com/api/javascript-api-v2/guide/abc/basetype)：高德位置采用GCJ02。资料单独存入 `amapLocation`，不把它标成通用WGS84坐标，不参与地图示意几何。
- [iOS路线规划协议](https://lbs.amap.com/api/amap-mobile/guide/ios/route)：支持 `sid/did` 和起终点坐标；文档也支持名称匹配，因此尚不能仅据代码判定高德17.00.2回退的内部原因。本次将手动起点改为明确坐标交接。

资料包版本为 `0.2.2-navigation`，运营截止日期仍为2026-06-28。生成器要求导航资料完整覆盖现有站点，并校验站名、坐标系及来源。JSON、SVG和manifest配套生成；原有分区、线网与示意坐标保留。

## 实际验证

- 修改前运行 `CoreTests.testAmapManualOriginIncludesStationIdentityAndPosition`，7处断言失败（缺少POI、起终点坐标以及错误的坐标标识）。这是交接参数回归，未冒充高德页面复现。
- 最终 `bash scripts/check.sh`：24项Python、11项JavaScript地图交互、20项Swift测试通过，资料包完整性校验通过。覆盖351站作为手动起点、起终点交换、定位起点、坐标系与来源校验、缺资料拒绝调起。
- iPhone17 / iOS26.5模拟器：手动选站→交换→未安装地图提示的1项UI测试通过；结果 `/tmp/underground-amap-simulator.xcresult`。
- 真机Debug构建成功。连接iPhone15上安装的高德版本为17.00.2；两次外部页面探测均在iOS启用UI自动化时超时，测试方法未开始执行。临时探测代码已移除。不能声称高德接收页面已实测通过。

尚待在手机上复测：桃园→前海湾、交换方向、当前位置→前海湾，以及用户实际遇到问题的站点组合。确认路线规划页显示所选起点；开始实时导航后的定位行为需要单独记录。
