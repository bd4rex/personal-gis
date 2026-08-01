# Operations

## Start, stop, and inspect

```powershell
D:\GISS\start-giss.cmd
D:\GISS\health-check.cmd
D:\GISS\stop-giss.cmd
```

Open `http://localhost:8080/` after health checks pass.

Detailed service state:

```powershell
Set-Location D:\GISS\services
docker compose ps
docker compose logs --tail 100 api web martin postgis
```

Expected core containers are `giss-web`, `giss-api`, `giss-martin`, and `giss-postgis`. A prepared installation also runs healthy `giss-nominatim`, `giss-valhalla`, and `giss-kiwix` containers.

## Advanced offline capabilities

```powershell
D:\GISS\prepare-advanced.cmd
```

The command is idempotent around verified products. It builds `giss-core-latest.osm.pbf` from every installed catalog pack; prepares the pinned Wikipedia and Wikivoyage ZIMs, Natural Earth overview, Open-Meteo snapshot, and OSM nautical layer; copies routing input into Valhalla; and starts the advanced Compose profile.

On this 16 GiB host, do not rebuild Valhalla and Nominatim concurrently. A first setup should let Valhalla finish, then let Nominatim import and index. Normal starts reuse `valhalla_tiles.tar` and the persistent Nominatim volume.

## Health checks

```powershell
D:\GISS\health-check.cmd
```

The script verifies:

- all prepared Compose services exist;
- nginx responds;
- FastAPI and PostGIS respond;
- Martin publishes exactly the configured sources;
- every installed regional PMTiles byte-range request returns 206;
- the map-pack API sees the synchronized global catalog and every installed archive;
- the latest backup directory can be identified.
- Nominatim, Valhalla, elevation grids, both Kiwix archives, global overview, weather, and nautical endpoints are ready.

Resource lifecycle assertions use the last complete persistent inventory so a health check does not start a full disk scan while a large map is being built. On a first start with no inventory cache, the check performs one fresh inventory with an extended timeout.

Functional CRUD test:

```powershell
D:\GISS\smoke-test.cmd
```

This creates, updates, searches, and deletes temporary personal records; verifies regional packs, geocoding, reverse geocoding, route geometry/instructions/profile, point elevation, terrain PNGs, emergency references, Kiwix, unified search, GPX, media, export, and cleanup.

Browser test:

```powershell
docker build -f D:\GISS\services\tools\ui-test\Dockerfile -t giss-ui-test:1 D:\GISS
docker run --rm --network container:giss-web -e GISS_UI_URL=http://127.0.0.1 -v D:\GISS\runtime\ui-smoke:/work/runtime/ui-smoke giss-ui-test:1
docker run --rm --network container:giss-web -e GISS_UI_URL=http://127.0.0.1 -v D:\GISS\runtime\ui-smoke:/work/runtime/ui-smoke --entrypoint node giss-ui-test:1 tests/world-map-smoke.cjs
```

Screenshots are written to `runtime/ui-smoke`. The main test checks real map rendering, clickable base-feature details, nearby lookup and clustering, collection management and assignment, personal details/media state, regional pack verification/switching, offline reference search, readiness metadata, OpenStreetMap attribution, editing, theme switching, and non-overlapping narrow layout controls. The targeted world-map test checks an uninstalled region's catalog search, world location, persistent coverage prompt, online toggle, and return to the exact offline build target.

## Map and resource manager

Open **System -> Manage resources** for the OsmAnd-style management surface:

- **Available** browses the world hierarchy, searches regions/resources, and opens per-region capability details;
- **Local** accounts for maps, source data, search/routing, terrain, encyclopedia, personal records, media, backups, and cache;
- **Updates** checks installed maps, shared indexes, the global catalog, overview, weather, nautical data, encyclopedia, and travel guide, then runs allowed updates through the local maintenance queue.

Available uses a persistent split view: the left side retains the world and current hierarchy while the right side shows the selected region or map pack. Selecting a region must not replace the rest of the catalog.

The main map always has a local Natural Earth world overview at low zoom. **Locate on world map** focuses an available package and keeps that exact selection in a coverage prompt. **View online** temporarily places the configured OpenStreetMap Standard raster above the local base map for the current viewport; **Download region** returns to the selected package's real build action. The online source is optional, clearly marked, and is never bulk-cached. Turning it off immediately returns to owned local coverage.

