#!/bin/bash
set -e

echo "=== Instalando PostgreSQL en DB ==="
apt-get update
apt-get install -y postgresql postgresql-contrib

# Permitir conexiones remotas
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/14/main/postgresql.conf
echo "host    all             all             192.168.56.0/24        md5" >> /etc/postgresql/14/main/pg_hba.conf

systemctl restart postgresql

# Crear usuario y base de datos
sudo -u postgres psql <<EOF
CREATE USER erp_user WITH PASSWORD 'erp_password123';
CREATE DATABASE erp_db OWNER erp_user;
GRANT ALL PRIVILEGES ON DATABASE erp_db TO erp_user;
EOF

# Copiar el script SQL de inicialización
cp /vagrant/db/init.sql /tmp/init.sql
#sudo -u postgres psql -d erp_db -f /tmp/init.sql
PGPASSWORD=erp_password123 psql -h 127.0.0.1 -U erp_user -d erp_db -f /tmp/init.sql

echo "=== PostgreSQL listo en 192.168.56.12:5432 ==="