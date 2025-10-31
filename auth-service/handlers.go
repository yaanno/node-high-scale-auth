package main

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"golang.org/x/crypto/bcrypt"
)

// LoginRequest represents the JSON payload for login
type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

// LoginResponse represents the successful login response
type LoginResponse struct {
	Token string `json:"token"`
}

// ErrorResponse represents an error response
type ErrorResponse struct {
	Error string `json:"error"`
	Code  string `json:"code"`
}

// handleLogin processes POST /login requests
// This endpoint performs CPU-intensive bcrypt comparison and JWT generation
func handleLogin(w http.ResponseWriter, r *http.Request) {
	// Only accept POST requests
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(ErrorResponse{
			Error: "Method not allowed",
			Code:  "METHOD_NOT_ALLOWED",
		})
		return
	}

	// Parse JSON request body
	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("[AUTH] ERROR: Invalid JSON in login request: %v", err)
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(ErrorResponse{
			Error: "Invalid request format",
			Code:  "INVALID_JSON",
		})
		return
	}

	log.Printf("[AUTH] Login attempt for user: %s", req.Username)

	// Look up user in database (I/O operation)
	user, err := getUserByUsername(req.Username)
	if err != nil {
		log.Printf("[AUTH] ERROR: Database error during login: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(ErrorResponse{
			Error: "Internal server error",
			Code:  "DATABASE_ERROR",
		})
		return
	}

	if user == nil {
		log.Printf("[AUTH] FAILED: User not found: %s", req.Username)
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(ErrorResponse{
			Error: "Invalid credentials",
			Code:  "INVALID_CREDENTIALS",
		})
		return
	}

	// ========================================
	// CPU-INTENSIVE OPERATION: bcrypt comparison
	// This is why we isolated this service from Node.js
	// ========================================
	log.Printf("[AUTH] Performing bcrypt comparison (CPU-intensive)...")
	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password))
	if err != nil {
		log.Printf("[AUTH] FAILED: Invalid password for user: %s", req.Username)
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(ErrorResponse{
			Error: "Invalid credentials",
			Code:  "INVALID_CREDENTIALS",
		})
		return
	}

	// ========================================
	// CPU-INTENSIVE OPERATION: JWT generation
	// HMAC-SHA256 signing is computationally expensive
	// ========================================
	log.Printf("[AUTH] Generating JWT token (CPU-intensive)...")
	token, err := generateJWT(user.ID)
	if err != nil {
		log.Printf("[AUTH] ERROR: Failed to generate JWT: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(ErrorResponse{
			Error: "Internal server error",
			Code:  "TOKEN_GENERATION_FAILED",
		})
		return
	}

	log.Printf("[AUTH] SUCCESS: User %s authenticated, JWT generated", req.Username)

	// Return JWT token to client
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(LoginResponse{
		Token: token,
	})
}

// handleValidate processes GET /validate requests from Nginx
// This endpoint is called via auth_request to validate JWT tokens
func handleValidate(w http.ResponseWriter, r *http.Request) {
	// Only accept GET requests
	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	// Extract Authorization header
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		log.Println("[AUTH] VALIDATION FAILED: Missing Authorization header")
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	// Check for Bearer token format
	parts := strings.Split(authHeader, " ")
	if len(parts) != 2 || parts[0] != "Bearer" {
		log.Println("[AUTH] VALIDATION FAILED: Invalid Authorization header format")
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	tokenString := parts[1]

	// ========================================
	// CPU-INTENSIVE OPERATION: JWT validation
	// HMAC-SHA256 signature verification is computationally expensive
	// ========================================
	log.Println("[AUTH] Validating JWT token (CPU-intensive)...")
	userID, err := validateJWT(tokenString)
	if err != nil {
		log.Printf("[AUTH] VALIDATION FAILED: %v", err)
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	log.Printf("[AUTH] VALIDATION SUCCESS: Token valid for user ID %d", userID)

	// CRITICAL: Inject X-User-ID header for Nginx to forward to API service
	// This is the trusted header that the Node.js service will read
	w.Header().Set("X-User-ID", extractUserIDString(userID))
	w.WriteHeader(http.StatusOK)
}
