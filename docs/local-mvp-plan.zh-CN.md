# 个人 GIS 本地 MVP 规划

> [English](local-mvp-plan.md) | 简体中文 · 历史文档

这是当前系统形成之前的规划记录，不是部署说明。当前实现以[项目 README](../README.zh-CN.md)和[架构文档](ARCHITECTURE.zh-CN.md)为准。

## 最初目标

在自研完整移动应用前，先验证一套可演进的个人 GIS 闭环：

```text
桌面管理 -> 手机查看/采集 -> 标记同步 -> Web 地图 -> 本地长期归档
```

## 当时评估的原则

- 可替换参考底图与不可替代个人资料分离。
- 优先使用 GeoPackage、GPX、GeoJSON、PostGIS 等开放格式。
- 在投入自研客户端前复用成熟手机应用。
- 先验证小区域，再考虑全球数据。
- 文件型数据必须能平滑迁移到 PostGIS 与本地 API。

## 路线比较

| 路线 | 优点 | 限制 | 适用阶段 |
| --- | --- | --- | --- |
| OsmAnd + Syncthing + QGIS | 启动快、离线导航成熟 | 结构化合并与冲突较弱 | 习惯验证 |
| QGIS + QField + GeoPackage | 表单、照片、点线面自然 | 需要配置 QGIS/QField | 推荐早期 MVP |
| QGIS + 自托管 QFieldCloud + PostGIS | 长期数据库与同步 | 初始部署更重 | MVP 后期 / v1 |
| Mergin Maps CE + QGIS | 外业流程成熟、服务端开放版本 | 绑定其服务模型 | 同步备选 |
| 自写 Web/移动端 + PostGIS | 完全可控 | 离线与同步成本最高 | v2 以后 |

## 最初推荐路线

```text
短期：OsmAnd 或 QField + GeoPackage
长期：PostGIS + Martin + MapLibre
```

文件型方案计划使用 `places` 数据集，包含稳定 ID、名称、分类、WGS84 几何、备注、标签、评分、来源、照片路径、时间和同步状态；后续再增加访问、集合、轨迹、附件和版本历史。

## 原计划阶段

### 阶段 0 — 文件验证

- 创建 `places.gpkg` 或 GeoJSON。
- 把 OsmAnd 收藏/GPX 导入 QGIS。
- 用至少十个分类点位确认字段。

### 阶段 1 — QField 采集

- 创建含手机表单的 QGIS/QField 项目。
- 手机采集点位、备注和照片。
- 验证数据与相对媒体路径回到本地。

### 阶段 2 — 本地 Web

- 用 MapLibre 或 Leaflet 渲染 GeoJSON。
- 显示分类和详情。
- 先使用在线或小型离线底图。

### 阶段 3 — PostGIS 内核

- Docker 启动 PostgreSQL/PostGIS。
- 导入稳定个人数据模型。
- 通过 Martin 或 API 发布经过审核的数据。

### 阶段 4 — 同步选择

- 比较 QFieldCloud、Mergin Maps CE、Syncthing 和轻量自写 API。
- 数据模型和真实手机流程稳定后再选择。

## 实际实现的变化

当前项目已经超过该规划：PostGIS 成为个人权威数据；FastAPI 负责写入；Martin 只发布批准视图；PMTiles 与 OSM Carto 提供本地地图；Nominatim、Valhalla、地形、Kiwix、资源生命周期、备份和断网恢复已经运行。专用移动同步客户端仍属于未来工作。

## 历史参考

- [QFieldCloud 自托管](https://docs.qfield.org/fi/reference/qfieldcloud/self_hosted/)
- [Mergin Maps 服务端](https://merginmaps.com/docs/server/)
- [OsmAnd 导入导出](https://osmand.net/docs/user/personal/import-export/)
- [Martin](https://martin.maplibre.org/)
