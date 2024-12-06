#!/bin/sh -e

sudo apt-get update

sudo apt-get install -y build-essential curl git

# remove default (older version of) postgresql
sudo apt-get --purge remove postgresql-14

echo | sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
      
sudo apt-get install -y pgxnclient postgresql-17 postgresql-client-17 postgresql-17-postgis-3 postgresql-server-dev-17       

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

