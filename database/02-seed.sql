-- ==========================================
-- Seed Data for Auth Demo
-- ==========================================
-- This file populates the database with test users.
-- Password hashes are pre-generated using bcrypt (cost factor: 10).
--
-- DEMO USERS (for testing purposes):
-- ==========================================
-- Username: alice
-- Password: password123
-- User ID: 1
--
-- Username: bob
-- Password: securepass456
-- User ID: 2
--
-- Username: admin
-- Password: adminpass789
-- User ID: 3
-- ==========================================

-- Insert demo users with bcrypt-hashed passwords
-- Note: These hashes were generated with cost factor 10
INSERT INTO users (username, password_hash) VALUES
    -- alice / password123
    ('alice', '$2b$10$GxD1o2o5AbfW9QpoyS9e1.0HmRAYxv2xX9dw1s0z.KyWFaOOgZu/.'),
    
    -- bob / securepass456
    ('bob', '$2b$10$/gDo0D1/l9sPzQjqOCg81.ET/oEI1KIe9zyWJNSMH5vUS98TCumlq'),
    
    -- admin / adminpass789
    ('admin', '$2b$10$r38y6BDvzVtKVK6IoBlm5.8ADRmxRF3zCT4ylgrQwPK7FrPjKoh9i');

-- Log successful seed completion
DO $$
BEGIN
    RAISE NOTICE 'Seed data inserted: 3 demo users (alice, bob, admin)';
END $$;
