#!/bin/bash
set -eu

# Read the WordPress user and admin passwords from Docker secrets for security
MYSQL_PASSWORD=$(cat /run/secrets/MYSQL_PASSWORD)
WORDPRESS_PASSWORD=$(cat /run/secrets/WORDPRESS_PASSWORD)
WORDPRESS_ADMIN_PASSWORD=$(cat /run/secrets/WORDPRESS_ADMIN_PASSWORD)

# Wait for MariaDB to be ready and accepting TCP connections
echo "Waiting for MariaDB to be ready..."
until mariadb -h mariadb -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; do
    sleep 2
done
echo "MariaDB is ready. Continuing with WordPress..."

# Download and install WP-CLI dynamically if not present
# WP-CLI is a command-line interface for managing WordPress installations, allowing for automation and scripting of tasks.
if [ ! -f /usr/local/bin/wp ]; then
    echo "Installing WP-CLI utility..."
    curl -fsSL -o /tmp/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x /tmp/wp-cli.phar
    mv /tmp/wp-cli.phar /usr/local/bin/wp
fi

# Download the official WordPress core in Spanish if the directory is empty
if [ ! -f /var/www/html/index.php ]; then
    echo "Downloading official WordPress core in Spanish..."
    cd /var/www/html
    wp core download --allow-root --locale=es_ES
fi

# Generate the wp-config.php configuration file with secure variables sent by .env
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "Writing configuration to wp-config.php..."
    wp config create --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="mariadb:3306" \
        --path='/var/www/html'
fi

# Set the canonical HTTPS URL before any WP-CLI command loads WordPress (to avoid warnings)
SITE_URL="https://${DOMAIN_NAME}"
if [ "$(wp config get WP_HOME --type=constant --allow-root --path=/var/www/html 2>/dev/null || true)" != "$SITE_URL" ]; then
    wp config set WP_HOME "$SITE_URL" --type=constant --allow-root --path=/var/www/html
fi

if [ "$(wp config get WP_SITEURL --type=constant --allow-root --path=/var/www/html 2>/dev/null || true)" != "$SITE_URL" ]; then
    wp config set WP_SITEURL "$SITE_URL" --type=constant --allow-root --path=/var/www/html
fi

# Install the website and create the two mandatory users
if ! wp core is-installed --allow-root --path=/var/www/html; then
    echo "Installing WordPress core and creating mandatory users..."

    wp core install --allow-root \
        --url="${DOMAIN_NAME}" \
        --title="${WORDPRESS_TITLE}" \
        --admin_user="${WORDPRESS_ADMIM}" \
        --admin_password="${WORDPRESS_ADMIN_PASSWORD}" \
        --admin_email="${WORDPRESS_ADMIM_EMAIL}" \
        --skip-email \
        --path=/var/www/html

    echo "Creating WordPress user with author role..."
    wp user create "${WORDPRESS_USER}" "${WORDPRESS_EMAIL}" \
        --role=author \
        --user_pass="${WORDPRESS_PASSWORD}" \
        --allow-root \
        --path=/var/www/html
fi

# Correct file ownership and permissions in the mapped volume
# www-data is the official web server user that requires write permissions in uploads and plugins
# 755: Owner can read/write/execute, group and others can read/execute
echo "Setting correct file ownership and permissions for /var/www/html..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# The exec command replaces the shell with the PHP-FPM daemon, ensuring that it runs as PID 1
# -F forces PHP-FPM to run in the foreground, which is necessary for Docker to keep the container active and running
echo "WordPress setup complete! Starting PHP-FPM on port 9000..."
mkdir -p /run/php
chown -R www-data:www-data /run/php
exec /usr/sbin/php-fpm8.2 -F
