#!/bin/bash
set -e

# We make sure the necessary directories exist and have the correct permissions for MariaDB to run properly
mkdir -p /var/run/mysqld /var/lib/mysql /var/log/mysql
chown -R mysql:mysql /var/run/mysqld /var/lib/mysql /var/log/mysql

# Read the database credentials from Docker secrets to ensure they are not exposed in the environment or logs
MYSQL_PASSWORD=$(cat /run/secrets/MYSQL_PASSWORD)
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/MYSQL_ROOT_PASSWORD)

# Check if the MariaDB data directory is empty, and if so, initialize it and apply the database configuration
# Bootstrap mode allows us to run SQL commands directly without starting the full server, which is useful for initial setup
if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then
    echo "Initializing data directory physically..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null

    echo "Applying database configuration via bootstrap mode..."
    mysqld --user=mysql --bootstrap << EOF
USE mysql;
FLUSH PRIVILEGES;

ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${MYSQL_ROOT_PASSWORD}');

DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
DROP USER IF EXISTS ''@'localhost';

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

FLUSH PRIVILEGES;
EOF
    echo "Database configuration completed successfully."
fi

echo "Starting MariaDB service..."
exec mysqld --user=mysql --datadir=/var/lib/mysql --socket=/var/run/mysqld/mysqld.sock --skip-name-resolve