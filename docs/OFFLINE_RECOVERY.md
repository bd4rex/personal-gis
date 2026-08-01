# GISS Offline Recovery Guide

This guide is designed to remain usable when internet access and image registries are unavailable. Print a copy and keep it with the offline disk.

## What the kit contains

- the GISS application, scripts, documentation, browser libraries, glyphs, and sprites;
- the latest PostgreSQL and media backup;
- every installed catalogued PMTiles archive and provenance manifest;
- every installed pack's regional PBF, the China PBF/state, all member polygons, and cached Planetiler inputs;
- the shared capability PBF, Valhalla graph/elevation, verified Wikipedia ZIM, and a consistent Nominatim index snapshot;
- the Natural Earth world overview and global downloadable-region catalog;
- pinned runtime, advanced-engine, map-build, Osmium, and browser-test Docker images;
- a SHA256 manifest covering every payload and image-archive file.

The kit does not include Windows or the Docker Desktop installer. Archive a tested Docker Desktop installer separately when preparing a fully disconnected replacement computer.

## Before an emergency

1. Keep two copies on different physical disks.
2. Run `verify-offline-kit.cmd` after copying a kit to another disk.
3. Run `test-offline-recovery.cmd` after creating a new kit.
4. Record the successful recovery report and kit ID on paper.
5. Protect the disk physically: the database backup can contain private locations, notes, tracks, and photos.

## Verify a kit

From the original GISS project:

```powershell
D:\GISS\verify-offline-kit.cmd -KitDirectory E:\GISS-OFFLINE\YYYYMMDD-HHMMSS
```

From inside the kit itself:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\verify-offline-kit.ps1 -KitDirectory .
```

Do not restore a kit when any checksum or size check fails.

## Restore on a replacement computer

Prerequisites: 64-bit Windows, Docker Desktop with Linux containers, and enough free space for the kit plus Docker images. The target directory must be empty.

```powershell
D:\GISS\restore-offline-kit.cmd `
  -KitDirectory E:\GISS-OFFLINE\YYYYMMDD-HHMMSS `
  -TargetDirectory D:\GISS-RESTORED
```

The restore process:

1. verifies every kit file;
2. copies the payload to the empty target directory;
3. loads Docker images without contacting a registry;
4. restores the packaged Nominatim volume before Compose starts;
5. generates new local database and Nominatim passwords;
6. starts services without rebuilding images or advanced indexes;
7. restores the newest personal database and media backup;
8. runs the normal health check.

Open `http://localhost:8080/` only after the health check succeeds.

## Manual checks after restore

1. Browse Jiangsu/Anhui at overview and street zoom.
2. Zoom out to the local world overview, locate an uninstalled region, and confirm its offline package prompt appears without enabling the online map.
3. Open System, verify both installed packs, switch to Shanghai/Zhejiang, then switch back.
4. Search for `南京` and open an OSM reference result.
5. Open a personal point and inspect its collections and photos.
6. Export personal GeoJSON from the System tab.
7. Import a small GPX file, then delete the temporary track.
8. Create a new backup on the replacement computer.
9. Search a complete address, reverse-check a map point, and plan one short car/walk route.
10. Enable terrain and emergency facilities, then open `/wiki/` while external networking is disabled.

The **View online** action is expected to be unavailable or blank during a disconnected recovery. This is not an offline failure: the Natural Earth overview, installed PMTiles, personal data, local search/route indexes, terrain already owned on disk, and Kiwix content remain local. Offline expansion uses an already archived PBF or a restored kit; it does not rely on the OpenStreetMap Standard tile service.

## Restore without starting services

Use this when preparing files for inspection or when Docker is not yet available:

```powershell
D:\GISS\restore-offline-kit.cmd `
  -KitDirectory E:\GISS-OFFLINE\YYYYMMDD-HHMMSS `
  -TargetDirectory D:\GISS-RESTORED `
  -PrepareOnly `
  -SkipImageLoad
```

## Rebuild the regional map while offline

The kit includes the China PBF, province polygons, regional PBF, cached Planetiler supporting datasets, and required Docker images. In the restored project:

```powershell
D:\GISS-RESTORED\region-pack.cmd Build -PackId jiangsu
D:\GISS-RESTORED\region-pack.cmd Build -PackId anhui
D:\GISS-RESTORED\region-pack.cmd Build -PackId shanghai
D:\GISS-RESTORED\region-pack.cmd Build -PackId zhejiang
D:\GISS-RESTORED\build-capability-source.cmd
D:\GISS-RESTORED\import-reference-search.cmd
D:\GISS-RESTORED\health-check.cmd
```

Do not run `download-osm.cmd` or `download-web-assets.cmd` while disconnected; those commands intentionally contact upstream sources.

## Failure rules

- Never delete the only backup or PMTiles archive while diagnosing a restore.
- Never ignore a checksum mismatch.
- Keep the original offline disk read-only during recovery when possible.
- Restore into a new empty directory instead of overwriting an uncertain installation.
- If Docker images fail to load, preserve the kit and inspect disk health before trying another copy.
