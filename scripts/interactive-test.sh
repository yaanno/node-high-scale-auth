#!/bin/bash

# ==========================================
# Quick Interactive Test
# ==========================================
# Simple interactive script for manual testing

# Configuration
BASE_URL="http://localhost"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Quick Interactive Auth Test         ${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Get username
echo -e "${YELLOW}Available users:${NC} alice, bob, admin"
read -p "Enter username [alice]: " USERNAME
USERNAME=${USERNAME:-alice}

# Get password
echo ""
echo -e "${YELLOW}Default passwords:${NC}"
echo "  alice  -> password123"
echo "  bob    -> securepass456"
echo "  admin  -> adminpass789"
read -sp "Enter password: " PASSWORD
echo ""
echo ""

# Login
echo -e "${BLUE}Logging in...${NC}"
RESPONSE=$(curl -s -X POST "${BASE_URL}/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"${USERNAME}\", \"password\": \"${PASSWORD}\"}")

TOKEN=$(echo "$RESPONSE" | jq -r '.token' 2>/dev/null)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo -e "${GREEN}❌ Login failed!${NC}"
    echo "Response: $RESPONSE"
    exit 1
fi

echo -e "${GREEN}✅ Login successful!${NC}"
echo ""
echo "Your JWT token:"
echo "$TOKEN"
echo ""
echo "Token length: ${#TOKEN} characters"
echo ""

# Access protected endpoint
echo -e "${BLUE}Accessing protected endpoint...${NC}"
PROFILE_RESPONSE=$(curl -s "${BASE_URL}/api/v1/user/profile" \
  -H "Authorization: Bearer ${TOKEN}")

echo ""
echo "Response:"
echo "$PROFILE_RESPONSE" | jq '.' 2>/dev/null || echo "$PROFILE_RESPONSE"
echo ""

# Extract and display user info
USER_ID=$(echo "$PROFILE_RESPONSE" | jq -r '.data.id' 2>/dev/null)
USERNAME_FROM_API=$(echo "$PROFILE_RESPONSE" | jq -r '.data.username' 2>/dev/null)
ROLE=$(echo "$PROFILE_RESPONSE" | jq -r '.data.role' 2>/dev/null)

if [ "$USER_ID" != "null" ]; then
    echo -e "${GREEN}✅ Successfully accessed protected resource!${NC}"
    echo ""
    echo "User Information:"
    echo "  ID: $USER_ID"
    echo "  Username: $USERNAME_FROM_API"
    echo "  Role: $ROLE"
else
    echo -e "${GREEN}❌ Failed to access protected resource${NC}"
fi

echo ""
echo -e "${YELLOW}Export token to use in other commands:${NC}"
echo "export TOKEN=\"$TOKEN\""
echo ""
echo -e "${YELLOW}Test with curl:${NC}"
echo "curl http://localhost/api/v1/user/profile \\"
echo "  -H \"Authorization: Bearer \$TOKEN\""
