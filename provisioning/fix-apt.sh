#!/bin/bash
# Corrige el sources.list de la box ubuntu/jammy64
echo "=== Corrigiendo sources.list ==="

# Reemplazar por un sources.list limpio
cat > /etc/apt/sources.list <<'EOF'
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
EOF

# Limpiar archivos adicionales problemáticos
rm -f /etc/apt/sources.list.d/*.list

# Actualizar
apt-get update -y
echo "=== sources.list corregido ==="