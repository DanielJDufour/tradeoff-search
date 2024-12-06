#!/bin/sh -e

echo "starting database"
sudo systemctl start postgresql.service

echo "creating sketches table"
sudo -Hiu postgres psql -d seasketch < "$PWD/sql/seed.sql"
