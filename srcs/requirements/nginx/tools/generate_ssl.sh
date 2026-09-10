#!/bin/bash

# Exit immediately if a command exits with a non-zero status (strict mode)
set -e

# Ensure the SSL storage directory exists inside the 
SSL_DIR="/etc/nginx/ssl"
mkdir -p "$SSL_DIR"

# Check if the SSL certificate already exists to avoid overwriting it when the container restarts
if [ ! -f "$SSL_DIR/inception.crt" ] || [ ! -f "$SSL_DIR/inception.key" ]; then
	echo "Generating self-signed SSL certificate for $DOMAIN_NAME..."

	# openssl req: utility to create certificate requests and self-signed certificates
	# -x509: indicates that we want a self-signed digital certificate instead of a request (CSR)
	# -nodes: "no DES", saves the private key unencrypted (without password)
	# -days 365: certificate validity (1 year)
	# -newkey rsa:2048: generates a new RSA private key of 204
	# -subj: non-interactively fills in the required certificate metadata
	#		Country, State, Locality, Organization, Organizational Unit, Common Name
	#		NOTE: In the 'CN' (Common Name) we remove the trailing hyphen due to DNS network restrictions

	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout "$SSL_DIR/inception.key" \
		-out "$SSL_DIR/inception.crt" \
		-subj "/C=ES/ST=Madrid/L=Madrid/O=42/OU=student/CN=$DOMAIN_NAME"

	# Set secure Linux permissions on the generated files
	# 700: read/write/execute for root only
	# 600: read/write for root only
	# 644: read for everyone, write only for root
	chmod 700 "$SSL_DIR"
	chmod 600 "$SSL_DIR/inception.key"
	chmod 644 "$SSL_DIR/inception.crt"

	echo "SSL certificate generated and configured successfully!"
else
	echo "SSL certificate already exists in the volume. Skipping generation."
fi

# Run NGINX in the foreground (PID 1) replacing the current terminal process (exec)
# 'daemon off;' prevents NGINX from running in the background, which would cause the container to stop
echo "Starting NGINX in the foreground..."
exec nginx -g "daemon off;"
