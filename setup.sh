#!/bin/sh -e

sudo apt-get update

sudo apt-get install -y build-essential curl git

sudo apt-get install -y postgresql-common

echo | sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
      
sudo apt-get install -y pgxnclient postgresql-17 postgresql-client-17 postgresql-17-postgis-3 postgresql-server-dev-17       

sudo pgxn install h3

echo "starting database"
sudo systemctl start postgresql.service

echo "testing database connection"
sudo -Hiu postgres psql -c 'SELECT version();'
