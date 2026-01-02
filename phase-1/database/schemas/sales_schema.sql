-- Sales Database Schema
-- E-commerce domain: Customer orders, products, sales transactions

-- Customers table
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    country VARCHAR(100) DEFAULT 'USA',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products table
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    brand VARCHAR(100),
    price DECIMAL(10, 2) NOT NULL,
    cost DECIMAL(10, 2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Orders table
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10, 2) NOT NULL,
    discount_amount DECIMAL(10, 2) DEFAULT 0,
    tax_amount DECIMAL(10, 2) DEFAULT 0,
    shipping_cost DECIMAL(10, 2) DEFAULT 0,
    status VARCHAR(50) DEFAULT 'pending',
    payment_method VARCHAR(50),
    shipping_address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Order Items table
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id),
    product_id INTEGER REFERENCES products(product_id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sales Representatives table
CREATE TABLE sales_representatives (
    rep_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    region VARCHAR(100),
    hire_date DATE,
    commission_rate DECIMAL(5, 2) DEFAULT 5.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sales Assignments (which rep handles which customer)
CREATE TABLE sales_assignments (
    assignment_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    rep_id INTEGER REFERENCES sales_representatives(rep_id),
    assigned_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Insert sample data

-- Sample Customers
INSERT INTO customers (first_name, last_name, email, phone, address, city, state, zip_code) VALUES
('John', 'Doe', 'john.doe@email.com', '555-0101', '123 Main St', 'New York', 'NY', '10001'),
('Jane', 'Smith', 'jane.smith@email.com', '555-0102', '456 Oak Ave', 'Los Angeles', 'CA', '90001'),
('Robert', 'Johnson', 'robert.j@email.com', '555-0103', '789 Pine Rd', 'Chicago', 'IL', '60601'),
('Emily', 'Williams', 'emily.w@email.com', '555-0104', '321 Elm St', 'Houston', 'TX', '77001'),
('Michael', 'Brown', 'michael.b@email.com', '555-0105', '654 Maple Dr', 'Phoenix', 'AZ', '85001'),
('Sarah', 'Davis', 'sarah.d@email.com', '555-0106', '987 Cedar Ln', 'Philadelphia', 'PA', '19101'),
('David', 'Miller', 'david.m@email.com', '555-0107', '147 Birch Blvd', 'San Antonio', 'TX', '78201'),
('Lisa', 'Wilson', 'lisa.w@email.com', '555-0108', '258 Spruce Way', 'San Diego', 'CA', '92101'),
('James', 'Moore', 'james.m@email.com', '555-0109', '369 Ash Ct', 'Dallas', 'TX', '75201'),
('Jennifer', 'Taylor', 'jennifer.t@email.com', '555-0110', '741 Willow Pl', 'San Jose', 'CA', '95101');

-- Sample Products
INSERT INTO products (product_name, category, brand, price, cost, stock_quantity, description) VALUES
('Laptop Pro 15', 'Electronics', 'TechBrand', 1299.99, 850.00, 50, 'High-performance laptop with 16GB RAM'),
('Wireless Mouse', 'Electronics', 'TechBrand', 29.99, 12.00, 200, 'Ergonomic wireless mouse'),
('USB-C Cable', 'Accessories', 'TechBrand', 19.99, 5.00, 500, 'Fast charging USB-C cable'),
('Smartphone X', 'Electronics', 'PhoneCo', 899.99, 600.00, 100, 'Latest smartphone with 5G'),
('Bluetooth Headphones', 'Electronics', 'AudioMax', 149.99, 75.00, 150, 'Noise-canceling headphones'),
('Phone Case', 'Accessories', 'PhoneCo', 24.99, 8.00, 300, 'Protective phone case'),
('Tablet 10', 'Electronics', 'TechBrand', 499.99, 325.00, 75, '10-inch tablet with stylus'),
('Smart Watch', 'Electronics', 'TechBrand', 349.99, 200.00, 120, 'Fitness tracking smart watch'),
('Portable Charger', 'Accessories', 'PowerPlus', 49.99, 20.00, 250, '20000mAh portable charger'),
('Screen Protector', 'Accessories', 'ProtectAll', 14.99, 3.00, 400, 'Tempered glass screen protector');

-- Sample Sales Representatives
INSERT INTO sales_representatives (first_name, last_name, email, phone, region, hire_date, commission_rate) VALUES
('Tom', 'Anderson', 'tom.anderson@company.com', '555-1001', 'Northeast', '2022-01-15', 5.50),
('Maria', 'Garcia', 'maria.garcia@company.com', '555-1002', 'West', '2021-06-20', 6.00),
('Chris', 'Martinez', 'chris.martinez@company.com', '555-1003', 'South', '2023-03-10', 5.00),
('Amy', 'Lee', 'amy.lee@company.com', '555-1004', 'Midwest', '2022-09-01', 5.50);

-- Sample Sales Assignments
INSERT INTO sales_assignments (customer_id, rep_id) VALUES
(1, 1), (2, 2), (3, 4), (4, 3), (5, 3),
(6, 1), (7, 3), (8, 2), (9, 3), (10, 2);

-- Sample Orders
INSERT INTO orders (customer_id, order_date, total_amount, discount_amount, tax_amount, shipping_cost, status, payment_method, shipping_address) VALUES
(1, '2024-12-01 10:30:00', 1349.98, 50.00, 104.00, 15.00, 'delivered', 'credit_card', '123 Main St, New York, NY 10001'),
(2, '2024-12-02 14:15:00', 179.98, 0.00, 14.40, 10.00, 'delivered', 'paypal', '456 Oak Ave, Los Angeles, CA 90001'),
(3, '2024-12-03 09:45:00', 899.99, 0.00, 72.00, 0.00, 'shipped', 'credit_card', '789 Pine Rd, Chicago, IL 60601'),
(1, '2024-12-05 16:20:00', 69.97, 10.00, 4.80, 5.00, 'processing', 'credit_card', '123 Main St, New York, NY 10001'),
(4, '2024-12-06 11:00:00', 549.98, 25.00, 42.00, 12.00, 'delivered', 'debit_card', '321 Elm St, Houston, TX 77001'),
(5, '2024-12-07 13:30:00', 1299.99, 0.00, 104.00, 20.00, 'shipped', 'credit_card', '654 Maple Dr, Phoenix, AZ 85001'),
(2, '2024-12-08 10:00:00', 74.97, 5.00, 5.60, 8.00, 'delivered', 'paypal', '456 Oak Ave, Los Angeles, CA 90001'),
(6, '2024-12-09 15:45:00', 349.99, 0.00, 28.00, 10.00, 'processing', 'credit_card', '987 Cedar Ln, Philadelphia, PA 19101'),
(7, '2024-12-10 09:15:00', 199.97, 20.00, 14.40, 10.00, 'shipped', 'debit_card', '147 Birch Blvd, San Antonio, TX 78201'),
(8, '2024-12-11 14:30:00', 924.98, 50.00, 70.00, 15.00, 'delivered', 'credit_card', '258 Spruce Way, San Diego, CA 92101');

-- Sample Order Items
INSERT INTO order_items (order_id, product_id, quantity, unit_price, subtotal) VALUES
-- Order 1
(1, 1, 1, 1299.99, 1299.99),
(1, 2, 1, 29.99, 29.99),
(1, 3, 1, 19.99, 19.99),
-- Order 2
(2, 5, 1, 149.99, 149.99),
(2, 2, 1, 29.99, 29.99),
-- Order 3
(3, 4, 1, 899.99, 899.99),
-- Order 4
(4, 3, 2, 19.99, 39.98),
(4, 2, 1, 29.99, 29.99),
-- Order 5
(5, 7, 1, 499.99, 499.99),
(5, 9, 1, 49.99, 49.99),
-- Order 6
(6, 1, 1, 1299.99, 1299.99),
-- Order 7
(7, 6, 3, 24.99, 74.97),
-- Order 8
(8, 8, 1, 349.99, 349.99),
-- Order 9
(9, 5, 1, 149.99, 149.99),
(9, 9, 1, 49.99, 49.99),
-- Order 10
(10, 4, 1, 899.99, 899.99),
(10, 6, 1, 24.99, 24.99);

-- Create indexes for better query performance
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_sales_assignments_customer_id ON sales_assignments(customer_id);
CREATE INDEX idx_sales_assignments_rep_id ON sales_assignments(rep_id);
