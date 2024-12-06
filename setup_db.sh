#!/bin/sh -e

echo "starting database"
sudo systemctl start postgresql.service

echo "creating seasketch database"
sudo -Hiu postgres psql seasketch -c "CREATE DATABASE seasketch;"

echo "creating postgis extension"
sudo -Hiu postgres psql seasketch -c "CREATE EXTENSION postgis;"

echo "loading h3 extension"
sudo -Hiu postgres pgxn load -d seasketch h3

