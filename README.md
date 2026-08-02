# GIS_P Personal Offline Map

GIS_P is a local-first personal GIS with 34 Chinese province units and a synchronized global Geofabrik catalog. It combines an interactive offline OpenStreetMap base map with self-owned places, tracks, photos, full address search, route planning, terrain, weather, nautical references, a Chinese encyclopedia and travel guide, backup, and disconnected recovery.

The browser only needs one local URL:

```text
http://localhost:8080/
```

资源与地图版本管理使用独立页面：

```text
http://localhost:8080/resources.html
```

该页面默认展示全部已安装地图包，并提供添加区域、上游版本检查、更新/重建、启停、完整性校验、原子回退、受保护删除、任务速率和分类磁盘占用。实现约束见 [`docs/RESOURCE_AND_VERSION_MANAGEMENT.md`](docs/RESOURCE_AND_VERSION_MANAGEMENT.md)。

## 产品目标与核心需求

GIS_P 的目标不是制作一张只能联网查看的地图，也不是复刻某一个移动应用，而是建立一套基于开放数据、个人可控、可持续更新，并能在长期断网后继续使用的全球地图系统。江苏、安徽是首批个人数据和离线能力的验证区域，架构与资源目录必须能够继续扩展到中国其他省份和全球。

### 产品原则

- **数据自主**：地图包、OSM 源快照、个人点位、轨迹、照片、备注、索引、构建工具和恢复材料均应能够本地保存、校验、重建和迁移。
- **离线优先**：断网后仍应保留已安装地图、全球概览、个人资料、搜索、路线、地形和本地知识库；在线地图只是当前视口的可选参考，不属于已拥有数据。
- **日常可用**：系统既要管理个人地理记录，也要像成熟地图产品一样适合浏览、探索和规划，优先保证信息丰富度、界面易用性和可控性。
- **开放演进**：参考 OsmAnd、Organic Maps 和 CoMaps 的资源组织经验，以 OpenStreetMap 的浏览体验为基准，但保持引擎、数据源和界面可替换。
- **真实状态**：界面不能用占位选项、假进度或日期猜测代替真实能力；下载、构建、校验、更新、回退和失败状态都必须来自实际任务与文件。

### 地图与个人资料

- 提供始终可用的全球低缩放离线概览，以及按省、国家或地区独立安装的 PMTiles；地理分组只用于导航，不能冒充一个下载包。
- 同时渲染所有已启用的离线区域，支持 OSM 风格道路、建筑、水系、地名、兴趣点、等高线、地形阴影、天气、航海和应急参考图层。
- WiFi 快捷菜单必须能够手工选择 **仅离线、OSM 标准、OpenFreeMap**，显示实际正在渲染的来源，并在在线源失败时依次回退到备用源和本地概览。
- 离线覆盖和缺包提示必须跟随用户实际可见的地图区域，使用精确边界与中文区域名，不能把相邻省份或台湾、福建等区域混淆。
- 个人数据支持点位、轨迹、照片、备注、标签、评分、集合、GPX 导入导出、附近地点和路线端点；PostGIS 与本地媒体目录是个人资料的权威来源。

### 资源与版本管理

- 资源页面分为 **可获取、本地、可更新**，默认可浏览完整全球目录；中国按 34 个省级单元管理，全球按洲、国家和真实可下载地区组织。
- 每项统一展示源数据时间、本地构建时间、上次检查、下次检查、大小、安装状态、启用状态和完整性状态。
- 每项任务在自己的行内显示队列位置、阶段、真实进度、下载速度或瓦片生成速度，并提供对应的取消和重试操作。
- 支持多选、批量校验、批量更新、受保护删除，以及单项信息、清单导出、启用/停用、重建和移除；停用时保留文件但不参与渲染与索引。
- 已达到上游当前序列的地图不能重复更新；使用当前源重新生成必须走独立的 **重建** 操作。可再生缓存应单独计量和清理，旧组合包应给出独立区域替代建议。

### 可靠性与交付约束

- 地图构建和索引维护尽量在后台进行，当前地图、搜索和路线版本继续服务；重型共享索引采用候选版本验收后切换，并保留可回退版本。
- 完整 OSM 快照重建是灾备基线；增量更新只能先在隔离链路研究，不能直接覆盖生产 PBF、PMTiles、Nominatim 或 Valhalla 数据。
- 备份和离线恢复包必须带 SHA256 清单，并能在无外网 Docker 网络中执行恢复演练。
- 每次重要修改都应完成健康检查、API 生命周期测试和 Playwright 地图/资源界面测试，更新重建文档，并通过 PR 合并到 GitHub `main`。
- 当前主项目位于 `D:\GISS`，Docker 数据位于 `D:\DockerData\wsl`；C 盘项目路径仅作为兼容 Junction，不保留第二份项目或 Docker 数据。

`GIS_P` 是当前产品名称。为保证现有部署、备份和离线恢复包继续可用，`D:\GISS` 路径、`giss-*` Docker 名称、`GISS_UI_URL` 等环境变量、浏览器 `giss-*` 存储键以及计划任务名称暂时保留为兼容性标识，不代表旧品牌仍在界面中使用。