Opening the manager is cache-first. The last complete inventory is read from `data\maintenance\resource-inventory-cache.json`, while a single lock-protected refresh thread collects a new local/update inventory. The worker never deletes the last complete snapshot when a job finishes. Available renders from the map catalog and Updates renders from the independent maintenance snapshot, so active progress remains visible during a slow disk scan. The refresh icon starts a fresh inventory and trusted upstream check; the page polls the cached generation and replaces the view when the atomic refresh completes.

The Updates view shows the host worker heartbeat and job state. **Update** queues one resource; each active row shows its queue position or elapsed time, current stage, progress track, attached cancel action, and any throughput the underlying tool can report. Direct downloads show bytes per second plus received/total size. Planetiler builds show tiles per second, generated tile count, and staged output size. Stages without a reliable counter remain labelled as processing and never display an invented speed. Failed jobs expose retry on the same row. The summary strip contains counts only. **Update all** queues only non-heavy items. The automatic-update switch schedules weather every 6 hours and the global region catalog every 7 days; the overview map is present in settings but disabled by default. Shared search/route indexes, map builds, and large knowledge downloads always require an explicit action. A forced refresh asks the trusted source provider for its current replication state and distinguishes upstream updates, local refreshes, missing products, and shared-index rebuilds.

Local map-pack management supports multi-select verification, update, and protected removal. Each pack also has its own information, verification, manifest export, enable/disable, rebuild, browse, and remove menu. Disable keeps the PMTiles and source files but excludes the pack from MapLibre rendering immediately. It also makes the shared search/route index stale; geocoding, reverse lookup, and routing are then held unavailable until **Search and route shared index** is rebuilt for the enabled coverage. State is stored in `data\maintenance\map-pack-state.json` and is included in new offline recovery kits.

Regenerable storage is accounted separately as terrain tiles, build temporary files, and the resource-inventory cache. Clear actions use a fixed server-side allowlist. Build temporary files cannot be cleared while maintenance work is queued or running. Legacy `suwan` and `huzhe` combination files, when present, are reported with their independent province replacements.

Every update row uses the same lifecycle fields: source-data time, local-build time, last-check time, and next-check time. For the incremental-update research path and full-snapshot disaster-recovery rules, see `docs/OSM_INCREMENTAL_UPDATES.md` and run `D:\GISS\plan-osm-incremental-updates.cmd`.

Maintenance state is stored in `D:\GISS\data\maintenance`:

| Path | Purpose |
| --- | --- |
| `settings.json` | Automatic-update policy |
| `worker.json` | Worker PID, heartbeat, and current job |
| `jobs\*.json` | Queue and completed job records |
| `logs\*.log` | Script output for each job |
| `backup-policy.json` | Installed daily-backup schedule and optional mirror target |

The API accepts only catalog pack IDs and a fixed resource allowlist. It never accepts a command string from the browser. `start-giss.cmd` starts `scripts\maintenance-worker.ps1` hidden; `stop-giss.cmd` requests a clean worker stop before Docker shuts down.

The storage total is intentionally conservative. Host directories and PostGIS are counted; Docker-managed Nominatim bytes are shown as volume-managed and are not guessed.

### Nominatim incomplete-import recovery

If `/status` is healthy but ordinary searches return `Query took too long to process`, run the database self-check before rebuilding the volume:

```powershell
docker exec -u nominatim giss-nominatim nominatim admin --check-database --project-dir /nominatim
```

An absent database version or missing `idx_search_name_name_vector` / `idx_search_name_nameaddress_vector` means the import reached place indexing but not final database post-processing. Resume only that stage:

```powershell
docker exec -u nominatim giss-nominatim nominatim import --project-dir /nominatim --continue db-postprocess -j 4 --no-updates --offline
```

This can take tens of minutes on a large existing volume while map rendering remains available. Monitor `pg_stat_progress_create_index`; do not restart Docker during the transaction. On completion, rerun `admin --check-database`, then verify `/api/geocode` and `/api/reverse`. A completed self-check must report matching database/software versions, complete valid indexes, working tokenizer, and finished indexing status.

### Regional pack commands

Use the System tab for everyday pack inspection, checksum verification, switching, named regional views, building, and updating. The UI queues the same guarded scripts listed below; direct commands remain useful for recovery and diagnostics:

```powershell
D:\GISS\region-pack.cmd List
D:\GISS\region-pack.cmd Verify
D:\GISS\region-pack.cmd Plan -PackId jiangsu
D:\GISS\region-pack.cmd Build -PackId jiangsu
D:\GISS\region-pack.cmd Update -PackId jiangsu
D:\GISS\region-pack.cmd Remove -PackId jiangsu -ConfirmRemove
```

