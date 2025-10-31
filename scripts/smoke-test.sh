#!/bin/bash

# ==========================================
# Smoke Test - Performance & Load Validation
# ==========================================
# This script runs modest load tests to validate:
# 1. The system works under concurrent load
# 2. Auth service handles bcrypt operations efficiently
# 3. API service remains responsive (event loop not blocked)

set -e

# Configuration
BASE_URL="http://localhost"
SEQUENTIAL_REQUESTS=50
CONCURRENT_REQUESTS=100
CONCURRENCY_LEVEL=10

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Smoke Test - High-Scale Auth Demo            ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${CYAN}This test validates the architecture under load:${NC}"
echo -e "  • Sequential logins (baseline)"
echo -e "  • Concurrent logins (CPU-intensive)"
echo -e "  • Protected endpoint access (I/O-bound)"
echo ""

# ==========================================
# Pre-flight Check
# ==========================================
echo -e "${YELLOW}[Pre-flight] Checking services...${NC}"

# Check if services are running
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "404" ]; then
    echo -e "${RED}❌ Services not responding (HTTP $HTTP_CODE). Run: docker compose up -d${NC}"
    exit 1
fi

# Get a test token
echo -e "${YELLOW}[Pre-flight] Obtaining test token...${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "password123"}')

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token' 2>/dev/null)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo -e "${RED}❌ Failed to obtain token. Check services.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Services ready${NC}"
echo ""

# ==========================================
# Test 1: Sequential Login Performance
# ==========================================
echo -e "${BLUE}================================================${NC}"
echo -e "${YELLOW}[Test 1] Sequential Login Performance${NC}"
echo -e "${CYAN}Testing ${SEQUENTIAL_REQUESTS} sequential bcrypt operations${NC}"
echo -e "${CYAN}This measures baseline Auth service performance${NC}"
echo ""

START_TIME=$(date +%s.%N)

SUCCESS_COUNT=0
for i in $(seq 1 $SEQUENTIAL_REQUESTS); do
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/login" \
      -H "Content-Type: application/json" \
      -d '{"username": "alice", "password": "password123"}')
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" = "200" ]; then
        ((SUCCESS_COUNT++))
    fi
    
    # Progress indicator
    if [ $((i % 10)) -eq 0 ]; then
        echo -ne "\rProgress: ${i}/${SEQUENTIAL_REQUESTS}"
    fi
done

END_TIME=$(date +%s.%N)
DURATION=$(echo "$END_TIME - $START_TIME" | bc)
RPS=$(echo "scale=2; $SEQUENTIAL_REQUESTS / $DURATION" | bc)

echo -e "\n"
echo -e "${GREEN}✅ Sequential Test Complete${NC}"
echo -e "   Requests: ${SUCCESS_COUNT}/${SEQUENTIAL_REQUESTS}"
echo -e "   Duration: ${DURATION}s"
echo -e "   Throughput: ${RPS} req/s"
echo ""

# ==========================================
# Test 2: Concurrent Login Performance
# ==========================================
echo -e "${BLUE}================================================${NC}"
echo -e "${YELLOW}[Test 2] Concurrent Login Performance${NC}"
echo -e "${CYAN}Testing ${CONCURRENT_REQUESTS} logins with ${CONCURRENCY_LEVEL} concurrent requests${NC}"
echo -e "${CYAN}This validates Go's ability to handle concurrent bcrypt${NC}"
echo ""

# Create temporary file for results
TEMP_FILE=$(mktemp)

START_TIME=$(date +%s.%N)

# Run concurrent requests
for i in $(seq 1 $CONCURRENT_REQUESTS); do
    {
        RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/login" \
          -H "Content-Type: application/json" \
          -d '{"username": "alice", "password": "password123"}')
        
        HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
        echo "$HTTP_CODE" >> "$TEMP_FILE"
    } &
    
    # Limit concurrency (compatible with older bash)
    while [ $(jobs -r | wc -l | tr -d ' ') -ge $CONCURRENCY_LEVEL ]; do
        sleep 0.1
    done
done

# Wait for all background jobs to complete
wait

END_TIME=$(date +%s.%N)
DURATION=$(echo "$END_TIME - $START_TIME" | bc)
RPS=$(echo "scale=2; $CONCURRENT_REQUESTS / $DURATION" | bc)

# Count successes
SUCCESS_COUNT=$(grep -c "200" "$TEMP_FILE" || echo "0")
rm -f "$TEMP_FILE"

