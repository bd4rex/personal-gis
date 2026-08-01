ALTER TABLE app.media DROP CONSTRAINT IF EXISTS media_place_id_fkey;
ALTER TABLE app.media DROP CONSTRAINT IF EXISTS media_track_id_fkey;

ALTER TABLE app.media
  ADD CONSTRAINT media_place_id_fkey FOREIGN KEY (place_id) REFERENCES app.places(id) ON DELETE CASCADE;
ALTER TABLE app.media
  ADD CONSTRAINT media_track_id_fkey FOREIGN KEY (track_id) REFERENCES app.tracks(id) ON DELETE CASCADE;

COMMENT ON TABLE app.media IS
  'Content-addressed images owned by a place or track. The API removes metadata and unreferenced files with the owner.';
