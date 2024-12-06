#!/bin/sh -e

sudo apt-get update

sudo apt-get install -y build-essential curl git
      
sudo apt-get install -y pgxnclient postgresql-14 postgresql-14-postgis-3 postgresql-server-dev-14        

apt-cache search h3
      
apt-cache search postgresql

sudo pgxn install h3

# sudo pgxn load -d seasketch -h 127.0.0.1 -U postgres h3
