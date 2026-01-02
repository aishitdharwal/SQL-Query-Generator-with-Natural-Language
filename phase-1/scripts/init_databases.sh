#!/bin/bash

# Initialize databases and tables for each team
# Run this after Aurora cluster is created

set -e

echo "=========================================="
echo "Initializing Databases and Tables"
echo "=========================================="
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found. Please create it from .env.example"
    exit 1
fi

echo "Connecting to: $DB_HOST"
echo ""

# Create databases for each team
echo "Step 1: Creating databases..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d postgres -c "CREATE DATABASE sales_db;" 2>/dev/null || echo "sales_db already exists"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d postgres -c "CREATE DATABASE marketing_db;" 2>/dev/null || echo "marketing_db already exists"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d postgres -c "CREATE DATABASE operations_db;" 2>/dev/null || echo "operations_db already exists"

echo ""
echo "Step 2: Creating tables in sales_db..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d sales_db <<EOF
-- Customers table
CREATE TABLE IF NOT EXISTS customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(50),
    state VARCHAR(50),
    country VARCHAR(50),
    postal_code VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products table
CREATE TABLE IF NOT EXISTS products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    shipping_address TEXT,
    payment_method VARCHAR(50)
);

-- Order Items table
CREATE TABLE IF NOT EXISTS order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id),
    product_id INTEGER REFERENCES products(product_id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL
);

-- Sales Representatives table
CREATE TABLE IF NOT EXISTS sales_reps (
    rep_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    region VARCHAR(50),
    hire_date DATE,
    commission_rate DECIMAL(5, 2)
);

-- Insert sample data for sales_db
INSERT INTO customers (first_name, last_name, email, phone, city, state, country, postal_code) VALUES
('John', 'Doe', 'john.doe@email.com', '+1-555-0101', 'New York', 'NY', 'USA', '10001'),
('Jane', 'Smith', 'jane.smith@email.com', '+1-555-0102', 'Los Angeles', 'CA', 'USA', '90001'),
('Robert', 'Johnson', 'robert.j@email.com', '+1-555-0103', 'Chicago', 'IL', 'USA', '60601'),
('Emily', 'Williams', 'emily.w@email.com', '+1-555-0104', 'Houston', 'TX', 'USA', '77001'),
('Michael', 'Brown', 'michael.b@email.com', '+1-555-0105', 'Phoenix', 'AZ', 'USA', '85001')
ON CONFLICT (email) DO NOTHING;

INSERT INTO products (product_name, category, price, stock_quantity, description) VALUES
('Laptop Pro 15', 'Electronics', 1299.99, 50, 'High-performance laptop with 15-inch display'),
('Wireless Mouse', 'Electronics', 29.99, 200, 'Ergonomic wireless mouse'),
('Office Chair', 'Furniture', 249.99, 75, 'Comfortable ergonomic office chair'),
('Desk Lamp', 'Furniture', 39.99, 150, 'LED desk lamp with adjustable brightness'),
('Notebook Set', 'Stationery', 12.99, 500, 'Pack of 3 premium notebooks'),
('Smartphone X', 'Electronics', 899.99, 100, 'Latest smartphone with advanced features'),
('Tablet Pro', 'Electronics', 599.99, 80, '10-inch tablet for productivity'),
('Headphones', 'Electronics', 149.99, 120, 'Noise-canceling headphones')
ON CONFLICT DO NOTHING;

INSERT INTO sales_reps (first_name, last_name, email, phone, region, hire_date, commission_rate) VALUES
('Sarah', 'Connor', 'sarah.connor@company.com', '+1-555-0201', 'Northeast', '2023-01-15', 5.5),
('James', 'Miller', 'james.miller@company.com', '+1-555-0202', 'West', '2023-03-20', 6.0),
('Lisa', 'Anderson', 'lisa.anderson@company.com', '+1-555-0203', 'South', '2022-11-10', 5.0)
ON CONFLICT (email) DO NOTHING;