`List` reports every physical pack. `Plan` resolves a province without changing data and prints its source profile, paths, boundaries, estimates, and command. `Verify` reads installed archives and compares SHA256. `Build` uses cached sources/boundaries. `Update` refreshes trusted provider state and source data before rebuilding, including shared-snapshot mainland packs; same-sequence queued province updates reuse the already validated China snapshot. `Remove` requires the explicit confirmation switch, deletes only derived PMTiles/manifest files, and retains source/boundary caches.

An update is complete only when the installed manifest records the trusted upstream sequence. A fresh inventory then removes that item from **Updates**. The maintenance API returns `409` for another update request at the same sequence; use **Rebuild** when the source is current but the derived PMTiles must be regenerated.

The China catalog contains 34 province-level units, and the global catalog contains more than 550 Geofabrik country/region units. Continents and Chinese geographic headings are navigation sections, not bundle IDs. Combination packs are not supported installation units.

To add a province, open it under Available and choose **Build**. Mainland builds reuse the local China snapshot and one cached boundary. Taiwan downloads and verifies its direct source when first built. To define a future country/state unit, extend `region-catalog.json` with a source profile and dataset rather than adding another combination pack. Uninstalled units are skipped by capability-source and offline-kit builds; partially installed units remain visible as repair work and never count as installed.

### Rebuild shared search and route indexes

Adding a new region or changing an installed source hash marks the shared index as updateable:

```powershell
D:\GISS\rebuild-shared-indexes.cmd -Plan
D:\GISS\rebuild-shared-indexes.cmd -ConfirmRebuild
```

The confirmed operation may take many hours, but it no longer rebuilds either production index in place. It creates a resource-limited Valhalla candidate and a separate Nominatim candidate volume while the active map, search, and routing services stay online. The candidates are switched into service only after health and database checks pass. The previous pointers are retained for rollback, and a failed or cancelled build leaves the current version selected. Personal PostGIS data is never replaced.

The resource task page reports five phases: source snapshot, route candidate, search candidate, validation, and activation. A heavy shared-index task is never automatically retried after failure or a worker restart. Review its log and start a new task explicitly.

## Backup

```powershell
D:\GISS\backup-giss.cmd
```

Each backup contains:

- `personal_gis.dump`: PostgreSQL custom-format dump;
- `media/`: personal image files, when present;
- `manifest.json`: file sizes and SHA256 hashes.

