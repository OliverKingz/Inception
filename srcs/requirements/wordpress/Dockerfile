FROM debian:bookworm

# Install system dependencies, PHP-FPM, PHP extensions, and MariaDB client in a single layer
# Also, clean the apt cache afterward to reduce the image size
RUN apt-get update && apt-get install -y \
    php8.2-fpm \
    php8.2-mysql \
    php8.2-curl \
    php8.2-gd \
    php8.2-intl \
    php8.2-mbstring \
    php8.2-soap \
    php8.2-xml \
    php8.2-zip \
    mariadb-client \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create the runtime directory where PHP-FPM stores its execution pid/socket
RUN mkdir -p /run/php && chmod 755 /run/php

# Copy the custom pool configuration (listening on TCP port 9000)
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

# Copy the auto-setup script and grant execution permissions
COPY tools/setup_wordpress.sh /usr/local/bin/setup_wordpress.sh
RUN chmod +x /usr/local/bin/setup_wordpress.sh

# Define the working directory where the shared volume will operate
WORKDIR /var/www/html

# Expose port 9000 for NGINX FastCGI protocol (documentative)
EXPOSE 9000

# The script acts as an Entrypoint to launch the auto-installer before the final service.
# It ensures that WordPress is set up correctly with the provided environment variables before starting PHP-FPM.
ENTRYPOINT ["/usr/local/bin/setup_wordpress.sh"]
