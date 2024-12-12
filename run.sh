#!/bin/sh -e

sudo apt-get update

sudo apt-get install -y build-essential curl git

# remove default (older version of) postgresql
sudo apt-get --purge remove postgresql-14

echo | sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
      
sudo apt-get install -y pgxnclient postgresql-16 postgresql-client-16 postgresql-16-postgis-3 postgresql-server-dev-16      

sudo pgxn install h3

echo "starting database"
sudo systemctl start postgresql.service

echo "testing database connection"
sudo -Hiu postgres psql -c 'SELECT version();'

echo "testing psql version"
psql --version

sudo -Hiu postgres psql -c 'CREATE DATABASE seasketch';
sudo -Hiu postgres psql -c 'CREATE EXTENSION postgis';
sudo -Hiu postgres psql -c 'CREATE EXTENSION postgis_raster';
sudo -Hiu postgres psql -c 'CREATE EXTENSION h3';
sudo -Hiu postgres psql -c 'CREATE EXTENSION h3_postgis';

# check that postgis is installed properly
sudo -Hiu postgres psql -c 'SELECT ST_Point(-71.104, 42.315);'
sudo -Hiu postgres psql -c 'SELECT ST_Dump(ST_Point(-71.104, 42.315));'


# create main sketches table
sudo -Hiu postgres psql < ./sql/create_sketches_table.sql

# test pulling from sketches table
sudo -Hiu postgres psql -c 'SELECT COUNT(*) FROM sketches'

# download random sketches
sh -c "cd data/random-sketches && sh ./setup.sh"

# unzip seed.sql
sh -c "cd sql && unzip -qq seed.sql.zip"

sudo -Hiu postgres psql -q < ./sql/seed.sql

# seed collection, a sketch with null geometry
sudo -Hiu postgres psql -c "INSERT INTO sketches (geom) VALUES (NULL);"

# add really small geometry
sudo -Hiu postgres psql -c "INSERT INTO sketches (geom) VALUES (ST_GeomFromText('POLYGON((0 0, 0.00000001 0.00000001,
0.00000001 0, 0 0))'));"

# sudo -Hiu postgres psql < ./v1/setup.sql
# sudo -Hiu postgres psql < ./v1/test.sql
# sudo -Hiu postgres psql < ./v1/test2.sql

# sudo -Hiu postgres psql < ./v2/setup.sql
# sudo -Hiu postgres psql < ./v2/test.sql
# sudo -Hiu postgres psql < ./v2/refresh.sql

sudo -Hiu postgres psql < ./v3/setup.sql
sudo -Hiu postgres psql < ./v3/test.sql
sudo -Hiu postgres psql < ./v3/refresh.sql
