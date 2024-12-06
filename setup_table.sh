#!/bin/sh -e

echo "starting database"
sudo systemctl start postgresql.service

pwd

ls -alsh .

echo "creating sketches table"
sudo -Hiu postgres psql -d seasketch -f ./sql/create_sketches_table.sql
