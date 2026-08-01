# 个人 GIS 本地 MVP 规划

> 本文是演进路线图，不等同于当前实现。2026-08-01 的实际组件、配置和完成度见[技术架构与组合逻辑](architecture.md)与[资源与配置清单](resource-configuration.md)。

目标：先在本地跑通一套可演化的个人 GIS 标记系统。MVP 不追求一开始自研完整移动端，而是先验证核心闭环：

```text
本地桌面管理 -> 手机端查看/采集 -> 标记数据同步 -> Web 地图浏览 -> 数据长期归档
```

## 核心原则

- 底图和个人数据分离。底图可以来自在线服务、本地 MBTiles、OsmAnd 离线包或 OpenFreeMap；个人标记必须由自己保存。
- MVP 优先使用开放格式：GeoPackage、GPX、GeoJSON、PostGIS。
- 手机端先借用成熟 App，避免从零写移动端。
- 本地第一阶段不要追求全球底图自托管，先用在线底图或小区域离线底图。
- 系统要能从文件型 MVP 平滑升级到 PostGIS + Web API。

## 系统路线对比

| 路线 | 组成 | 优点 | 缺点 | 适合阶段 |
|---|---|---|---|---|
| OsmAnd + Syncthing + QGIS | 手机 OsmAnd，桌面 QGIS，同步 GPX/收藏/轨迹 | 最快开始，手机体验成熟，离线地图强 | 数据模型偏 OsmAnd，冲突合并和结构化属性弱 | 第 0 阶段验证习惯 |
| QGIS + QField + GeoPackage | 桌面 QGIS，手机 QField，共享 `.gpkg` 项目 | 更像专业 GIS，表单/照片/点线面都自然 | 需要学习 QGIS/QField 项目配置 | 推荐 MVP |
| QGIS + QFieldCloud 自托管 + PostGIS | QField/QGIS 同步，中心库 PostGIS | 可长期演化，支持在线/离线/多人/REST API | 部署稍重，初期复杂度高 | MVP 后半段或 v1 |
| Mergin Maps CE + QGIS | Mergin Maps 手机端和自托管 CE | 外业采集与同步体验成熟，开源 CE | 生态绑定 Mergin 服务端模型 | 可替代 QFieldCloud |
| 自写 Web + 自写移动端 + PostGIS | MapLibre Web，Flutter/React Native 移动端 | 完全可控，产品形态自由 | 最慢，移动离线/同步成本高 | v2 以后 |

## 推荐 MVP 路线

建议采用“双轨 MVP”：

```text
短期工作流：OsmAnd/QField + GeoPackage
长期内核：PostGIS + Martin + MapLibre
```

第一阶段不要把所有东西都塞进 PostGIS。先用 `places.gpkg` 作为主数据文件，因为它能被 QGIS、QField 和很多 GIS 工具直接打开。等字段、分类、照片路径和同步方式稳定后，再升级到 PostGIS。

## MVP 目标

本地必须做到：

- 在 QGIS 中打开个人标记图层。
- 新增、编辑、分类个人兴趣点。
- 保存备注、标签、评分、来源、照片路径。
- 在 Web 地图中查看这些点。
- 手机上能新增或导入点位。
- 数据能回到本地项目目录。

暂不做：

- 用户系统和权限。
- 商业 POI 批量导入。
- 全球瓦片自托管。
- 从零开发移动 App。
- 复杂路线规划和导航。

## 本地目录建议

```text
个人GIS/
  data/
    places.gpkg
    imports/
      osmand/
      gpx/
      geojson/
    photos/
    basemaps/
      mbtiles/
      pmtiles/
  docs/
    local-mvp-plan.md
  services/
    docker-compose.yml
    postgis/
    martin/
  web/
    index.html
    src/
  qgis/
    personal-gis.qgz
  scripts/
    import-gpx.ps1
    export-geojson.ps1
```

## 数据模型 MVP

主图层：`places`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | text/uuid | 稳定 ID |
| `name` | text | 名称 |
| `category` | text | 分类，如 food、trail、shop、viewpoint、todo |
| `geom` | point | WGS84 点位 |
| `note` | text | 备注 |
| `tags` | text/json | 标签 |
| `rating` | integer | 个人评分 |
| `source` | text | manual、osmand、qfield、gpx、import |
| `photo_path` | text | 本地照片相对路径 |
| `created_at` | datetime | 创建时间 |
| `updated_at` | datetime | 更新时间 |
| `sync_state` | text | local、synced、conflict |

