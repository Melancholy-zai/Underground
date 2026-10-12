# 批量站点坐标与所属区候选核验

核验日期：2026-09-24。结论：本轮三个候选均未提供已成功下载、覆盖全部 351 站的坐标及结构化所属区数据。未调用 SZMC 乘车查询 API。

## 1. 交通局开放数据：地铁站点信息

- 页面：https://opendata.sz.gov.cn/data/dataSet/toDataDetails/29200_00403624
- 数据集 ID：29200/00403624；提供方：深圳市交通运输局；开放等级：无条件开放。
- 实际数据更新：2024-09-13；298 条。2025-12-31 是字段/元信息更新，不能误作站点数据更新。
- 字段：ID、线路名称、站点介绍、站点名字、入库时间。没有经纬度、结构化区字段。
- 已获取公开预览 50 条，部分介绍明确写所属区，可作逐站文本依据，但覆盖不完整且版本旧。
- 已保存：`open-data-station-metadata.json`、`open-data-station-fields.json`、`open-data-station-preview.json`。

## 2. 政府开放平台：深圳地铁站点信息

- 页面：https://opendata.sz.gov.cn/data/dataSet/toDataDetails/29200_63800003
- 数据集 ID：29200/63800003；提供方：深圳市地铁集团有限公司；开放等级：无条件开放。
- 数据更新：2025-12-28；385 条，描述包含站点名称、站点简介。
- 元信息明确只含深铁所辖线路，不含港铁 4/13 号线；未列经纬度、结构化区字段。
- 文件清单确认存在 39966 字节的“深圳地铁站点信息.xlsx”。下载页面要求登录并完成实名认证；本轮没有绕过登录，也没有下载这个文件。
- 已保存：`open-data-metro-station-metadata.json`、`open-data-metro-station-files.json`、`open-data-metro-station-fields.json`（空字段列表，源为文件）。
- `open-data-search-results.json` 是公开目录搜索结果，包含上述数据集及其他相关数据集。

## 3. OpenStreetMap / Overpass

- 官方说明：https://wiki.openstreetmap.org/wiki/Overpass_API
- 数据许可及署名要求：https://www.openstreetmap.org/copyright （ODbL）。
- 查询深圳附近包围框内地铁站标签；社区完整性和新增线更新情况必须另行验证。
- 实际请求结果：private.coffee POST 50 秒超时，零响应；主实例 GET HTTP 406；private.coffee GET 40 秒超时，零响应。
- 未取得原始 OSM 站点数据，因此不能声称已验证覆盖率、真实坐标或所属区。
- 可行后续路线：下载 OSM 区域 extract，筛选车站并对照官方 351 站白名单，再以相同坐标系区界做点落区；不应凭站名猜区。

## 排除的搜索误命中

`29200/00903558` 的页面搜索摘要出现“地铁站点”，但官方元信息实际显示“气象月降水数据”；地铁文字来自网站侧栏。`open-data-candidate-metadata.json` 保留了这一误命中的核验证据。
