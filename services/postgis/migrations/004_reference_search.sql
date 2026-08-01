CREATE TABLE IF NOT EXISTS app.reference_places (
  id text PRIMARY KEY,
  name text NOT NULL,
  name_zh text NOT NULL DEFAULT '',
  category text NOT NULL DEFAULT 'other',
  subtype text NOT NULL DEFAULT '',
  search_text text NOT NULL,
  tags jsonb NOT NULL DEFAULT '{}'::jsonb,
  imported_at timestamptz NOT NULL DEFAULT now(),
  geom geometry(Point, 4326) NOT NULL
);

CREATE TABLE IF NOT EXISTS app.dataset_state (
  id text PRIMARY KEY,
  source_updated_at timestamptz,
  imported_at timestamptz NOT NULL DEFAULT now(),
  record_count bigint NOT NULL DEFAULT 0,
  sha256 text NOT NULL DEFAULT '',
  details jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS reference_places_geom_idx
  ON app.reference_places USING gist (geom);
CREATE INDEX IF NOT EXISTS reference_places_search_idx
  ON app.reference_places USING gin (search_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS reference_places_category_idx
  ON app.reference_places (category, subtype);

COMMENT ON TABLE app.reference_places IS
  'Rebuildable offline search index derived from named OSM nodes in the active regional snapshot.';
COMMENT ON TABLE app.dataset_state IS
  'Import provenance and freshness metadata for rebuildable datasets.';
