CREATE TABLE IF NOT EXISTS app.collections (
  id text PRIMARY KEY,
  name text NOT NULL UNIQUE,
  color text NOT NULL DEFAULT '#267352' CHECK (color ~ '^#[0-9A-Fa-f]{6}$'),
  note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.place_collections (
  place_id text NOT NULL REFERENCES app.places(id) ON DELETE CASCADE,
  collection_id text NOT NULL REFERENCES app.collections(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (place_id, collection_id)
);

DROP TRIGGER IF EXISTS collections_touch_record ON app.collections;
CREATE TRIGGER collections_touch_record
BEFORE UPDATE ON app.collections
FOR EACH ROW EXECUTE FUNCTION app.touch_record();

CREATE INDEX IF NOT EXISTS place_collections_collection_idx
  ON app.place_collections (collection_id, place_id);

INSERT INTO app.collections (id, name, color, note)
VALUES
  ('default-favorites', '收藏', '#d18b23', '长期保留、经常参考的地点'),
  ('default-plans', '旅行计划', '#266f9d', '准备前往或正在规划的地点'),
  ('default-research', '待考察', '#c94532', '需要进一步核实和实地考察的地点')
ON CONFLICT (id) DO NOTHING;

COMMENT ON TABLE app.collections IS 'User-owned place collections included in normal database backups.';
COMMENT ON TABLE app.place_collections IS 'Many-to-many membership between personal places and collections.';
