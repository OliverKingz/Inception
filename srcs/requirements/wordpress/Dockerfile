FROM debian:bookworm

# Instalar dependencias del sistema, PHP-FPM, extensiones de PHP y cliente de MariaDB en la misma capa
# Ademas, limpiar la caché de apt para reducir el tamaño de la imagen
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

# Requisito de Linux: Crear el directorio runtime donde PHP-FPM guarda su pid/socket de ejecución
RUN mkdir -p /run/php && chmod 755 /run/php

# Copiar la configuración personalizada de pools (escucha en puerto TCP 9000)
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

# Copiar el script de configuración automática y darle permisos de ejecución
COPY tools/setup_wordpress.sh /usr/local/bin/setup_wordpress.sh
RUN chmod +x /usr/local/bin/setup_wordpress.sh

# Definir el directorio de trabajo donde operará el volumen compartido
WORKDIR /var/www/html

# Exponer puerto 9000 para el protocolo FastCGI de NGINX (documentativo)
EXPOSE 9000

# El script actúa como Entrypoint para lanzar el auto-instalador antes del servicio definitivo 
ENTRYPOINT ["/usr/local/bin/setup_wordpress.sh"]
