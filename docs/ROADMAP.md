# Roadmap

## Current local system

Implemented and verified:

- independently verifiable Jiangsu/Anhui and Shanghai/Zhejiang OSM PMTiles packs;
- a built-and-removed Monaco sample proving the global direct-source build/remove lifecycle end to end without retaining test data;
- an in-app pack center for install state, source freshness, SHA256 verification, switching, and named views;
- OSM-like standard and exploration styles with offline labels and POI sprites;
- personal point CRUD, categories, tags, notes, optimistic versions, and audit log;
- versioned track editing, GPX import/export, point/track photo ownership, GeoJSON export, and full portable ZIP archives;
- unified search across personal records and 126,340 named offline OSM reference places;
- copy an OSM reference result into the personal point database;
- click rendered POIs, place labels, roads, water, peaks, parks, and buildings for local details;
- discover distance-ranked nearby places with clustered map results;
- organize points into built-in or custom collections and filter the personal list;
- inspect personal point collections, notes, nearby tracks, and local photos in one detail panel;
- visible source snapshot, reference-index size, and backup freshness in the system panel;
- backup, checksum verification, restore, migrations, health checks, API smoke tests, and browser smoke tests;
- complete disconnected recovery kits with map inputs/products and Docker images;
- destructive-in-spirit recovery drills contained on an isolated temporary Docker network with JSON audit evidence;
- localhost-only network exposure and pinned runtime images.
- normalized full address/reverse geocoding with Nominatim;
- offline car, bicycle, and pedestrian routing with Valhalla, saved as personal tracks;
- point elevation, route profiles, cached terrain hillshade, emergency references, and a local Chinese encyclopedia.
- a 34-unit province catalog with independent build/update/verify/remove lifecycle, source provenance, and estimates;
- an OsmAnd-style Available/Local/Updates resource manager with global hierarchy and real storage accounting.
- a generated 547-node global browse hierarchy and 554 buildable Geofabrik map packs;
- installed Natural Earth world overview, 29-city weather snapshot, 5,718-feature nautical layer, Chinese Wikivoyage, local route TTS, and working layer/resource actions;
- update checks and disconnected-kit coverage for maps, catalog, overview, weather, nautical data, encyclopedia, and travel guide.
- source-hash-aware shared-index freshness plus rollback-protected Nominatim/Valhalla rebuild tooling.
- provider-state-aware map updates, cancellable/retryable maintenance jobs, daily verified backups, and two-generation recovery-kit retention.

## Recovery milestone completed

The regional system can now be rebuilt from a checksum-verified local kit without registries or upstream data servers. The restore path is exercised against fresh temporary personal and address volumes while the live installation continues running. The remaining external prerequisite is a compatible Windows/Docker Desktop installation, whose installer should be archived separately.

## Advanced offline milestone completed

The fifth-priority capability set is implemented behind optional local services:

1. Nominatim provides full address search and reverse geocoding from the same OSM source used by the installed maps.
2. Valhalla provides driving, cycling, and walking routes through a stable GIS_P adapter; saved routes become ordinary personal tracks.
3. Fifty-eight local HGT grids provide point elevation, route profiles, and optional MapLibre terrain hillshade.
4. A checksum-pinned Chinese Wikipedia all-mini ZIM is served locally by Kiwix.
5. The lightweight PostGIS reference index now also drives bounded emergency layers for medical care, rescue, shelter, supplies, and fuel.
6. The disconnected kit carries the capability PBF, route graph, elevation, encyclopedia, images, and a consistent Nominatim index snapshot.

The API boundaries keep alternative engines viable. Pelias/Photon could replace Nominatim, GraphHopper could replace Valhalla, and another ZIM collection could extend Kiwix without changing personal records or the main map architecture.

## Province resource model completed

The China catalog migration is implemented and verified:

1. All 34 province-level administrative units are independent datasets; six geographic sections affect presentation only.
2. Schema v3 expands region/source profiles without combination download units.
3. Jiangsu, Anhui, Shanghai, and Zhejiang are installed as independent province products.
4. Every province carries boundary/source readiness, provenance, storage/time estimates, and lifecycle commands.
5. The browser renders every installed pack by default and offers combined/per-region camera shortcuts; independent clipped packs remain separately updateable.
6. Recovery kits dynamically include all installed catalog packs and validate their headers after restore.

Separating the build machine remains optional when regional build time becomes disruptive.

## Global offline architecture implemented

A single planet-scale z16 PMTiles, global geocoder, and global routing graph are operationally expensive. Prefer region packs sharing one catalog:

- global low-zoom overview;
- country/region high-zoom base-map packs;
- optional regional search indexes;
- optional regional routing graphs;
- one global personal PostGIS database with portable GeoJSON/GPX exports.

The catalog and lifecycle are now implemented. Global high-detail data remains intentionally opt-in by country/region so the 100 GB budget is not consumed by an impossible planet-wide z16 build; installed packs remain fully recoverable and independently verifiable.
