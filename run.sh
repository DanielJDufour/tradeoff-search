#!/bin/sh -e

PG_HOST="127.0.0.1"

psql -h $PG_HOST -p 5432 --username postgres seasketch < ./sql/create_extensions.sql

#sh -c "cd ./scripts && ./create_extensions.sh"
