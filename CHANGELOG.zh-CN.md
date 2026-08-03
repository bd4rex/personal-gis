# 版本变更记录

> [English](CHANGELOG.md) | 简体中文
>
> 历史整理时间：`2026-08-03T23:12:23+08:00`

本文件记录面向使用者的开发里程碑，采用成熟开源项目常见的分类式结构，并保留 ISO 8601 时间戳。

在本文件加入前，仓库没有 Git tag 或 GitHub Release。下列 `M0.x` 是追溯整理的文档编号；提交哈希与时间戳才是权威依据，这些编号不代表补建了历史 Release。

## 未发布 — 区域策略自动推广

### 新增

- OSM Carto 蓝绿候选卷及逐区域非空瓦片验收。
- 天气城市动态提取、天气/航海区域输入清单和高程覆盖裁剪清单。
- 区域构建、更新、删除、启用或停用改变活动范围后，自动排入天气与航海轻量派生任务。

### 修复

- 修复山东基础包安装后未进入 OSM Carto、共享搜索/路线、天气、航海和高程覆盖的问题。
- 修复资源盘点只看服务整体健康、无法发现新增区域缺口的问题。
- 判定搜索、路线、Carto、天气与航海覆盖有效前逐区域比对源 SHA256，不再只比较区域 ID。
- 从地图包清单解析实际源路径，使未来国家和地区包继承同一派生流程。
- 删除旧苏皖组合 Carto 源，并从新路线候选中清理 97 个历史无关 HGT 格网。

### 改进

- OSM Carto 全球水域、冰盖和低缩放边界改为校验后从本地归档复用。
- Valhalla 在所有已启用区域执行真实路线验收；冒烟测试要求各派生资源范围与已启用地图包一致。

## 文档快照 — 2026-08-03T23:12:23+08:00

### 新增

- 项目入口及每份维护文档的英文与简体中文版本。
- 双语文档索引和文档间语言切换链接。
- 基于真实提交记录的历史版本说明。

### 变更

- 将主 README 重写为英文，并新增内容对等的中文 README。
- 按当前八服务架构、OSM Carto、本地资源生命周期和断网恢复模型更新说明。

## M0.7 — 存储所有权与离线地图生命周期

- **提交：** [`b2a6503`](https://github.com/bd4rex/personal-gis/commit/b2a6503304fbea851a968d7cdabeddb1b7e1a81c)
- **时间：** `2026-08-03T18:13:25+08:00`
- **当时状态：** 直接提交到 `main`，没有 tag 或 Release

### 新增

- 可续建外部数据准备的本地 OSM Carto 构建与修复流水线。
- Planetiler 高细节叠加包与 schema-v3 地图清单。
- 共享索引候选版本激活、清理和活动版本保留。
- 恢复包 schema v4 中的 OSM Carto 数据与隔离恢复验证。

### 改进

- 按当前江苏、安徽范围重建 Nominatim 和 Valhalla。
- 恢复验证通过后移除德国、摩纳哥、上海、浙江及重复区域源。
- 清理无用卷、镜像和可再生缓存后压缩 Docker 存储。
- 扩展资源页面状态、任务操作、测试和真实进度显示。

## M0.6 — GIS_P 品牌与默认工作区

- **提交：** [`c1de372`](https://github.com/bd4rex/personal-gis/commit/c1de372c6d69cc5ddf77d409438c4a06bf012d2e)
- **时间：** `2026-08-02T14:38:57+08:00`
- **合并：** [PR #5](https://github.com/bd4rex/personal-gis/pull/5)

### 变更

- 用户界面产品名从 GISS 改为 GIS_P，同时保留兼容标识。
- 地图默认收起侧栏，并统一焦点、ARIA、动画与覆盖状态。
- 将共享索引的覆盖完整性和范围是否最新拆分显示。

## M0.5 — 产品需求基线

- **提交：** [`a6309f8`](https://github.com/bd4rex/personal-gis/commit/a6309f84085b0f8bc6295c444bfd26370b933844)
- **时间：** `2026-08-02T08:07:31+08:00`
- **合并：** [PR #4](https://github.com/bd4rex/personal-gis/pull/4)

### 新增

- 数据自主、离线行为、真实状态、可靠性和交付原则。
- 区域地图、个人资料、资源版本、回退与恢复要求。

## M0.4 — D 盘 Docker 清理记录

- **提交：** [`cd28db5`](https://github.com/bd4rex/personal-gis/commit/cd28db5cde78b6dcdb78a962c3b8923de8e61491)
- **时间：** `2026-08-02T07:53:13+08:00`
- **合并：** [PR #3](https://github.com/bd4rex/personal-gis/pull/3)

### 改进

- 记录 Docker Desktop WSL 数据迁移到 `D:\DockerData\wsl` 后的验证。
- 只有在服务、卷、备份和 API 检查通过后，才删除停用的 C 盘 VHD。

## M0.3 — 地图来源控制与实时覆盖状态

- **提交：** [`725ae42`](https://github.com/bd4rex/personal-gis/commit/725ae424c7cb00b86733ebdf2b025ace30d8cf0a)
- **时间：** `2026-08-02T03:20:56+08:00`
- **合并：** [PR #2](https://github.com/bd4rex/personal-gis/pull/2)

### 新增

- “仅离线、OpenStreetMap Standard、OpenFreeMap”明确来源选择。
- 首选来源、实际来源、回退、连接状态和本地覆盖状态。
- 基于可见视口的区域判断与本地化下载提示。

### 改进

- 扩展浏览器测试，覆盖手动来源、回退、完全离线和区域归属提示。

## M0.2 — 离线 GIS 平台扩展

- **提交：** [`9d2ea5d`](https://github.com/bd4rex/personal-gis/commit/9d2ea5d29a1e3b7bd4cf0717e6ebe2606c11d3d6)
- **时间：** `2026-08-02T02:42:50+08:00`
- **合并：** [PR #1](https://github.com/bd4rex/personal-gis/pull/1)

### 新增

- FastAPI、有序 PostGIS 迁移、Martin、nginx、Nominatim、Valhalla、Kiwix、地形和维护工作器。
- 中国省级独立地图包与同步的全球 Geofabrik 目录。
- 资源管理、全球概览、天气、航海、个人媒体、集合和可移植导出。
- SHA256 备份、完整断网恢复包和隔离恢复演练。
- 健康检查、API 生命周期、主界面、资源页面和全球地图测试。

### 改进

- 将文件型验证项目扩展成由清单驱动的本地优先平台。
- 增加原子构建、候选验收、回退、缓存优先盘点、真实任务进度和版本化更新。

## M0.1 — 首次发布个人 GIS

- **提交：** [`aa76756`](https://github.com/bd4rex/personal-gis/commit/aa76756ad887590574cdd622b4a2133f4dafc7ba)
- **时间：** `2026-08-01T18:44:56+08:00`
- **当时状态：** 仓库初始提交，没有 tag 或 Release

### 新增

- 初始 MapLibre 浏览器界面和 GeoJSON 个人点位样例。
- PostGIS 与 Martin Compose 服务。
- 本地架构、资源配置、运维与 MVP 规划文档。
- 本地服务和网页的 PowerShell 启动脚本。

## Git 之前的开发记录

仓库于 2026-08-01 首次发布，但 [docs/PROCESS_LOG.zh-CN.md](docs/PROCESS_LOG.zh-CN.md)记录了从 2026-07-03 开始的本地实施工作。这些日期代表开发与验证事件，不是 Git Release 时间。
