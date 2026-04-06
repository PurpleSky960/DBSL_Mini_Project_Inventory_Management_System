import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';

function AdminDashboard() {
  const navigate = useNavigate();
  const username = localStorage.getItem('username');
  const userId = localStorage.getItem('userId');

  const [activeTab, setActiveTab] = useState('alerts');
  const [alerts, setAlerts] = useState([]);
  const [products, setProducts] = useState([]);
  const [suppliers, setSuppliers] = useState([]);
  const [users, setUsers] = useState([]);
  const [auditLogs, setAuditLogs] = useState([]);
  const [categories, setCategories] = useState([]); // NEW STATE
  const [message, setMessage] = useState({ text: '', type: '' });

  // Form States
  const [restockProduct, setRestockProduct] = useState('');
  const [restockQty, setRestockQty] = useState('');
  const [deactivateCatId, setDeactivateCatId] = useState('');

  // Setup Form States
  const [catName, setCatName] = useState('');
  const [catDesc, setCatDesc] = useState('');
  const [supName, setSupName] = useState('');
  const [supContact, setSupContact] = useState('');
  const [supEmail, setSupEmail] = useState('');
  const [supAddress, setSupAddress] = useState('');
  const [prodName, setProdName] = useState('');
  const [prodCat, setProdCat] = useState('');
  const [prodSup, setProdSup] = useState('');
  const [prodPrice, setProdPrice] = useState('');
  const [prodStock, setProdStock] = useState('');
  const [prodRestock, setProdRestock] = useState('');

  // User Form States
  const [newUsername, setNewUsername] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newEmail, setNewEmail] = useState('');
  const [newRole, setNewRole] = useState('STAFF');

  const fetchData = useCallback(async () => {
    try {
      const [alertRes, prodRes, supRes, userRes, auditRes, catRes] = await Promise.all([
        axios.get('http://localhost:8080/api/inventory/alerts'),
        axios.get('http://localhost:8080/api/inventory/products'),
        axios.get('http://localhost:8080/api/inventory/suppliers'),
        axios.get('http://localhost:8080/api/inventory/admin/users'),
        axios.get('http://localhost:8080/api/inventory/admin/audit'),
        axios.get('http://localhost:8080/api/inventory/categories') // NEW ENDPOINT
      ]);
      setAlerts(alertRes.data);
      setProducts(prodRes.data);
      setSuppliers(supRes.data);
      setUsers(userRes.data);
      setAuditLogs(auditRes.data);
      setCategories(catRes.data); // SET CATEGORIES
    } catch (err) {
      console.error("Error fetching data", err);
    }
  }, []);

  useEffect(() => {
    const role = localStorage.getItem('role');
    if (!role || (role !== 'ADMIN' && role !== 'MANAGER')) {
      navigate('/login');
    } else {
      fetchData();
    }
  }, [navigate, fetchData]);

  // NEW CLEAN CATEGORY LOGIC
  const activeCategories = categories.filter(c => c.IS_ACTIVE === 1);
  const inactiveCategories = categories.filter(c => c.IS_ACTIVE === 0);

  // --- HANDLERS ---
  const handleRestock = async (e) => {
    e.preventDefault();
    try {
      await axios.post('http://localhost:8080/api/inventory/restock', { userId, productId: restockProduct, quantity: restockQty });
      setMessage({ text: 'Stock added successfully!', type: 'success' });
      setRestockQty(''); fetchData(); 
    } catch (err) { setMessage({ text: err.response?.data?.error || 'Restock failed', type: 'error' }); }
  };

  const handleDeactivateCategory = async (e) => {
    e.preventDefault();
    try {
      await axios.put(`http://localhost:8080/api/inventory/admin/category/${deactivateCatId}/deactivate`);
      setMessage({ text: 'Category deactivated successfully!', type: 'success' });
      setDeactivateCatId(''); fetchData(); 
    } catch (err) { setMessage({ text: err.response?.data?.error || 'Failed to deactivate', type: 'error' }); }
  };

  const handleReactivate = async (categoryId) => {
    try { await axios.put(`http://localhost:8080/api/inventory/admin/category/${categoryId}/reactivate`); fetchData(); } 
    catch (err) { console.error(err); }
  };

  const handleAddCategory = async (e) => {
    e.preventDefault();
    try {
      await axios.post('http://localhost:8080/api/inventory/admin/add-category', { name: catName, description: catDesc });
      setMessage({ text: 'Category Added!', type: 'success' });
      setCatName(''); setCatDesc(''); fetchData();
    } catch (err) { setMessage({ text: err.response?.data?.error || 'Failed to add category', type: 'error' }); }
  };

  const handleAddSupplier = async (e) => {
    e.preventDefault();
    try {
      await axios.post('http://localhost:8080/api/inventory/admin/add-supplier', { name: supName, contact: supContact, email: supEmail, address: supAddress });
      setMessage({ text: 'Supplier Added!', type: 'success' });
      setSupName(''); setSupContact(''); setSupEmail(''); setSupAddress(''); fetchData();
    } catch (err) { setMessage({ text: err.response?.data?.error || 'Failed to add supplier', type: 'error' }); }
  };

  const handleAddProduct = async (e) => {
    e.preventDefault();
    try {
      await axios.post('http://localhost:8080/api/inventory/admin/add-product', { 
        name: prodName, categoryId: prodCat, supplierId: prodSup, price: prodPrice, initStock: prodStock, restockLvl: prodRestock 
      });
      setMessage({ text: 'Product Added!', type: 'success' });
      setProdName(''); setProdCat(''); setProdSup(''); setProdPrice(''); setProdStock(''); setProdRestock(''); fetchData();
    } catch (err) { setMessage({ text: err.response?.data?.error || 'Failed to add product', type: 'error' }); }
  };

  const handleAddUser = async (e) => {
    e.preventDefault();
    try {
      await axios.post('http://localhost:8080/api/inventory/admin/add-user', { username: newUsername, password: newPassword, email: newEmail, role: newRole });
      setMessage({ text: 'User Created!', type: 'success' });
      setNewUsername(''); setNewPassword(''); setNewEmail(''); setNewRole('STAFF'); fetchData();
    } catch (err) { setMessage({ text: err.response?.data?.error || 'Failed to create user', type: 'error' }); }
  };

  const handleToggleUser = async (toggleId, currentStatus) => {
    try {
      const newStatus = currentStatus === 1 ? 0 : 1;
      await axios.put(`http://localhost:8080/api/inventory/admin/user/${toggleId}/status/${newStatus}`);
      fetchData();
    } catch (err) { console.error(err); }
  };

  const handleLogout = () => { localStorage.clear(); navigate('/login'); };

  const sidebarBtnStyle = (tabName) => ({
    width: '100%', padding: '15px', textAlign: 'left', background: activeTab === tabName ? '#34495E' : 'transparent',
    color: 'white', border: 'none', borderLeft: activeTab === tabName ? '5px solid #3498DB' : '5px solid transparent',
    cursor: 'pointer', fontSize: '16px', fontWeight: activeTab === tabName ? 'bold' : 'normal'
  });

  return (
    <div style={{ display: 'flex', minHeight: '100vh', fontFamily: 'sans-serif', backgroundColor: '#ECF0F1' }}>
      
      {/* SIDEBAR */}
      <div style={{ width: '250px', backgroundColor: '#2C3E50', color: 'white', display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '20px', borderBottom: '1px solid #34495E' }}>
          <h2 style={{ margin: 0, color: '#3498DB' }}>IMS Admin</h2>
          <p style={{ margin: '5px 0 0 0', fontSize: '14px', color: '#BDC3C7' }}>Logged in as: {username}</p>
        </div>
        <div style={{ flex: 1, paddingTop: '10px' }}>
          <button style={sidebarBtnStyle('alerts')} onClick={() => {setActiveTab('alerts'); setMessage({text:'', type:''})}}>Live Alerts</button>
          <button style={sidebarBtnStyle('products')} onClick={() => {setActiveTab('products'); setMessage({text:'', type:''})}}>Product Catalog</button>
          <button style={sidebarBtnStyle('categories')} onClick={() => {setActiveTab('categories'); setMessage({text:'', type:''})}}>Manage Categories</button>
          <button style={sidebarBtnStyle('restock')} onClick={() => {setActiveTab('restock'); setMessage({text:'', type:''})}}>Manual Restock</button>
          <button style={sidebarBtnStyle('setup')} onClick={() => {setActiveTab('setup'); setMessage({text:'', type:''})}}>System Setup</button>
          <button style={sidebarBtnStyle('users')} onClick={() => {setActiveTab('users'); setMessage({text:'', type:''})}}>User Mgmt</button>
          <button style={sidebarBtnStyle('audit')} onClick={() => {setActiveTab('audit'); setMessage({text:'', type:''})}}>Audit Logs</button>
        </div>
        <div style={{ padding: '20px' }}>
          <button onClick={() => navigate('/change-password')} style={{ width: '100%', padding: '10px', backgroundColor: '#F39C12', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold', marginBottom: '10px' }}>CHANGE PASS</button>
          <button onClick={handleLogout} style={{ width: '100%', padding: '10px', backgroundColor: '#E74C3C', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold' }}>LOGOUT</button>
        </div>
      </div>

      {/* DYNAMIC CONTENT */}
      <div style={{ flex: 1, padding: '40px', overflowY: 'auto' }}>
        
        {message.text && (
          <div style={{ padding: '10px', marginBottom: '20px', borderRadius: '4px', backgroundColor: message.type === 'success' ? '#D4EFDF' : '#F2D7D5', color: message.type === 'success' ? '#27AE60' : '#C0392B' }}>
            {message.text}
          </div>
        )}

        {/* ALERTS */}
        {activeTab === 'alerts' && (
          <div>
            <h1 style={{ color: '#2C3E50', marginTop: 0 }}>Restock Alerts</h1>
            <table style={{ width: '100%', backgroundColor: 'white', borderCollapse: 'collapse', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
              <thead><tr style={{ backgroundColor: '#E74C3C', color: 'white', textAlign: 'left' }}><th style={{ padding: '15px' }}>Product</th><th style={{ padding: '15px' }}>Category</th><th style={{ padding: '15px' }}>Stock</th><th style={{ padding: '15px' }}>Shortage</th><th style={{ padding: '15px' }}>Supplier</th></tr></thead>
              <tbody>
                {alerts.length === 0 ? (<tr><td colSpan="5" style={{ padding: '20px', textAlign: 'center' }}>All stock levels are healthy!</td></tr>) : 
                (alerts.map((a, i) => (
                  <tr key={i} style={{ borderBottom: '1px solid #ECF0F1' }}>
                    <td style={{ padding: '15px', fontWeight: 'bold' }}>{a.PRODUCT}</td><td style={{ padding: '15px' }}>{a.CATEGORY}</td><td style={{ padding: '15px', color: '#E74C3C', fontWeight: 'bold' }}>{a.CURRENT_STOCK}</td><td style={{ padding: '15px' }}>{a.UNITS_NEEDED} needed</td><td style={{ padding: '15px' }}>{a.SUPPLIER} ({a.SUPPLIER_CONTACT})</td>
                  </tr>
                )))}
              </tbody>
            </table>
          </div>
        )}

        {/* PRODUCTS */}
        {activeTab === 'products' && (
          <div>
            <h1 style={{ color: '#2C3E50', marginTop: 0 }}>Product Catalog</h1>
            <table style={{ width: '100%', backgroundColor: 'white', borderCollapse: 'collapse', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
              <thead><tr style={{ backgroundColor: '#2980B9', color: 'white', textAlign: 'left' }}><th style={{ padding: '15px' }}>ID</th><th style={{ padding: '15px' }}>Product</th><th style={{ padding: '15px' }}>Category</th><th style={{ padding: '15px' }}>Price</th><th style={{ padding: '15px' }}>Stock</th></tr></thead>
              <tbody>
                {products.map((p, i) => (
                  <tr key={i} style={{ borderBottom: '1px solid #ECF0F1', backgroundColor: p.CAT_ACTIVE === 0 ? '#F9E7E7' : 'white' }}>
                    <td style={{ padding: '15px' }}>{p.PRODUCTID}</td>
                    <td style={{ padding: '15px' }}>{p.PRODUCT} {p.CAT_ACTIVE === 0 && <span style={{color: 'red', fontSize:'12px', marginLeft: '5px'}}>(Inactive)</span>}</td>
                    <td style={{ padding: '15px' }}>{p.CATEGORY}</td><td style={{ padding: '15px' }}>Rs. {p.UNIT_PRICE}</td><td style={{ padding: '15px' }}>{p.STOCK_QTY}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* CATEGORIES */}
        {activeTab === 'categories' && (
          <div>
            <h1 style={{ color: '#2C3E50', marginTop: 0 }}>Manage Categories</h1>
            <div style={{ display: 'flex', gap: '30px', alignItems: 'flex-start' }}>
              <div style={{ flex: 1, backgroundColor: 'white', padding: '30px', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
                <h3 style={{ marginTop: 0, color: '#E74C3C' }}>Deactivate Category</h3>
                <form onSubmit={handleDeactivateCategory}>
                  <select value={deactivateCatId} onChange={(e) => setDeactivateCatId(e.target.value)} required style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', marginBottom: '15px' }}>
                    <option value="">-- Choose Category --</option>
                    {activeCategories.map(c => <option key={c.CATEGORYID} value={c.CATEGORYID}>{c.NAME}</option>)}
                  </select>
                  <button type="submit" style={{ width: '100%', padding: '12px', backgroundColor: '#E74C3C', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold' }}>DEACTIVATE CATEGORY</button>
                </form>
              </div>
              <div style={{ flex: 1, backgroundColor: 'white', padding: '30px', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
                <h3 style={{ marginTop: 0, color: '#27AE60' }}>Inactive Categories</h3>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                  <tbody>
                    {inactiveCategories.length === 0 ? (<tr><td style={{ padding: '15px', textAlign: 'center', color: '#7F8C8D' }}>No inactive categories.</td></tr>) : 
                    inactiveCategories.map(c => (
                      <tr key={c.CATEGORYID} style={{ borderBottom: '1px solid #ECF0F1' }}>
                        <td style={{ padding: '10px', color: '#E74C3C', fontWeight: 'bold' }}>{c.NAME}</td>
                        <td style={{ padding: '10px', textAlign: 'right' }}><button onClick={() => handleReactivate(c.CATEGORYID)} style={{ padding: '6px 12px', backgroundColor: '#27AE60', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '12px', fontWeight: 'bold' }}>REACTIVATE</button></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* RESTOCK */}
        {activeTab === 'restock' && (
          <div style={{ backgroundColor: 'white', padding: '30px', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)', maxWidth: '500px' }}>
            <h1 style={{ color: '#2C3E50', marginTop: 0 }}>Process Restock</h1>
            <form onSubmit={handleRestock}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Select Product</label>
              <select value={restockProduct} onChange={(e) => setRestockProduct(e.target.value)} required style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', marginBottom: '15px' }}>
                <option value="">-- Choose Product --</option>
                {products.map(p => <option key={p.PRODUCTID} value={p.PRODUCTID}>{p.PRODUCT} (Current: {p.STOCK_QTY})</option>)}
              </select>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Quantity Received</label>
              <input type="number" min="1" value={restockQty} onChange={(e) => setRestockQty(e.target.value)} required style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', marginBottom: '20px' }} />
              <button type="submit" style={{ width: '100%', padding: '12px', backgroundColor: '#27AE60', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold' }}>CONFIRM RESTOCK</button>
            </form>
          </div>
        )}

        {/* SYSTEM SETUP */}
        {activeTab === 'setup' && (
          <div>
            <h1 style={{ color: '#2C3E50', marginTop: 0 }}>System Setup</h1>
            <div style={{ display: 'flex', gap: '20px', flexWrap: 'wrap' }}>
              <div style={{ flex: '1 1 300px', backgroundColor: 'white', padding: '25px', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
                <h3 style={{ marginTop: 0, color: '#8E44AD' }}>Add Category</h3>
                <form onSubmit={handleAddCategory}>
                  <input type="text" placeholder="Category Name" value={catName} onChange={e => setCatName(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }} />
                  <input type="text" placeholder="Description" value={catDesc} onChange={e => setCatDesc(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '15px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }} />
                  <button type="submit" style={{ width: '100%', padding: '10px', backgroundColor: '#8E44AD', color: 'white', border: 'none', borderRadius: '4px', fontWeight: 'bold', cursor: 'pointer' }}>ADD CATEGORY</button>
                </form>
              </div>
              <div style={{ flex: '1 1 300px', backgroundColor: 'white', padding: '25px', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
                <h3 style={{ marginTop: 0, color: '#D35400' }}>Add Supplier</h3>
                <form onSubmit={handleAddSupplier}>
                  <input type="text" placeholder="Supplier Name" value={supName} onChange={e => setSupName(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }} />
                  <input type="text" placeholder="Contact Number" value={supContact} onChange={e => setSupContact(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }} />
                  <input type="email" placeholder="Email Address" value={supEmail} onChange={e => setSupEmail(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }} />
                  <input type="text" placeholder="Address" value={supAddress} onChange={e => setSupAddress(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '15px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }} />
                  <button type="submit" style={{ width: '100%', padding: '10px', backgroundColor: '#D35400', color: 'white', border: 'none', borderRadius: '4px', fontWeight: 'bold', cursor: 'pointer' }}>ADD SUPPLIER</button>
                </form>
              </div>
              <div style={{ flex: '1 1 300px', backgroundColor: 'white', padding: '25px', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
                <h3 style={{ marginTop: 0, color: '#2980B9' }}>Add Product</h3>
                <form onSubmit={handleAddProduct}>
                  <input type="text" placeholder="Product Name" value={prodName} onChange={e => setProdName(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }} />
                  <select value={prodCat} onChange={e => setProdCat(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }}>
                    <option value="">-- Select Category --</option>
                    {activeCategories.map(c => <option key={c.CATEGORYID} value={c.CATEGORYID}>{c.NAME}</option>)}
                  </select>
                  <select value={prodSup} onChange={e => setProdSup(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }}>
                    <option value="">-- Select Supplier --</option>
                    {suppliers.map(s => <option key={s.SUPPLIERID} value={s.SUPPLIERID}>{s.NAME}</option>)}
                  </select>
                  <div style={{ display: 'flex', gap: '10px', marginBottom: '10px' }}>
                    <input type="number" placeholder="Unit Price" value={prodPrice} onChange={e => setProdPrice(e.target.value)} required style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }} />
                    <input type="number" placeholder="Initial Stock" value={prodStock} onChange={e => setProdStock(e.target.value)} required style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }} />
                  </div>
                  <input type="number" placeholder="Restock Threshold Level" value={prodRestock} onChange={e => setProdRestock(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '15px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }} />
                  <button type="submit" style={{ width: '100%', padding: '10px', backgroundColor: '#2980B9', color: 'white', border: 'none', borderRadius: '4px', fontWeight: 'bold', cursor: 'pointer' }}>ADD PRODUCT</button>
                </form>
              </div>
            </div>
          </div>
        )}

        {/* USER MANAGEMENT */}
        {activeTab === 'users' && (
          <div>
            <h1 style={{ color: '#2C3E50', marginTop: 0 }}>User Management</h1>
            <div style={{ display: 'flex', gap: '30px', alignItems: 'flex-start' }}>
              <div style={{ flex: 1, backgroundColor: 'white', padding: '30px', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
                <h3 style={{ marginTop: 0, color: '#2980B9' }}>Add New User</h3>
                <form onSubmit={handleAddUser}>
                  <input type="text" placeholder="Username" value={newUsername} onChange={e => setNewUsername(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }} />
                  <input type="email" placeholder="Email" value={newEmail} onChange={e => setNewEmail(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }} />
                  <input type="password" placeholder="Temporary Password" value={newPassword} onChange={e => setNewPassword(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }} />
                  <select value={newRole} onChange={e => setNewRole(e.target.value)} required style={{ width: '100%', padding: '10px', marginBottom: '15px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing:'border-box' }}>
                    <option value="STAFF">STAFF</option>
                    <option value="MANAGER">MANAGER</option>
                    <option value="ADMIN">ADMIN</option>
                  </select>
                  <button type="submit" style={{ width: '100%', padding: '12px', backgroundColor: '#2980B9', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold' }}>CREATE USER</button>
                </form>
              </div>
              <div style={{ flex: 2, backgroundColor: 'white', padding: '30px', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
                <h3 style={{ marginTop: 0, color: '#2C3E50' }}>System Users</h3>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                  <thead><tr style={{ backgroundColor: '#ECF0F1', textAlign: 'left' }}><th style={{ padding: '10px' }}>ID</th><th style={{ padding: '10px' }}>User</th><th style={{ padding: '10px' }}>Role</th><th style={{ padding: '10px' }}>Status</th><th style={{ padding: '10px', textAlign: 'right' }}>Action</th></tr></thead>
                  <tbody>
                    {users.map(u => (
                      <tr key={u.USERID} style={{ borderBottom: '1px solid #ECF0F1' }}>
                        <td style={{ padding: '10px' }}>{u.USERID}</td>
                        <td style={{ padding: '10px', fontWeight: 'bold' }}>{u.USERNAME} <br/><span style={{fontSize: '12px', color: '#7F8C8D', fontWeight: 'normal'}}>{u.EMAIL}</span></td>
                        <td style={{ padding: '10px' }}>{u.ROLE}</td>
                        <td style={{ padding: '10px', color: u.IS_ACTIVE === 1 ? '#27AE60' : '#E74C3C', fontWeight: 'bold' }}>{u.IS_ACTIVE === 1 ? 'ACTIVE' : 'DISABLED'}</td>
                        <td style={{ padding: '10px', textAlign: 'right' }}>
                          <button onClick={() => handleToggleUser(u.USERID, u.IS_ACTIVE)} style={{ padding: '6px 12px', backgroundColor: u.IS_ACTIVE === 1 ? '#E74C3C' : '#27AE60', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '12px', fontWeight: 'bold' }}>
                            {u.IS_ACTIVE === 1 ? 'DISABLE' : 'ENABLE'}
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* AUDIT LOGS */}
        {activeTab === 'audit' && (
          <div>
            <h1 style={{ color: '#2C3E50', marginTop: 0 }}>System Audit Logs</h1>
            <p style={{ color: '#7F8C8D', marginBottom: '20px' }}>Showing the last 50 database operations.</p>
            <table style={{ width: '100%', backgroundColor: 'white', borderCollapse: 'collapse', boxShadow: '0 4px 8px rgba(0,0,0,0.1)', fontSize: '14px' }}>
              <thead>
                <tr style={{ backgroundColor: '#34495E', color: 'white', textAlign: 'left' }}>
                  <th style={{ padding: '12px' }}>ID</th>
                  <th style={{ padding: '12px' }}>Timestamp</th>
                  <th style={{ padding: '12px' }}>User</th>
                  <th style={{ padding: '12px' }}>Action</th>
                  <th style={{ padding: '12px' }}>Table</th>
                  <th style={{ padding: '12px' }}>Details</th>
                </tr>
              </thead>
              <tbody>
                {auditLogs.map((log) => (
                  <tr key={log.LOGID} style={{ borderBottom: '1px solid #ECF0F1' }}>
                    <td style={{ padding: '12px', color: '#7F8C8D' }}>{log.LOGID}</td>
                    <td style={{ padding: '12px' }}>{log.CHANGE_DATE}</td>
                    <td style={{ padding: '12px', fontWeight: 'bold' }}>{log.CHANGED_BY}</td>
                    <td style={{ padding: '12px', color: log.OPERATION === 'INSERT' ? '#27AE60' : log.OPERATION === 'DELETE' ? '#E74C3C' : '#F39C12', fontWeight: 'bold' }}>{log.OPERATION}</td>
                    <td style={{ padding: '12px' }}>{log.TABLE_NAME}</td>
                    <td style={{ padding: '12px' }}>{log.DESCRIPTION}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

      </div>
    </div>
  );
}

export default AdminDashboard;