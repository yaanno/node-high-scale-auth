use crate::models::Claims;
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use std::time::{SystemTime, UNIX_EPOCH};

/// Generate a JWT token for the given user ID
/// This is CPU-intensive due to HMAC-SHA256 signing
pub fn generate_jwt(user_id: i32, secret: &str) -> Result<String, jsonwebtoken::errors::Error> {
    // Token expires in 24 hours (for demo purposes)
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs() as usize;
    let expiration = now + (5 * 60); // 5 minutes

    let claims = Claims::new(user_id, expiration, now);
    let encoding_key = EncodingKey::from_secret(secret.as_bytes());
    encode(&Header::default(), &claims, &encoding_key)
}

/// Validate a JWT token and extract claims
/// This is called by Nginx via the /validate endpoint
pub fn validate_jwt(token: &str, secret: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
    let decoding_key = DecodingKey::from_secret(secret.as_bytes());

    // Set up validation to check audience claim
    let mut validation = Validation::default();
    validation.set_audience(&["api-service"]);

    let token_data = decode::<Claims>(token, &decoding_key, &validation)?;
    Ok(token_data.claims)
}
