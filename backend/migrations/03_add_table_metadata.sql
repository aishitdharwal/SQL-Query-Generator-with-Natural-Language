-- Add table metadata for Demo Team
-- This allows the schema_manager to find the tables

-- First, get the demo team's schema_id
DO $$
DECLARE
    v_team_id UUID;
    v_schema_id UUID;
BEGIN
    -- Get demo team ID
    SELECT team_id INTO v_team_id
    FROM teams
    WHERE team_name = 'Demo Team';
    
    IF v_team_id IS NULL THEN
        RAISE EXCEPTION 'Demo Team not found!';
    END IF;
    
    RAISE NOTICE 'Demo Team ID: %', v_team_id;
    
    -- Get or create schema for demo team
    SELECT schema_id INTO v_schema_id
    FROM database_schemas
    WHERE team_id = v_team_id;
    
    IF v_schema_id IS NULL THEN
        -- Create schema entry
        INSERT INTO database_schemas (team_id, schema_name)
        VALUES (v_team_id, 'ecommerce')
        RETURNING schema_id INTO v_schema_id;
        
        RAISE NOTICE 'Created schema_id: %', v_schema_id;
    ELSE
        RAISE NOTICE 'Existing schema_id: %', v_schema_id;
    END IF;
    
    -- Now insert table metadata
    -- Delete existing metadata first to allow re-running
    DELETE FROM tables_metadata WHERE schema_id = v_schema_id;
    
    -- Insert users table
    INSERT INTO tables_metadata (schema_id, table_name, table_ddl, description)
    VALUES (
        v_schema_id,
        'users',
        'CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    region_id INTEGER REFERENCES regions(region_id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);',
        'Customer user accounts with contact and location information'
    );
    
    -- Insert regions table
    INSERT INTO tables_metadata (schema_id, table_name, table_ddl, description)
    VALUES (
        v_schema_id,
        'regions',
        'CREATE TABLE regions (
    region_id SERIAL PRIMARY KEY,
    region_name VARCHAR(100) NOT NULL,
    country VARCHAR(100),
    description TEXT
);',
        'Geographic regions for sales and shipping'
    );
    
    -- Insert categories table
    INSERT INTO tables_metadata (schema_id, table_name, table_ddl, description)
    VALUES (
        v_schema_id,
        'categories',
        'CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    parent_category_id INTEGER REFERENCES categories(category_id),
    description TEXT
);',
        'Product categories with hierarchical structure'
    );
    
    -- Insert products table
    INSERT INTO tables_metadata (schema_id, table_name, table_ddl, description)
    VALUES (
        v_schema_id,
        'products',
        'CREATE TABLE products (
    product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_name VARCHAR(255) NOT NULL,
    category_id INTEGER REFERENCES categories(category_id),
    description TEXT,
    price DECIMAL(10, 2),
    cost DECIMAL(10, 2),
    stock_quantity INTEGER DEFAULT 0,
    sku VARCHAR(100) UNIQUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);',
        'Product catalog with pricing and inventory'
    );
    
    -- Insert orders table
    INSERT INTO tables_metadata (schema_id, table_name, table_ddl, description)
    VALUES (
        v_schema_id,
        'orders',
        'CREATE TABLE orders (
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id),
    order_date TIMESTAMP DEFAULT NOW(),
    status VARCHAR(50),
    total_amount DECIMAL(10, 2),
    shipping_address_line1 VARCHAR(255),
    shipping_address_line2 VARCHAR(255),
    shipping_city VARCHAR(100),
    shipping_state VARCHAR(50),
    shipping_postal_code VARCHAR(20),
    shipping_country VARCHAR(100),
    region_id INTEGER REFERENCES regions(region_id)
);',
        'Customer orders with shipping details'
    );
    
    -- Insert order_items table
    INSERT INTO tables_metadata (schema_id, table_name, table_ddl, description)
    VALUES (
        v_schema_id,
        'order_items',
        'CREATE TABLE order_items (
    order_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(order_id),
    product_id UUID REFERENCES products(product_id),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2),
    discount_amount DECIMAL(10, 2) DEFAULT 0
);',
        'Line items for each order with pricing details'
    );
    
    RAISE NOTICE 'Successfully inserted metadata for 6 tables';
END $$;

-- Verify the insertion
SELECT 
    t.table_name,
    t.description,
    LENGTH(t.table_ddl) as ddl_length
FROM tables_metadata t
JOIN database_schemas ds ON t.schema_id = ds.schema_id
JOIN teams tm ON ds.team_id = tm.team_id
WHERE tm.team_name = 'Demo Team'
ORDER BY t.table_name;
