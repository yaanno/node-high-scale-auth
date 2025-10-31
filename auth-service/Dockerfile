# ==========================================
# Stage 1: Build Stage
# ==========================================
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum* ./

# Download dependencies
RUN go mod download

# Copy source code
COPY *.go ./

# Build the application
# CGO_ENABLED=0 creates a static binary (no C dependencies)
# -ldflags="-w -s" strips debug info to reduce binary size
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o auth-service .

# ==========================================
# Stage 2: Runtime Stage
# ==========================================
FROM alpine:latest

# Install CA certificates for HTTPS (if needed)
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -g 1001 -S authgroup && \
    adduser -S authuser -u 1001 -G authgroup

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder --chown=authuser:authgroup /build/auth-service .

# Switch to non-root user
USER authuser

# Expose port
EXPOSE 8080

# Run the application
CMD ["./auth-service"]
