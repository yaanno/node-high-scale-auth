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

/// Claims represents the JWT payload structure matching Go's jwt.RegisteredClaims
#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    // Standard JWT claims (as per RFC 7519)
    pub jti: String,      // JWT ID (maps to Go's ID field)
    pub sub: String,      // Subject - contains user ID as string
    pub aud: Vec<String>, // Audience (array to match Go's RegisteredClaims)
    pub exp: usize,       // Expiration timestamp (unix epoch)
    pub iat: usize,       // Issued at timestamp
    pub iss: String,      // Issuer
}

impl Claims {
    /// Create a new Claims instance
    pub fn new(user_id: i32, exp: usize, iat: usize) -> Self {
        let user_id_str = user_id.to_string();
        Claims {
            jti: user_id_str.clone(),
            sub: user_id_str,
            aud: vec!["api-service".to_string()],
            exp,
            iat,
            iss: "auth-service".to_string(),
        }
    }
}

// Property accessor for backward compatibility
impl Claims {
    pub fn user_id(&self) -> i32 {
        self.sub.parse::<i32>().unwrap_or(0)
    }
}
