#!/bin/sh -e

sudo apt-get update

sudo apt-get install -y build-essential curl git
      
sudo apt-get install -y pgxnclient postgresql-14 postgresql-14-postgis-3 postgresql-server-dev-14        

sudo pgxn install h3

echo "starting database"
sudo systemctl start postgresql.service

echo "testing database connection"
sudo -u postgres psql -c 'SELECT 1;'

# create database
sudo -u postgres psql -c 'CREATE DATABASE seasketch;'

# load h3 extension
sudo -u postgres pgxn load -d seasketch h3
