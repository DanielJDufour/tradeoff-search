#!/bin/sh -e

echo "starting database"
sudo systemctl start postgresql.service

echo "creating sketches table"
chmod 764 "$PWD/sql/create_sketches_table.sql"
sudo -Hiu postgres psql -f "$PWD/sql/create_sketches_table.sql"
