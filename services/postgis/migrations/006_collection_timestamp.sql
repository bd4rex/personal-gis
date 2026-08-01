CREATE OR REPLACE FUNCTION app.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS collections_touch_record ON app.collections;
CREATE TRIGGER collections_touch_record
BEFORE UPDATE ON app.collections
FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