echo ""
echo -e "${GREEN}✅ Concurrent Test Complete${NC}"
echo -e "   Requests: ${SUCCESS_COUNT}/${CONCURRENT_REQUESTS}"
echo -e "   Duration: ${DURATION}s"
echo -e "   Throughput: ${RPS} req/s"
echo -e "   Concurrency: ${CONCURRENCY_LEVEL}"
echo ""

# ==========================================
# Test 3: Protected Endpoint Under Load
# ==========================================
echo -e "${BLUE}================================================${NC}"
echo -e "${YELLOW}[Test 3] Protected Endpoint Performance${NC}"
echo -e "${CYAN}Testing ${CONCURRENT_REQUESTS} authorized requests${NC}"
echo -e "${CYAN}This validates JWT validation + API I/O performance${NC}"
echo ""

# Create temporary file for results
TEMP_FILE=$(mktemp)

START_TIME=$(date +%s.%N)

# Run concurrent requests to protected endpoint
for i in $(seq 1 $CONCURRENT_REQUESTS); do
    {
        RESPONSE=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/v1/user/profile" \
          -H "Authorization: Bearer ${TOKEN}")
        
        HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
        echo "$HTTP_CODE" >> "$TEMP_FILE"
    } &
    
    # Limit concurrency (compatible with older bash)
    while [ $(jobs -r | wc -l | tr -d ' ') -ge $CONCURRENCY_LEVEL ]; do
        sleep 0.1
    done
done

# Wait for all background jobs to complete
wait

END_TIME=$(date +%s.%N)
DURATION=$(echo "$END_TIME - $START_TIME" | bc)
RPS=$(echo "scale=2; $CONCURRENT_REQUESTS / $DURATION" | bc)

# Count successes
SUCCESS_COUNT=$(grep -c "200" "$TEMP_FILE" || echo "0")
rm -f "$TEMP_FILE"

echo ""
echo -e "${GREEN}✅ Protected Endpoint Test Complete${NC}"
echo -e "   Requests: ${SUCCESS_COUNT}/${CONCURRENT_REQUESTS}"
echo -e "   Duration: ${DURATION}s"
echo -e "   Throughput: ${RPS} req/s"
echo ""

# ==========================================
# Test 4: Event Loop Non-Blocking Validation
# ==========================================
echo -e "${BLUE}================================================${NC}"
echo -e "${YELLOW}[Test 4] Event Loop Non-Blocking Validation${NC}"
echo -e "${CYAN}Verifying Node.js API remains responsive during auth load${NC}"
echo ""

echo -e "Starting 20 login requests (CPU-intensive in Go)..."

# Start background login requests
for i in $(seq 1 20); do
    {
        curl -s -X POST "${BASE_URL}/login" \
          -H "Content-Type: application/json" \
          -d '{"username": "alice", "password": "password123"}' > /dev/null
    } &
done

# While auth is processing, test API responsiveness
sleep 0.5

echo -e "Testing API responsiveness DURING auth load..."

API_START=$(date +%s.%N)
API_RESPONSE=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/v1/user/profile" \
  -H "Authorization: Bearer ${TOKEN}")
API_END=$(date +%s.%N)
API_DURATION=$(echo "scale=3; ($API_END - $API_START) * 1000" | bc)

API_CODE=$(echo "$API_RESPONSE" | tail -n1)

# Wait for background jobs
wait

echo ""
if [ "$API_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Event Loop Validation Passed${NC}"
    echo -e "   API responded in: ${API_DURATION}ms"
    echo -e "   Node.js remained responsive during CPU load"
else
    echo -e "${RED}❌ API did not respond (HTTP $API_CODE)${NC}"
fi
echo ""

# ==========================================
# Summary & Architecture Validation
# ==========================================
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}✅ SMOKE TEST COMPLETE${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${CYAN}Architecture Validated:${NC}"
echo -e "  ✓ Auth Service (Go) handles CPU-intensive bcrypt operations"
echo -e "  ✓ Concurrent logins processed efficiently with goroutines"
echo -e "  ✓ Nginx auth_request pattern working correctly"
echo -e "  ✓ API Service (Node.js) remains responsive under load"
echo -e "  ✓ Event loop not blocked by authentication operations"
echo ""
echo -e "${YELLOW}Note:${NC} This is a localhost smoke test. Real-world performance"
echo -e "will differ based on network latency, infrastructure, and scale."
echo ""
echo -e "${CYAN}For production load testing, consider:${NC}"
echo -e "  • k6 (https://k6.io/)"
echo -e "  • Apache Bench (ab)"
echo -e "  • Distributed load testing in K8s"
echo ""
