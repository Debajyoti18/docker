#!/bin/bash
set -e

# Install Docker
echo "Installing Docker..."
sudo apt update -y
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Run MySQL container
echo "Running MySQL container..."
sudo docker run -d \
  --name mysql-db \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=mydb \
  -p 3306:3306 \
  mysql:latest

# Wait for MySQL to initialize
echo "Waiting for MySQL to initialize..."
sleep 30

# Create additional database via docker exec (optional, since MYSQL_DATABASE already creates one)
echo "Creating database 'projectdb' inside container..."
sudo docker exec -i mysql-db mysql -uroot -prootpass -e "CREATE DATABASE IF NOT EXISTS projectdb; SHOW DATABASES;"

