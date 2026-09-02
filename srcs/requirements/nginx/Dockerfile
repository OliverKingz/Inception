FROM debian:bookworm

# Instalar el servidor web NGINX y la herramienta openssl en la misma capa
# Ademas, limpiar la caché de apt para reducir el tamaño de la imagen
RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/* 

# Copiar la configuración a la ubicación oficial de NGINX
COPY conf/nginx.conf /etc/nginx/nginx.conf

# Copiar el script de inicialización SSL al contenedor
COPY tools/generate_ssl.sh /usr/local/bin/generate_ssl.sh

# Asignar permisos de ejecución al script para evitar errores de permisos
RUN chmod +x /usr/local/bin/generate_ssl.sh

# Puerto expuesto para tráfico encriptado HTTPS (documentativo)
EXPOSE 443

# El Entrypoint asegura que el script prepare el entorno antes de iniciar el daemon
ENTRYPOINT ["/usr/local/bin/generate_ssl.sh"]
