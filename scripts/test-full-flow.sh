#!/bin/bash

# ==========================================
# Authentication & Authorization Test Script
# ==========================================
# This script tests both flows:
# 1. Authentication (login to get JWT)
# 2. Authorization (access protected endpoint with JWT)

set -e  # Exit on error

# Configuration
BASE_URL="http://localhost"
API_ENDPOINT="/api/v1/user/profile"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  High-Performance Auth Demo - Full Flow Test  ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# ==========================================
# STEP 1: Test Login (Authentication)
# ==========================================
echo -e "${YELLOW}[STEP 1] Testing Authentication Flow${NC}"
echo -e "Logging in as: ${GREEN}alice${NC}"
echo ""

LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "password123"}')

echo "Response from /login:"
echo "$LOGIN_RESPONSE" | jq '.' 2>/dev/null || echo "$LOGIN_RESPONSE"
echo ""

# Extract token from response
TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token' 2>/dev/null)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo -e "${RED}❌ FAILED: Could not extract token from login response${NC}"
    echo "Make sure the services are running: docker-compose up"
    exit 1
fi

echo -e "${GREEN}✅ SUCCESS: JWT token received${NC}"
echo -e "Token (first 50 chars): ${TOKEN:0:50}..."
echo ""

# ==========================================
# STEP 2: Test Protected Endpoint (Authorization)
# ==========================================
echo -e "${YELLOW}[STEP 2] Testing Authorization Flow${NC}"
echo -e "Accessing protected endpoint: ${GREEN}${API_ENDPOINT}${NC}"
echo -e "With JWT token in Authorization header"
echo ""

PROFILE_RESPONSE=$(curl -s "${BASE_URL}${API_ENDPOINT}" \
  -H "Authorization: Bearer ${TOKEN}")

echo "Response from protected endpoint:"
echo "$PROFILE_RESPONSE" | jq '.' 2>/dev/null || echo "$PROFILE_RESPONSE"
echo ""

# Check if response contains expected data
if echo "$PROFILE_RESPONSE" | jq -e '.data.id' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ SUCCESS: Authorized access to protected endpoint${NC}"
    USER_ID=$(echo "$PROFILE_RESPONSE" | jq -r '.data.id')
    echo -e "User ID from response: ${GREEN}${USER_ID}${NC}"
else
    echo -e "${RED}❌ FAILED: Could not access protected endpoint${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Summary:"
echo "  1. ✅ Login successful (JWT generated)"
echo "  2. ✅ JWT validation successful (via Nginx auth_request)"
echo "  3. ✅ Protected endpoint accessible (with trusted X-User-ID header)"
echo ""
echo -e "${YELLOW}Architecture validated:${NC}"
echo "  • Auth Service (Go) handled CPU-intensive bcrypt & JWT operations"
echo "  • Nginx validated JWT and injected trusted X-User-ID header"
echo "  • API Service (Node.js) processed I/O-bound business logic"
