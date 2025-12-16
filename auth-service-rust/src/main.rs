mod db;
mod handlers;
mod jwt;
mod models;

use axum::{
    routing::{get, post},
    Router,
};
use handlers::{handle_login, handle_validate, AppState};
use std::env;

#[tokio::main]
async fn main() {
    // Read configuration from environment variables
    let port = env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let database_url = env::var("DATABASE_URL").expect("[AUTH] ERROR: DATABASE_URL environment variable is required");
    let jwt_secret = env::var("JWT_SECRET").unwrap_or_else(|_| {
        println!("[AUTH] WARNING: JWT_SECRET not set, using default (NOT for production!)");
        "demo-secret-key-change-in-production".to_string()
    });

    // Initialize database connection
    let db_pool = match db::init_db(&database_url).await {
        Ok(pool) => pool,
        Err(e) => {
            eprintln!("[AUTH] ERROR: Failed to connect to database: {}", e);
            std::process::exit(1);
        }
    };

    // Create application state
    let state = AppState {
        db_pool,
        jwt_secret,
    };

    // Build the router
    let app = Router::new()
        .route("/login", post(handle_login))
        .route("/validate", get(handle_validate))
        .with_state(state);

    // Start the HTTP server
    let listener = match tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port)).await {
        Ok(listener) => listener,
        Err(e) => {
            eprintln!("[AUTH] ERROR: Failed to bind to port {}: {}", port, e);
            std::process::exit(1);
        }
    };

    println!("[AUTH] CPU-intensive Auth service listening on port {}", port);
    println!("[AUTH] Ready to handle bcrypt and JWT operations");

    // Run the server
    if let Err(e) = axum::serve(listener, app).await {
        eprintln!("[AUTH] ERROR: Server failed: {}", e);
        std::process::exit(1);
    }
}
