DO $migration$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis_topology') THEN
    ALTER EXTENSION postgis_topology UPDATE;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis_tiger_geocoder') THEN
    ALTER EXTENSION postgis_tiger_geocoder UPDATE;
  END IF;
END
$migration$;
