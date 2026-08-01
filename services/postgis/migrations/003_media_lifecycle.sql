ALTER TABLE app.media DROP CONSTRAINT IF EXISTS media_stored_path_key;
ALTER TABLE app.media DROP CONSTRAINT IF EXISTS media_check;

COMMENT ON TABLE app.media IS
  'Content-addressed images. Records may become unlinked when a place or track is deleted.';
