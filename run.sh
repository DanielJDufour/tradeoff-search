#!/bin/sh -e

psql -h postgres -p 5432 --username postgres seasketch < ../sql/create_extensions.sql

#sh -c "cd ./scripts && ./create_extensions.sh"
