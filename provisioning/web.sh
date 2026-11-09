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

# Componente Modal
cat > src/ModalEditar.js <<'MODAL_EOF'
import React from 'react';

const estilosModal = {
  overlay: { position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', justifyContent: 'center', alignItems: 'center' },
  content: { background: 'white', padding: '20px', borderRadius: '8px', width: '400px', maxWidth: '90%' },
  input: { width: '100%', padding: '8px', marginBottom: '10px', border: '1px solid #ccc', borderRadius: '4px', boxSizing: 'border-box' },
  btnGuardar: { padding: '8px 15px', background: '#27ae60', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' },
  btnCancelar: { padding: '8px 15px', background: '#95a5a6', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }
};

function ModalEditar({ tipo, datos, setDatos, onGuardar, onClose }) {
  if (!datos) return null;

  return (
    <div style={estilosModal.overlay}>
      <div style={estilosModal.content}>
        <h3>Editar {tipo}</h3>
        {Object.keys(datos).filter(k => k !== 'id' && k !== 'created_at' && k !== 'fecha').map(key => (
          <div key={key} style={{ marginBottom: '10px' }}>
            <label style={{ display: 'block', textTransform: 'capitalize' }}>{key}:</label>
            <input 
              style={estilosModal.input} 
              value={datos[key] || ''} 
              onChange={e => setDatos({ ...datos, [key]: e.target.value })} 
            />
          </div>
        ))}
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '20px' }}>
          <button style={estilosModal.btnCancelar} onClick={onClose}>Cancelar</button>
          <button style={estilosModal.btnGuardar} onClick={onGuardar}>Guardar Cambios</button>
        </div>
      </div>
    </div>
  );
}

export default ModalEditar;
MODAL_EOF

# Componente Login
cat > src/Login.js <<'LOGIN_EOF'
import React, { useState } from 'react';

