#!/bin/bash
set -e

echo "=== Instalando Nginx en FILES ==="
apt-get update
apt-get install -y nginx

# Carpeta de archivos multimedia
mkdir -p /srv/files/{musica,documentos,imagenes}
chmod -R 755 /srv/files

# Configurar Nginx para listar y servir los archivos
cat > /etc/nginx/sites-available/files <<'EOF'
server {
    listen 8081 default_server;
    server_name _;
    
    location /musica/ {
        alias /srv/files/musica/;
        autoindex on;
    }
    location /documentos/ {
        alias /srv/files/documentos/;
        autoindex on;
    }
    location /imagenes/ {
        alias /srv/files/imagenes/;
        autoindex on;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/files /etc/nginx/sites-enabled/files
systemctl restart nginx

echo "=== Servidor de Archivos listo en 192.168.56.13:8081 ==="