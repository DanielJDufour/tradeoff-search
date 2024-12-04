#!/bin/sh -e

sudo systemctl start postgresql.service

psql -h 0.0.0.0 -p 5432 --username postgres seasketch < ../sql/create_extensions.sql
