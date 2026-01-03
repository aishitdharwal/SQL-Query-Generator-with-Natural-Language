# SQL Query Generator - Complete Project Documentation

Natural language to SQL query converter with team-based access control.

## Project Overview

A production-ready application that converts natural language questions into SQL queries using Claude AI, with team-based database access control for e-commerce operations.

**Tech Stack:**
- **Frontend**: HTML, CSS, JavaScript (Vanilla)
- **Backend**: FastAPI (Python)
- **Database**: Aurora PostgreSQL Serverless v2
- **AI**: Claude Sonnet 4.5 (Anthropic)
- **Deployment**: AWS EC2 + Nginx

## Architecture

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ HTTP/HTTPS
       ↓
┌─────────────┐
│   Nginx     │ ← Serves frontend + Reverse proxy
└──────┬──────┘
       │
       ├─→ /api/* ────→ ┌──────────────┐
       │                │ FastAPI      │
       │                │ (Port 8080)  │
       │                └──────┬───────┘
       │                       │
       │                       ↓
       │                ┌──────────────┐      ┌─────────────┐
       │                │ Claude API   │      │   Aurora    │
       │                │ (Anthropic)  │      │ PostgreSQL  │
       │                └──────────────┘      └─────────────┘
       │                                             ↑
       └─────────────────────────────────────────────┘
```

## Features

### User Features
- ✅ Team-based authentication (Sales, Marketing, Operations)
- ✅ Natural language to SQL conversion
- ✅ Database schema browser
- ✅ SQL query execution
- ✅ Edit and re-run queries
- ✅ Results table with row counts
- ✅ Copy SQL to clipboard

### Technical Features
- ✅ Session-based authentication
- ✅ Team-specific database access
- ✅ Real-time SQL generation
- ✅ Error handling and validation
- ✅ Responsive UI design
- ✅ Production-ready deployment

## Project Structure

```
phase-1/
├── infrastructure/           # AWS infrastructure setup
│   └── setup_aurora.sh      # Aurora PostgreSQL creation
├── database/                # Database initialization
│   ├── init_databases.sh    # Create databases and users
│   └── schemas/             # SQL schema files
│       ├── sales_schema.sql
│       ├── marketing_schema.sql
│       └── operations_schema.sql
├── backend/                 # FastAPI backend
│   ├── main.py             # Main application
│   ├── database.py         # Database manager
│   ├── sql_generator.py    # Claude API integration
│   ├── auth.py             # Authentication
│   ├── requirements.txt    # Python dependencies
│   ├── setup.sh            # Backend setup
│   ├── run.sh              # Run backend locally
│   └── README.md           # Backend documentation
├── frontend/               # Web interface
│   ├── index.html          # Login page
│   ├── dashboard.html      # Main dashboard
│   ├── css/
│   │   └── styles.css      # All styles
│   ├── js/
│   │   ├── config.js       # API configuration
│   │   ├── auth.js         # Login logic
│   │   └── dashboard.js    # Dashboard logic
│   ├── serve.sh            # Serve frontend locally
│   └── README.md           # Frontend documentation
├── deployment/             # EC2 deployment
│   ├── setup_ec2.sh        # EC2 initial setup
│   ├── deploy.sh           # Automated deployment
│   ├── nginx.conf          # Nginx configuration
│   ├── supervisor.conf     # Supervisor configuration
│   ├── setup_ssl.sh        # SSL setup
│   ├── config.production.js # Production frontend config
│   └── README.md           # Deployment guide
├── .env.example            # Environment template
└── README.md               # This file
```

## Quick Start

### Development Setup

**Prerequisites:**
- Python 3.8+
- PostgreSQL client (psql)
- AWS CLI configured
- Claude API key

**1. Set up infrastructure:**
```bash
cd phase-1
cp .env.example .env
# Edit .env with your credentials

# Create Aurora database
./infrastructure/setup_aurora.sh

# Initialize databases
./database/init_databases.sh
```

**2. Start backend:**
```bash
cd backend
./setup.sh
./run.sh
# Backend runs on http://localhost:8080
```

**3. Start frontend:**
```bash
cd frontend
./serve.sh
# Frontend runs on http://localhost:3000
```

**4. Access the application:**
```
http://localhost:3000
```

Login with demo credentials:
- **Sales**: `sales_user` / `sales_secure_pass_123`
- **Marketing**: `marketing_user` / `marketing_secure_pass_123`
- **Operations**: `operations_user` / `operations_secure_pass_123`

### Production Deployment

See [deployment/README.md](deployment/README.md) for complete EC2 deployment guide.

**Quick deployment:**
```bash
cd deployment
# Edit deploy.sh with your EC2 IP
./deploy.sh
```

## Team Databases

### Sales Team (sales_db)
**Tables:**
- `customers` - Customer information
- `products` - Product catalog
- `orders` - Order transactions
- `order_items` - Order line items
- `sales_representatives` - Sales team
- `sales_assignments` - Customer assignments

### Marketing Team (marketing_db)
**Tables:**
- `campaigns` - Marketing campaigns
- `leads` - Lead management
- `email_campaigns` - Email metrics
- `customer_segments` - Segmentation
- `marketing_events` - Events tracking
- `social_media_posts` - Social performance
- `content_performance` - Content analytics

### Operations Team (operations_db)
**Tables:**
- `warehouses` - Warehouse locations
- `suppliers` - Supplier information
- `inventory` - Stock levels
- `purchase_orders` - PO management
- `po_items` - PO line items
- `shipments` - Shipment tracking
- `shipment_items` - Shipment contents
- `inventory_movements` - Transaction log

## Example Queries

### Sales Team
```
"Show me all customers who placed orders in December 2024"
"What are the top 5 products by total sales?"
"List customers with their total order amounts"
"Which sales representative has the most customers?"
```

### Marketing Team
```
"Show me all active campaigns"
"What's the average email open rate across all campaigns?"
"How many leads were generated from social media?"
"Which campaign had the best ROI?"
```

### Operations Team
```
"Show me current inventory levels for all warehouses"
"Which warehouse has the lowest stock of Laptop Pro 15?"
"List all shipments that are currently in transit"
"What's the total value of pending purchase orders?"
```

## API Endpoints

### Authentication
- `POST /api/login` - User login
- `POST /api/logout` - User logout
- `GET /api/session` - Get session info

### Database
- `GET /api/schema` - Get database schema
- `GET /api/tables` - List tables
- `GET /api/table/{name}` - Get table details

### Query
- `POST /api/generate-sql` - Generate SQL from natural language
- `POST /api/execute-query` - Execute SQL query
- `POST /api/query` - Generate and execute in one call

Full API documentation: `http://localhost:8080/docs`

## Configuration

### Environment Variables

```bash
# AWS Configuration
AWS_REGION=ap-south-1
AWS_PROFILE=default

# Aurora PostgreSQL
DB_HOST=your-aurora-endpoint
DB_PORT=5432
DB_MASTER_USERNAME=postgres
DB_MASTER_PASSWORD=your-password

# Team Credentials
SALES_TEAM_USERNAME=sales_user
SALES_TEAM_PASSWORD=sales_secure_pass_123
MARKETING_TEAM_USERNAME=marketing_user
MARKETING_TEAM_PASSWORD=marketing_secure_pass_123
OPERATIONS_TEAM_USERNAME=operations_user
OPERATIONS_TEAM_PASSWORD=operations_secure_pass_123

# Claude API
ANTHROPIC_API_KEY=your-api-key
CLAUDE_MODEL=claude-sonnet-4-5-20250929
```

## Security

### Authentication
- Team-based credentials
- Session-based authentication
- HTTP-only cookies
- 24-hour session expiration

### Database
- Separate database per team
- User-level permissions
- No cross-team data access
- RDS security groups

### Production
- HTTPS/SSL required
- CORS restrictions
- Rate limiting (recommended)
- Environment variable protection

## Performance

### Local Development
- Backend startup: ~2-3 seconds
- SQL generation: ~1-2 seconds
- Query execution: <1 second (typical)

### Production (EC2 t3.small)
- Page load: <500ms
- API response: <200ms
- SQL generation: ~1-2 seconds
- Concurrent users: 50+ (estimated)

### Database
- Aurora Serverless v2: 0.5-1 ACU
- Auto-scaling based on load
- Query performance: <100ms (typical)

## Cost Estimate

**Monthly AWS Costs:**
- EC2 t3.small: ~$15
- Aurora Serverless v2: ~$40-90
- Data transfer: ~$5-10
- **Total: ~$60-115/month**

**Development costs:**
- Local development: Free (except Aurora)
- Claude API: Pay per token (~$0.01-0.10 per query)

## Monitoring

### Application Logs
```bash
# Backend logs
sudo tail -f /var/log/supervisor/sql-query-generator-backend.out.log

# Nginx access logs
sudo tail -f /var/log/nginx/access.log
```

### Health Checks
- Backend: `http://localhost:8080/health`
- Production: `http://your-domain.com/health`

### Metrics to Monitor
- API response times
- SQL generation latency
- Database query performance
- Error rates
- User sessions

## Troubleshooting

### Common Issues

**"Unable to connect to server"**
- Check backend is running on port 8080
- Disable ad blocker or use incognito mode
- Verify CORS settings

**"Database connection failed"**
- Check .env has correct DB_HOST
- Verify security groups allow EC2/local IP
- Test with psql manually

**"Failed to generate SQL"**
- Verify ANTHROPIC_API_KEY in .env
- Check Claude API quota/limits
- Review backend logs for errors

**502 Bad Gateway (Production)**
- Backend not running: `sudo supervisorctl status`
- Check backend logs
- Restart: `sudo supervisorctl restart sql-query-generator-backend`

## Development

### Adding New Features

1. **New API Endpoint**: Add to `backend/main.py`
2. **Frontend UI**: Update `frontend/dashboard.html` and `dashboard.js`
3. **Database Schema**: Modify schema files and re-run init
4. **New Team**: Add to .env and update auth.py

### Testing

```bash
# Test backend
curl http://localhost:8080/health

# Test authentication
curl -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username": "sales_user", "password": "sales_secure_pass_123"}'

# Test SQL generation
# (Use Swagger UI at http://localhost:8080/docs)
```

## Contributing

This is a POC/educational project. To extend it:

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Test locally
5. Deploy to EC2
6. Document changes

## License

Educational/POC project - use as needed for learning.

## Support

For issues or questions:
1. Check troubleshooting section
2. Review component READMEs
3. Check application logs
4. Verify environment configuration

## Acknowledgments

- **Anthropic Claude**: AI-powered SQL generation
- **FastAPI**: Modern Python web framework
- **PostgreSQL**: Reliable database
- **AWS**: Cloud infrastructure

## Future Enhancements

Potential improvements:
- [ ] Query history and favorites
- [ ] Export results to CSV/Excel
- [ ] Advanced query builder UI
- [ ] Multi-user collaboration
- [ ] Query performance analytics
- [ ] Custom data visualizations
- [ ] Integration with BI tools
- [ ] API rate limiting
- [ ] Advanced error recovery
- [ ] Query caching

---

**Version**: 1.0.0 (Phase 1 POC)  
**Last Updated**: January 2026
