# Changelog

> English | [简体中文](CHANGELOG.zh-CN.md)
>
> History reconstructed: `2026-08-03T23:12:23+08:00`

This changelog documents user-visible development milestones. It follows the human-readable grouping used by mature open-source projects and records ISO 8601 timestamps.

The repository had no tags or GitHub Releases before this file was introduced. The `M0.x` labels below are retrospective documentation labels. Commit hashes and timestamps are the source of truth; no historical releases are implied.

## Documentation snapshot — 2026-08-03T23:12:23+08:00

### Added

- English and Simplified Chinese entry points for the project and every maintained document.
- A bilingual documentation index and cross-language navigation.
- This commit-based historical version record.

### Changed

- Rewrote the main README in English and added a feature-equivalent Chinese README.
- Updated architecture and operations descriptions for the eight-service stack, OSM Carto renderer, resource lifecycle, and disconnected recovery model.

## M0.7 — Storage ownership and offline-map lifecycle

- **Commit:** [`b2a6503`](https://github.com/bd4rex/personal-gis/commit/b2a6503304fbea851a968d7cdabeddb1b7e1a81c)
- **Timestamp:** `2026-08-03T18:13:25+08:00`
- **Git status at the time:** direct `main` commit; no tag or Release

### Added

- Local OSM Carto build and repair pipeline with resumable external-data preparation.
- Rich-detail Planetiler overlay builds and schema-v3 package manifests.
- Shared-index candidate activation, pruning, and active-version retention.
- OSM Carto data in recovery-kit schema v4 and isolated recovery validation.

### Improved

- Rebuilt Nominatim and Valhalla around the installed Jiangsu and Anhui scope.
- Removed obsolete Germany, Monaco, Shanghai, Zhejiang, and duplicate regional sources after recovery validation.
- Compacted Docker storage after pruning unused volumes, images, and renewable cache.
- Expanded resource-console status, task actions, tests, and honest progress reporting.

## M0.6 — GIS_P identity and default workspace

- **Commit:** [`c1de372`](https://github.com/bd4rex/personal-gis/commit/c1de372c6d69cc5ddf77d409438c4a06bf012d2e)
- **Timestamp:** `2026-08-02T14:38:57+08:00`
- **Merged by:** [PR #5](https://github.com/bd4rex/personal-gis/pull/5)

### Changed

- Renamed the user-facing product from GISS to GIS_P while retaining compatibility identifiers.
- Made the map open with the side panel collapsed and synchronized focus, ARIA, animation, and coverage state.
- Separated shared-index coverage completeness from exact scope freshness.

## M0.5 — Product requirements baseline

- **Commit:** [`a6309f8`](https://github.com/bd4rex/personal-gis/commit/a6309f84085b0f8bc6295c444bfd26370b933844)
- **Timestamp:** `2026-08-02T08:07:31+08:00`
- **Merged by:** [PR #4](https://github.com/bd4rex/personal-gis/pull/4)

### Added

- Explicit product principles for data ownership, offline behavior, truthful state, reliability, and delivery.
- Requirements for regional maps, personal data, resource/version management, rollback, and recovery.

## M0.4 — D-drive Docker storage cleanup record

- **Commit:** [`cd28db5`](https://github.com/bd4rex/personal-gis/commit/cd28db5cde78b6dcdb78a962c3b8923de8e61491)
- **Timestamp:** `2026-08-02T07:53:13+08:00`
- **Merged by:** [PR #3](https://github.com/bd4rex/personal-gis/pull/3)

### Improved

- Recorded verification of the Docker Desktop WSL migration to `D:\DockerData\wsl`.
- Documented removal of the inactive C-drive VHD only after service, volume, backup, and API checks passed.

## M0.3 — Map-source controls and live coverage

- **Commit:** [`725ae42`](https://github.com/bd4rex/personal-gis/commit/725ae424c7cb00b86733ebdf2b025ace30d8cf0a)
- **Timestamp:** `2026-08-02T03:20:56+08:00`
- **Merged by:** [PR #2](https://github.com/bd4rex/personal-gis/pull/2)

### Added

- Explicit Offline, OpenStreetMap Standard, and OpenFreeMap source selection.
- Preferred-source, actual-source, fallback, connectivity, and local-coverage status.
- Viewport-aware region detection and localized package prompts.

### Improved

- Expanded browser tests for manual source selection, fallback, offline degradation, and region ownership prompts.

## M0.2 — Offline GIS platform expansion

- **Commit:** [`9d2ea5d`](https://github.com/bd4rex/personal-gis/commit/9d2ea5d29a1e3b7bd4cf0717e6ebe2606c11d3d6)
- **Timestamp:** `2026-08-02T02:42:50+08:00`
- **Merged by:** [PR #1](https://github.com/bd4rex/personal-gis/pull/1)

### Added

- FastAPI, ordered PostGIS migrations, Martin, nginx, Nominatim, Valhalla, Kiwix, terrain, and a maintenance worker.
- Independent Chinese province packages and a synchronized global Geofabrik catalog.
- Resource manager, local world overview, weather and nautical layers, personal media, collections, and portable exports.
- SHA256 backups, complete disconnected recovery kits, and isolated recovery drills.
- Health, functional API, UI, resource-console, and world-map test suites.

### Improved

- Replaced the bootstrap file-based map with a manifest-driven local-first platform.
- Added atomic builds, candidate validation, rollback, cache-first inventory, real maintenance progress, and version-aware updates.

## M0.1 — Initial personal GIS publication

- **Commit:** [`aa76756`](https://github.com/bd4rex/personal-gis/commit/aa76756ad887590574cdd622b4a2133f4dafc7ba)
- **Timestamp:** `2026-08-01T18:44:56+08:00`
- **Git status at the time:** initial repository commit; no tag or Release

### Added

- Initial MapLibre browser interface and sample GeoJSON personal places.
- PostGIS and Martin Compose services.
- Local architecture, resource configuration, operations, and MVP planning documents.
- PowerShell launch helpers for the local stack and web server.

## Pre-Git development record

The repository was first published on 2026-08-01, but [docs/PROCESS_LOG.md](docs/PROCESS_LOG.md) records local implementation work from 2026-07-03 onward. Those dates describe work events and validation evidence, not Git release timestamps.
