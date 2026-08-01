from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
from typing import Any

import psycopg


DATABASE_URL = os.environ["DATABASE_URL"]

CATEGORY_KEYS = (
    "place",
    "amenity",
    "shop",
    "tourism",
    "historic",
    "leisure",
    "railway",
    "public_transport",
    "highway",
    "natural",
    "office",
    "craft",
    "man_made",
)


def classify(tags: dict[str, Any]) -> tuple[str, str]:
    for key in CATEGORY_KEYS:
        value = tags.get(key)
        if value:
            if key == "highway" and value not in {"motorway_junction", "services", "rest_area", "bus_stop"}:
                continue
            return key, str(value)[:120]
    return "other", ""


def search_text(tags: dict[str, Any], category: str, subtype: str) -> str:
    values = [
        tags.get("name"),
        tags.get("name:zh"),
        tags.get("name:en"),
        tags.get("old_name"),
        tags.get("alt_name"),
        tags.get("brand"),
        tags.get("operator"),
        tags.get("ref"),
        category,
        subtype,
    ]
    return " ".join(str(value).strip() for value in values if value).lower()[:4000]


def iter_rows(path: Path):
    with path.open("r", encoding="utf-8") as source:
        for line_number, raw_line in enumerate(source, start=1):
            line = raw_line.lstrip("\x1e").strip()
            if not line:
                continue
            feature = json.loads(line)
            geometry = feature.get("geometry") or {}
            coordinates = geometry.get("coordinates") or []
            tags = feature.get("properties") or {}
            name = str(tags.get("name") or tags.get("name:zh") or "").strip()
            if geometry.get("type") != "Point" or len(coordinates) < 2 or not name:
                continue
            longitude, latitude = float(coordinates[0]), float(coordinates[1])
            if not -180 <= longitude <= 180 or not -90 <= latitude <= 90:
                continue
            category, subtype = classify(tags)
            identity = f"{longitude:.7f}|{latitude:.7f}|{name}|{category}|{subtype}"
            reference_id = "osm-" + hashlib.sha256(identity.encode("utf-8")).hexdigest()[:32]
            yield (
                reference_id,
                name[:300],
                str(tags.get("name:zh") or "")[:300],
                category,
                subtype,
                search_text(tags, category, subtype),
                json.dumps(tags, ensure_ascii=False, separators=(",", ":")),
                longitude,
                latitude,
                line_number,
            )


def import_file(path: Path, source_updated_at: str | None, source_sha256: str) -> int:
    count = 0
    with psycopg.connect(DATABASE_URL) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                CREATE TEMP TABLE reference_places_stage (
                  id text NOT NULL,
                  name text NOT NULL,
                  name_zh text NOT NULL,
                  category text NOT NULL,
                  subtype text NOT NULL,
                  search_text text NOT NULL,
                  tags_text text NOT NULL,
                  longitude double precision NOT NULL,
                  latitude double precision NOT NULL
                ) ON COMMIT DROP
                """
            )
            with cursor.copy(
                """
                COPY reference_places_stage
                  (id, name, name_zh, category, subtype, search_text, tags_text, longitude, latitude)
                FROM STDIN
                """
            ) as copy:
                for row in iter_rows(path):
                    copy.write_row(row[:-1])
                    count += 1
                    if count % 25_000 == 0:
                        print(f"Prepared {count:,} reference places (source line {row[-1]:,})", flush=True)

            cursor.execute("TRUNCATE app.reference_places")
            cursor.execute(
                """
                INSERT INTO app.reference_places
                  (id, name, name_zh, category, subtype, search_text, tags, geom)
                SELECT DISTINCT ON (id)
                       id, name, name_zh, category, subtype, search_text, tags_text::jsonb,
                       ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
                FROM reference_places_stage
                ORDER BY id
                """
            )
            count = cursor.rowcount
            cursor.execute(
                """
                INSERT INTO app.dataset_state
                  (id, source_updated_at, imported_at, record_count, sha256, details)
                VALUES
                  ('osm_reference_search', %s::timestamptz, now(), %s, %s,
                   jsonb_build_object('strategy', 'named OSM nodes', 'format', 'GeoJSON sequence'))
                ON CONFLICT (id) DO UPDATE SET
                  source_updated_at=EXCLUDED.source_updated_at,
                  imported_at=EXCLUDED.imported_at,
                  record_count=EXCLUDED.record_count,
                  sha256=EXCLUDED.sha256,
                  details=EXCLUDED.details
                """,
                [source_updated_at, count, source_sha256],
            )
    return count


def main() -> None:
    parser = argparse.ArgumentParser(description="Import a rebuildable local OSM reference search index.")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--source-updated-at")
    parser.add_argument("--source-sha256", default="")
    args = parser.parse_args()
    if not args.input.is_file():
        raise SystemExit(f"Input file does not exist: {args.input}")
    imported = import_file(args.input, args.source_updated_at, args.source_sha256)
    print(f"Imported {imported:,} offline OSM reference places.")


if __name__ == "__main__":
    main()