INSERT INTO orders (customer_id, order_date, total_amount, status, payment_method) VALUES
(1, '2024-01-15 10:30:00', 1329.98, 'delivered', 'Credit Card'),
(2, '2024-01-16 14:20:00', 249.99, 'delivered', 'PayPal'),
(3, '2024-01-17 09:15:00', 899.99, 'shipped', 'Credit Card'),
(1, '2024-01-18 16:45:00', 52.98, 'delivered', 'Credit Card'),
(4, '2024-01-19 11:00:00', 599.99, 'processing', 'Debit Card'),
(5, '2024-01-20 13:30:00', 1449.98, 'pending', 'Credit Card')
ON CONFLICT DO NOTHING;

INSERT INTO order_items (order_id, product_id, quantity, unit_price, subtotal) VALUES
(1, 1, 1, 1299.99, 1299.99),
(1, 2, 1, 29.99, 29.99),
(2, 3, 1, 249.99, 249.99),
(3, 6, 1, 899.99, 899.99),
(4, 4, 1, 39.99, 39.99),
(4, 5, 1, 12.99, 12.99),
(5, 7, 1, 599.99, 599.99),
(6, 1, 1, 1299.99, 1299.99),
(6, 8, 1, 149.99, 149.99)
ON CONFLICT DO NOTHING;
EOF

