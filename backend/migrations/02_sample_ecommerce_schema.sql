-- ===========================
-- Sample E-commerce Database Schema
-- This is the business database that users will query against
-- ===========================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ===========================
-- Users Table
-- ===========================
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- ===========================
-- Regions Table
-- ===========================
CREATE TABLE regions (
    region_id SERIAL PRIMARY KEY,
    region_name VARCHAR(100) NOT NULL UNIQUE,
    country VARCHAR(100) NOT NULL,
    tax_rate NUMERIC(4, 2) DEFAULT 0.00,
    shipping_cost NUMERIC(10, 2) DEFAULT 0.00
);

-- ===========================
-- Categories Table
-- ===========================
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    parent_category_id INTEGER REFERENCES categories(category_id),
    description TEXT
);

-- ===========================
-- Products Table
-- ===========================
CREATE TABLE products (
    product_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_name VARCHAR(255) NOT NULL,
    category_id INTEGER REFERENCES categories(category_id),
    sku VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    cost NUMERIC(10, 2) CHECK (cost >= 0),
    stock_quantity INTEGER DEFAULT 0 CHECK (stock_quantity >= 0),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ===========================
-- Orders Table
-- ===========================
CREATE TABLE orders (
    order_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id),
    region_id INTEGER REFERENCES regions(region_id),
    order_date TIMESTAMP DEFAULT NOW(),
    status VARCHAR(50) DEFAULT 'pending', -- pending, processing, shipped, delivered, cancelled
    total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
    tax_amount NUMERIC(10, 2) DEFAULT 0.00,
    shipping_amount NUMERIC(10, 2) DEFAULT 0.00,
    discount_amount NUMERIC(10, 2) DEFAULT 0.00,
    shipping_address TEXT,
    notes TEXT
);

-- ===========================
-- Order Items Table
-- ===========================
CREATE TABLE order_items (
    order_item_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(product_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    discount NUMERIC(10, 2) DEFAULT 0.00,
    subtotal NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0)
);

-- ===========================
-- Payments Table
-- ===========================
CREATE TABLE payments (
    payment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(order_id),
    payment_method VARCHAR(50) NOT NULL, -- credit_card, debit_card, paypal, bank_transfer
    payment_status VARCHAR(50) DEFAULT 'pending', -- pending, completed, failed, refunded
    amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
    transaction_id VARCHAR(255) UNIQUE,
    payment_date TIMESTAMP DEFAULT NOW()
);

-- ===========================
-- Reviews Table
-- ===========================
CREATE TABLE reviews (
    review_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID REFERENCES products(product_id),
    user_id UUID REFERENCES users(user_id),
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title VARCHAR(255),
    review_text TEXT,
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ===========================
-- Indexes for Performance
-- ===========================

-- Users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at DESC);
CREATE INDEX idx_users_active ON users(is_active) WHERE is_active = TRUE;

-- Products
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_active ON products(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_products_price ON products(price);

-- Orders
CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_region ON orders(region_id);
CREATE INDEX idx_orders_date ON orders(order_date DESC);
CREATE INDEX idx_orders_status ON orders(status);

-- Order Items
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);

-- Payments
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_status ON payments(payment_status);

-- Reviews
CREATE INDEX idx_reviews_product ON reviews(product_id);
CREATE INDEX idx_reviews_user ON reviews(user_id);
CREATE INDEX idx_reviews_rating ON reviews(rating);

-- ===========================
-- Sample Data: Regions
-- ===========================
INSERT INTO regions (region_name, country, tax_rate, shipping_cost) VALUES
('North America - East', 'USA', 8.50, 9.99),
('North America - West', 'USA', 7.25, 12.99),
('North America - Central', 'USA', 6.00, 8.99),
('Europe - West', 'UK', 20.00, 15.99),
('Europe - Central', 'Germany', 19.00, 12.99),
('Asia - East', 'Japan', 10.00, 18.99),
('Asia - Southeast', 'Singapore', 7.00, 14.99);

-- ===========================
-- Sample Data: Categories
-- ===========================
INSERT INTO categories (category_name, parent_category_id, description) VALUES
('Electronics', NULL, 'Electronic devices and accessories'),
('Computers', 1, 'Laptops, desktops, and computer accessories'),
('Mobile Devices', 1, 'Smartphones, tablets, and accessories'),
('Audio', 1, 'Headphones, speakers, and audio equipment'),
('Clothing', NULL, 'Apparel and fashion'),
('Men''s Clothing', 5, 'Clothing for men'),
('Women''s Clothing', 5, 'Clothing for women'),
('Home & Garden', NULL, 'Home improvement and garden supplies'),
('Furniture', 8, 'Indoor and outdoor furniture'),
('Kitchen', 8, 'Kitchen appliances and utensils');

