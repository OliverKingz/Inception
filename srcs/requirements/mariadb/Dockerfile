FROM debian:bookworm

# Install the native MariaDB server from Debian Bookworm in a single clean layer
# As well, remove the apt cache and the default data directory to save space
RUN apt-get update && apt-get install -y \
    mariadb-server \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mysql/*

# Create the runtime directory /run/mysqld (the standard for Debian Bookworm)
# and assign it to the mysql user to avoid permission errors when writing the socket
# 755: Default for directories. Owner can read/write/execute, group and others can read/execute
RUN mkdir -p /run/mysqld \
    && chown -R mysql:mysql /run/mysqld \
    && chmod 755 /run/mysqld

# Copy the custom MariaDB configuration file to the appropriate directory in the container
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# Copy the secure initialization script to the container and make it executable
COPY tools/init_db.sh /usr/local/bin/init_db.sh
RUN chmod +x /usr/local/bin/init_db.sh

# Expose the default MariaDB port for interconnection with WordPress (documentative)
EXPOSE 3306

# The entrypoint executes our script to start the database in a controlled manner
ENTRYPOINT ["/usr/local/bin/init_db.sh"]
