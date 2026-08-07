# Roadmap

> English | [简体中文](ROADMAP.zh-CN.md) · Snapshot `2026-08-03T23:12:23+08:00`

## Completed foundation

- Independent Jiangsu and Anhui PMTiles packages with manifests, rollback, enable/disable, verification, rebuild, update, and protected removal.
- Local OSM Carto renderer as the default familiar map and PMTiles as the interactive vector alternative.
- A 34-unit Chinese province catalog and a synchronized catalog of more than 550 Geofabrik packages.
- Natural Earth world overview and explicit Offline/OSM Standard/OpenFreeMap source control.
- Personal places, collections, tracks, notes, tags, ratings, owned media, optimistic versions, audit, GPX, GeoJSON, and portable ZIP export.
- Lightweight OSM reference search plus Nominatim address/reverse search.
- Valhalla driving, cycling, and walking routes with elevation and track saving.
- HGT elevation, Terrarium terrain, hillshade, contours, weather, nautical, emergency, Wikipedia, and Wikivoyage layers.
- Cache-first resource inventory, real maintenance queue state, measured progress, updates, rollback, and storage classification.
- Daily verified personal backups and schema-v4 disconnected recovery kits containing Nominatim and OSM Carto snapshots.
- Layered health, API lifecycle, resource-console, main-map, world-map, performance, and isolated recovery tests, plus automated bilingual-document parity and link checks.

## Near-term priorities

1. Move performance-sensitive runtime assets and renewable build scratch from Windows bind mounts to Linux-native Docker volumes while retaining validated host-side recovery copies.
2. Establish explicit tagged releases after the historical milestone documentation is accepted.
3. Improve local search latency, query cancellation, and UI debounce under limited memory.
4. Add a supported workflow for extending shared search/routing scope without silently retaining removed regions.
5. Complete the isolated OSM incremental-update experiment and keep full snapshots as the disaster-recovery baseline.

## Medium-term work

- Optional mobile collection/synchronization using an evaluated QField, Mergin, or small API workflow.
- Richer visit history, attachments, import reconciliation, and user-visible change history.
- Additional independently installed country/region packages with calibrated build estimates.
- More granular search/routing products when a single shared index becomes operationally expensive.
- A documented authenticated LAN deployment profile separate from the current localhost-only mode.

## Long-term direction

Avoid one mandatory planet-scale z16 map, geocoder, or routing graph. Scale through a local global overview, independently owned high-detail regional packages, optional regional capability indexes, and one durable personal PostGIS database.

The personal data model must remain stable while renderers, catalogs, and derived engines evolve.
