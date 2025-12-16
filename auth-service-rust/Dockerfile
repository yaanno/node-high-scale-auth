# Build stage: Compile the Rust application
FROM rust:latest as builder

WORKDIR /app

# Copy Cargo files
COPY Cargo.toml .

# Copy source code
COPY src ./src

# Build the application in release mode
RUN cargo build --release

# Runtime stage: Minimal image with just the binary
FROM debian:bookworm-slim

WORKDIR /app

# Install CA certificates (needed for HTTPS if ever required)
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy the compiled binary from builder stage
COPY --from=builder /app/target/release/auth-service-rust /app/auth-service

# Expose port 8080
EXPOSE 8080

# Run the auth service
CMD ["./auth-service"]
