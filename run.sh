#!/bin/sh -e

PG_VERSION=17;

sudo apt-get update

sudo apt-get install -y build-essential curl git

# remove default (older version of) postgresql
sudo apt-get --purge remove postgresql-14*
sudo apt-get --purge remove postgresql-16*

echo | sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
      
sudo apt-get install -y postgresql-$PG_VERSION postgresql-client-$PG_VERSION postgresql-$PG_VERSION-postgis-3 postgresql-server-dev-$PG_VERSION postgresql-$PG_VERSION-h3     

echo "starting database"
sudo systemctl start postgresql.service

echo "logging postgresql version"
sudo -Hiu postgres psql -c 'SELECT version();'

echo "testing psql version"
psql --version

sudo -Hiu postgres psql -c 'CREATE DATABASE seasketch';
sudo -Hiu postgres psql -c 'CREATE EXTENSION postgis';
sudo -Hiu postgres psql -c 'CREATE EXTENSION postgis_raster';

echo "logging postgis version"
sudo -Hiu postgres psql -c 'SELECT PostGIS_full_version();'

# check that postgis is installed properly
sudo -Hiu postgres psql -c 'SELECT ST_Point(-71.104, 42.315);'
sudo -Hiu postgres psql -c 'SELECT ST_Dump(ST_Point(-71.104, 42.315));'
sudo -Hiu postgres psql -c "SELECT ST_Dump(ST_GeomFromText('POLYGON((0 0, 0.00000001 0.00000001, 0.00000001 0, 0 0))'));"

sudo -Hiu postgres psql -c 'CREATE EXTENSION h3';
sudo -Hiu postgres psql -c 'CREATE EXTENSION h3_postgis';
sudo -Hiu postgres psql -c "ALTER FUNCTION h3_polygon_to_cells(multi geometry, resolution integer) SET search_path = 'public'";

# create main sketches table
sudo -Hiu postgres psql < ./sql/create_sketches_table.sql

# test pulling from sketches table
sudo -Hiu postgres psql -c 'SELECT COUNT(*) FROM sketches'

echo "seeding 5k random geojson"
sudo -Hiu postgres psql -q < ./sql/seed_5k.sql
echo "finished seeding 5k random geojson"

# seed collection, a sketch with null geometry
sudo -Hiu postgres psql -c "INSERT INTO sketches (geom) VALUES (NULL);"

# add really small geometry
sudo -Hiu postgres psql -c "INSERT INTO sketches (geom) VALUES (ST_GeomFromText('POLYGON((0 0, 0.00000001 0.00000001,
0.00000001 0, 0 0))'));"

# geometry with duplicate polygons
sudo -Hiu postgres psql -c "INSERT INTO sketches (geom) VALUES (ST_GeomFromText('MULTIPOLYGON (((30 20, 45 40, 10 40, 30 20)),((30 20, 45 40, 10 40, 30 20)))'));"

# insert a couple null geoms
sudo -Hiu postgres psql -c "INSERT INTO sketches (geom) VALUES (NULL);"
sudo -Hiu postgres psql -c "INSERT INTO sketches (geom) VALUES (NULL);"

echo "Free space:"
df -h

echo "running ./v8/setup.sql"
sudo -Hiu postgres psql < ./v8/setup.sql
echo "running ./v8/test.sql"
sudo -Hiu postgres psql < ./v8/test.sql
echo "running ./v8/refresh.sql"
sudo -Hiu postgres psql < ./v8/refresh.sql
