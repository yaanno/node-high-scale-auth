# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Build the application (if you have a build script)
RUN npm run build || true

# Deploy stage
FROM node:20-alpine AS deploy

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S apiuser -u 1001

# Copy built application from builder stage
COPY --from=builder --chown=apiuser:nodejs /app .

# Switch to non-root user
USER apiuser

# Expose port
EXPOSE 3000

# Health check
# HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
#     CMD node healthcheck.js || exit 1

# Start the application
CMD ["node", "server.js"]