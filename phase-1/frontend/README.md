# Frontend Documentation

## Part 3: HTML/CSS/JavaScript Frontend

A clean, responsive web interface for the SQL Query Generator.

## Structure

```
frontend/
├── index.html          # Login page
├── dashboard.html      # Main dashboard
├── css/
│   └── styles.css     # All styles
├── js/
│   ├── config.js      # API configuration
│   ├── auth.js        # Login functionality
│   └── dashboard.js   # Dashboard functionality
└── serve.sh           # Development server script
```

## Setup & Running

### 1. Make sure the backend is running

```bash
cd backend
./run.sh
```

Backend should be running on `http://localhost:8080`

### 2. Start the frontend server

```bash
cd frontend
chmod +x serve.sh
./serve.sh
```

Frontend will be available at `http://localhost:3000`

### 3. Access the application

Open your browser and navigate to:
```
http://localhost:3000
```

## Features

### Login Page (`index.html`)
- Team-based authentication
- Demo credentials displayed
- Auto-redirect if already logged in
- Error handling

### Dashboard (`dashboard.html`)
- **Header**: Shows team name and username, logout button
- **Sidebar**: Database schema browser with all tables
- **Main Panel**:
  - Natural language query input
  - Generate SQL button
  - Generate & Execute button (combined)
  - Generated SQL display with copy button
  - Edit SQL functionality
  - Results table with row count
  - Error display

## User Flow

1. **Login**: User enters credentials (team-based)
2. **Dashboard**: After login, sees their team's database schema
3. **Query**:
   - Enter question in natural language
   - Click "Generate SQL" to see the SQL query
   - Click "Run Query" to execute it
   - OR click "Generate & Execute" to do both at once
4. **Results**: View query results in a formatted table
5. **Edit**: Can edit SQL before running if needed

## API Integration

All API calls are made to the backend running on `http://localhost:8080`:

- `POST /api/login` - Authentication
- `GET /api/session` - Check auth status
- `GET /api/schema` - Load database schema
- `POST /api/generate-sql` - Generate SQL from natural language
- `POST /api/execute-query` - Execute SQL query
- `POST /api/query` - Generate and execute in one call

## Examples

### Example Questions to Try

**Sales Team:**
- "Show me all customers"
- "How many orders were placed in December 2024?"
- "What are the top 5 products by total sales?"
- "List customers with their total order amounts"
- "Which sales rep has the most customers?"

**Marketing Team:**
- "Show me all active campaigns"
- "What's the average email open rate?"
- "How many leads were generated from social media?"
- "List campaigns with their total budget and spent amount"
- "Which campaign had the best conversion rate?"

**Operations Team:**
- "Show me current inventory levels"
- "Which warehouse has the most stock?"
- "List all pending purchase orders"
- "Show shipments that are in transit"
- "What's the total value of inventory across all warehouses?"

## Customization

### Changing API URL

If deploying to a different server, update `js/config.js`:

```javascript
const API_BASE_URL = 'http://your-server-address:8080';
```

### Styling

All styles are in `css/styles.css`. The design uses:
- Purple gradient theme (`#667eea` to `#764ba2`)
- Clean, modern UI
- Responsive design
- Smooth transitions

### Adding Features

To add new features:
1. Add HTML elements in `dashboard.html`
2. Style them in `css/styles.css`
3. Add JavaScript logic in `js/dashboard.js`
4. Make API calls using `fetch()` with credentials

## Browser Support

Works on all modern browsers:
- Chrome/Edge (recommended)
- Firefox
- Safari

## Production Deployment

For production:
1. Use a proper web server (Nginx, Apache)
2. Enable HTTPS
3. Update CORS settings in backend
4. Set proper `API_BASE_URL` in `config.js`
5. Add environment-based configuration

## Troubleshooting

**Login not working:**
- Check backend is running on port 8080
- Check browser console for errors
- Verify credentials in backend `.env` file

**Schema not loading:**
- Check database connection
- Verify session is valid
- Check network tab in browser dev tools

**CORS errors:**
- Backend CORS is configured for development
- For production, update allowed origins in `backend/main.py`

## Next Steps

**Part 4 will include:**
- EC2 deployment guide
- Production configuration
- Nginx setup
- SSL/HTTPS configuration
- Environment management
