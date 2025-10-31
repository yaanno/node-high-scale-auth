package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	// Read configuration from environment variables
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("[AUTH] ERROR: DATABASE_URL environment variable is required")
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		log.Println("[AUTH] WARNING: JWT_SECRET not set, using default (NOT for production!)")
		jwtSecret = "demo-secret-key-change-in-production"
	}

	// Initialize database connection
	log.Println("[AUTH] Connecting to database...")
	if err := initDB(dbURL); err != nil {
		log.Fatalf("[AUTH] ERROR: Failed to connect to database: %v", err)
	}
	defer closeDB()
	log.Println("[AUTH] Database connection established")

	// Store JWT secret globally (in a real app, use dependency injection)
	setJWTSecret(jwtSecret)

	// Setup HTTP routes
	// POST /login - Authenticate user and return JWT
	http.HandleFunc("/login", handleLogin)

	// GET /validate - Validate JWT token (called by Nginx via auth_request)
	http.HandleFunc("/validate", handleValidate)

	// Start the HTTP server
	log.Printf("[AUTH] CPU-intensive Auth service listening on port %s", port)
	log.Printf("[AUTH] Ready to handle bcrypt and JWT operations")

	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("[AUTH] ERROR: Server failed to start: %v", err)
	}
}
