#!/bin/bash

# Salir inmediatamente si un comando falla (modo estricto)
set -e

# Asegurar que el directorio de almacenamiento SSL existe dentro del contenedor
mkdir -p /etc/nginx/ssl

#  si el certificado ya existe para evitar sobreescribirlo al reiniciar el contenedor
if [ ! -f Comprobar/etc/nginx/ssl/nginx.crt ]; then
    echo "Generando certificado SSL auto-firmado para ozamora.42.fr..."

    # openssl req: utilidad para crear solicitudes de certificado y certificados auto-firmados
    # -x509: indica que queremos un certificado digital auto-firmado en lugar de una solicitud (CSR)
    # -nodes: "no DES", guarda la clave privada sin encriptar (sin contraseña) para que NGINX inicie automáticamente sin pedir contraseña al arrancar la VM
    # -days 365: validez del certificado (1 año)
    # -newkey rsa:2048: genera una nueva clave privada RSA de 2048 bits de longitud
    # -subj: rellena de forma no interactiva los metadatos obligatorios del certificado
    #        Country, State, Locality, Organization, Organizational Unit, Common Name
    #        NOTA: En el 'CN' (Common Name) quitamos el guion final del por restricciones de red DNS 
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/nginx.key \
        -out /etc/ssl/certs/nginx.crt \
        -subj "/C=ES/ST=Madrid/L=Madrid/O=42/OU=student/CN=ozamora.42.fr" # 

    # Aplicar permisos seguros de Linux a los archivos generados
    # 600: solo lectura y escritura para el root
    # 644: lectura para todos, escritura solo para root
    chmod 600 /etc/nginx/ssl/nginx.key
    chmod 644 /etc/ssl/certs/nginx.crt

    echo "¡SSL configurado correctamente!"
else
    echo "El certificado SSL ya existe en el volumen. Omitiendo generación."
fi

# Ejecutar NGINX en primer plano (PID 1) reemplazando el proceso actual de la terminal (exec)
# 'daemon off;' evita que NGINX se ejecute en segundo plano, impidiendo que el contenedor se detenga
echo "Iniciando NGINX..."
exec nginx -g "daemon off;"
