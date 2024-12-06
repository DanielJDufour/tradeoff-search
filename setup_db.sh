#!/bin/sh -e

echo "starting database"
sudo systemctl start postgresql.service

echo "creating seasketch database"
sudo -u postgres psql -c "CREATE DATABASE seasketch;"

echo "creating postgis extension"
sudo -u postgres psql -c "CREATE EXTENSION postgis;"

echo "loading h3 extension"
sudo -u postgres pgxn load -d seasketch h3

