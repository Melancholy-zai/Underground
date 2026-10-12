# Underground Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** 可构建、可测试的离线 iPhone 地铁 App 和资料工具。
**Architecture:** Foundation 业务模块 + SwiftUI 界面 + 本地 SVG，JSON/SVG 哈希配套。外部 App 执行导航。
**Tech Stack:** Swift 5.9+、iOS 17+、WebKit、CoreLocation、Python 3 标准库。
**Spec:** docs/superpowers/specs/2026-09-24-underground-design.md

## Global Constraints
- 最低 iOS 17，无第三方运行时依赖。
- 不租服务器、不要账户、不采集上传定位。
- sample 不冒充全深圳资料；没有可靠资料就显示暂无资料。
- 不自动提交或推送。

## Review Focus
- 用户切换手选起点后到达的定位回调必须失效。
- 次日 00:10 不能误显示为当天；服务日与有效期明确。
- 城市包重复 ID、缺站、图文不一致要拒绝加载。
- 中文及 & 符号不得破坏 URL 参数。
- 放大和拖动不得误触附近站点，恢复全图必须有效。

## Task 1: 数据与路线核心
Files: Sources/MetroCore/{Models,CityRepository,Route,Navigation}.swift, Tests/MetroCoreTests/CoreTests.swift。
Interfaces: CityPack → CityRepository；RouteSelection → NavigationRequest → NavigationURLBuilder。
- [x] 先编写核心行为测试，运行 `swift test --scratch-path /tmp/underground-spm` 观察缺失实现。
- [x] 实现解码、引用校验、搜索、服务时间、路线交换和 URLComponents 参数。
- [x] 同一命令全量通过。

## Task 2: 资料包流水线
Files: tools/citypack.py, tools/tests/test_citypack.py, data/shenzhen/source.json, App/Resources/CityPack/*。
Interfaces: source JSON → validate/build → city JSON + SVG + manifest SHA-256。
- [x] 测试无效引用、缺失生产依据、跨日时间、SVG 对象对应。
- [x] 实现 `python3 tools/citypack.py build data/shenzhen/source.json App/Resources/CityPack`。
- [x] 运行 `python3 -m unittest discover -s tools/tests -v`，检查生成的包。

## Task 3: 原生界面与交互地图
Files: App/{UndergroundApp,AppModel}.swift, App/Views/*, App/Services/*, App/Resources/Web/*, App/Info.plist, Underground.xcodeproj/*。
Interfaces: AppModel 持有 repository、route、selection；SVG Bridge 只传 type/id，原生校验后修改状态。
- [x] 实现地图/路线/资料页和定位服务，站点详情不生成不存在的信息。
- [x] 生成确定性的 Xcode 工程（App + UI Tests）。
- [x] 无签名模拟器构建，运行 UI 测试并查看截图。

## Task 4: 交付核验
Files: README.md, docs/{DATA_FORMAT,DEVICE_CHECKLIST,VERIFICATION,SOURCES}.md, scripts/check.sh。
- [x] 全量核心、Python、模拟器验证；独立审查关注数据真实性与导航状态。
- [x] 修复重要问题并补充对应回归验证。
- [x] 写明已执行结果、完整全线网缺口、签名安装步骤与真机待验证项。
