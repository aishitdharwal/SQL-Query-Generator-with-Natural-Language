-- Marketing Database Schema
-- E-commerce domain: Campaigns, leads, email marketing, customer segments

-- Campaigns table
CREATE TABLE campaigns (
    campaign_id SERIAL PRIMARY KEY,
    campaign_name VARCHAR(255) NOT NULL,
    campaign_type VARCHAR(50), -- email, social, ppc, seo
    start_date DATE NOT NULL,
    end_date DATE,
    budget DECIMAL(10, 2),
    spent_amount DECIMAL(10, 2) DEFAULT 0,
    status VARCHAR(50) DEFAULT 'active',
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Leads table
CREATE TABLE leads (
    lead_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    company VARCHAR(200),
    job_title VARCHAR(100),
    lead_source VARCHAR(100), -- website, referral, social_media, advertising
    lead_score INTEGER DEFAULT 0, -- 0-100 scoring
    status VARCHAR(50) DEFAULT 'new', -- new, contacted, qualified, converted, lost
    campaign_id INTEGER REFERENCES campaigns(campaign_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Email Campaigns table
CREATE TABLE email_campaigns (
    email_campaign_id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(campaign_id),
    subject_line VARCHAR(255) NOT NULL,
    email_content TEXT,
    sent_date TIMESTAMP,
    total_sent INTEGER DEFAULT 0,
    total_opened INTEGER DEFAULT 0,
    total_clicked INTEGER DEFAULT 0,
    total_bounced INTEGER DEFAULT 0,
    total_unsubscribed INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Customer Segments table
CREATE TABLE customer_segments (
    segment_id SERIAL PRIMARY KEY,
    segment_name VARCHAR(200) NOT NULL,
    description TEXT,
    criteria JSONB, -- Store segmentation criteria as JSON
    total_customers INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Marketing Events table
CREATE TABLE marketing_events (
    event_id SERIAL PRIMARY KEY,
    event_name VARCHAR(255) NOT NULL,
    event_type VARCHAR(100), -- webinar, conference, workshop, trade_show
    event_date DATE NOT NULL,
    location VARCHAR(255),
    budget DECIMAL(10, 2),
    expected_attendees INTEGER,
    actual_attendees INTEGER,
    leads_generated INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Social Media Posts table
CREATE TABLE social_media_posts (
    post_id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(campaign_id),
    platform VARCHAR(50), -- facebook, instagram, twitter, linkedin
    post_content TEXT NOT NULL,
    post_date TIMESTAMP NOT NULL,
    impressions INTEGER DEFAULT 0,
    likes INTEGER DEFAULT 0,
    shares INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Content Performance table
CREATE TABLE content_performance (
    content_id SERIAL PRIMARY KEY,
    content_title VARCHAR(255) NOT NULL,
    content_type VARCHAR(50), -- blog, video, infographic, whitepaper
    publish_date DATE NOT NULL,
    page_views INTEGER DEFAULT 0,
    unique_visitors INTEGER DEFAULT 0,
    avg_time_on_page INTEGER, -- in seconds
    bounce_rate DECIMAL(5, 2),
    conversions INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data

-- Sample Campaigns
INSERT INTO campaigns (campaign_name, campaign_type, start_date, end_date, budget, spent_amount, status, description) VALUES
('Holiday Sale 2024', 'email', '2024-11-01', '2024-12-31', 50000.00, 35000.00, 'active', 'Black Friday and Christmas promotions'),
('Spring Launch', 'social', '2024-03-01', '2024-04-30', 30000.00, 30000.00, 'completed', 'New product line launch on social media'),
('SEO Optimization', 'seo', '2024-01-01', NULL, 25000.00, 18000.00, 'active', 'Ongoing SEO improvements'),
('PPC Campaign Q4', 'ppc', '2024-10-01', '2024-12-31', 40000.00, 32000.00, 'active', 'Google Ads and Facebook Ads'),
('Summer Email Series', 'email', '2024-06-01', '2024-08-31', 15000.00, 15000.00, 'completed', 'Summer promotions email series');

-- Sample Leads
INSERT INTO leads (first_name, last_name, email, phone, company, job_title, lead_source, lead_score, status, campaign_id) VALUES
('Alex', 'Thompson', 'alex.t@techcorp.com', '555-2001', 'TechCorp Inc', 'CTO', 'website', 85, 'qualified', 1),
('Sophia', 'Chen', 'sophia.c@innovate.com', '555-2002', 'Innovate LLC', 'Marketing Director', 'referral', 92, 'converted', 2),
('Marcus', 'Rodriguez', 'marcus.r@startup.io', '555-2003', 'Startup.io', 'Founder', 'social_media', 78, 'contacted', 4),
('Emma', 'Johnson', 'emma.j@enterprise.com', '555-2004', 'Enterprise Solutions', 'VP Sales', 'advertising', 88, 'qualified', 1),
('Oliver', 'White', 'oliver.w@consulting.com', '555-2005', 'White Consulting', 'Partner', 'website', 95, 'converted', 3),
('Isabella', 'Martinez', 'isabella.m@digital.com', '555-2006', 'Digital Agency', 'CEO', 'referral', 45, 'new', 2),
('Noah', 'Brown', 'noah.b@solutions.net', '555-2007', 'Solutions Net', 'Product Manager', 'social_media', 62, 'contacted', 4),
('Ava', 'Davis', 'ava.d@cloud.co', '555-2008', 'Cloud Co', 'Engineer', 'website', 35, 'new', 1),
('Liam', 'Wilson', 'liam.w@growth.io', '555-2009', 'Growth.io', 'Growth Manager', 'advertising', 72, 'qualified', 4),
('Mia', 'Anderson', 'mia.a@ventures.com', '555-2010', 'Ventures Inc', 'Investor', 'referral', 90, 'converted', 3);

-- Sample Email Campaigns
INSERT INTO email_campaigns (campaign_id, subject_line, email_content, sent_date, total_sent, total_opened, total_clicked, total_bounced, total_unsubscribed) VALUES
(1, 'Exclusive Holiday Deals - Up to 50% Off!', 'Check out our amazing holiday deals...', '2024-11-15 09:00:00', 10000, 3500, 1200, 150, 25),
(1, 'Last Chance: Holiday Sale Ends Tonight!', 'Don''t miss out on these incredible savings...', '2024-12-24 18:00:00', 8500, 4200, 1800, 120, 18),
(5, 'Summer Savings Start Now', 'Beat the heat with our summer collection...', '2024-06-05 10:00:00', 12000, 4800, 1500, 200, 35),
(5, 'Your Exclusive Summer VIP Access', 'As a valued customer, get early access...', '2024-07-01 08:00:00', 5000, 2800, 950, 80, 12);

-- Sample Customer Segments
INSERT INTO customer_segments (segment_name, description, criteria, total_customers) VALUES
('High Value Customers', 'Customers with lifetime value > $5000', '{"min_lifetime_value": 5000}', 450),
('Recent Buyers', 'Made purchase in last 30 days', '{"days_since_purchase": 30}', 1200),
('Email Engaged', 'Opened emails in last 90 days', '{"email_engagement": "high"}', 3500),
('Cart Abandoners', 'Added items but didn''t complete purchase', '{"cart_status": "abandoned"}', 800),
('Inactive Customers', 'No purchase in last 6 months', '{"days_since_purchase": 180}', 2100);

-- Sample Marketing Events
INSERT INTO marketing_events (event_name, event_type, event_date, location, budget, expected_attendees, actual_attendees, leads_generated) VALUES
('E-commerce Summit 2024', 'conference', '2024-09-15', 'Las Vegas, NV', 25000.00, 500, 480, 85),
('Product Launch Webinar', 'webinar', '2024-03-20', 'Online', 5000.00, 200, 235, 42),
('Tech Trade Show', 'trade_show', '2024-11-10', 'San Francisco, CA', 40000.00, 1000, 950, 120),
('Holiday Workshop Series', 'workshop', '2024-12-05', 'Online', 8000.00, 100, 95, 28);

-- Sample Social Media Posts
INSERT INTO social_media_posts (campaign_id, platform, post_content, post_date, impressions, likes, shares, comments, clicks) VALUES
(2, 'instagram', 'Introducing our new spring collection! 🌸 #NewArrivals', '2024-03-15 14:00:00', 45000, 2800, 450, 320, 1200),
(2, 'facebook', 'Spring is here! Check out our latest products.', '2024-03-15 14:30:00', 35000, 1900, 280, 180, 950),
(4, 'linkedin', 'Why our customers choose us - read the latest case study', '2024-10-20 10:00:00', 12000, 580, 95, 42, 680),
(4, 'twitter', 'Limited time offer! Get 30% off with code FALL30', '2024-11-01 09:00:00', 28000, 1200, 340, 85, 820);

-- Sample Content Performance
INSERT INTO content_performance (content_title, content_type, publish_date, page_views, unique_visitors, avg_time_on_page, bounce_rate, conversions) VALUES
('10 Ways to Maximize Your E-commerce ROI', 'blog', '2024-10-15', 8500, 6200, 245, 35.5, 85),
('Product Demo Video: New Features', 'video', '2024-11-01', 12000, 9500, 180, 28.2, 120),
('Complete Guide to Online Shopping', 'whitepaper', '2024-09-10', 3500, 2800, 420, 22.8, 145),
('Infographic: E-commerce Trends 2024', 'infographic', '2024-08-20', 15000, 11000, 90, 45.5, 95);

-- Create indexes
CREATE INDEX idx_leads_email ON leads(email);
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_leads_campaign_id ON leads(campaign_id);
CREATE INDEX idx_email_campaigns_campaign_id ON email_campaigns(campaign_id);
CREATE INDEX idx_social_media_posts_campaign_id ON social_media_posts(campaign_id);
CREATE INDEX idx_campaigns_status ON campaigns(status);
