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

# server.js - API REST del ERP (Completa con PUT y DELETE)
cat > server.js <<'SERVER_EOF'
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
//app.use(cors());
app.use((req, res, next) => {
  // Permite peticiones desde el frontend (localhost:8080) y desde la IP del frontend
  res.header("Access-Control-Allow-Origin", "http://localhost:8080");
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  // Si la petición es un preflight (OPTIONS), responde OK inmediatamente
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});
app.use(express.json());

const pool = new Pool({
  host: '192.168.56.12',
  user: 'erp_user',
  password: 'erp_password123',
  database: 'erp_db',
  port: 5432,
});

// Asegurar carpeta de subidas
const uploadDir = '/opt/erp-api/uploads';
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

// Configuración de Multer para archivos
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => cb(null, Date.now() + '-' + file.originalname)
});
const upload = multer({ storage });

// ========== HEALTH CHECK ==========
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'OK', db: 'conectada' });
  } catch (e) {
    res.status(500).json({ status: 'ERROR', error: e.message });
  }
});

// ========== USUARIOS ==========
app.get('/api/usuarios', async (req, res) => {
  const r = await pool.query('SELECT id, nombre, email, rol FROM usuarios ORDER BY id');
  res.json(r.rows);
});

// ========== LOGIN ==========
app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const r = await pool.query('SELECT id, nombre, email, rol FROM usuarios WHERE email = $1 AND password_hash = $2', [email, password]);
    if (r.rows.length > 0) {
      res.json({ success: true, usuario: r.rows[0] });
    } else {
      res.status(401).json({ success: false, message: 'Credenciales incorrectas' });
    }
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ========== CREAR USUARIO ==========
app.post('/api/usuarios', async (req, res) => {
  const { nombre, email, password_hash, rol } = req.body;
  try {
    const r = await pool.query(
      'INSERT INTO usuarios (nombre, email, password_hash, rol) VALUES ($1,$2,$3,$4) RETURNING id, nombre, email, rol',
      [nombre, email, password_hash, rol || 'usuario']
    );
    res.json(r.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ========== ACTUALIZAR USUARIO ==========
app.put('/api/usuarios/:id', async (req, res) => {
  const { id } = req.params;
  const { nombre, email, password_hash, rol } = req.body;
  try {
    const r = await pool.query(
      'UPDATE usuarios SET nombre=$1, email=$2, password_hash=$3, rol=$4 WHERE id=$5 RETURNING id, nombre, email, rol',
      [nombre, email, password_hash, rol, id]
    );
    res.json(r.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ========== ELIMINAR USUARIO ==========
app.delete('/api/usuarios/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM usuarios WHERE id=$1', [req.params.id]);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});


// ========== PRODUCTOS ==========
app.get('/api/productos', async (req, res) => {
  const r = await pool.query(`
    SELECT p.*, pr.nombre as proveedor_nombre 
    FROM productos p 
    LEFT JOIN proveedores pr ON p.proveedor_id = pr.id 
    ORDER BY p.id
  `);
  res.json(r.rows);
});

app.post('/api/productos', async (req, res) => {
  const { codigo, nombre, precio, stock, proveedor_id } = req.body;
  const r = await pool.query(
    'INSERT INTO productos (codigo, nombre, precio, stock, proveedor_id) VALUES ($1,$2,$3,$4,$5) RETURNING *',
    [codigo, nombre, precio, stock, proveedor_id || null]
  );
  res.json(r.rows[0]);
});

// ACTUALIZAR PRODUCTO
app.put('/api/productos/:id', async (req, res) => {
  const { id } = req.params;
  const { codigo, nombre, precio, stock } = req.body;
  const r = await pool.query(
    'UPDATE productos SET codigo=$1, nombre=$2, precio=$3, stock=$4 WHERE id=$5 RETURNING *',
    [codigo, nombre, precio, stock, id]
  );
  res.json(r.rows[0]);
});

// ELIMINAR PRODUCTO
app.delete('/api/productos/:id', async (req, res) => {
  await pool.query('DELETE FROM productos WHERE id=$1', [req.params.id]);
  res.json({ success: true });
});

// ========== CLIENTES ==========
app.get('/api/clientes', async (req, res) => {
  const r = await pool.query('SELECT * FROM clientes ORDER BY id');
  res.json(r.rows);
});

app.post('/api/clientes', async (req, res) => {
  const { nombre, nit, email, telefono, direccion } = req.body;
  const r = await pool.query(
    'INSERT INTO clientes (nombre, nit, email, telefono, direccion) VALUES ($1,$2,$3,$4,$5) RETURNING *',
    [nombre, nit, email, telefono, direccion]
  );
  res.json(r.rows[0]);
});

// ACTUALIZAR CLIENTE
app.put('/api/clientes/:id', async (req, res) => {
  const { id } = req.params;
  const { nombre, nit, email, telefono, direccion } = req.body;
  const r = await pool.query(
    'UPDATE clientes SET nombre=$1, nit=$2, email=$3, telefono=$4, direccion=$5 WHERE id=$6 RETURNING *',
    [nombre, nit, email, telefono, direccion, id]
  );
  res.json(r.rows[0]);
});

// ELIMINAR CLIENTE
app.delete('/api/clientes/:id', async (req, res) => {
  await pool.query('DELETE FROM clientes WHERE id=$1', [req.params.id]);
  res.json({ success: true });
});

// ========== PROVEEDORES ==========
app.get('/api/proveedores', async (req, res) => {
  const r = await pool.query('SELECT * FROM proveedores ORDER BY id');
  res.json(r.rows);
});

app.post('/api/proveedores', async (req, res) => {
  const { nombre, contacto, email, telefono, direccion } = req.body;
  const r = await pool.query(
    'INSERT INTO proveedores (nombre, contacto, email, telefono, direccion) VALUES ($1,$2,$3,$4,$5) RETURNING *',
    [nombre, contacto, email, telefono, direccion]
  );
  res.json(r.rows[0]);
});

// ACTUALIZAR PROVEEDOR
app.put('/api/proveedores/:id', async (req, res) => {
  const { id } = req.params;
  const { nombre, contacto, email } = req.body;
  const r = await pool.query(
    'UPDATE proveedores SET nombre=$1, contacto=$2, email=$3 WHERE id=$4 RETURNING *',
    [nombre, contacto, email, id]
  );
  res.json(r.rows[0]);
});

// ELIMINAR PROVEEDOR
app.delete('/api/proveedores/:id', async (req, res) => {
  await pool.query('DELETE FROM proveedores WHERE id=$1', [req.params.id]);
  res.json({ success: true });
});

// ========== VENTAS (CON TRANSACCIÓN) ==========
app.get('/api/ventas', async (req, res) => {
  const r = await pool.query(`
    SELECT v.*, c.nombre AS cliente_nombre 
    FROM ventas v 
    LEFT JOIN clientes c ON v.cliente_id = c.id 
    ORDER BY v.id DESC
  `);
  res.json(r.rows);
});

app.post('/api/ventas', async (req, res) => {
  const { cliente_id, usuario_id, items } = req.body; 
  
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    let total = 0;
    items.forEach(item => total += (item.cantidad * item.precio_unitario));
    
    const ventaRes = await client.query(
      'INSERT INTO ventas (cliente_id, usuario_id, total) VALUES ($1,$2,$3) RETURNING id',
      [cliente_id, usuario_id, total]
    );
    const ventaId = ventaRes.rows[0].id;

    for (const item of items) {
      const subtotal = item.cantidad * item.precio_unitario;
      await client.query(
        'INSERT INTO ventas_detalle (venta_id, producto_id, cantidad, precio_unitario, subtotal) VALUES ($1,$2,$3,$4,$5)',
        [ventaId, item.producto_id, item.cantidad, item.precio_unitario, subtotal]
      );
      await client.query(
        'UPDATE productos SET stock = stock - $1 WHERE id = $2',
        [item.cantidad, item.producto_id]
      );
    }

    await client.query('COMMIT');
    res.json({ success: true, venta_id: ventaId, total });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: e.message });
  } finally {
    client.release();
  }
});

// ========== MULTIMEDIA (SUBIDA DE ARCHIVOS) ==========
app.get('/api/multimedia', async (req, res) => {
  const r = await pool.query('SELECT * FROM archivos_multimedia ORDER BY id DESC');
  res.json(r.rows);
});

app.post('/api/multimedia', upload.single('archivo'), async (req, res) => {
  try {
    const { nombre, tipo } = req.body;
    const ruta = `/uploads/${req.file.filename}`;
    const r = await pool.query(
      'INSERT INTO archivos_multimedia (nombre, tipo, ruta, tamano) VALUES ($1,$2,$3,$4) RETURNING *',
      [nombre || req.file.originalname, tipo || 'documento', ruta, req.file.size]
    );
    res.json(r.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ELIMINAR ARCHIVO MULTIMEDIA
app.delete('/api/multimedia/:id', async (req, res) => {
  try {
    const { id } = req.params;
    // Primero obtener la ruta del archivo para borrarlo del disco
    const result = await pool.query('SELECT ruta FROM archivos_multimedia WHERE id = $1', [id]);
    if (result.rows.length > 0) {
      const rutaArchivo = result.rows[0].ruta;
      const filePath = path.join(uploadDir, path.basename(rutaArchivo));
      // Borrar el archivo del disco si existe
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }
    // Borrar el registro de la base de datos
    await pool.query('DELETE FROM archivos_multimedia WHERE id = $1', [id]);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Servir archivos estáticos subidos
app.use('/uploads', express.static(uploadDir));

app.listen(3000, '0.0.0.0', () => {
  console.log('ERP API corriendo en http://0.0.0.0:3000');
});
SERVER_EOF

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