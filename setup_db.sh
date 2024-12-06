#!/bin/sh -e

echo "starting database"
sudo systemctl start postgresql.service

echo "creating extensions"
sudo -Hiu postgres psql -U postgres < "$PWD/sql/create_extensions.sql"
