#!/bin/bash
set -e

echo "=== Instalando Node.js en ERP ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Crear estructura de la app
mkdir -p /opt/erp-api
cd /opt/erp-api

# package.json
cat > package.json <<'EOF'
{
  "name": "erp-api",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.0",
    "cors": "^2.8.5",
    "multer": "^1.4.5-lts.1"
  }
}
EOF

# server.js - API REST del ERP
cat > server.js <<'EOF'
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const multer = require('multer');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({
  host: '192.168.56.12',
  user: 'erp_user',
  password: 'erp_password123',
  database: 'erp_db',
  port: 5432,
});

// Health check
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'OK', db: 'conectada' });
  } catch (e) {
    res.status(500).json({ status: 'ERROR', error: e.message });
  }
});

// CRUD Productos
app.get('/api/productos', async (req, res) => {
  const r = await pool.query('SELECT * FROM productos ORDER BY id');
  res.json(r.rows);
});

app.post('/api/productos', async (req, res) => {
  const { codigo, nombre, precio, stock } = req.body;
  const r = await pool.query(
    'INSERT INTO productos (codigo, nombre, precio, stock) VALUES ($1,$2,$3,$4) RETURNING *',
    [codigo, nombre, precio, stock]
  );
  res.json(r.rows[0]);
});

// CRUD Clientes
app.get('/api/clientes', async (req, res) => {
  const r = await pool.query('SELECT * FROM clientes ORDER BY id');
  res.json(r.rows);
});

// CRUD Ventas
app.get('/api/ventas', async (req, res) => {
  const r = await pool.query(`
    SELECT v.*, c.nombre AS cliente 
    FROM ventas v 
    LEFT JOIN clientes c ON v.cliente_id = c.id 
    ORDER BY v.id DESC
  `);
  res.json(r.rows);
});

// Subida de archivos multimedia
const storage = multer.diskStorage({
  destination: '/opt/erp-api/uploads',
  filename: (req, file, cb) => cb(null, Date.now() + '-' + file.originalname)
});
const upload = multer({ storage });

app.post('/api/multimedia', upload.single('archivo'), async (req, res) => {
  const { nombre, tipo } = req.body;
  const ruta = `/uploads/${req.file.filename}`;
  const r = await pool.query(
    'INSERT INTO archivos_multimedia (nombre, tipo, ruta, tamano) VALUES ($1,$2,$3,$4) RETURNING *',
    [nombre || req.file.originalname, tipo || 'documento', ruta, req.file.size]
  );
  res.json(r.rows[0]);
});

app.get('/api/multimedia', async (req, res) => {
  const r = await pool.query('SELECT * FROM archivos_multimedia ORDER BY id DESC');
  res.json(r.rows);
});

app.listen(3000, '0.0.0.0', () => {
  console.log('ERP API corriendo en http://0.0.0.0:3000');
});
EOF

mkdir -p uploads
npm install

# Servicio systemd
cat > /etc/systemd/system/erp-api.service <<'EOF'
[Unit]
Description=ERP API Node.js
After=network.target

[Service]
WorkingDirectory=/opt/erp-api
ExecStart=/usr/bin/node server.js
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now erp-api

echo "=== ERP API lista en 192.168.56.11:3000 ==="