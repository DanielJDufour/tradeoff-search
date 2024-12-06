#!/bin/sh -e

echo "starting database"
sudo systemctl start postgresql.service

echo "creating sketches table"
chmod 764 ./sql/create_sketches_table.sql
sudo -Hiu postgres psql -f ./sql/create_sketches_table.sql
