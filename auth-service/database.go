package main

import (
	"database/sql"
	"fmt"

	_ "github.com/lib/pq" // PostgreSQL driver
)

var db *sql.DB

// initDB establishes a connection to PostgreSQL
func initDB(databaseURL string) error {
	var err error
	db, err = sql.Open("postgres", databaseURL)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}

	// Verify the connection is working
	if err = db.Ping(); err != nil {
		return fmt.Errorf("failed to ping database: %w", err)
	}

	return nil
}

// closeDB closes the database connection
func closeDB() {
	if db != nil {
		db.Close()
	}
}

// User represents a user record from the database
type User struct {
	ID           int
	Username     string
	PasswordHash string
}

// getUserByUsername queries the database for a user by username
// This is an I/O operation but only happens during login
func getUserByUsername(username string) (*User, error) {
	user := &User{}

	query := "SELECT id, username, password_hash FROM users WHERE username = $1"
	err := db.QueryRow(query, username).Scan(&user.ID, &user.Username, &user.PasswordHash)

	if err == sql.ErrNoRows {
		return nil, nil // User not found
	}
	if err != nil {
		return nil, fmt.Errorf("database query failed: %w", err)
	}

	return user, nil
}
