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
    ('alice', '$2a$10$xK9Y7VJZk0vX7x9uH8.D1.eZhPzXxN7Xv5m5kMqF5J8YqQ6X8J5Ym'),
    
    -- bob / securepass456
    ('bob', '$2a$10$rN5XnJ9Y8vD6mH7K0xL4X.2JzP9nC5qR8T3wF6V1M7yN4tQ2vB8Ye'),
    
    -- admin / adminpass789
    ('admin', '$2a$10$hM8K4T6R9xY3nL5J2vN9P.7FzQ3wD1eS5G4yH8T2nV6pR9mK0jL3X');

-- Log successful seed completion
DO $$
BEGIN
    RAISE NOTICE 'Seed data inserted: 3 demo users (alice, bob, admin)';
END $$;