const estilos = {
  container: { display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', background: '#f0f2f5' },
  form: { background: 'white', padding: '40px', borderRadius: '10px', boxShadow: '0 4px 12px rgba(0,0,0,0.1)', width: '350px' },
  input: { width: '100%', padding: '10px', marginBottom: '15px', border: '1px solid #ccc', borderRadius: '4px', boxSizing: 'border-box' },
  btn: { width: '100%', padding: '10px', background: '#3498db', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '16px' },
  error: { color: 'red', marginBottom: '10px', textAlign: 'center' }
};

function Login({ onLogin }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    try {
      const res = await fetch('http://192.168.56.11:3000/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      const data = await res.json();
      if (data.success) {
        onLogin(data.usuario);
      } else {
        setError(data.message || 'Error al iniciar sesión');
      }
    } catch (err) {
      setError('Error de conexión con el servidor');
    }
  };

  return (
    <div style={estilos.container}>
      <form style={estilos.form} onSubmit={handleSubmit}>
        <h2 style={{ textAlign: 'center', marginBottom: '20px' }}>🔐 Iniciar Sesión</h2>
        {error && <div style={estilos.error}>{error}</div>}
        
        <label>Correo Electrónico</label>
        <input style={estilos.input} type="email" value={email} onChange={e => setEmail(e.target.value)} required placeholder="admin@erp.local" />
        
        <label>Contraseña</label>
        <input style={estilos.input} type="password" value={password} onChange={e => setPassword(e.target.value)} required placeholder="admin123" />
        
        <button style={estilos.btn} type="submit">Ingresar</button>
      </form>
    </div>
  );
}

export default Login;
LOGIN_EOF

cat > src/App.js <<'APP_EOF'
import React, { useState, useEffect } from 'react';
import ModalEditar from './ModalEditar';
import Login from './Login';

const API = 'http://192.168.56.11:3000/api';

function App() {
  const [usuarioLogueado, setUsuarioLogueado] = useState(null);
  const [seccion, setSeccion] = useState('dashboard');
  const [estado, setEstado] = useState('');
  
  // Estados para listas
  const [productos, setProductos] = useState([]);
  const [clientes, setClientes] = useState([]);
  const [proveedores, setProveedores] = useState([]);
  const [ventas, setVentas] = useState([]);
  const [multimedia, setMultimedia] = useState([]);
  const [usuarios, setUsuarios] = useState([]);

  // Estados para edición
  const [editProd, setEditProd] = useState(null);
  const [editCli, setEditCli] = useState(null);
  const [editProv, setEditProv] = useState(null);
  const [editUsu, setEditUsu] = useState(null);

  // Cargar sesión guardada
  useEffect(() => {
    const saved = localStorage.getItem('erp_user');
    if (saved) setUsuarioLogueado(JSON.parse(saved));
  }, []);

  const handleLogin = (user) => {
    setUsuarioLogueado(user);
    localStorage.setItem('erp_user', JSON.stringify(user));
  };

  const handleLogout = () => {
    setUsuarioLogueado(null);
    localStorage.removeItem('erp_user');
  };

  const cargarDatos = async () => {
    if (!usuarioLogueado) return;
    try {
      const resHealth = await fetch(`${API}/health`);
      const dataHealth = await resHealth.json();
      setEstado(dataHealth.status);

      if (seccion === 'dashboard' || seccion === 'productos') { const res = await fetch(`${API}/productos`); if (res.ok) setProductos(await res.json()); }
      if (seccion === 'dashboard' || seccion === 'clientes') { const res = await fetch(`${API}/clientes`); if (res.ok) setClientes(await res.json()); }
      if (seccion === 'dashboard' || seccion === 'proveedores') { const res = await fetch(`${API}/proveedores`); if (res.ok) setProveedores(await res.json()); }
      if (seccion === 'dashboard' || seccion === 'ventas') { const res = await fetch(`${API}/ventas`); if (res.ok) setVentas(await res.json()); }
      if (seccion === 'dashboard' || seccion === 'multimedia') { const res = await fetch(`${API}/multimedia`); if (res.ok) setMultimedia(await res.json()); }
      if (seccion === 'dashboard' || seccion === 'usuarios') { const res = await fetch(`${API}/usuarios`); if (res.ok) setUsuarios(await res.json()); }
    } catch (err) { console.error('Error cargando datos:', err); }
  };

  useEffect(() => { cargarDatos(); }, [seccion, usuarioLogueado]);

  const estilos = {
    navBtn: { padding: '10px 20px', marginRight: '10px', cursor: 'pointer', border: 'none', borderRadius: '5px', background: '#eee' },
    navBtnActive: { background: '#3498db', color: 'white' },
    table: { width: '100%', borderCollapse: 'collapse', marginTop: '20px' },
    th: { background: '#2c3e50', color: 'white', padding: '10px', textAlign: 'left' },
    td: { padding: '10px', borderBottom: '1px solid #ddd' },
    input: { padding: '8px', marginRight: '10px', marginBottom: '10px', border: '1px solid #ccc', borderRadius: '4px' },
    btnGuardar: { padding: '8px 15px', background: '#27ae60', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' },
    btnEditar: { padding: '5px 10px', background: '#f39c12', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', marginRight: '5px' },
    btnEliminar: { padding: '5px 10px', background: '#e74c3c', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' },
    btnSalir: { padding: '8px 15px', background: '#c0392b', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', float: 'right' }
  };

  const eliminarItem = async (ruta, id) => {
    if (window.confirm('¿Estás seguro de eliminar este registro?')) {
      await fetch(`${API}/${ruta}/${id}`, { method: 'DELETE' });
      cargarDatos();
    }
  };

  const guardarEdicion = async (ruta, datos, setDatos) => {
    await fetch(`${API}/${ruta}/${datos.id}`, { method: 'PUT', headers: {'Content-Type':'application/json'}, body: JSON.stringify(datos) });
    setDatos(null);
    cargarDatos();
  };

  // ========== FORMULARIOS ==========
  const FormProducto = () => {
    const [form, setForm] = useState({ codigo: '', nombre: '', precio: 0, stock: 0 });
    const guardar = async (e) => {
      e.preventDefault();
      await fetch(`${API}/productos`, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(form) });
      setForm({ codigo: '', nombre: '', precio: 0, stock: 0 });
      cargarDatos();
    };
    return (
      <form onSubmit={guardar} style={{ marginBottom: '20px', background: '#f9f9f9', padding: '15px' }}>
        <h3>Nuevo Producto</h3>
        <input style={estilos.input} placeholder="Código" value={form.codigo} onChange={e=>setForm({...form, codigo: e.target.value})} required />
        <input style={estilos.input} placeholder="Nombre" value={form.nombre} onChange={e=>setForm({...form, nombre: e.target.value})} required />
        <input style={estilos.input} type="number" placeholder="Precio" value={form.precio} onChange={e=>setForm({...form, precio: e.target.value})} required />
        <input style={estilos.input} type="number" placeholder="Stock" value={form.stock} onChange={e=>setForm({...form, stock: e.target.value})} required />
        <button style={estilos.btnGuardar} type="submit">Guardar Producto</button>
      </form>
    );
  };

  const FormCliente = () => {
    const [form, setForm] = useState({ nombre: '', nit: '', email: '', telefono: '' });
    const guardar = async (e) => {
      e.preventDefault();
      await fetch(`${API}/clientes`, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(form) });
      setForm({ nombre: '', nit: '', email: '', telefono: '' });
      cargarDatos();
    };
    return (
      <form onSubmit={guardar} style={{ marginBottom: '20px', background: '#f9f9f9', padding: '15px' }}>
        <h3>Nuevo Cliente</h3>
        <input style={estilos.input} placeholder="Nombre" value={form.nombre} onChange={e=>setForm({...form, nombre: e.target.value})} required />
        <input style={estilos.input} placeholder="NIT" value={form.nit} onChange={e=>setForm({...form, nit: e.target.value})} />
        <input style={estilos.input} placeholder="Email" value={form.email} onChange={e=>setForm({...form, email: e.target.value})} />
        <input style={estilos.input} placeholder="Teléfono" value={form.telefono} onChange={e=>setForm({...form, telefono: e.target.value})} />
        <button style={estilos.btnGuardar} type="submit">Guardar Cliente</button>
      </form>
    );
  };

  const FormProveedor = () => {
    const [form, setForm] = useState({ nombre: '', contacto: '', email: '' });
    const guardar = async (e) => {
      e.preventDefault();
      await fetch(`${API}/proveedores`, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(form) });
      setForm({ nombre: '', contacto: '', email: '' });
      cargarDatos();
    };
    return (
      <form onSubmit={guardar} style={{ marginBottom: '20px', background: '#f9f9f9', padding: '15px' }}>
        <h3>Nuevo Proveedor</h3>
        <input style={estilos.input} placeholder="Nombre Empresa" value={form.nombre} onChange={e=>setForm({...form, nombre: e.target.value})} required />
        <input style={estilos.input} placeholder="Contacto" value={form.contacto} onChange={e=>setForm({...form, contacto: e.target.value})} />
        <input style={estilos.input} placeholder="Email" value={form.email} onChange={e=>setForm({...form, email: e.target.value})} />
        <button style={estilos.btnGuardar} type="submit">Guardar Proveedor</button>
      </form>
    );
  };

  const FormVenta = () => {
    const [clienteId, setClienteId] = useState('');
    const [productoId, setProductoId] = useState('');
    const [cantidad, setCantidad] = useState(1);
    const [carrito, setCarrito] = useState([]);

    const agregarItem = () => {
      if (!productoId || cantidad <= 0) return;
      const prod = productos.find(p => p.id === parseInt(productoId));
      if (!prod) return;

      const existe = carrito.find(item => item.producto_id === prod.id);
      if (existe) {
        setCarrito(carrito.map(item => 
          item.producto_id === prod.id ? { ...item, cantidad: item.cantidad + parseInt(cantidad) } : item
        ));
      } else {
        setCarrito([...carrito, { 
          producto_id: prod.id, 
          nombre: prod.nombre, 
          precio_unitario: prod.precio, 
          cantidad: parseInt(cantidad) 
        }]);
      }
      setProductoId('');
      setCantidad(1);
    };

    const guardarVenta = async (e) => {
      e.preventDefault();
      if (!clienteId || carrito.length === 0) { alert("Selecciona un cliente y al menos un producto"); return; }
      await fetch(`${API}/ventas`, {
        method: 'POST',
        headers: {'Content-Type':'application/json'},
        body: JSON.stringify({ cliente_id: clienteId, usuario_id: 1, items: carrito })
      });
      setClienteId(''); setCarrito([]);
      cargarDatos();
      alert("Venta registrada con éxito");
    };

    const total = carrito.reduce((acc, item) => acc + (item.cantidad * item.precio_unitario), 0);

    return (
      <form onSubmit={guardarVenta} style={{ marginBottom: '20px', background: '#f9f9f9', padding: '15px' }}>
        <h3>Registrar Nueva Venta</h3>
        
        <div style={{ marginBottom: '10px' }}>
          <label>Cliente: </label>
          <select style={estilos.input} value={clienteId} onChange={e=>setClienteId(e.target.value)} required>
            <option value="">-- Seleccionar Cliente --</option>
            {clientes.map(c => <option key={c.id} value={c.id}>{c.nombre}</option>)}
          </select>
        </div>

        <div style={{ marginBottom: '10px', border: '1px solid #ccc', padding: '10px', background: '#fff' }}>
          <label>Agregar Productos:</label><br/>
          <select style={estilos.input} value={productoId} onChange={e=>setProductoId(e.target.value)}>
            <option value="">-- Seleccionar Producto --</option>
            {productos.map(p => <option key={p.id} value={p.id}>{p.nombre} - Q{p.precio} (Stock: {p.stock})</option>)}
          </select>
          <input style={{...estilos.input, width: '80px'}} type="number" min="1" value={cantidad} onChange={e=>setCantidad(e.target.value)} />
          <button type="button" style={{...estilos.btnGuardar, background: '#3498db'}} onClick={agregarItem}>+ Agregar al carrito</button>
        </div>

        {carrito.length > 0 && (
          <table style={estilos.table}>
            <thead><tr><th style={estilos.th}>Producto</th><th style={estilos.th}>Cantidad</th><th style={estilos.th}>Precio</th><th style={estilos.th}>Subtotal</th></tr></thead>
            <tbody>
              {carrito.map((item, idx) => (
                <tr key={idx}>
                  <td style={estilos.td}>{item.nombre}</td>
                  <td style={estilos.td}>{item.cantidad}</td>
                  <td style={estilos.td}>Q{item.precio_unitario}</td>
                  <td style={estilos.td}>Q{item.cantidad * item.precio_unitario}</td>
                </tr>
              ))}
              <tr>
                <td colSpan="3" style={{...estilos.td, textAlign: 'right', fontWeight: 'bold'}}>Total:</td>
                <td style={{...estilos.td, fontWeight: 'bold'}}>Q{total}</td>
              </tr>
            </tbody>
          </table>
        )}

        <button style={{...estilos.btnGuardar, marginTop: '15px'}} type="submit">Registrar Venta</button>
      </form>
    );
  };

  const FormMultimedia = () => {
    const [file, setFile] = useState(null);
    const [tipo, setTipo] = useState('documento');
    const subir = async (e) => {
      e.preventDefault();
      if(!file) return;
      const fd = new FormData();
      fd.append('archivo', file);
      fd.append('tipo', tipo);
      await fetch(`${API}/multimedia`, { method: 'POST', body: fd });
      setFile(null);
      cargarDatos();
    };
    return (
      <form onSubmit={subir} style={{ marginBottom: '20px', background: '#f9f9f9', padding: '15px' }}>
        <h3>Subir Archivo Multimedia</h3>
        <input style={estilos.input} type="file" onChange={e=>setFile(e.target.files[0])} required />
        <select style={estilos.input} value={tipo} onChange={e=>setTipo(e.target.value)}>
          <option value="documento">Documento</option>
          <option value="musica">Música</option>
          <option value="imagen">Imagen</option>
        </select>
        <button style={estilos.btnGuardar} type="submit">Subir Archivo</button>
      </form>
    );
  };

  const FormUsuario = () => {
    const [form, setForm] = useState({ nombre: '', email: '', password_hash: '', rol: 'usuario' });
    const guardar = async (e) => {
      e.preventDefault();
      await fetch(`${API}/usuarios`, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(form) });
      setForm({ nombre: '', email: '', password_hash: '', rol: 'usuario' });
      cargarDatos();
    };
    return (
      <form onSubmit={guardar} style={{ marginBottom: '20px', background: '#f9f9f9', padding: '15px' }}>
        <h3>Nuevo Usuario</h3>
        <input style={estilos.input} placeholder="Nombre" value={form.nombre} onChange={e=>setForm({...form, nombre: e.target.value})} required />
        <input style={estilos.input} placeholder="Email" value={form.email} onChange={e=>setForm({...form, email: e.target.value})} required />
        <input style={estilos.input} type="password" placeholder="Contraseña" value={form.password_hash} onChange={e=>setForm({...form, password_hash: e.target.value})} required />
        <select style={estilos.input} value={form.rol} onChange={e=>setForm({...form, rol: e.target.value})}>
          <option value="usuario">Usuario</option>
          <option value="admin">Administrador</option>
        </select>
        <button style={estilos.btnGuardar} type="submit">Guardar Usuario</button>
      </form>
    );
  };

  // Si no hay usuario logueado, mostrar Login
  if (!usuarioLogueado) {
    return <Login onLogin={handleLogin} />;
  }

  return (
    <div style={{ fontFamily: 'Arial', padding: 20, maxWidth: '1200px', margin: '0 auto' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h1>🏢 Sistema ERP</h1>
        <div>
          <span style={{ marginRight: '15px' }}>👤 {usuarioLogueado.nombre}</span>
          <button style={estilos.btnSalir} onClick={handleLogout}>Cerrar Sesión</button>
        </div>
      </div>
      <p>Estado de la API: <b style={{color: estado === 'OK' ? 'green' : 'red'}}>{estado || 'Cargando...'}</b></p>
      
      <nav style={{ marginBottom: 20, paddingBottom: '20px', borderBottom: '1px solid #ccc' }}>
        {['dashboard', 'productos', 'clientes', 'proveedores', 'ventas', 'multimedia', 'usuarios'].map(sec => (
          <button key={sec} onClick={() => setSeccion(sec)} style={{...estilos.navBtn, ...(seccion === sec ? estilos.navBtnActive : {})}}>
            {sec.charAt(0).toUpperCase() + sec.slice(1)}
          </button>
        ))}
      </nav>

      {seccion === 'dashboard' && (
        <div>
          <h2>Resumen General</h2>
          <div style={{display: 'flex', gap: '20px', marginTop: '20px'}}>
            <div style={{background: '#3498db', color:'white', padding: '20px', borderRadius: '8px', flex: 1}}>
              <h3>Productos</h3><h1>{productos.length}</h1>
            </div>
            <div style={{background: '#2ecc71', color:'white', padding: '20px', borderRadius: '8px', flex: 1}}>
              <h3>Clientes</h3><h1>{clientes.length}</h1>
            </div>
            <div style={{background: '#e67e22', color:'white', padding: '20px', borderRadius: '8px', flex: 1}}>
              <h3>Ventas</h3><h1>{ventas.length}</h1>
            </div>
          </div>
        </div>
      )}

      {seccion === 'productos' && (
        <div>
          <FormProducto />
          <table style={estilos.table}>
            <thead><tr><th style={estilos.th}>ID</th><th style={estilos.th}>Código</th><th style={estilos.th}>Nombre</th><th style={estilos.th}>Precio</th><th style={estilos.th}>Stock</th><th style={estilos.th}>Acciones</th></tr></thead>
            <tbody>{productos.map(p=>
              <tr key={p.id}>
                <td style={estilos.td}>{p.id}</td>
                <td style={estilos.td}>{p.codigo}</td>
                <td style={estilos.td}>{p.nombre}</td>
                <td style={estilos.td}>Q{p.precio}</td>
                <td style={estilos.td}>{p.stock}</td>
                <td style={estilos.td}>
                  <button style={estilos.btnEditar} onClick={()=>setEditProd(p)}>Editar</button>
                  <button style={estilos.btnEliminar} onClick={()=>eliminarItem('productos', p.id)}>Eliminar</button>
                </td>
              </tr>
            )}</tbody>
          </table>
        </div>
      )}

      {seccion === 'clientes' && (
        <div>
          <FormCliente />
          <table style={estilos.table}>
            <thead><tr><th style={estilos.th}>ID</th><th style={estilos.th}>Nombre</th><th style={estilos.th}>Email</th><th style={estilos.th}>Teléfono</th><th style={estilos.th}>Acciones</th></tr></thead>
            <tbody>{clientes.map(c=>
              <tr key={c.id}>
                <td style={estilos.td}>{c.id}</td>
                <td style={estilos.td}>{c.nombre}</td>
                <td style={estilos.td}>{c.email}</td>
                <td style={estilos.td}>{c.telefono}</td>
                <td style={estilos.td}>
                  <button style={estilos.btnEditar} onClick={()=>setEditCli(c)}>Editar</button>
                  <button style={estilos.btnEliminar} onClick={()=>eliminarItem('clientes', c.id)}>Eliminar</button>
                </td>
              </tr>
            )}</tbody>
          </table>
        </div>
      )}

      {seccion === 'proveedores' && (
        <div>
          <FormProveedor />
          <table style={estilos.table}>
            <thead><tr><th style={estilos.th}>ID</th><th style={estilos.th}>Nombre</th><th style={estilos.th}>Contacto</th><th style={estilos.th}>Email</th><th style={estilos.th}>Acciones</th></tr></thead>
            <tbody>{proveedores.map(p=>
              <tr key={p.id}>
                <td style={estilos.td}>{p.id}</td>
                <td style={estilos.td}>{p.nombre}</td>
                <td style={estilos.td}>{p.contacto}</td>
                <td style={estilos.td}>{p.email}</td>
                <td style={estilos.td}>
                  <button style={estilos.btnEditar} onClick={()=>setEditProv(p)}>Editar</button>
                  <button style={estilos.btnEliminar} onClick={()=>eliminarItem('proveedores', p.id)}>Eliminar</button>
                </td>
              </tr>
            )}</tbody>
          </table>
        </div>
      )}

      {seccion === 'ventas' && (
        <div>
          <FormVenta />
          <h3>Historial de Ventas</h3>
          <table style={estilos.table}>
            <thead><tr><th style={estilos.th}>ID</th><th style={estilos.th}>Cliente</th><th style={estilos.th}>Fecha</th><th style={estilos.th}>Total</th><th style={estilos.th}>Estado</th></tr></thead>
            <tbody>{ventas.map(v=><tr key={v.id}><td style={estilos.td}>{v.id}</td><td style={estilos.td}>{v.cliente_nombre}</td><td style={estilos.td}>{new Date(v.fecha).toLocaleDateString()}</td><td style={estilos.td}>Q{v.total}</td><td style={estilos.td}>{v.estado}</td></tr>)}</tbody>
          </table>
        </div>
      )}

      {seccion === 'multimedia' && (
        <div>
          <FormMultimedia />
          <table style={estilos.table}>
            <thead><tr><th style={estilos.th}>ID</th><th style={estilos.th}>Nombre</th><th style={estilos.th}>Tipo</th><th style={estilos.th}>Acciones</th></tr></thead>
            <tbody>{multimedia.map(m=>(
              <tr key={m.id}>
                <td style={estilos.td}>{m.id}</td>
                <td style={estilos.td}>{m.nombre}</td>
                <td style={estilos.td}>{m.tipo}</td>
                <td style={estilos.td}>
                  <a href={`http://192.168.56.11:3000${m.ruta}`} target="_blank" rel="noreferrer" download style={{...estilos.btnEditar, textDecoration: 'none', display: 'inline-block', marginRight: '5px'}}>Descargar</a>
                  <button style={estilos.btnEliminar} onClick={()=>eliminarItem('multimedia', m.id)}>Eliminar</button>
                </td>
              </tr>
            ))}</tbody>
          </table>
        </div>
      )}

      {seccion === 'usuarios' && (
        <div>
          <FormUsuario />
          <table style={estilos.table}>
            <thead><tr><th style={estilos.th}>ID</th><th style={estilos.th}>Nombre</th><th style={estilos.th}>Email</th><th style={estilos.th}>Rol</th><th style={estilos.th}>Acciones</th></tr></thead>
            <tbody>{usuarios.map(u=>
              <tr key={u.id}>
                <td style={estilos.td}>{u.id}</td>
                <td style={estilos.td}>{u.nombre}</td>
                <td style={estilos.td}>{u.email}</td>
                <td style={estilos.td}>{u.rol}</td>
                <td style={estilos.td}>
                  <button style={estilos.btnEditar} onClick={()=>setEditUsu(u)}>Editar</button>
                  <button style={estilos.btnEliminar} onClick={()=>eliminarItem('usuarios', u.id)}>Eliminar</button>
                </td>
              </tr>
            )}</tbody>
          </table>
        </div>
      )}

      {/* MODALES DE EDICIÓN */}
      <ModalEditar tipo="Producto" datos={editProd} setDatos={setEditProd} onGuardar={() => guardarEdicion('productos', editProd, setEditProd)} onClose={() => setEditProd(null)} />
      <ModalEditar tipo="Cliente" datos={editCli} setDatos={setEditCli} onGuardar={() => guardarEdicion('clientes', editCli, setEditCli)} onClose={() => setEditCli(null)} />
      <ModalEditar tipo="Proveedor" datos={editProv} setDatos={setEditProv} onGuardar={() => guardarEdicion('proveedores', editProv, setEditProv)} onClose={() => setEditProv(null)} />
      <ModalEditar tipo="Usuario" datos={editUsu} setDatos={setEditUsu} onGuardar={() => guardarEdicion('usuarios', editUsu, setEditUsu)} onClose={() => setEditUsu(null)} />
    </div>
  );
}

export default App;
APP_EOF

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
systemctl restart n