#!/bin/bash
set -e

echo "=== Instalando Nginx + Node.js en WEB ==="
apt-get update
apt-get install -y nginx curl

curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Crear app React 
mkdir -p /opt/erp-frontend
cd /opt/erp-frontend

cat > package.json <<'EOF'
{
  "name": "erp-frontend",
  "version": "1.0.0",
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1"
  },
  "scripts": { "build": "react-scripts build" },
  "browserslist": { "production": [">0.2%", "not dead"], "development": ["last 1 chrome version"] }
}
EOF

mkdir -p public src

cat > public/index.html <<'EOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><title>ERP</title></head>
<body><div id="root"></div></body></html>
EOF

cat > src/index.js <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
ReactDOM.createRoot(document.getElementById('root')).render(<App />);
EOF

cat > src/App.js <<'EOF'
import React, { useState, useEffect } from 'react';

const API = 'http://192.168.56.11:3000/api';

function App() {
  const [seccion, setSeccion] = useState('productos');
  const [productos, setProductos] = useState([]);
  const [clientes, setClientes] = useState([]);
  const [multimedia, setMultimedia] = useState([]);
  const [estado, setEstado] = useState('');

  useEffect(() => {
    fetch(`${API}/health`).then(r => r.json()).then(d => setEstado(d.status));
    fetch(`${API}/productos`).then(r => r.json()).then(setProductos);
    fetch(`${API}/clientes`).then(r => r.json()).then(setClientes);
    fetch(`${API}/multimedia`).then(r => r.json()).then(setMultimedia);
  }, []);

  return (
    <div style={{fontFamily:'Arial', padding:20}}>
      <h1>Sistema ERP</h1>
      <p>Estado API: <b>{estado}</b></p>
      <nav style={{marginBottom:20}}>
        <button onClick={()=>setSeccion('productos')}>Productos</button>
        <button onClick={()=>setSeccion('clientes')}>Clientes</button>
        <button onClick={()=>setSeccion('multimedia')}>Multimedia</button>
      </nav>
      {seccion==='productos' && (
        <div><h2>Productos</h2>
          <table border="1" cellPadding="8">
            <thead><tr><th>ID</th><th>Código</th><th>Nombre</th><th>Precio</th><th>Stock</th></tr></thead>
            <tbody>{productos.map(p=><tr key={p.id}><td>{p.id}</td><td>{p.codigo}</td><td>{p.nombre}</td><td>Q{p.precio}</td><td>{p.stock}</td></tr>)}</tbody>
          </table>
        </div>
      )}
      {seccion==='clientes' && (
        <div><h2>Clientes</h2>
          <table border="1" cellPadding="8">
            <thead><tr><th>ID</th><th>Nombre</th><th>Email</th><th>Teléfono</th></tr></thead>
            <tbody>{clientes.map(c=><tr key={c.id}><td>{c.id}</td><td>{c.nombre}</td><td>{c.email}</td><td>{c.telefono}</td></tr>)}</tbody>
          </table>
        </div>
      )}
      {seccion==='multimedia' && (
        <div><h2>Archivos Multimedia</h2>
          <table border="1" cellPadding="8">
            <thead><tr><th>ID</th><th>Nombre</th><th>Tipo</th><th>Ruta</th></tr></thead>
            <tbody>{multimedia.map(m=><tr key={m.id}><td>{m.id}</td><td>{m.nombre}</td><td>{m.tipo}</td><td>{m.ruta}</td></tr>)}</tbody>
          </table>
        </div>
      )}
    </div>
  );
}
export default App;
EOF

npm install
npm run build

# Configurar Nginx para servir el build de React
cat > /etc/nginx/sites-available/erp <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /opt/erp-frontend/build;
    index index.html;
    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/erp /etc/nginx/sites-enabled/erp
systemctl restart nginx

echo "=== Frontend ERP listo en 192.168.56.10:80 ==="