## Current system

| Part | Purpose |
| --- | --- |
| MapLibre GL JS | Renders the local vector map and personal layers in the browser |
| PMTiles | Stores each regional OpenMapTiles base map as one portable, checksum-tracked file |
| FastAPI | CRUD, GPX import/export, owned media, unified search, status, and portable personal archives |
| PostGIS | Personal source of truth plus a reproducible 126k-place offline OSM reference index |
| Martin | Publishes the approved PostGIS views as vector tiles |
| Nominatim | Full local address search and reverse geocoding |
| Valhalla | Local driving, cycling, and walking routes built from the same OSM snapshot |
| SRTM / Terrarium | Point elevation, route profiles, hillshade, and browser-generated vector contours |
| Natural Earth | Provides the installed global low-zoom overview, country outlines, and major-city labels |
| Open-Meteo snapshot | Provides a locally saved seven-day layer for 29 Jiangsu/Anhui cities |
| Kiwix | Serves checksum-pinned Chinese Wikipedia and Wikivoyage ZIMs at `/wiki/` |
| Maintenance worker | Executes allowlisted map/resource jobs from the local queue and records progress/results |
| nginx | The only host-facing service; serves the UI and proxies API/Martin |

Only `127.0.0.1:8080` is exposed. PostGIS, FastAPI, and Martin stay inside the Docker network.

## Start and verify

The start command launches Docker Desktop when it is installed but not running.

```powershell
D:\GISS\start-giss.cmd
D:\GISS\health-check.cmd
D:\GISS\smoke-test.cmd
```

`start-giss.cmd` creates strong local database and Nominatim passwords when needed, applies versioned migrations, builds the API image, and starts the core services. It automatically enables the advanced profile when its prepared data is present.

Prepare or rebuild the advanced offline capabilities:

```powershell
D:\GISS\prepare-advanced.cmd
```

This merges installed region sources into one capability PBF; prepares the encyclopedia, travel guide, global overview, weather, and nautical references; builds the Valhalla graph and elevation cache; and imports Nominatim. The first build is CPU-, memory-, and disk-intensive; later starts reuse the products and index.

## Everyday operations

```powershell
D:\GISS\backup-giss.cmd
D:\GISS\stop-giss.cmd
D:\GISS\start-giss.cmd
```

Backups are written under `D:\GISS\backups\<timestamp>` and include a PostgreSQL custom dump, media, and SHA256 manifest. The default policy keeps 14 backups.

`install-backup-task.cmd` installs the local `GISS Daily Personal Backup` Windows task for 03:00 every day. Pass `-MirrorRoot E:\GISS-BACKUPS` to `scripts\backup-giss.ps1` when a second physical disk is available; the script rejects a mirror on the same drive.

For a fully disconnected recovery package, including the active maps, source PBFs, build caches, Docker images, and a fresh personal-data backup:

```powershell
D:\GISS\create-offline-kit.cmd
D:\GISS\test-offline-recovery.cmd
```

The recovery test restores the kit on a temporary Docker `--internal` network and writes an audit report under `runtime/recovery-audit` without stopping the live system.

## Manage regional maps

System -> Manage resources provides Available, Local, and Updates views. Available keeps the world hierarchy visible in a left browser while the selected region's details stay on the right. China contains 34 independent province-level units; the synchronized global directory adds more than 550 Geofabrik country/region packs. Geographic headings are navigation only, never bundled downloads. Jiangsu, Anhui, Shanghai, and Zhejiang are installed and rendered together by default; the region shortcuts only focus the camera and do not hide the other installed packs.

The map itself now carries the same ownership transition. A local Natural Earth world overview remains visible at low zoom; locating an uninstalled catalog region opens the exact offline package prompt. The WiFi shortcut provides offline-only, OpenStreetMap Standard, and OpenFreeMap choices, reports the source actually rendering plus current local coverage, and falls back from OSM to OpenFreeMap to the local overview as needed. Online tiles are never bulk-cached or treated as owned data.

Build, update, and remove buttons create real allowlisted local maintenance jobs. `start-giss.cmd` starts the hidden worker with Docker, and `stop-giss.cmd` stops it. The Updates view shows each task's queue position, elapsed time, current build stage, live transfer/generation throughput, and in-row cancel/retry action; its summary bar contains totals only. Installed map jobs derive a five-stage progress model from their live maintenance logs instead of presenting a made-up byte percentage. Curl-backed downloads report bytes per second and received/total bytes, while Planetiler reports generated tiles, tiles per second, and staged output size. The manager can automatically refresh weather every 6 hours plus the global directory every 7 days. Installed map freshness is compared with the provider's trusted HTTPS replication state rather than guessed from local dates. Heavy map builds, encyclopedia downloads, and shared search/route rebuilds remain explicit actions and are never included in the regular automatic batch.

