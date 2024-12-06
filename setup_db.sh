#!/bin/sh -e

echo "starting database"
sudo systemctl start postgresql.service

echo "creating seasketch database"
sudo -Hiu postgres psql -c "CREATE DATABASE seasketch;"

echo "creating extensions"
sudo -Hiu postgres psql seasketch < "$PWD/sql/create_extensions.sql"

echo "loading h3 extension"
# sudo -Hiu postgres pgxn load -d seasketch h3

