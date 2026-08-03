# Local Service Stack

> English | [简体中文](local-stack.zh-CN.md) · Snapshot `2026-08-03T23:12:23+08:00`

| Component | Role | Host exposure |
| --- | --- | --- |
| nginx | Single entry point, static assets, PMTiles Range, and reverse proxy | `127.0.0.1:8080` |
| MapLibre | Browser map composition, vector rendering, and interaction | through nginx |
| OSM Carto | Familiar locally rendered OSM raster map | through `/carto/` |
| PMTiles | Independently versioned interactive regional vector maps | through `/tiles/` |
| FastAPI | Personal CRUD, GPX, media, search, routing adapters, resources, and exports | internal |
| PostGIS | Personal source of truth, spatial indexes, versions, and audit | internal |
| Martin | Approved personal-data vector-tile views | internal |
| Nominatim | Address search and reverse geocoding | internal |
| Valhalla | Offline driving, cycling, and walking routes | internal |
| Kiwix | Local Chinese Wikipedia and Wikivoyage | through `/wiki/` |
| HGT/Terrarium | Elevation, profiles, hillshade, and contours | through `/api/` |

## Why some URLs return JSON

Use `http://localhost:8080/` for the application and `http://localhost:8080/resources.html` for resource management. `/api/health`, `/martin/catalog`, and `/healthz` are machine endpoints by design.

## Why map data and personal data are separate

OSM maps, search indexes, routes, and caches are reproducible reference products. Personal places, tracks, photos, and notes are irreplaceable assets stored in PostGIS and `data/media`. A renderer or regional package can therefore be replaced without migrating personal records.

## Current limits

- High-detail offline and shared search/route scope currently covers Jiangsu and Anhui.
- The global catalog describes downloadable packages; it is not a preinstalled global map.
- Chinese Wikipedia uses an all-mini archive and does not contain the full multimedia corpus.
- The service has no account system and is safe only as a trusted localhost application.

See the [roadmap](ROADMAP.md) for planned expansion.
