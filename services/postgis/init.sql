CREATE EXTENSION IF NOT EXISTS postgis;

CREATE SCHEMA IF NOT EXISTS app;

CREATE TABLE IF NOT EXISTS app.places (
  id text PRIMARY KEY,
  name text NOT NULL,
  province text NOT NULL DEFAULT '',
  category text NOT NULL DEFAULT 'todo',
  note text NOT NULL DEFAULT '',
  tags text NOT NULL DEFAULT '',
  rating integer NOT NULL DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
  source text NOT NULL DEFAULT 'manual',
  photo_path text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  sync_state text NOT NULL DEFAULT 'local',
  geom geometry(Point, 4326) NOT NULL
);

CREATE INDEX IF NOT EXISTS places_geom_idx ON app.places USING gist (geom);
CREATE INDEX IF NOT EXISTS places_province_idx ON app.places (province);
CREATE INDEX IF NOT EXISTS places_category_idx ON app.places (category);
CREATE INDEX IF NOT EXISTS places_updated_at_idx ON app.places (updated_at);

INSERT INTO app.places (
  id,
  name,
  province,
  category,
  note,
  tags,
  rating,
  source,
  photo_path,
  created_at,
  updated_at,
  sync_state,
  geom
) VALUES
  (
    'demo-001',
    '南京示例点',
    '江苏省',
    'todo',
    '江苏 MVP 种子点：后续可替换为真实标记。',
    'jiangsu,demo,mvp',
    3,
    'manual',
    '',
    '2026-07-03T00:00:00+08:00',
    '2026-07-03T00:00:00+08:00',
    'local',
    ST_SetSRID(ST_MakePoint(118.7969, 32.0603), 4326)
  ),
  (
    'demo-002',
    '合肥示例点',
    '安徽省',
    'field',
    '安徽 MVP 种子点：用于验证分类、弹窗和矢量瓦片发布。',
    'anhui,field,qfield',
    4,
    'manual',
    '',
    '2026-07-03T00:00:00+08:00',
    '2026-07-03T00:00:00+08:00',
    'local',
    ST_SetSRID(ST_MakePoint(117.2272, 31.8206), 4326)
  )
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE VIEW app.places_web AS
SELECT
  id,
  name,
  province,
  category,
  note,
  tags,
  rating,
  source,
  photo_path,
  created_at,
  updated_at,
  sync_state,
  geom
FROM app.places;