-- ===========================
-- Sample Data: Products
-- ===========================
INSERT INTO products (product_name, category_id, sku, description, price, cost, stock_quantity) VALUES
-- Electronics
('Laptop Pro 15"', 2, 'LAPTOP-PRO-15', 'High-performance laptop with 16GB RAM', 1299.99, 899.99, 45),
('Laptop Air 13"', 2, 'LAPTOP-AIR-13', 'Lightweight laptop for everyday use', 899.99, 629.99, 62),
('Smartphone X', 3, 'PHONE-X-128', 'Latest smartphone with 128GB storage', 799.99, 549.99, 120),
('Smartphone Pro', 3, 'PHONE-PRO-256', 'Premium smartphone with 256GB storage', 1099.99, 749.99, 85),
('Wireless Earbuds', 4, 'EARBUDS-WIRELESS', 'Noise-cancelling wireless earbuds', 149.99, 79.99, 200),
('Studio Headphones', 4, 'HEADPHONES-STUDIO', 'Professional studio headphones', 299.99, 189.99, 75),
('Bluetooth Speaker', 4, 'SPEAKER-BT-20', 'Portable Bluetooth speaker', 79.99, 39.99, 150),

-- Clothing
('Men''s T-Shirt Classic', 6, 'MENS-TSHIRT-001', 'Cotton classic fit t-shirt', 24.99, 9.99, 500),
('Men''s Jeans Slim', 6, 'MENS-JEANS-SLIM', 'Slim fit denim jeans', 59.99, 29.99, 300),
('Women''s Dress Summer', 7, 'WOMENS-DRESS-SUM', 'Lightweight summer dress', 49.99, 24.99, 200),
('Women''s Jacket', 7, 'WOMENS-JACKET-01', 'All-season casual jacket', 89.99, 44.99, 150),

-- Home & Garden
('Office Chair Ergonomic', 9, 'CHAIR-OFFICE-ERG', 'Ergonomic office chair with lumbar support', 249.99, 149.99, 80),
('Dining Table Oak', 9, 'TABLE-DINING-OAK', '6-person oak dining table', 599.99, 349.99, 25),
('Coffee Maker Deluxe', 10, 'COFFEE-DELUXE-12', '12-cup programmable coffee maker', 89.99, 49.99, 100),
('Blender Pro 1000W', 10, 'BLENDER-PRO-1000', 'High-power blender for smoothies', 129.99, 69.99, 90);

-- ===========================
-- Sample Data: Users
-- ===========================
INSERT INTO users (email, first_name, last_name, phone, created_at, last_login) VALUES
('john.doe@email.com', 'John', 'Doe', '555-0101', NOW() - INTERVAL '365 days', NOW() - INTERVAL '2 days'),
('jane.smith@email.com', 'Jane', 'Smith', '555-0102', NOW() - INTERVAL '320 days', NOW() - INTERVAL '1 day'),
('bob.johnson@email.com', 'Bob', 'Johnson', '555-0103', NOW() - INTERVAL '280 days', NOW() - INTERVAL '5 days'),
('alice.williams@email.com', 'Alice', 'Williams', '555-0104', NOW() - INTERVAL '250 days', NOW() - INTERVAL '1 day'),
('charlie.brown@email.com', 'Charlie', 'Brown', '555-0105', NOW() - INTERVAL '200 days', NOW() - INTERVAL '10 days'),
('diana.miller@email.com', 'Diana', 'Miller', '555-0106', NOW() - INTERVAL '180 days', NOW() - INTERVAL '3 days'),
('evan.davis@email.com', 'Evan', 'Davis', '555-0107', NOW() - INTERVAL '150 days', NOW() - INTERVAL '1 day'),
('fiona.garcia@email.com', 'Fiona', 'Garcia', '555-0108', NOW() - INTERVAL '120 days', NOW() - INTERVAL '7 days'),
('george.martinez@email.com', 'George', 'Martinez', '555-0109', NOW() - INTERVAL '90 days', NOW() - INTERVAL '2 days'),
('hannah.rodriguez@email.com', 'Hannah', 'Rodriguez', '555-0110', NOW() - INTERVAL '60 days', NOW() - INTERVAL '1 day');

-- ===========================
-- Sample Data: Orders (Generate realistic order history)
-- ===========================

-- Function to generate random orders
DO $$
DECLARE
    v_user_id UUID;
    v_order_id UUID;
    v_region_id INTEGER;
    v_order_date TIMESTAMP;
    v_product_record RECORD;
    v_quantity INTEGER;
    v_subtotal NUMERIC(12, 2);
    v_total NUMERIC(12, 2);
    v_tax NUMERIC(10, 2);
    v_shipping NUMERIC(10, 2);
    v_status VARCHAR(50);
    i INTEGER;
