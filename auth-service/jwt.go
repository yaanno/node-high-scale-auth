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

// generateJWT creates a signed JWT token for the given user ID
// This is CPU-intensive due to HMAC-SHA256 signing
func generateJWT(userID int) (string, error) {
	// Token expires in 24 hours (for demo purposes)
	now := time.Now()

	// Create claims with user ID and expiration
	claims := jwt.RegisteredClaims{
		ID:        strconv.Itoa(userID),
		Subject:   strconv.Itoa(userID),
		Audience:  []string{"api-service"},
		ExpiresAt: jwt.NewNumericDate(now.Add(3 * time.Minute)),
		IssuedAt:  jwt.NewNumericDate(now),
		Issuer:    "auth-service",
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
func validateJWT(tokenString string) (string, error) {
	claims := &jwt.RegisteredClaims{}

	// Parse and validate the token (CPU-intensive operation)
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		// Verify signing method
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return jwtSecretKey, nil
	})

	if err != nil {
		return "", fmt.Errorf("failed to parse token: %w", err)
	}

	if !token.Valid {
		return "", fmt.Errorf("invalid token")
	}

	return claims.ID, nil
}
