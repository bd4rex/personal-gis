# GISS Personal Offline Map

GISS is a local-first personal GIS with 34 Chinese province units and a synchronized global Geofabrik catalog. It combines an interactive offline OpenStreetMap base map with self-owned places, tracks, photos, full address search, route planning, terrain, weather, nautical references, a Chinese encyclopedia and travel guide, backup, and disconnected recovery.

The browser only needs one local URL:

```text
http://localhost:8080/
```

资源与地图版本管理使用独立页面：

```text
http://localhost:8080/resources.html
```

该页面默认展示全部已安装地图包，并提供添加区域、上游版本检查、更新/重建、启停、完整性校验、原子回退、受保护删除、任务速率和分类磁盘占用。实现约束见 [`docs/RESOURCE_AND_VERSION_MANAGEMENT.md`](docs/RESOURCE_AND_VERSION_MANAGEMENT.md)。

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

The map itself now carries the same ownership transition. A local Natural Earth world overview remains visible at low zoom; locating an uninstalled catalog region opens a prompt to either view that viewport temporarily through the optional OpenStreetMap Standard source or open the exact region package for an offline build. Online tiles are never bulk-cached or treated as owned data.

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
