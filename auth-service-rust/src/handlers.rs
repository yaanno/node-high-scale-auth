use axum::{
    extract::{Query, State},
    http::StatusCode,
    Json,
};
use bcrypt::verify;
use serde::Deserialize;
use sqlx::PgPool;

use crate::models::{ErrorResponse, LoginRequest, LoginResponse};
use crate::{db, jwt};

/// Application state containing shared resources
#[derive(Clone)]
pub struct AppState {
    pub db_pool: PgPool,
    pub jwt_secret: String,
}

/// Handle POST /login requests
/// Authenticates user and returns JWT token
pub async fn handle_login(
    State(state): State<AppState>,
    Json(req): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, (StatusCode, Json<ErrorResponse>)> {
    println!("[AUTH] Login attempt for user: {}", req.username);

    // Look up user in database (I/O operation)
    let user = match db::get_user_by_username(&state.db_pool, &req.username).await {
        Ok(Some(user)) => user,
        Ok(None) => {
            println!("[AUTH] FAILED: User not found: {}", req.username);
            return Err((
                StatusCode::UNAUTHORIZED,
                Json(ErrorResponse {
                    error: "Invalid credentials".to_string(),
                    code: "INVALID_CREDENTIALS".to_string(),
                }),
            ));
        }
        Err(e) => {
            println!("[AUTH] ERROR: Database error during login: {}", e);
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: "Internal server error".to_string(),
                    code: "DATABASE_ERROR".to_string(),
                }),
            ));
        }
    };

    // ========================================
    // CPU-INTENSIVE OPERATION: bcrypt comparison
    // This is why we isolated this service from Node.js
    // ========================================
    let password_match = match verify(&req.password, &user.password_hash) {
        Ok(is_match) => is_match,
        Err(e) => {
            println!("[AUTH] ERROR: bcrypt verification failed: {}", e);
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: "Internal server error".to_string(),
                    code: "HASH_ERROR".to_string(),
                }),
            ));
        }
    };

    if !password_match {
        println!("[AUTH] FAILED: Invalid password for user: {}", req.username);
        return Err((
            StatusCode::UNAUTHORIZED,
            Json(ErrorResponse {
                error: "Invalid credentials".to_string(),
                code: "INVALID_CREDENTIALS".to_string(),
            }),
        ));
    }

    // ========================================
    // CPU-INTENSIVE OPERATION: JWT signing
    // ========================================
    let token = match jwt::generate_jwt(user.id, &state.jwt_secret) {
        Ok(token) => token,
        Err(e) => {
            println!("[AUTH] ERROR: JWT generation failed: {}", e);
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: "Internal server error".to_string(),
                    code: "JWT_ERROR".to_string(),
                }),
            ));
        }
    };

    println!("[AUTH] SUCCESS: User {} authenticated", req.username);
    Ok(Json(LoginResponse { token }))
}

/// ValidateQuery represents query parameters for GET /validate
#[derive(Debug, Deserialize)]
pub struct ValidateQuery {
    pub token: String,
}

/// Handle GET /validate requests
/// Validates JWT token (called by Nginx via auth_request directive)
/// Returns user_id as X-User-ID header via response headers
pub async fn handle_validate(
    State(state): State<AppState>,
    Query(query): Query<ValidateQuery>,
) -> Result<(StatusCode, [(String, String); 1]), (StatusCode, Json<ErrorResponse>)> {
    println!("[AUTH] Validating token...");

    // ========================================
    // CPU-INTENSIVE OPERATION: JWT verification
    // Validates signature and expiration
    // ========================================
    let claims = match jwt::validate_jwt(&query.token, &state.jwt_secret) {
        Ok(claims) => {
            println!(
                "[AUTH] SUCCESS: Token validated for user {}",
                claims.user_id
            );
            claims
        }
        Err(e) => {
            println!("[AUTH] FAILED: Token validation error: {}", e);
            return Err((
                StatusCode::UNAUTHORIZED,
                Json(ErrorResponse {
                    error: "Invalid token".to_string(),
                    code: "INVALID_TOKEN".to_string(),
                }),
            ));
        }
    };

    // Return 200 OK with X-User-ID header (Nginx reads this)
    Ok((
        StatusCode::OK,
        [("X-User-ID".to_string(), claims.user_id.to_string())],
    ))
}
