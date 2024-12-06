#!/bin/sh -e

echo "starting database"
sudo systemctl start postgresql.service

echo "creating materialize views and indices"
sudo -Hiu postgres psql -d seasketch < "$PWD/v1/setup.sql"
