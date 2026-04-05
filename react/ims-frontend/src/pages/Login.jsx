import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';

function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const navigate = useNavigate();

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');

    try {
      const response = await axios.post('http://localhost:8080/api/inventory/login', {
        email: email,
        password: password
      });

      const userData = response.data;
      
      // Save user details so the rest of the app knows who is logged in
      localStorage.setItem('userId', userData.USERID);
      localStorage.setItem('role', userData.ROLE);
      localStorage.setItem('username', userData.USERNAME);

      // Route them to the correct dashboard based on Oracle role
      if (userData.ROLE === 'ADMIN' || userData.ROLE === 'MANAGER') {
        navigate('/admin');
      } else {
        navigate('/staff');
      }

    } catch (err) {
      setError(err.response?.data?.error || 'Failed to connect to the server.');
    }
  };

  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', backgroundColor: '#ECF0F1' }}>
      <form onSubmit={handleLogin} style={{ padding: '40px', backgroundColor: 'white', borderRadius: '8px', boxShadow: '0 4px 8px rgba(0,0,0,0.1)', width: '300px' }}>
        <h2 style={{ textAlign: 'center', color: '#2C3E50', marginBottom: '20px' }}>IMS Login</h2>
        
        {error && <div style={{ color: 'red', marginBottom: '15px', textAlign: 'center', fontSize: '14px' }}>{error}</div>}

        <div style={{ marginBottom: '15px' }}>
          <label style={{ display: 'block', marginBottom: '5px', color: '#34495E' }}>Email</label>
          <input 
            type="email" 
            value={email} 
            onChange={(e) => setEmail(e.target.value)} 
            required 
            style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing: 'border-box' }}
          />
        </div>

        <div style={{ marginBottom: '20px' }}>
          <label style={{ display: 'block', marginBottom: '5px', color: '#34495E' }}>Password</label>
          <input 
            type="password" 
            value={password} 
            onChange={(e) => setPassword(e.target.value)} 
            required 
            style={{ width: '100%', padding: '10px', borderRadius: '4px', border: '1px solid #BDC3C7', boxSizing: 'border-box' }}
          />
        </div>

        <button type="submit" style={{ width: '100%', padding: '10px', backgroundColor: '#2980B9', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold' }}>
          LOGIN
        </button>
      </form>
    </div>
  );
}

export default Login;