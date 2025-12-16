use serde::{Deserialize, Serialize};

// ============================================
// Request/Response DTOs
// ============================================

/// LoginRequest represents the JSON payload for POST /login
#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

/// LoginResponse represents the successful login response
#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub token: String,
}

/// ErrorResponse represents an error response
#[derive(Debug, Serialize)]
pub struct ErrorResponse {
    pub error: String,
    pub code: String,
}

// ============================================
// Database Models
// ============================================

/// User represents a user record from the database
#[derive(Debug, Clone)]
pub struct User {
    pub id: i32,
    #[allow(dead_code)]
    pub username: String,
    pub password_hash: String,
}

// ============================================
// JWT Models
// ============================================

/// Claims represents the JWT payload structure
#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub user_id: i32,
    pub exp: usize,  // Expiration timestamp (unix epoch)
    pub iat: usize,  // Issued at timestamp
    pub iss: String, // Issuer
}