BEGIN
    -- Generate 100 orders
    FOR i IN 1..100 LOOP
        -- Random user
        SELECT user_id INTO v_user_id FROM users ORDER BY RANDOM() LIMIT 1;
        
        -- Random region
        SELECT region_id INTO v_region_id FROM regions ORDER BY RANDOM() LIMIT 1;
        
        -- Random date in last 90 days
        v_order_date := NOW() - (RANDOM() * INTERVAL '90 days');
        
        -- Random status (weighted towards completed)
        v_status := CASE 
            WHEN RANDOM() < 0.7 THEN 'delivered'
            WHEN RANDOM() < 0.85 THEN 'shipped'
            WHEN RANDOM() < 0.95 THEN 'processing'
            ELSE 'cancelled'
        END;
        
        -- Get tax and shipping for region
        SELECT tax_rate, shipping_cost INTO v_tax, v_shipping FROM regions WHERE region_id = v_region_id;
        
        -- Create order
        v_order_id := uuid_generate_v4();
        
        v_total := 0;
        
        -- Add 1-5 random products to order
        FOR j IN 1..(1 + FLOOR(RANDOM() * 4)::INTEGER) LOOP
            SELECT product_id, price INTO v_product_record FROM products WHERE is_active = TRUE ORDER BY RANDOM() LIMIT 1;
            
            v_quantity := 1 + FLOOR(RANDOM() * 3)::INTEGER;
            v_subtotal := v_product_record.price * v_quantity;
            v_total := v_total + v_subtotal;
            
            INSERT INTO order_items (order_id, product_id, quantity, unit_price, subtotal)
            VALUES (v_order_id, v_product_record.product_id, v_quantity, v_product_record.price, v_subtotal);
        END LOOP;
        
        -- Calculate final amounts
        v_tax := v_total * (v_tax / 100);
        v_total := v_total + v_tax + v_shipping;
        
        INSERT INTO orders (order_id, user_id, region_id, order_date, status, total_amount, tax_amount, shipping_amount)
        VALUES (v_order_id, v_user_id, v_region_id, v_order_date, v_status, v_total, v_tax, v_shipping);
        
        -- Create payment if order is not cancelled
        IF v_status != 'cancelled' THEN
            INSERT INTO payments (order_id, payment_method, payment_status, amount, transaction_id, payment_date)
            VALUES (
                v_order_id,
                CASE WHEN RANDOM() < 0.7 THEN 'credit_card' ELSE 'paypal' END,
                CASE WHEN v_status = 'delivered' THEN 'completed' ELSE 'pending' END,
                v_total,
                'TXN-' || LPAD(i::TEXT, 8, '0'),
                v_order_date + INTERVAL '1 hour'
            );
        END IF;
    END LOOP;
END $$;

-- ===========================
-- Sample Data: Reviews
-- ===========================
INSERT INTO reviews (product_id, user_id, rating, title, review_text, helpful_count) 
SELECT 
    p.product_id,
    u.user_id,
    (3 + FLOOR(RANDOM() * 3))::INTEGER, -- Random rating 3-5
    'Great product!',
    'Very satisfied with this purchase. Would recommend to others.',
    FLOOR(RANDOM() * 50)::INTEGER
FROM products p
CROSS JOIN users u
WHERE RANDOM() < 0.15 -- 15% of product-user combinations get reviews
LIMIT 50;

-- ===========================
-- Views for Common Queries
-- ===========================

-- Revenue by region
CREATE OR REPLACE VIEW revenue_by_region AS
SELECT 
    r.region_name,
    r.country,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value
FROM orders o
JOIN regions r ON o.region_id = r.region_id
WHERE o.status != 'cancelled'
GROUP BY r.region_id, r.region_name, r.country
ORDER BY total_revenue DESC;

-- Top selling products
CREATE OR REPLACE VIEW top_selling_products AS
SELECT 
    p.product_name,
    c.category_name,
    COUNT(oi.order_item_id) as times_ordered,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.subtotal) as total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
GROUP BY p.product_id, p.product_name, c.category_name
ORDER BY total_revenue DESC;

-- Customer lifetime value
CREATE OR REPLACE VIEW customer_lifetime_value AS
SELECT 
    u.user_id,
    u.email,
    u.first_name || ' ' || u.last_name as full_name,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as lifetime_value,
    AVG(o.total_amount) as avg_order_value,
    MAX(o.order_date) as last_order_date
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id AND o.status != 'cancelled'
GROUP BY u.user_id, u.email, u.first_name, u.last_name
ORDER BY lifetime_value DESC NULLS LAST;

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO admin_user;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO admin_user;
