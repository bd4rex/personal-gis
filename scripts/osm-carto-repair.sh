#!/usr/bin/env bash
set -euo pipefail

chown renderer: /data/database/
chown -R postgres: /var/lib/postgresql /data/database/postgres/
cp /etc/postgresql/$PG_VERSION/main/postgresql.custom.conf.tmpl /etc/postgresql/$PG_VERSION/main/conf.d/postgresql.custom.conf
echo "autovacuum = on" >> /etc/postgresql/$PG_VERSION/main/conf.d/postgresql.custom.conf
service postgresql start
trap 'service postgresql stop >/dev/null 2>&1 || true' EXIT
sudo -E -u renderer python3 /home/renderer/src/openstreetmap-carto-backup/scripts/get-external-data.py \
  -c /repair/external-data.yml -D /tmp/external-data

table_count=$(sudo -u renderer psql -d gis -Atc "SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename IN ('water_polygons','simplified_water_polygons','icesheet_polygons','icesheet_outlines','ne_110m_admin_0_boundary_lines_land');")
if [ "$table_count" -ne 5 ]; then
  echo "Expected 5 Carto external tables, found $table_count." >&2
  exit 1
fi
sudo -u renderer touch /data/database/planet-import-complete
service postgresql stop
trap - EXIT
