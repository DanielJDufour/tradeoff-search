#!/bin/sh -e

echo "starting database"
sudo systemctl start postgresql.service

echo "creating postgis extension"
sudo -Hiu postgres psql -c "CREATE EXTENSION postgis";
