package main

import (
	"fmt"
	"strconv"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var jwtSecretKey []byte

// setJWTSecret stores the JWT secret key
func setJWTSecret(secret string) {
	jwtSecretKey = []byte(secret)
}

// Claims represents the JWT payload structure
type Claims struct {
	UserID int `json:"user_id"`
	jwt.RegisteredClaims
}

// generateJWT creates a signed JWT token for the given user ID
// This is CPU-intensive due to HMAC-SHA256 signing
func generateJWT(userID int) (string, error) {
	// Token expires in 24 hours (for demo purposes)
	expirationTime := time.Now().Add(24 * time.Hour)

	// Create claims with user ID and expiration
	claims := &Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "auth-service",
		},
	}

	// Create token with claims
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	// Sign the token with our secret key (CPU-intensive operation)
	tokenString, err := token.SignedString(jwtSecretKey)
	if err != nil {
		return "", fmt.Errorf("failed to sign token: %w", err)
	}

	return tokenString, nil
}

// validateJWT verifies the JWT signature and extracts the user ID
// This is CPU-intensive due to HMAC-SHA256 verification
func validateJWT(tokenString string) (int, error) {
	claims := &Claims{}

	// Parse and validate the token (CPU-intensive operation)
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		// Verify signing method
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return jwtSecretKey, nil
	})

	if err != nil {
		return 0, fmt.Errorf("failed to parse token: %w", err)
	}

	if !token.Valid {
		return 0, fmt.Errorf("invalid token")
	}

	return claims.UserID, nil
}

// extractUserIDString converts user ID to string for header injection
func extractUserIDString(userID int) string {
	return strconv.Itoa(userID)
}
