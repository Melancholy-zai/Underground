# 周边地区与完整图例实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox syntax for tracking.

**Goal:** 在完整线网与浅色分区基础上补齐周边关系、独立交界线、水域、图例及可独立使用的横向矢量图。
**Architecture:** 城市包增加可选mapContext资料；Python独立模块校验并绘制外围和说明，生成器统一平移原示意坐标以留出边距。Swift离线读取相同资料，Web地图新增按区域框聚焦；SVG/PDF共用一份图形。
**Tech Stack:** SwiftUI、WebKit、Python标准库、SVG；本地矢量PDF导出。
**Spec:** 用户本次清单与“直接实施并验证”授权。

## Global Constraints
- 保留现有线网固定编号、站序、交互、分区底色及高德导航修复；不增加服务器。
- 独立表达市界、深港界线、区界、海岸线；隔海相望不能画成陆地接壤。
- 未确认资料保留局部待核实；生成日期、复核日期与运营截止日期分别显示。
- 大鹏已有溪涌站，不能标全区无地铁；深汕在独立插图按特殊管理区域注明。
- 当前目录没有Git仓库；保留本地修改，不执行提交。

## Review Focus
- 新外围图形不截获站点点击，线路淡化不影响图例。
- 坐标平移后搜索聚焦、线路/站点命中仍一致。
- 区界拓扑不得引入伪相邻或把已定站点涂入别区。
- 缺少来源/错误边界类型/引用错配应被资料校验拒绝。
- 手机竖屏中小图和图例能独立放大，恢复全图可回到完整横向画布。

## Tasks
- [x] 1. 复核官方线网/邻接关系/六处疑点；保存带来源的研究记录。无新证据不提升运营截止日。
- [x] 2. 新增 `tools/map_context.py` 的 `prepare(data, reference)`、`validate_context(data)`、`render_background(data)`、`render_foreground(data)`；新增来源资料 `data/shenzhen/references/map-context.json`。测试缺资料/错误引用/独立边界/日期图例先失败，再实现。
- [x] 3. 模型追加MapContext及其区域、边界、插图/聚焦框字段；collector、citypack校验/构建/verify配套接入。修正龙华—罗湖共享区界，维持站点区属验证。
- [x] 4. `map.js` 支持area命令，MapScreen添加周边/图例入口；JS测试验证区域框聚焦、重复命令、恢复；UI测试验证按钮与站点搜索。
- [x] 5. 完整图例含17线路颜色、10分区、普通/换乘/站外换乘、边界/海岸/待核实符号；SVG自带日期来源声明。
- [x] 6. 生成SVG与横向矢量PDF，视觉检查全图及手机周边放大；运行 `bash scripts/check.sh` 和针对性的Xcode UI测试；完成独立审查并更新验证记录。

## Decisions / evidence
- 线网当前17编号/351唯一站/432站次；资料复核日2026-09-28，截止日是否提高由明确来源决定。
- 外围内容为带来源的示意关系，不能将原分区外框整体当作市界。
