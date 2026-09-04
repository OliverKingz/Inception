FROM debian:bookworm

# Install NGINX and OpenSSL, and clean the apt cache afterward to reduce the image size
RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/* 

# Copy the configuration to the official NGINX location
COPY conf/nginx.conf /etc/nginx/nginx.conf

# Copy the SSL initialization script to the container
COPY tools/generate_ssl.sh /usr/local/bin/generate_ssl.sh

# Grant execution permissions to the script to avoid permission errors
RUN chmod +x /usr/local/bin/generate_ssl.sh

# Expose the port for encrypted HTTPS traffic
EXPOSE 443

# The Entrypoint ensures that the script prepares the environment before starting the daemon
ENTRYPOINT ["/usr/local/bin/generate_ssl.sh"]