echo ""
echo "Step 3: Creating tables in marketing_db..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d marketing_db <<EOF
-- Campaigns table
CREATE TABLE IF NOT EXISTS campaigns (
    campaign_id SERIAL PRIMARY KEY,
    campaign_name VARCHAR(100) NOT NULL,
    campaign_type VARCHAR(50),
    start_date DATE,
    end_date DATE,
    budget DECIMAL(10, 2),
    status VARCHAR(20) DEFAULT 'active',
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Email Campaigns table
CREATE TABLE IF NOT EXISTS email_campaigns (
    email_campaign_id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(campaign_id),
    subject_line VARCHAR(200),
    sent_date TIMESTAMP,
    total_sent INTEGER,
    total_opened INTEGER,
    total_clicked INTEGER,
    conversion_rate DECIMAL(5, 2)
);

-- Social Media Posts table
CREATE TABLE IF NOT EXISTS social_media_posts (
    post_id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(campaign_id),
    platform VARCHAR(50),
    post_date TIMESTAMP,
    content TEXT,
    likes INTEGER DEFAULT 0,
    shares INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    impressions INTEGER DEFAULT 0
);

-- Leads table
CREATE TABLE IF NOT EXISTS leads (
    lead_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    company VARCHAR(100),
    source VARCHAR(50),
    status VARCHAR(20) DEFAULT 'new',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data for marketing_db
INSERT INTO campaigns (campaign_name, campaign_type, start_date, end_date, budget, status, description) VALUES
('Summer Sale 2024', 'Promotional', '2024-06-01', '2024-08-31', 50000.00, 'active', 'Summer discount campaign'),
('Product Launch - Smartphone X', 'Product Launch', '2024-01-01', '2024-03-31', 75000.00, 'completed', 'Launch campaign for new smartphone'),
('Holiday Season', 'Seasonal', '2024-11-01', '2024-12-31', 100000.00, 'planned', 'Holiday shopping campaign'),
('Back to School', 'Seasonal', '2024-08-01', '2024-09-15', 40000.00, 'active', 'Back to school promotions')
ON CONFLICT DO NOTHING;

INSERT INTO email_campaigns (campaign_id, subject_line, sent_date, total_sent, total_opened, total_clicked, conversion_rate) VALUES
(1, 'Hot Summer Deals - Up to 50% Off!', '2024-06-15 09:00:00', 10000, 3500, 875, 8.75),
(2, 'Introducing Smartphone X - Pre-order Now', '2024-01-10 10:00:00', 15000, 6000, 1800, 12.00),
(1, 'Last Chance - Summer Sale Ending Soon', '2024-08-25 09:00:00', 10000, 4200, 1260, 12.60),
(4, 'Save Big on Back to School Essentials', '2024-08-05 08:00:00', 8000, 2800, 560, 7.00)
ON CONFLICT DO NOTHING;

INSERT INTO social_media_posts (campaign_id, platform, post_date, content, likes, shares, comments, impressions) VALUES
(1, 'Facebook', '2024-06-01 12:00:00', 'Summer is here! Check out our amazing deals!', 1250, 340, 89, 45000),
(1, 'Instagram', '2024-06-01 12:00:00', 'Summer is here! Check out our amazing deals!', 2100, 520, 156, 67000),
(2, 'Twitter', '2024-01-01 10:00:00', 'Revolutionary Smartphone X is here! Pre-order now!', 3400, 890, 234, 120000),
(2, 'LinkedIn', '2024-01-01 10:00:00', 'Introducing our latest innovation - Smartphone X', 890, 234, 67, 34000),
(4, 'Instagram', '2024-08-01 09:00:00', 'Get ready for school with our special offers!', 1560, 420, 123, 52000)
ON CONFLICT DO NOTHING;

INSERT INTO leads (first_name, last_name, email, phone, company, source, status) VALUES
('Alice', 'Thompson', 'alice.t@company.com', '+1-555-0301', 'Tech Corp', 'Website Form', 'qualified'),
('David', 'Martinez', 'david.m@business.com', '+1-555-0302', 'Business Solutions', 'LinkedIn', 'new'),
('Sophie', 'Garcia', 'sophie.g@startup.com', '+1-555-0303', 'Innovation Startup', 'Referral', 'contacted'),
('Chris', 'Lee', 'chris.l@enterprise.com', '+1-555-0304', 'Enterprise Inc', 'Trade Show', 'qualified'),
('Maria', 'Rodriguez', 'maria.r@solutions.com', '+1-555-0305', 'Smart Solutions', 'Email Campaign', 'new')
ON CONFLICT (email) DO NOTHING;
EOF

echo ""
echo "Step 4: Creating tables in operations_db..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d operations_db <<EOF
-- Warehouses table
CREATE TABLE IF NOT EXISTS warehouses (
    warehouse_id SERIAL PRIMARY KEY,
    warehouse_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    country VARCHAR(50),
    capacity INTEGER,
    manager_name VARCHAR(100)
);

-- Inventory table
CREATE TABLE IF NOT EXISTS inventory (
    inventory_id SERIAL PRIMARY KEY,
    warehouse_id INTEGER REFERENCES warehouses(warehouse_id),
    product_name VARCHAR(100) NOT NULL,
    sku VARCHAR(50) UNIQUE,
    quantity INTEGER DEFAULT 0,
    reorder_level INTEGER,
    last_restocked TIMESTAMP,
    unit_cost DECIMAL(10, 2)
);

-- Suppliers table
CREATE TABLE IF NOT EXISTS suppliers (
    supplier_id SERIAL PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    contact_person VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(50),
    country VARCHAR(50),
    rating DECIMAL(3, 2)
);

-- Shipments table
CREATE TABLE IF NOT EXISTS shipments (
    shipment_id SERIAL PRIMARY KEY,
    warehouse_id INTEGER REFERENCES warehouses(warehouse_id),
    order_id INTEGER,
    shipment_date TIMESTAMP,
    expected_delivery DATE,
    actual_delivery DATE,
    carrier VARCHAR(50),
    tracking_number VARCHAR(100),
    status VARCHAR(20) DEFAULT 'pending'
);

-- Employees table
CREATE TABLE IF NOT EXISTS employees (
    employee_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    department VARCHAR(50),
    position VARCHAR(50),
    warehouse_id INTEGER REFERENCES warehouses(warehouse_id),
    hire_date DATE,
    salary DECIMAL(10, 2)
);

-- Insert sample data for operations_db
INSERT INTO warehouses (warehouse_name, location, city, state, country, capacity, manager_name) VALUES
('East Coast Distribution Center', '123 Warehouse Blvd', 'Newark', 'NJ', 'USA', 100000, 'Tom Harris'),
('West Coast Fulfillment', '456 Logistics Ave', 'Los Angeles', 'CA', 'USA', 85000, 'Jennifer White'),
('Midwest Hub', '789 Distribution Dr', 'Chicago', 'IL', 'USA', 95000, 'Mark Davis'),
('South Regional Center', '321 Supply Chain Rd', 'Atlanta', 'GA', 'USA', 75000, 'Patricia Moore')
ON CONFLICT DO NOTHING;

INSERT INTO inventory (warehouse_id, product_name, sku, quantity, reorder_level, last_restocked, unit_cost) VALUES
(1, 'Laptop Pro 15', 'ELEC-LP15-001', 125, 30, '2024-01-10 08:00:00', 950.00),
(1, 'Wireless Mouse', 'ELEC-WM-002', 450, 100, '2024-01-12 10:00:00', 15.99),
(2, 'Office Chair', 'FURN-OC-003', 200, 50, '2024-01-08 14:00:00', 180.00),
(2, 'Desk Lamp', 'FURN-DL-004', 350, 80, '2024-01-15 09:00:00', 22.50),
(3, 'Notebook Set', 'STAT-NB-005', 1500, 300, '2024-01-05 11:00:00', 7.99),
(3, 'Smartphone X', 'ELEC-SP-006', 250, 60, '2024-01-18 13:00:00', 650.00),
(4, 'Tablet Pro', 'ELEC-TB-007', 180, 40, '2024-01-14 15:00:00', 425.00),
(1, 'Headphones', 'ELEC-HP-008', 300, 70, '2024-01-16 12:00:00', 95.00)
ON CONFLICT (sku) DO NOTHING;

INSERT INTO suppliers (supplier_name, contact_person, email, phone, city, country, rating) VALUES
('Global Tech Supplies', 'Kevin Zhang', 'kevin@globaltech.com', '+1-555-0401', 'San Francisco', 'USA', 4.8),
('Office Furniture Direct', 'Laura Mitchell', 'laura@officefurn.com', '+1-555-0402', 'Grand Rapids', 'USA', 4.5),
('Stationery Wholesale Co', 'Andrew Scott', 'andrew@statwholesale.com', '+1-555-0403', 'Boston', 'USA', 4.6),
('Premium Electronics', 'Rachel Kim', 'rachel@premelec.com', '+1-555-0404', 'Seattle', 'USA', 4.9),
('Quality Goods Inc', 'Daniel Park', 'daniel@qualitygoods.com', '+1-555-0405', 'Dallas', 'USA', 4.7)
ON CONFLICT DO NOTHING;

INSERT INTO shipments (warehouse_id, order_id, shipment_date, expected_delivery, carrier, tracking_number, status) VALUES
(1, 1001, '2024-01-15 14:00:00', '2024-01-18', 'FedEx', 'FDX123456789', 'delivered'),
(2, 1002, '2024-01-16 09:00:00', '2024-01-20', 'UPS', 'UPS987654321', 'in_transit'),
(1, 1003, '2024-01-17 11:00:00', '2024-01-19', 'DHL', 'DHL456789123', 'delivered'),
(3, 1004, '2024-01-18 15:30:00', '2024-01-22', 'FedEx', 'FDX789123456', 'in_transit'),
(4, 1005, '2024-01-19 10:00:00', '2024-01-23', 'USPS', 'USPS321654987', 'pending')
ON CONFLICT DO NOTHING;

INSERT INTO employees (first_name, last_name, email, phone, department, position, warehouse_id, hire_date, salary) VALUES
('Tom', 'Harris', 'tom.harris@company.com', '+1-555-0501', 'Operations', 'Warehouse Manager', 1, '2020-03-15', 75000.00),
('Jennifer', 'White', 'jennifer.white@company.com', '+1-555-0502', 'Operations', 'Warehouse Manager', 2, '2019-07-20', 78000.00),
('Mark', 'Davis', 'mark.davis@company.com', '+1-555-0503', 'Operations', 'Warehouse Manager', 3, '2021-01-10', 72000.00),
('Patricia', 'Moore', 'patricia.moore@company.com', '+1-555-0504', 'Operations', 'Warehouse Manager', 4, '2020-11-05', 74000.00),
('Alex', 'Turner', 'alex.turner@company.com', '+1-555-0505', 'Operations', 'Inventory Specialist', 1, '2022-04-12', 52000.00),
('Nina', 'Patel', 'nina.patel@company.com', '+1-555-0506', 'Operations', 'Logistics Coordinator', 2, '2021-09-18', 55000.00)
ON CONFLICT (email) DO NOTHING;
EOF

echo ""
echo "=========================================="
echo "Database Initialization Complete!"
echo "=========================================="
echo ""
echo "Databases created:"
echo "  - sales_db (5 tables with sample data)"
echo "  - marketing_db (4 tables with sample data)"
echo "  - operations_db (5 tables with sample data)"
echo ""
echo "You can now run the application!"
echo ""
