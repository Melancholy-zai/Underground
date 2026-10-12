# 实施参考与未验证项

## 2026-09-28 站点服务资料更新

已完成全目录动态查询和服务资料入包，过程、使用条件和未解决冲突见 [STATION_SERVICES.md](STATION_SERVICES.md)。4／13号线图片核读见 [OPERATOR_SERVICE_IMPORT.md](OPERATOR_SERVICE_IMPORT.md)，真实异常及公告见 [STATION_SERVICE_ANOMALY_AUDIT.md](STATION_SERVICE_ANOMALY_AUDIT.md)。下文保留早期线网研究记录，不代表当前所有服务字段仍为空。

核对日期：2026-09-24。这是技术文档和资料核验入口记录，不是完整深圳城市数据的授权或真实性证明。

## 外部地图协议

- [高德 iOS 路线规划官方文档](https://developer.amap.com/api/amap-mobile/guide/ios/route)：本工程使用 `iosamap://path`，`t=1` 公交、`t=2` 步行，设置 sourceApplication；显式提供手动起点名称/坐标，不让其退回当前位置。名称采用 URLComponents 编码。坐标为 WGS84 时请求平台按 `dev=1` 处理。
- [百度 iOS 地图调起官方文档](https://lbsyun.baidu.com/docs/webapi?title=mapadjustment%2Furi%2Fios)：本工程使用 `baidumap://map/direction`，mode 为 transit/walking；起终点名称单独提供时不加 name: 前缀，名称与坐标共同提供时用 name:…|latlng:…；经纬度顺序先纬后经；显式声明 coord_type=wgs84。
- [高德 iOS 接入说明](https://developer.amap.com/api/amap-mobile/gettingstarted)：将 iosamap 加入可查询 Scheme，并使用 UIApplication 的 open API。百度 baidumap 同样加入本工程 LSApplicationQueriesSchemes。

协议参数已通过构造测试；外部 App 真机实际接收行为未验证。外部平台可变更协议或依据用户设置调整交通偏好。

## 深圳资料（完整线网版）

详见 [完整核验记录](NETWORK_RESEARCH.md)。本次实际获取并保存了：

- [官方票价表 XLSX](https://fgw.sz.gov.cn/attachment/1/1723/1723434/12849099.xlsx)：17条编号线、432线路内站次，按同名站去重为351站。
- [深圳政府在线站名表](https://www.sz.gov.cn/xxgk/sydwxxgk/jt/dt/ywxx/dtxlxx/content/post_11086804.html)：交叉校对站序；大学城、人民南、深圳北站以票价表完整名称为准。
- [官方线路图 PDF](https://www.sz.gov.cn/attachment/1/1726/1726728/11086804.pdf)：转录示意位置和曲线路径，并从公开图示提取显示颜色（不是声称取得官方品牌色标准）。删除图中标注未开通的13号线南延及西丽高铁站。
- [13北延开通公告](https://jtys.sz.gov.cn/ydmh/jtzx/zyhy_1510/content/post_12867344.html)：2026-06-28开通至李松蓢。

本版本运营范围截止2026-06-28，资料核对日期2026-09-24。原始文件及转录记录保存在 data/shenzhen/references。地图来源署名深圳政府在线、原图编制深圳地铁及港铁深圳；仅供本地非商业开发核对，不将公开可下载等同于商业再分发授权。

2026-09-28已恢复行政分区底色，并按公开站址人工对应区属；6处区界或来源冲突局部待核实，详见 [分区资料记录](DISTRICT_RESEARCH.md)。已补齐351站高德POI编号与GCJ02导航位置；同日已入包站点时刻与出口，具体收录及缺口见上文服务资料记录，通用WGS84坐标仍缺失。详见 [高德导航资料与修复](AMAP_NAVIGATION.md)。旧候选资料来源与获取结果见 references/METADATA_SOURCES.md。旧17站样本仅留作测试夹具，不再作为App内置地图。