The default retention is 14. To choose another count:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\GISS\scripts\backup-giss.ps1 -Keep 30
```

Install or refresh the daily 03:00 Windows task:

```powershell
D:\GISS\install-backup-task.cmd
```

For a second physical disk, run the script with `-MirrorRoot E:\GISS-BACKUPS`; verification completes locally before the backup is copied. A same-drive mirror is rejected because it does not protect against disk loss.

Base maps and advanced indexes are not part of the small everyday backup because they are reproducible and much larger than personal data. The disconnected recovery kit below captures them.

## Restore

Restoration replaces database contents. Stop editing the map first and use a directory inside `D:\GISS\backups`:

```powershell
D:\GISS\restore-giss.cmd -BackupDirectory D:\GISS\backups\YYYYMMDD-HHMMSS
```

The script rejects paths outside the backup root, validates the database dump checksum, stops API/Martin, restores with `pg_restore --clean --if-exists`, applies any migrations newer than the dump, copies media, and starts the services again. Run health and smoke tests afterward.

## Disconnected recovery kit

Create a complete kit after the normal health and smoke tests pass:

```powershell
D:\GISS\create-offline-kit.cmd
```

The command first checks free space, creates a fresh personal backup; copies the application, every installed map pack and source, shared capability PBF, route graph, elevation grids, both Kiwix archives, global overview sources, weather, and nautical data; snapshots Nominatim; exports runtime/build/test Docker images; then writes and verifies a SHA256 manifest. Kits are written to `D:\GISS\offline-kit\<timestamp>`. After verification, the default policy retains the latest two valid kits and deletes failed/older kit directories through path-guarded cleanup.

Verify an existing kit without restoring it:

```powershell
D:\GISS\verify-offline-kit.cmd -KitDirectory D:\GISS\offline-kit\YYYYMMDD-HHMMSS
```

Run a non-destructive isolated recovery drill:

```powershell
D:\GISS\test-offline-recovery.cmd -KitDirectory D:\GISS\offline-kit\YYYYMMDD-HHMMSS
```

The drill creates temporary containers on a Docker `--internal` network, restores PostGIS, media, and the Nominatim snapshot, starts the packaged Valhalla and Kiwix products, then verifies API health/status/search/export, address search, routing/elevation, encyclopedia access, Martin sources, nginx proxying, PMTiles headers, restored row counts, and blocked external routing. It removes temporary resources afterward; the JSON result remains under `runtime/recovery-audit`.

The printable replacement-computer procedure is in `docs/OFFLINE_RECOVERY.md`.

## Refresh map data

```powershell
D:\GISS\backup-giss.cmd
D:\GISS\download-osm.cmd
D:\GISS\region-pack.cmd Update -PackId jiangsu
D:\GISS\region-pack.cmd Update -PackId anhui
D:\GISS\region-pack.cmd Update -PackId shanghai
D:\GISS\region-pack.cmd Update -PackId zhejiang
D:\GISS\build-capability-source.cmd
D:\GISS\sync-world-catalog.cmd
D:\GISS\sync-weather.cmd
D:\GISS\build-nautical.cmd
D:\GISS\import-reference-search.cmd
D:\GISS\health-check.cmd
```

Do not delete `.previous` files until the new map has passed browser testing. Builds use significant CPU, disk I/O, and up to roughly 6GB Java heap.

## Useful direct probes

```powershell
Invoke-RestMethod http://localhost:8080/api/status
Invoke-RestMethod 'http://localhost:8080/api/search?q=南京'
Invoke-RestMethod http://localhost:8080/martin/catalog
Invoke-RestMethod http://localhost:8080/api/map-packs
Invoke-RestMethod http://localhost:8080/api/resources
Invoke-RestMethod http://localhost:8080/api/capabilities
Invoke-RestMethod 'http://localhost:8080/api/geocode?q=南京大学'
Invoke-RestMethod 'http://localhost:8080/api/elevation?longitude=118.7969&latitude=32.0603'
curl.exe -I -H "Range: bytes=0-1023" http://localhost:8080/tiles/jiangsu.pmtiles
curl.exe -I -H "Range: bytes=0-1023" http://localhost:8080/tiles/zhejiang.pmtiles
```

The last command should return `206 Partial Content`.

## Troubleshooting

### The port shows JSON or text

Use only `http://localhost:8080/` for the application. `/api/health`, `/martin/catalog`, and `/healthz` are machine-readable service endpoints by design.

### Blank or incomplete map

1. Run `health-check.cmd`.
2. Check that every installed pack's `.pmtiles` and manifest exist and are not staging files; use a per-region shortcut to isolate the affected area.
3. Verify the Range probe returns 206.
4. Inspect `docker compose logs web`.
5. Run the UI smoke test and inspect its screenshots.

### Personal data missing

Check `/api/status`, then inspect API/PostGIS logs. Do not recreate the Docker volume before taking a dump. Use the most recent checksum-valid backup if recovery is necessary.

### Database password changed

Run `start-giss.cmd`. It reads `services/.env`, starts PostGIS, synchronizes the role password, applies migrations, then starts dependent services.

### Rebuild interrupted

The installed PMTiles remains untouched until the staged file passes checks. Remove only `<pack>.staged.pmtiles` and files under `tmp/osmium-<pack>`, then rerun `region-pack.cmd Build -PackId <pack>`. Do not remove the installed `<pack>.pmtiles`.

For a shared search/route rebuild, the active services also remain untouched. The worker removes task-labelled candidate containers and volumes on cancellation. Candidate Valhalla files left under `runtime/index-rebuild/<timestamp>` are build cache and may be removed after confirming there is no active maintenance task. Do not delete the Nominatim volume or routing path named by `services/.env`.

### Address search is still building

Normal updates import in a `giss-nominatim-candidate-*` container while `giss-nominatim` continues serving the active database. Inspect the candidate log from the task page or with `docker logs`. Do not run `nominatim import --continue` or full-table maintenance checks in the production container. Cancel the task and start a fresh candidate build after diagnosing the failure.

### Route or terrain is unavailable

Check `products/routing/valhalla/valhalla_tiles.tar`, `elevation_data`, and `docker logs giss-valhalla`. A normal restart should load the existing tile archive rather than rebuild. Terrain PNGs under `data/terrain-cache` are disposable and regenerate from the HGT files; cached flat PNGs are intentional neighbor tiles used to keep contour generation fast at coverage edges.
