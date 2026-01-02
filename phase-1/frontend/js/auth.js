// Login page functionality
document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('loginForm');
    const errorMessage = document.getElementById('errorMessage');
    
    // Check if already logged in
    checkSession();
    
    loginForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;
        
        try {
            const response = await fetch(API_ENDPOINTS.LOGIN, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                credentials: 'include',
                body: JSON.stringify({ username, password }),
            });
            
            const data = await response.json();
            
            if (response.ok) {
                // Login successful
                window.location.href = 'dashboard.html';
            } else {
                // Login failed
                showError(data.detail || 'Login failed. Please check your credentials.');
            }
        } catch (error) {
            showError('Unable to connect to the server. Please try again.');
            console.error('Login error:', error);
        }
    });
    
    function showError(message) {
        errorMessage.textContent = message;
        errorMessage.classList.add('show');
        
        setTimeout(() => {
            errorMessage.classList.remove('show');
        }, 5000);
    }
    
    async function checkSession() {
        try {
            const response = await fetch(API_ENDPOINTS.SESSION, {
                credentials: 'include',
            });
            
            if (response.ok) {
                // Already logged in, redirect to dashboard
                window.location.href = 'dashboard.html';
            }
        } catch (error) {
            // Not logged in, stay on login page
            console.log('Not logged in');
        }
    }
});
