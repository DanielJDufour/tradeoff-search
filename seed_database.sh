#!/bin/sh -e

echo "starting database"
sudo systemctl start postgresql.service

echo "seeding sketches table"
sudo -Hiu postgres psql < "$PWD/sql/seed.sql"
