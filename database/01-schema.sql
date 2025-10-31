-- ==========================================
-- Database Schema for Auth Demo
-- ==========================================
-- This file creates the users table for storing
-- authentication credentials. It runs automatically
-- when the PostgreSQL container starts for the first time.

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on username for fast lookups during login
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);

-- Add a comment to the table for documentation
COMMENT ON TABLE users IS 'Stores user credentials for authentication. Password hashes are generated using bcrypt.';
COMMENT ON COLUMN users.password_hash IS 'bcrypt hash of the user password (cost factor: 10)';

-- Log successful schema creation
DO $$
BEGIN
    RAISE NOTICE 'Schema created successfully: users table with username index';
END $$;
