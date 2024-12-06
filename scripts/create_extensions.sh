#!/bin/sh -e

psql -h postgres -p 5432 --username postgres < ../sql/create_extensions.sql

psql -h postgres -p 5432 --username postgres seasketch < ../sql/create_extensions.sql