后续可扩展：

- `visits`：访问记录。
- `collections`：收藏夹/项目。
- `tracks`：轨迹。
- `attachments`：照片、录音、文档。
- `place_versions`：版本历史。

## 阶段计划

### 阶段 0：文件型验证

目标：1 天内跑通。

- 创建 `data/places.gpkg`。
- 用 QGIS 建一个点图层和简单样式。
- 手机用 OsmAnd 导出 favorites/GPX，放入 `data/imports/osmand/`。
- 在 QGIS 中导入 GPX，手工合并到 `places.gpkg`。
- 记录哪些字段需要保留。

验收：

- QGIS 能打开 `places.gpkg`。
- 至少有 10 个个人标记点。
- 点位有分类、备注、来源。

### 阶段 1：QField 手机采集

目标：手机端能新增点位。

- 用 QGIS 创建 `qgis/personal-gis.qgz`。
- 配置 QField 可用的表单字段。
- 将项目同步到手机。
- 手机新增点位、备注、照片。
- 回传并在 QGIS 中确认。

验收：

- 手机新增的点能回到本地。
- 照片路径能在项目里追踪。
- 字段结构没有明显别扭处。

### 阶段 2：本地 Web 查看

目标：浏览器中查看个人点。

- 使用 MapLibre GL JS 或 Leaflet。
- 先把 `places.gpkg` 导出为 GeoJSON。
- Web 页面加载 GeoJSON 并显示分类图标。
- 底图先用在线 OSM/OpenFreeMap/MapTiler，后续再换本地瓦片。

验收：

- 本地浏览器能打开地图。
- 点位按分类显示。
- 点击点位能看到名称、备注、照片链接。

### 阶段 3：PostGIS 内核

目标：把长期数据放进数据库。

- 使用 Docker 启动 PostgreSQL + PostGIS。
- 将 `places.gpkg` 导入 PostGIS。
- 用 Martin 从 PostGIS 发布矢量瓦片或 GeoJSON API。
- Web 端改为从本地服务读取数据。

验收：

- PostGIS 有 `places` 表。
- Web 端不再依赖静态 GeoJSON。
- 能通过 SQL 查询分类、范围、更新时间。

### 阶段 4：同步服务选择

目标：决定长期手机同步方案。

候选：

- QFieldCloud 自托管。
- Mergin Maps CE 自托管。
- Syncthing 文件同步。
- 自写轻量 API。

建议先比较 QFieldCloud 和 Mergin Maps CE。二者都比从零写移动同步靠谱；差异主要在部署、授权、生态和你更喜欢哪个移动端体验。

## 当前推荐决策

优先路线：

```text
QGIS + QField + GeoPackage -> PostGIS + Martin + MapLibre -> QFieldCloud 或 Mergin Maps CE
```

保留 OsmAnd：

```text
OsmAnd = 日常导航、离线地图、轨迹和收藏来源
QField = 严肃采集和结构化编辑
QGIS = 桌面整理和项目配置
PostGIS = 长期数据库
MapLibre = Web 查看和未来产品界面
```

## 第一个可执行任务

下一步可以直接做：

1. 建立 `data/`、`qgis/`、`web/`、`services/`、`scripts/` 目录。
2. 生成一个空的 `places.geojson` 或 `places.gpkg` 种子数据。
3. 做一个本地 Web 地图页面，先读取 GeoJSON。
4. 后面再补 QGIS/QField 项目。

如果机器暂时没有 GDAL/QGIS 命令行环境，第一步可用 GeoJSON 代替 GeoPackage。GeoJSON 足够验证 Web 和数据模型，GeoPackage 留给 QGIS/QField 阶段。

## 参考资料

- QFieldCloud self-hosting: https://docs.qfield.org/fi/reference/qfieldcloud/self_hosted/
- Mergin Maps CE server: https://merginmaps.com/docs/server/
- OsmAnd import/export: https://osmand.net/docs/user/personal/import-export/
- OsmAnd favorites: https://osmand.net/docs/user/personal/favorites/
- Martin tile server: https://martin.maplibre.org/
- MapLibre Martin docs: https://maplibre.org/martin/
