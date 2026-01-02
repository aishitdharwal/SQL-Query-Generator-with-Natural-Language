-- Operations Database Schema
-- E-commerce domain: Inventory, suppliers, warehouses, shipping

-- Warehouses table
CREATE TABLE warehouses (
    warehouse_id SERIAL PRIMARY KEY,
    warehouse_name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(50) NOT NULL,
    zip_code VARCHAR(20) NOT NULL,
    country VARCHAR(100) DEFAULT 'USA',
    capacity INTEGER, -- total capacity in units
    manager_name VARCHAR(200),
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Suppliers table
CREATE TABLE suppliers (
    supplier_id SERIAL PRIMARY KEY,
    supplier_name VARCHAR(200) NOT NULL,
    contact_name VARCHAR(200),
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    country VARCHAR(100),
    payment_terms VARCHAR(100),
    rating DECIMAL(3, 2), -- 0.00 to 5.00
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory table
CREATE TABLE inventory (
    inventory_id SERIAL PRIMARY KEY,
    warehouse_id INTEGER REFERENCES warehouses(warehouse_id),
    product_sku VARCHAR(100) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity_available INTEGER DEFAULT 0,
    quantity_reserved INTEGER DEFAULT 0,
    reorder_point INTEGER DEFAULT 10,
    reorder_quantity INTEGER DEFAULT 50,
    last_restocked_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Purchase Orders table
CREATE TABLE purchase_orders (
    po_id SERIAL PRIMARY KEY,
    supplier_id INTEGER REFERENCES suppliers(supplier_id),
    warehouse_id INTEGER REFERENCES warehouses(warehouse_id),
    order_date DATE NOT NULL,
    expected_delivery_date DATE,
    actual_delivery_date DATE,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending', -- pending, confirmed, shipped, received, cancelled
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Purchase Order Items table
CREATE TABLE po_items (
    po_item_id SERIAL PRIMARY KEY,
    po_id INTEGER REFERENCES purchase_orders(po_id),
    product_sku VARCHAR(100) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity_ordered INTEGER NOT NULL,
    quantity_received INTEGER DEFAULT 0,
    unit_cost DECIMAL(10, 2) NOT NULL,
    total_cost DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Shipments table
CREATE TABLE shipments (
    shipment_id SERIAL PRIMARY KEY,
    warehouse_id INTEGER REFERENCES warehouses(warehouse_id),
    order_reference VARCHAR(100), -- external order ID
    customer_name VARCHAR(200),
    shipping_address TEXT NOT NULL,
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    carrier VARCHAR(100),
    tracking_number VARCHAR(200),
    ship_date TIMESTAMP,
    estimated_delivery TIMESTAMP,
    actual_delivery TIMESTAMP,
    status VARCHAR(50) DEFAULT 'preparing', -- preparing, shipped, in_transit, delivered, returned
    shipping_cost DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Shipment Items table
CREATE TABLE shipment_items (
    shipment_item_id SERIAL PRIMARY KEY,
    shipment_id INTEGER REFERENCES shipments(shipment_id),
    product_sku VARCHAR(100) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory Movements table (track all inventory changes)
CREATE TABLE inventory_movements (
    movement_id SERIAL PRIMARY KEY,
    warehouse_id INTEGER REFERENCES warehouses(warehouse_id),
    product_sku VARCHAR(100) NOT NULL,
    movement_type VARCHAR(50) NOT NULL, -- inbound, outbound, adjustment, transfer
    quantity INTEGER NOT NULL,
    reference_type VARCHAR(50), -- purchase_order, shipment, adjustment
    reference_id INTEGER,
    notes TEXT,
    movement_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100)
);

-- Insert sample data

-- Sample Warehouses
INSERT INTO warehouses (warehouse_name, address, city, state, zip_code, capacity, manager_name, phone) VALUES
('East Coast Distribution Center', '1000 Warehouse Blvd', 'Newark', 'NJ', '07101', 100000, 'John Stevens', '555-3001'),
('West Coast Distribution Center', '2500 Logistics Way', 'Los Angeles', 'CA', '90001', 120000, 'Maria Lopez', '555-3002'),
('Central Warehouse', '750 Distribution Dr', 'Chicago', 'IL', '60601', 80000, 'Robert Chen', '555-3003'),
('Southern Hub', '1800 Commerce St', 'Dallas', 'TX', '75201', 90000, 'Sarah Johnson', '555-3004');

-- Sample Suppliers
INSERT INTO suppliers (supplier_name, contact_name, email, phone, address, city, state, country, payment_terms, rating) VALUES
('TechSupply Co', 'Mike Wilson', 'mike@techsupply.com', '555-4001', '500 Industrial Pkwy', 'San Jose', 'CA', 'USA', 'Net 30', 4.5),
('Global Electronics Ltd', 'Linda Zhang', 'linda@globalelec.com', '555-4002', '200 Tech Center', 'Austin', 'TX', 'USA', 'Net 45', 4.8),
('Accessory Warehouse Inc', 'Tom Harris', 'tom@accwarehouse.com', '555-4003', '1500 Parts Ave', 'Detroit', 'MI', 'USA', 'Net 30', 4.2),
('Phone Parts Direct', 'Amy Chen', 'amy@phonepartsdirect.com', '555-4004', '800 Component Rd', 'Raleigh', 'NC', 'USA', 'Net 60', 4.6),
('Premium Tech Supplies', 'David Lee', 'david@premiumtech.com', '555-4005', '300 Supply Chain Ln', 'Seattle', 'WA', 'USA', 'Net 30', 4.7);

-- Sample Inventory
INSERT INTO inventory (warehouse_id, product_sku, product_name, quantity_available, quantity_reserved, reorder_point, reorder_quantity, last_restocked_date) VALUES
-- East Coast
(1, 'LAP-PRO-15', 'Laptop Pro 15', 25, 5, 10, 30, '2024-11-15'),
(1, 'MSE-WRL-01', 'Wireless Mouse', 150, 10, 50, 100, '2024-11-20'),
(1, 'CBL-USBC-01', 'USB-C Cable', 300, 20, 100, 200, '2024-11-18'),
(1, 'PHN-SMX-01', 'Smartphone X', 40, 8, 15, 40, '2024-11-10'),
-- West Coast
(2, 'LAP-PRO-15', 'Laptop Pro 15', 30, 8, 10, 30, '2024-11-22'),
(2, 'HDP-BLT-01', 'Bluetooth Headphones', 80, 15, 30, 60, '2024-11-25'),
(2, 'CAS-PHN-01', 'Phone Case', 200, 25, 75, 150, '2024-11-28'),
(2, 'TAB-10-01', 'Tablet 10', 45, 5, 15, 35, '2024-11-12'),
-- Central
(3, 'WAT-SMT-01', 'Smart Watch', 60, 12, 20, 50, '2024-11-20'),
(3, 'CHG-PRT-01', 'Portable Charger', 180, 20, 80, 120, '2024-11-24'),
(3, 'SCR-PRT-01', 'Screen Protector', 250, 30, 120, 200, '2024-11-26'),
-- Southern
(4, 'PHN-SMX-01', 'Smartphone X', 35, 6, 15, 40, '2024-11-18'),
(4, 'HDP-BLT-01', 'Bluetooth Headphones', 55, 10, 30, 60, '2024-11-21'),
(4, 'TAB-10-01', 'Tablet 10', 25, 3, 15, 35, '2024-11-15');

-- Sample Purchase Orders
INSERT INTO purchase_orders (supplier_id, warehouse_id, order_date, expected_delivery_date, actual_delivery_date, total_amount, status, notes) VALUES
(1, 1, '2024-11-01', '2024-11-15', '2024-11-14', 38999.70, 'received', 'Regular stock replenishment'),
(2, 2, '2024-11-05', '2024-11-20', '2024-11-19', 35999.60, 'received', 'Smartphone restock'),
(3, 3, '2024-11-10', '2024-11-25', NULL, 7499.80, 'shipped', 'Accessory replenishment'),
(4, 1, '2024-11-15', '2024-12-01', NULL, 11249.75, 'confirmed', 'Phone parts order'),
(5, 2, '2024-11-20', '2024-12-05', NULL, 25999.00, 'pending', 'Premium laptop order');

-- Sample PO Items
INSERT INTO po_items (po_id, product_sku, product_name, quantity_ordered, quantity_received, unit_cost, total_cost) VALUES
-- PO 1
(1, 'LAP-PRO-15', 'Laptop Pro 15', 30, 30, 850.00, 25500.00),
(1, 'MSE-WRL-01', 'Wireless Mouse', 100, 100, 12.00, 1200.00),
(1, 'CBL-USBC-01', 'USB-C Cable', 250, 250, 5.00, 1250.00),
(1, 'PHN-SMX-01', 'Smartphone X', 20, 20, 600.00, 12000.00),
-- PO 2
(2, 'PHN-SMX-01', 'Smartphone X', 60, 60, 600.00, 36000.00),
-- PO 3
(3, 'HDP-BLT-01', 'Bluetooth Headphones', 100, 0, 75.00, 7500.00),
-- PO 4
(4, 'CAS-PHN-01', 'Phone Case', 150, 0, 8.00, 1200.00),
(4, 'SCR-PRT-01', 'Screen Protector', 250, 0, 3.00, 750.00),
-- PO 5
(5, 'LAP-PRO-15', 'Laptop Pro 15', 30, 0, 866.00, 25980.00);

-- Sample Shipments
INSERT INTO shipments (warehouse_id, order_reference, customer_name, shipping_address, city, state, zip_code, carrier, tracking_number, ship_date, estimated_delivery, actual_delivery, status, shipping_cost) VALUES
(1, 'ORD-001', 'John Doe', '123 Main St', 'New York', 'NY', '10001', 'FedEx', 'FX123456789', '2024-12-01 10:00:00', '2024-12-03 17:00:00', '2024-12-03 15:30:00', 'delivered', 15.00),
(2, 'ORD-002', 'Jane Smith', '456 Oak Ave', 'Los Angeles', 'CA', '90001', 'UPS', 'UP987654321', '2024-12-02 11:00:00', '2024-12-04 17:00:00', '2024-12-04 16:00:00', 'delivered', 10.00),
(3, 'ORD-003', 'Robert Johnson', '789 Pine Rd', 'Chicago', 'IL', '60601', 'USPS', 'US555666777', '2024-12-03 09:00:00', '2024-12-05 17:00:00', NULL, 'in_transit', 0.00),
(1, 'ORD-004', 'Emily Williams', '321 Elm St', 'Houston', 'TX', '77001', 'FedEx', 'FX222333444', '2024-12-06 14:00:00', '2024-12-08 17:00:00', NULL, 'shipped', 12.00),
(2, 'ORD-005', 'Michael Brown', '654 Maple Dr', 'Phoenix', 'AZ', '85001', 'UPS', 'UP111222333', '2024-12-07 10:00:00', '2024-12-09 17:00:00', NULL, 'preparing', 20.00);

-- Sample Shipment Items
INSERT INTO shipment_items (shipment_id, product_sku, product_name, quantity) VALUES
-- Shipment 1
(1, 'LAP-PRO-15', 'Laptop Pro 15', 1),
(1, 'MSE-WRL-01', 'Wireless Mouse', 1),
(1, 'CBL-USBC-01', 'USB-C Cable', 1),
-- Shipment 2
(2, 'HDP-BLT-01', 'Bluetooth Headphones', 1),
(2, 'MSE-WRL-01', 'Wireless Mouse', 1),
-- Shipment 3
(3, 'PHN-SMX-01', 'Smartphone X', 1),
-- Shipment 4
(4, 'CBL-USBC-01', 'USB-C Cable', 2),
(4, 'MSE-WRL-01', 'Wireless Mouse', 1),
-- Shipment 5
(5, 'LAP-PRO-15', 'Laptop Pro 15', 1);

-- Sample Inventory Movements
INSERT INTO inventory_movements (warehouse_id, product_sku, movement_type, quantity, reference_type, reference_id, notes, created_by) VALUES
(1, 'LAP-PRO-15', 'inbound', 30, 'purchase_order', 1, 'PO received', 'system'),
(1, 'LAP-PRO-15', 'outbound', -1, 'shipment', 1, 'Customer order', 'system'),
(2, 'PHN-SMX-01', 'inbound', 60, 'purchase_order', 2, 'PO received', 'system'),
(2, 'HDP-BLT-01', 'outbound', -1, 'shipment', 2, 'Customer order', 'system'),
(1, 'MSE-WRL-01', 'adjustment', 5, 'adjustment', NULL, 'Found additional stock during audit', 'admin'),
(3, 'CHG-PRT-01', 'outbound', -10, 'shipment', NULL, 'Bulk order fulfillment', 'system');

-- Create indexes
CREATE INDEX idx_inventory_warehouse_id ON inventory(warehouse_id);
CREATE INDEX idx_inventory_product_sku ON inventory(product_sku);
CREATE INDEX idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);
CREATE INDEX idx_purchase_orders_status ON purchase_orders(status);
CREATE INDEX idx_po_items_po_id ON po_items(po_id);
CREATE INDEX idx_shipments_warehouse_id ON shipments(warehouse_id);
CREATE INDEX idx_shipments_status ON shipments(status);
CREATE INDEX idx_shipment_items_shipment_id ON shipment_items(shipment_id);
CREATE INDEX idx_inventory_movements_warehouse_id ON inventory_movements(warehouse_id);
CREATE INDEX idx_inventory_movements_product_sku ON inventory_movements(product_sku);
