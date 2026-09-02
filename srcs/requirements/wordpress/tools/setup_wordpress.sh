#!/bin/bash
set -eu

# 1. Esperar a que la base de datos MariaDB esté lista respondiendo conexiones TCP
# Esto previene errores de "Error establishing database connection" al arrancar el stack de golpe
echo "Esperando a que MariaDB acepte conexiones..."
until mariadb -h mariadb -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; do
    sleep 2
done
echo "MariaDB lista. Continuando con WordPress..."

# 2. Descargar e instalar WP-CLI de forma dinámica si no está presente
if [ ! -f /usr/local/bin/wp ]; then
    echo "Instalando la utilidad WP-CLI..."
    curl -fsSL -o /tmp/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x /tmp/wp-cli.phar
    mv /tmp/wp-cli.phar /usr/local/bin/wp
fi

# 3. Descargar el núcleo oficial de WordPress en español si el directorio está vacío
if [ ! -f /var/www/html/index.php ]; then
    echo "Descargando código fuente de WordPress..."
    cd /var/www/html
    wp core download --allow-root --locale=es_ES
fi

# 4. Generar el archivo de configuración wp-config.php con las variables seguras enviadas por .env
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "Escribiendo credenciales en wp-config.php..."
    wp config create --allow-root \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="mariadb:3306" \
        --path='/var/www/html'
fi

# 5. Instalar el sitio web y crear los dos usuarios obligatorios
if ! wp core is-installed --allow-root --path=/var/www/html; then
    echo "Ejecutando instalación del core de WordPress..."

    wp core install --allow-root \
        --url="${DOMAIN_NAME}" \
        --title="${WORDPRESS_TITLE}" \
        --admin_user="${WORDPRESS_ADMIM}" \
        --admin_password="${WORDPRESS_ADMIM_PASS}" \
        --admin_email="${WORDPRESS_ADMIM_EMAIL}" \
        --skip-email \
        --path=/var/www/html

    echo "Creando el segundo usuario con privilegios de autor..."
    wp user create "${WORDPRESS_USER}" "${WORDPRESS_EMAIL}" \
        --role=author \
        --user_pass="${WORDPRESS_USER_PASS}" \
        --allow-root \
        --path=/var/www/html

    echo "Instalando tema base para la vista..."
    wp theme install twentytwentythree --activate --allow-root --path=/var/www/html || true
fi

# 6. Corregir propietarios y permisos del sistema de archivos en el volumen mapeado
# www-data es el usuario oficial del servidor web que requiere permisos de escritura en uploads y plugins
echo "Corrigiendo propietario de archivos a www-data..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# 7. Ejecutar PHP-FPM en primer plano como PID 1 (evita la caída del contenedor)
# -F fuerza a PHP-FPM a ejecutarse en primer plano, lo que es necesario para que Docker mantenga el contenedor activo, en ejecicion constante
echo "Wordpress listo! Iniciando PHP-FPM en el puerto 9000..."
mkdir -p /run/php
chown -R www-data:www-data /run/php
exec /usr/sbin/php-fpm8.2 -F