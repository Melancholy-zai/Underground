# 行政分区背景修复

日期：2026-09-28；资料包：`0.2.1-districts`。线网运营截止日期仍为 2026-06-28，本次没有重新扩大运营范围。

## 修复内容

根因是 `collect_shenzhen.py` 将 `districts` 固定写成空数组，并清空全部站点区属。SVG 渲染器原有分区支持，因此只改生成后的 SVG 会在下次打包时再次丢失。

新增 `data/shenzhen/references/district-layout.json`，保存10个浅色区块、区名位置、示意区界、351个固定站点编号对应的区属及依据。生成器从该文件读取；JSON、SVG、manifest 整体重建。原17条线、351站、432站次、68个多线站、2/8贯通与线路/站点几何保持不变。

区界为配合现有线网独立绘制的多边形，不是测绘边界。345站按公开站址中的区名、道路或片区人工对应；这不等于完成全部站体和出入口的地籍核验。程序检查已赋区属的站点是否落在对应底色内，不能靠这项几何检查证明现实中的行政归属。

## 资料依据与限制

- [深圳地铁站点查询](https://www.szmc.net/shentieyunying/yunyingfuwu/zhandianchaxun/)：检查公开页面使用的站点索引和 `zdxx?StieCode=…` 查询。349个匹配站名中348个请求成功，313个返回可用站址介绍。仅保存站址事实摘要至 `official-station-locations.json`，逐条附 URL；其余为空或“暂无数据”。没有把接口的时刻、出口或运营状态一并导入。
- [深圳政府在线线路资料](https://www.sz.gov.cn/xxgk/sydwxxgk/jt/dt/)：4号线福田、龙华片区，以及13号线南山、宝安、光明片区的背景资料。只作为站址人工对应的补充，不由整条线路统一推断区属。
- [梅林关片区介绍](https://www.sz.gov.cn/cn/xxgk/zfxxgj/gqdt/content/post_10730632.html)：龙华区梅林关片区、4/6号线及民乐周边背景。
- [应人石站施工通告](https://szjj.sz.gov.cn/ZWGK/TZGG/GGJG/content/post_8687843.html)：明确宝安区市场路。
- [百旺站接驳说明](https://www.szns.gov.cn/xxgk/qzfxxgkml/jqdt/content/post_12576520.html)：南山区西丽街道阳光社区片区。
- [光明区13号线北延资料](https://www.szgm.gov.cn/xxgk/xqgwhxxgkml/xwzx/tpxw/content/post_12302407.html)、[红坳公园站供地公告](https://pnr.sz.gov.cn/xxgk/gggs/content/post_12574210.html)、[下村至李松蓢规划公示](https://www.sz.gov.cn/szzt2010/wgkzl/glgk/jgxxgk/gtzy/content/post_12314222.html)：对应光明段；红坳公园站供地位置明确为光明区凤凰街道。
- [溪涌站规划许可](https://pnr.sz.gov.cn/gkmlpt/content/11/11772/post_11772775.html)：明确大鹏新区溪涌片区。大鹏新区按功能区管理范围单独标示，不当作法定行政区代码，也不额外绘制前海为行政区。
- 梧桐山南的运营方站址明确写罗湖区；沙头角写盐田区，小梅沙写盐田区，溪涌写大鹏新区。保留这几个转换点，避免把8号线整条涂为盐田。

## 局部待核实

侨城东、深圳湾公园、红岭北、园岭、银湖：涉及区界附近站体/出入口，暂不作单一区属断言。翰岭：运营方站址写龙华区，但[规划部门公开目录](https://pnr.sz.gov.cn/szsghhzrzyjwzgkml/szsghhzrzyjwzgkml/seztfw/zzrd/wyk/index_19.html)由福田管理局发布该站许可，资料存在冲突。

这6站 `districtIDs=[]`，保留具体 `districtNote`，站点周边覆盖中性斜纹和问号。详情显示待核实，其他区块仍然正常显示。后续核实时应修改固定编号对应的参考记录，并同步调整示意边界，再整体生成资料包。

## 防止再次退化

- 生成器要求分区记录与站点固定编号一一对应，分区列表不可为空。
- 回归测试检查重新生成后有10个分区、区块在线路下方、典型跨区站点对应正确、疑点位置有中性斜纹。
- 全线网打包检查区名在本区内部、每个已赋区属站点只能被对应底色覆盖。
- 底图与斜纹 `pointer-events="none"`，站点和线路继续使用原交互与命中顺序。
