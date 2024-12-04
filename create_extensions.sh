#!/bin/sh -e

psql -h 0.0.0.0 -p 5432 --username postgres < ../sql/create_extensions.sql
