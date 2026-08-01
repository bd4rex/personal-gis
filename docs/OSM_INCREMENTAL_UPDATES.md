# OSM 增量更新与完整快照基线

## 当前策略

生产更新继续使用完整快照构建。增量链只进入隔离试验，不直接覆盖现有 PBF、PMTiles、Nominatim 或 Valhalla 数据。每次可恢复发布必须保留：

- 上次验证通过的完整 OSM PBF 快照及 SHA256。
- 对应复制序列号、源时间、下载来源和地图包清单。
- 由该快照生成的 PMTiles 与共享索引回滚点。
- 增量试验期间下载的 OSC 文件、顺序和 SHA256。

运行只读准备检查：

```powershell
D:\GISS\plan-osm-incremental-updates.cmd
D:\GISS\plan-osm-incremental-updates.cmd -Json
```

## 试验链路

1. 从已校验的完整快照复制出 staging PBF，不在原文件上更新。
2. 根据源的 state 文件锁定起始序列，连续下载到已发布的目标序列。
3. 逐个保存 OSC 与 SHA256。不得仅猜测或递增尚未由上游 state 公布的序列号。
4. 使用 `osmium apply-changes` 按顺序生成新的 staging PBF。
5. 执行 `osmium fileinfo`、`osmium check-refs`、边界和对象数量检查。
6. 先重建一个省级 PMTiles 包，比较清单、抽样瓦片和关键地点。
7. 通过后再重建共享搜索/路线索引；发布采用原子替换并保留上一代。

Osmium 官方文档说明 `apply-changes` 会把一个或多个 OSM change 文件应用到数据文件；区域 extract 的 change 文件必须按从旧到新的顺序提供。Pyosmium 的复制工具可以根据 PBF 中的复制信息续接序列，但切换复制源或缺少复制头时必须显式引导。参考：[Osmium apply-changes](https://docs.osmcode.org/osmium/latest/osmium-apply-changes.html)、[Pyosmium Replication Tools](https://docs.osmcode.org/pyosmium/v4.3.0/user_manual/10-Replication-Tools/)。

OpenStreetMap 的复制说明强调：只能获取当前 state 已确认发布到的序列，不能通过简单递增序列号猜测未来 diff。参考：[Planet.osm/diffs](https://wiki.openstreetmap.org/wiki/Planet.osm/diffs)。

## 灾备规则

- 任一序列缺失、哈希不符、引用完整性异常或地图抽样回归时，立即放弃本轮增量结果。
- 增量链连续运行一个月并经过至少一次“增量结果与同期完整快照”比对前，不作为唯一更新方式。
- 即使增量链稳定，也至少按季度获取并验证完整快照，重新建立灾备基线。
- 搜索与路线索引是可重建派生物；完整 OSM 快照、复制状态和个人数据备份才是恢复根。

## 后续阶段

- 阶段 1：江苏单包离线 staging 试验，只生成报告。
- 阶段 2：江苏、安徽连续增量并与完整快照做对象与瓦片抽样对比。
- 阶段 3：为 Nominatim 与 Valhalla 分别评估原生增量和全量重建成本。
- 阶段 4：满足回滚、审计和定期全量基线要求后，才允许计划任务自动执行。
