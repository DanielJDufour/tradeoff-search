#!/bin/sh -e

echo "starting database"
sudo systemctl start postgresql.service

echo "creating materialize views and indices"
sudo -Hiu postgres psql -U postgres < "$PWD/v1/setup.sql"

echo "run performance tests"
sudo -Hiu postgres psql -U postgres < "$PWD/v1/test.sql"