Resource inventory is cache-first: the last complete, host-persisted inventory is displayed immediately while local storage and update checks refresh together in the background. Available regions render directly from the already-loaded catalog, and maintenance state is fetched independently, so a large local disk scan cannot hide an active task. OsmAnd-informed design boundaries and the next management features are documented in `docs/OSMAND_REFERENCE.md`.

```powershell
D:\GISS\region-pack.cmd List
D:\GISS\region-pack.cmd Verify
D:\GISS\region-pack.cmd Plan -PackId jiangsu
D:\GISS\region-pack.cmd Build -PackId jiangsu
D:\GISS\region-pack.cmd Update -PackId jiangsu
D:\GISS\region-pack.cmd Remove -PackId jiangsu -ConfirmRemove
D:\GISS\region-pack.cmd Plan -PackId gf-japan
D:\GISS\rebuild-shared-indexes.cmd -Plan
```

`Plan` resolves all paths and estimates without changing data. `Build` uses owned source data; `Update` refreshes trusted provider state and source first, then creates one staged PMTiles and replaces the old product only after validation. Shared China-snapshot province updates reuse one newly validated download at the same sequence. A completed update disappears from Updates, and the API rejects another update at the same sequence; **Rebuild** is the separate source-current regeneration action. `Verify` checks installed hashes. `Remove` deletes only the derived map/manifest after explicit confirmation and retains offline rebuild inputs.

After adding or updating map packs, the Updates tab reports whether shared address and route indexes are stale. `rebuild-shared-indexes.cmd -ConfirmRebuild` snapshots the current Nominatim volume and Valhalla products, rebuilds them sequentially, and rolls back derived indexes if either rebuild fails.

## Refresh the source snapshot

```powershell
D:\GISS\download-osm.cmd
D:\GISS\region-pack.cmd Update -PackId jiangsu
D:\GISS\region-pack.cmd Update -PackId anhui
D:\GISS\import-reference-search.cmd
D:\GISS\health-check.cmd
```

Downloads and builds use staging files. The previous usable PBF and PMTiles remain in place until validation succeeds. The current combined source is built from one China snapshot to avoid duplicate OSM object IDs along the provincial boundary.

`import-reference-search.cmd` rebuilds the lightweight offline search index from the same regional PBF. It currently indexes named OSM nodes such as cities, stations, amenities, shops, tourism, and historic places. The UI keeps personal results distinct and lets a reference result be copied into the personal database.

Rendered OSM places, POIs, roads, water, peaks, parks, and buildings are clickable. The detail panel enriches tile properties with nearby reference-index tags, groups dense results, finds nearby places, and saves a selected feature into a personal collection. Personal point details include collections, nearby tracks, photos, editing, and deletion.

## Important paths

| Path | Contents |
| --- | --- |
| `web/` | Map application, local JS/CSS, glyphs, and sprites |
| `services/` | Docker Compose, API, nginx, Martin, and SQL migrations |
| `raw/osm/` | Downloaded OSM PBF files, state files, and province polygons |
| `web/config/region-catalog.json` | 34 province datasets, source profiles, bounds, estimates, and legacy coverage |
| `web/config/world-region-catalog.json` | Generated global Geofabrik hierarchy and country/region build definitions |
| `web/config/map-catalog.json` | Active province and rendering limits |
| `products/tiles/pmtiles/*.pmtiles` | Installed offline regional base maps |
| `products/routing/valhalla/` | Route graph, 58 local elevation grids, and build configuration |
| `products/encyclopedia/` | Verified Chinese Wikipedia ZIM and manifest |
| `products/weather/` | Local seven-day weather snapshot and manifest |
| `products/nautical/` | OSM seamark/harbor reference layer and manifest |
| `web/assets/overview/` | Natural Earth global overview, countries, and major places |
| `raw/osm/china/giss-core-latest.osm.pbf` | Shared source for address and route engines |
| `data/terrain-cache/` | On-demand Terrarium PNG cache shared by hillshade and vector contour generation |
| `data/maintenance/` | Maintenance settings, queue state, worker heartbeat, job history, and logs |
| `data/media/` | Content-addressed personal image files |
| `backups/` | Database and media recovery points |
| `offline-kit/` | Generated checksum-protected disconnected recovery packages (latest two retained) |
| `scripts/` | Rebuild, migrate, backup, restore, health, and smoke-test scripts |

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Configuration](docs/CONFIGURATION.md)
- [Data pipeline](docs/DATA_PIPELINE.md)
- [Operations](docs/OPERATIONS.md)
- [Rebuild from scratch](docs/REBUILD.md)
- [Offline recovery](docs/OFFLINE_RECOVERY.md)
- [Sources and licenses](docs/SOURCES_AND_LICENSES.md)
- [Roadmap](docs/ROADMAP.md)

The system is intentionally split into replaceable layers. PMTiles is the reference map, PostGIS is the personal source of truth, and the browser is only a client. Nominatim, Valhalla, Kiwix, and the terrain adapter sit behind stable local boundaries, so the engines and regional coverage can evolve without migrating personal records.
