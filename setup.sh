#!/bin/sh -e

sudo apt-get update

sudo apt-get install -qq -y build-essential curl git

# remove default (older version of) postgresql
sudo apt-get --purge remove postgresql-14

echo | sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
      
sudo apt-get install -qq -y pgxnclient postgresql-17 postgresql-client-17 postgresql-17-postgis-3 postgresql-server-dev-17       

sudo pgxn install h3

echo "starting database"
sudo systemctl start postgresql.service

echo "testing database connection"
sudo -Hiu postgres psql -c 'SELECT version();'

echo "testing psql version"
psql --version

su postgres -c "psql -c 'CREATE DATABASE seasketch'";
su postgres -c "psql -c 'CREATE ROLE $(whoami) SUPERUSER LOGIN CREATEDB'";
su postgres -c "psql -c 'ALTER DATABASE seasketch OWNER TO $(whoami)'";

psql -c "CREATE EXTENSION postgis" seasketch;
psql -c "CREATE EXTENSION postgis_raster" seasketch;
psql -c "CREATE EXTENSION h3" seasketch;

sudo systemctl restart postgresql.service



