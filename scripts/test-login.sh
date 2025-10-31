#!/bin/bash

# ==========================================
# Login Test Script
# ==========================================
# Test the authentication flow for different users

# Configuration
BASE_URL="http://localhost"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}  Login Test - Multiple Users            ${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Test user credentials
declare -A USERS=(
    ["alice"]="password123"
    ["bob"]="securepass456"
    ["admin"]="adminpass789"
)

SUCCESS_COUNT=0
FAIL_COUNT=0

# Test each user
for username in "${!USERS[@]}"; do
    password="${USERS[$username]}"
    
    echo -e "${YELLOW}Testing: ${username}${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/login" \
      -H "Content-Type: application/json" \
      -d "{\"username\": \"${username}\", \"password\": \"${password}\"}")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ]; then
        TOKEN=$(echo "$BODY" | jq -r '.token' 2>/dev/null)
        if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
            echo -e "${GREEN}✅ SUCCESS${NC} - Token received (${#TOKEN} chars)"
            echo "   Token preview: ${TOKEN:0:40}..."
            ((SUCCESS_COUNT++))
        else
            echo -e "${RED}❌ FAILED${NC} - No token in response"
            ((FAIL_COUNT++))
        fi
    else
        echo -e "${RED}❌ FAILED${NC} - HTTP $HTTP_CODE"
        echo "   Response: $BODY"
        ((FAIL_COUNT++))
    fi
    echo ""
done

# Test invalid credentials
echo -e "${YELLOW}Testing: invalid credentials${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "wrongpassword"}')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "401" ]; then
    echo -e "${GREEN}✅ SUCCESS${NC} - Correctly rejected invalid password (401)"
    ((SUCCESS_COUNT++))
else
    echo -e "${RED}❌ FAILED${NC} - Expected 401, got HTTP $HTTP_CODE"
    ((FAIL_COUNT++))
fi
echo ""

# Summary
echo -e "${BLUE}===========================================${NC}"
echo -e "Summary: ${GREEN}${SUCCESS_COUNT} passed${NC}, ${RED}${FAIL_COUNT} failed${NC}"
echo -e "${BLUE}===========================================${NC}"

exit $FAIL_COUNT
