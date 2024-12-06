#!/bin/sh -e

echo "starting database"
sudo systemctl start postgresql.service

echo "creating seasketch database"
sudo -Hiu postgres psql -U postgres -c "CREATE DATABASE seasketch;"

sudo -Hiu postgres psql -U postgres -c "GRANT USAGE ON SCHEMA public TO postgres;"

echo "creating extensions"
sudo -Hiu postgres psql -U postgres seasketch < "$PWD/sql/create_extensions.sql"
