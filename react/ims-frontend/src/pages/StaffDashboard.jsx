import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';

function StaffDashboard() {
  const navigate = useNavigate();
  const userId = localStorage.getItem('userId');
  const username = localStorage.getItem('username');

  const [products, setProducts] = useState([]);
  const [transactions, setTransactions] = useState([]);
  
  // Form State
  const [selectedProduct, setSelectedProduct] = useState('');
  const [actionType, setActionType] = useState('SALE');
  const [quantity, setQuantity] = useState('');
  const [message, setMessage] = useState({ text: '', type: '' });

  // Wrap in useCallback so we can trigger it after a transaction
  const fetchDashboardData = useCallback(async () => {
    try {
      const prodRes = await axios.get('http://localhost:8080/api/inventory/products');
      setProducts(prodRes.data);

      const txnRes = await axios.get(`http://localhost:8080/api/inventory/transactions/${userId}`);
      setTransactions(txnRes.data);
    } catch (err) {
      console.error("Error fetching data", err);
    }
  }, [userId]);

  useEffect(() => {
    if (!userId) {
      navigate('/login');
      return;
    }
    fetchDashboardData();
  }, [userId, navigate, fetchDashboardData]);

  const handleTransaction = async (e) => {
    e.preventDefault();
    setMessage({ text: '', type: '' });

    if (!selectedProduct || !quantity || quantity <= 0) {
      setMessage({ text: 'Please select a product and enter a valid quantity.', type: 'error' });
      return;
    }

    const endpoint = actionType === 'SALE' ? '/sale' : '/return';
    
    try {
      await axios.post(`http://localhost:8080/api/inventory${endpoint}`, {
        userId: userId,
        productId: selectedProduct,
        quantity: quantity,
        notes: `Staff ${actionType} entry`
      });

      setMessage({ text: `Successfully processed ${actionType} for ${quantity} unit(s).`, type: 'success' });
      setQuantity('');
      fetchDashboardData(); // Refresh the grid and stock levels instantly
    } catch (err) {
      setMessage({ text: err.response?.data?.error || 'Transaction failed', type: 'error' });
    }
  };

  const handleLogout = () => {
    localStorage.clear();
    navigate('/login');
  };

  return (
    <div style={{ padding: '30px', fontFamily: 'sans-serif', backgroundColor: '#ECF0F1', minHeight: '100vh' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px' }}>
        <h1 style={{ color: '#2C3E50', margin: 0 }}>Staff Portal - Welcome, {username}</h1>
        <button onClick={handleLogout} style={{ padding: '10px 20px', backgroundColor: '#E74C3C', color: 'white', border: 'none', borderRadius: '5px', cursor: 'pointer', fontWeight: 'bold' }}>
          LOGOUT
        </button>
      </div>

      <div style={{ display: 'flex', gap: '30px' }}>
        {/* Left Column: Transaction Form */}
        <div style={{ flex: '1', backgroundColor: 'white', padding: '25px', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)', height: 'fit-content' }}>
          <h2 style={{ marginTop: 0, color: '#2980B9' }}>New Transaction</h2>
          
          {message.text && (
            <div style={{ padding: '10px', marginBottom: '15px', borderRadius: '4px', backgroundColor: message.type === 'success' ? '#D4EFDF' : '#F2D7D5', color: message.type === 'success' ? '#27AE60' : '#C0392B' }}>
              {message.text}
            </div>
          )}

          <form onSubmit={handleTransaction}>
            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Product</label>
              <select value={selectedProduct} onChange={(e) => setSelectedProduct(e.target.value)} style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #BDC3C7' }}>
                <option value="">-- Select a Product --</option>
                {products.map(p => (
                  // Oracle JDBC returns keys in UPPERCASE
                  <option key={p.PRODUCTID} value={p.PRODUCTID}>
                    {p.PRODUCT} (Stock: {p.STOCK_QTY} | Rs.{p.UNIT_PRICE})
                  </option>
                ))}
              </select>
            </div>

            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Transaction Type</label>
              <select value={actionType} onChange={(e) => setActionType(e.target.value)} style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #BDC3C7' }}>
                <option value="SALE">Sale (Deduct Stock)</option>
                <option value="RETURN">Return (Add Stock)</option>
              </select>
            </div>

            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Quantity</label>
              <input type="number" min="1" value={quantity} onChange={(e) => setQuantity(e.target.value)} style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing: 'border-box' }} />
            </div>

            <button type="submit" style={{ width: '100%', padding: '12px', backgroundColor: '#2C3E50', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold', fontSize: '16px' }}>
              PROCESS {actionType}
            </button>
          </form>
        </div>

        {/* Right Column: History Grid */}
        <div style={{ flex: '2', backgroundColor: 'white', padding: '25px', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)' }}>
          <h2 style={{ marginTop: 0, color: '#2980B9' }}>Your Recent Transactions</h2>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ backgroundColor: '#2C3E50', color: 'white', textAlign: 'left' }}>
                <th style={{ padding: '12px' }}>Txn ID</th>
                <th style={{ padding: '12px' }}>Type</th>
                <th style={{ padding: '12px' }}>Product</th>
                <th style={{ padding: '12px' }}>Qty</th>
                <th style={{ padding: '12px' }}>Amount</th>
              </tr>
            </thead>
            <tbody>
              {transactions.length === 0 ? (
                <tr><td colSpan="5" style={{ padding: '15px', textAlign: 'center' }}>No transactions found.</td></tr>
              ) : (
                transactions.map((txn, idx) => (
                  <tr key={idx} style={{ borderBottom: '1px solid #ECF0F1' }}>
                    <td style={{ padding: '12px' }}>{txn.TRANSACTIONID}</td>
                    <td style={{ padding: '12px', color: txn.TRANS_TYPE === 'SALE' ? '#27AE60' : '#E67E22', fontWeight: 'bold' }}>{txn.TRANS_TYPE}</td>
                    <td style={{ padding: '12px' }}>{txn.PRODUCT_NAME}</td>
                    <td style={{ padding: '12px' }}>{txn.QUANTITY}</td>
                    <td style={{ padding: '12px' }}>Rs. {txn.SUBTOTAL}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

export default StaffDashboard;