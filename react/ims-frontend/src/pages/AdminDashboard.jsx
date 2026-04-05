import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';

function AdminDashboard() {
  const navigate = useNavigate();
  const username = localStorage.getItem('username');
  const userId = localStorage.getItem('userId');

  // Navigation State
  const [activeTab, setActiveTab] = useState('alerts');

  // Data States
  const [alerts, setAlerts] = useState([]);
  const [products, setProducts] = useState([]);
  
  // Form States
  const [restockProduct, setRestockProduct] = useState('');
  const [restockQty, setRestockQty] = useState('');
  const [deactivateCatId, setDeactivateCatId] = useState('');
  const [message, setMessage] = useState({ text: '', type: '' });

  // Fetch all data
  const fetchData = useCallback(async () => {
    try {
      const alertRes = await axios.get('http://localhost:8080/api/inventory/alerts');
      setAlerts(alertRes.data);

      const prodRes = await axios.get('http://localhost:8080/api/inventory/products');
      setProducts(prodRes.data);
    } catch (err) {
      console.error("Error fetching data", err);
    }
  }, []);

  useEffect(() => {
    // Security check
    const role = localStorage.getItem('role');
    if (!role || (role !== 'ADMIN' && role !== 'MANAGER')) {
      navigate('/login');
    } else {
      fetchData();
    }
  }, [navigate, fetchData]);

  // --- DERIVE CATEGORIES FROM PRODUCTS DATA ---
  // This extracts unique categories without needing a new Spring Boot endpoint
  const uniqueCategories = Array.from(new Map(products.map(p => [
    p.CATEGORYID, { id: p.CATEGORYID, name: p.CATEGORY, isActive: p.CAT_ACTIVE }
  ])).values());
  const activeCategories = uniqueCategories.filter(c => c.isActive === 1);
  const inactiveCategories = uniqueCategories.filter(c => c.isActive === 0);

  // --- HANDLERS ---
  const handleRestock = async (e) => {
    e.preventDefault();
    setMessage({ text: '', type: '' });

    try {
      await axios.post('http://localhost:8080/api/inventory/restock', {
        userId: userId,
        productId: restockProduct,
        quantity: restockQty
      });
      setMessage({ text: 'Stock added successfully!', type: 'success' });
      setRestockQty('');
      fetchData(); 
    } catch (err) {
      setMessage({ text: err.response?.data?.error || 'Restock failed', type: 'error' });
    }
  };

  const handleDeactivateCategory = async (e) => {
    e.preventDefault();
    setMessage({ text: '', type: '' });
    try {
      await axios.put(`http://localhost:8080/api/inventory/admin/category/${deactivateCatId}/deactivate`);
      setMessage({ text: 'Category deactivated successfully!', type: 'success' });
      setDeactivateCatId('');
      fetchData(); 
    } catch (err) {
      setMessage({ text: err.response?.data?.error || 'Failed to deactivate category', type: 'error' });
    }
  };

  const handleReactivate = async (categoryId) => {
    setMessage({ text: '', type: '' });
    try {
      await axios.put(`http://localhost:8080/api/inventory/admin/category/${categoryId}/reactivate`);
      fetchData(); 
    } catch (err) {
      setMessage({ text: 'Failed to reactivate category', type: 'error' });
    }
  };

  const handleLogout = () => {
    localStorage.clear();
    navigate('/login');
  };

  // --- REUSABLE UI STYLES ---
  const sidebarBtnStyle = (tabName) => ({
    width: '100%', padding: '15px', textAlign: 'left', background: activeTab === tabName ? '#34495E' : 'transparent',
    color: 'white', border: 'none', borderLeft: activeTab === tabName ? '5px solid #3498DB' : '5px solid transparent',
    cursor: 'pointer', fontSize: '16px', fontWeight: activeTab === tabName ? 'bold' : 'normal'
  });

  return (
    <div style={{ display: 'flex', minHeight: '100vh', fontFamily: 'sans-serif', backgroundColor: '#ECF0F1' }}>
      
      {/* LEFT PANE: SIDEBAR */}
      <div style={{ width: '250px', backgroundColor: '#2C3E50', color: 'white', display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '20px', borderBottom: '1px solid #34495E' }}>
          <h2 style={{ margin: 0, color: '#3498DB' }}>IMS Admin</h2>
          <p style={{ margin: '5px 0 0 0', fontSize: '14px', color: '#BDC3C7' }}>Logged in as: {username}</p>
        </div>
        
        <div style={{ flex: 1, paddingTop: '10px' }}>
          <button style={sidebarBtnStyle('alerts')} onClick={() => setActiveTab('alerts')}>Live Alerts</button>
          <button style={sidebarBtnStyle('products')} onClick={() => setActiveTab('products')}>Product Catalog</button>
          <button style={sidebarBtnStyle('categories')} onClick={() => setActiveTab('categories')}>Manage Categories</button>
          <button style={sidebarBtnStyle('restock')} onClick={() => setActiveTab('restock')}>Manual Restock</button>
        </div>

        <div style={{ padding: '20px' }}>
          <button onClick={handleLogout} style={{ width: '100%', padding: '10px', backgroundColor: '#E74C3C', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold' }}>
            LOGOUT
          </button>
        </div>
      </div>

      {/* RIGHT PANE: DYNAMIC CONTENT */}
      <div style={{ flex: 1, padding: '40px', overflowY: 'auto' }}>
        
        {/* VIEW 1: ALERTS */}
        {activeTab === 'alerts' && (
          <div>
            <h1 style={{ color: '#2C3E50', marginTop: 0 }}>Restock Alerts Dashboard</h1>
            <table style={{ width: '100%', backgroundColor: 'white', borderCollapse: 'collapse', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
              <thead>
                <tr style={{ backgroundColor: '#E74C3C', color: 'white', textAlign: 'left' }}>
                  <th style={{ padding: '15px' }}>Product</th>
                  <th style={{ padding: '15px' }}>Category</th>
                  <th style={{ padding: '15px' }}>Current Stock</th>
                  <th style={{ padding: '15px' }}>Shortage</th>
                  <th style={{ padding: '15px' }}>Supplier</th>
                </tr>
              </thead>
              <tbody>
                {alerts.length === 0 ? (
                  <tr><td colSpan="5" style={{ padding: '20px', textAlign: 'center' }}>All stock levels are healthy!</td></tr>
                ) : (
                  alerts.map((a, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid #ECF0F1' }}>
                      <td style={{ padding: '15px', fontWeight: 'bold' }}>{a.PRODUCT}</td>
                      <td style={{ padding: '15px' }}>{a.CATEGORY}</td>
                      <td style={{ padding: '15px', color: '#E74C3C', fontWeight: 'bold' }}>{a.CURRENT_STOCK}</td>
                      <td style={{ padding: '15px' }}>{a.UNITS_NEEDED} needed</td>
                      <td style={{ padding: '15px' }}>{a.SUPPLIER} ({a.SUPPLIER_CONTACT})</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}

        {/* VIEW 2: PRODUCT CATALOG */}
        {activeTab === 'products' && (
          <div>
            <h1 style={{ color: '#2C3E50', marginTop: 0 }}>Global Product Catalog</h1>
            <table style={{ width: '100%', backgroundColor: 'white', borderCollapse: 'collapse', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
              <thead>
                <tr style={{ backgroundColor: '#2980B9', color: 'white', textAlign: 'left' }}>
                  <th style={{ padding: '15px' }}>ID</th>
                  <th style={{ padding: '15px' }}>Product</th>
                  <th style={{ padding: '15px' }}>Category</th>
                  <th style={{ padding: '15px' }}>Price</th>
                  <th style={{ padding: '15px' }}>Stock</th>
                </tr>
              </thead>
              <tbody>
                {products.map((p, i) => (
                  <tr key={i} style={{ borderBottom: '1px solid #ECF0F1', backgroundColor: p.CAT_ACTIVE === 0 ? '#F9E7E7' : 'white' }}>
                    <td style={{ padding: '15px' }}>{p.PRODUCTID}</td>
                    <td style={{ padding: '15px' }}>
                      {p.PRODUCT} 
                      {p.CAT_ACTIVE === 0 && <span style={{color: 'red', fontSize:'12px', marginLeft: '5px'}}>(Inactive)</span>}
                    </td>
                    <td style={{ padding: '15px' }}>{p.CATEGORY}</td>
                    <td style={{ padding: '15px' }}>Rs. {p.UNIT_PRICE}</td>
                    <td style={{ padding: '15px' }}>{p.STOCK_QTY}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* VIEW 3: CATEGORY MANAGEMENT (NEW) */}
        {activeTab === 'categories' && (
          <div>
            <h1 style={{ color: '#2C3E50', marginTop: 0 }}>Category Management</h1>
            
            {message.text && (
              <div style={{ padding: '10px', marginBottom: '15px', borderRadius: '4px', backgroundColor: message.type === 'success' ? '#D4EFDF' : '#F2D7D5', color: message.type === 'success' ? '#27AE60' : '#C0392B' }}>
                {message.text}
              </div>
            )}

            <div style={{ display: 'flex', gap: '30px', alignItems: 'flex-start' }}>
              {/* Deactivate Form */}
              <div style={{ flex: 1, backgroundColor: 'white', padding: '30px', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
                <h3 style={{ marginTop: 0, color: '#E74C3C' }}>Deactivate Category</h3>
                <p style={{ fontSize: '14px', color: '#7F8C8D', marginBottom: '20px' }}>Deactivating a category prevents restocking of all associated products.</p>
                <form onSubmit={handleDeactivateCategory}>
                  <div style={{ marginBottom: '20px' }}>
                    <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Select Active Category</label>
                    <select value={deactivateCatId} onChange={(e) => setDeactivateCatId(e.target.value)} required style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #BDC3C7' }}>
                      <option value="">-- Choose Category --</option>
                      {activeCategories.map(c => (
                        <option key={c.id} value={c.id}>{c.name}</option>
                      ))}
                    </select>
                  </div>
                  <button type="submit" style={{ width: '100%', padding: '12px', backgroundColor: '#E74C3C', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold' }}>
                    DEACTIVATE CATEGORY
                  </button>
                </form>
              </div>

              {/* Inactive Categories Table */}
              <div style={{ flex: 1, backgroundColor: 'white', padding: '30px', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
                <h3 style={{ marginTop: 0, color: '#27AE60' }}>Inactive Categories</h3>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                  <thead>
                    <tr style={{ backgroundColor: '#ECF0F1', textAlign: 'left' }}>
                      <th style={{ padding: '10px' }}>Category Name</th>
                      <th style={{ padding: '10px', textAlign: 'right' }}>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {inactiveCategories.length === 0 ? (
                      <tr><td colSpan="2" style={{ padding: '15px', textAlign: 'center', color: '#7F8C8D' }}>No inactive categories.</td></tr>
                    ) : (
                      inactiveCategories.map(c => (
                        <tr key={c.id} style={{ borderBottom: '1px solid #ECF0F1' }}>
                          <td style={{ padding: '10px', color: '#E74C3C', fontWeight: 'bold' }}>{c.name}</td>
                          <td style={{ padding: '10px', textAlign: 'right' }}>
                            <button 
                              onClick={() => handleReactivate(c.id)}
                              style={{ padding: '6px 12px', backgroundColor: '#27AE60', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '12px', fontWeight: 'bold' }}
                            >
                              REACTIVATE
                            </button>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* VIEW 4: RESTOCK FORM */}
        {activeTab === 'restock' && (
          <div style={{ backgroundColor: 'white', padding: '30px', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)', maxWidth: '500px' }}>
            <h1 style={{ color: '#2C3E50', marginTop: 0 }}>Process Restock</h1>
            
            {message.text && activeTab === 'restock' && (
              <div style={{ padding: '10px', marginBottom: '15px', borderRadius: '4px', backgroundColor: message.type === 'success' ? '#D4EFDF' : '#F2D7D5', color: message.type === 'success' ? '#27AE60' : '#C0392B' }}>
                {message.text}
              </div>
            )}

            <form onSubmit={handleRestock}>
              <div style={{ marginBottom: '15px' }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Select Product to Restock</label>
                <select value={restockProduct} onChange={(e) => setRestockProduct(e.target.value)} required style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #BDC3C7' }}>
                  <option value="">-- Choose Product --</option>
                  {products.map(p => (
                    <option key={p.PRODUCTID} value={p.PRODUCTID}>
                      {p.PRODUCT} (Current: {p.STOCK_QTY}) {p.CAT_ACTIVE === 0 ? ' - INACTIVE' : ''}
                    </option>
                  ))}
                </select>
              </div>

              <div style={{ marginBottom: '20px' }}>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Quantity Received</label>
                <input type="number" min="1" value={restockQty} onChange={(e) => setRestockQty(e.target.value)} required style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing: 'border-box' }} />
              </div>

              <button type="submit" style={{ width: '100%', padding: '12px', backgroundColor: '#27AE60', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold', fontSize: '16px' }}>
                CONFIRM RESTOCK
              </button>
            </form>
          </div>
        )}

      </div>
    </div>
  );
}

export default AdminDashboard;