use crate::models::User;
use sqlx::postgres::PgPool;

/// Initialize database connection pool
pub async fn init_db(database_url: &str) -> Result<PgPool, sqlx::Error> {
    println!("[AUTH] Connecting to database...");

    let pool = PgPool::connect(database_url).await?;

    // Verify connection
    pool.acquire().await?;

    println!("[AUTH] Database connection established");
    Ok(pool)
}

/// Get user by username from the database
/// This is an I/O operation but only happens during login
pub async fn get_user_by_username(
    pool: &PgPool,
    username: &str,
) -> Result<Option<User>, sqlx::Error> {
    let user = sqlx::query_as::<_, (i32, String, String)>(
        "SELECT id, username, password_hash FROM users WHERE username = $1",
    )
    .bind(username)
    .fetch_optional(pool)
    .await?;

    Ok(user.map(|(id, username, password_hash)| User {
        id,
        username,
        password_hash,
    }))
}
