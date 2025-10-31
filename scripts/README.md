# Test Scripts

This directory contains testing scripts for the High-Performance Auth Demo project.

## Prerequisites

- Services must be running: `docker-compose up`
- `curl` must be installed
- `jq` (optional, for pretty JSON output)

## Available Scripts

### 🚀 Quick Start

**`smoke-test.sh`** - Performance validation and smoke testing

```bash
./scripts/smoke-test.sh
```

- Validates system under load (150+ requests)
- Tests sequential and concurrent performance
- Measures throughput and response times
- Validates event loop remains non-blocking
- **Run this to validate the architecture works!**

**`interactive-test.sh`** - Interactive testing script

```bash
./scripts/interactive-test.sh
```

- Prompts for username/password
- Shows full login and authorization flow
- Great for learning and manual testing

### 🧪 Automated Tests

**`test-full-flow.sh`** - Complete end-to-end test

```bash
./scripts/test-full-flow.sh
```

- Tests both authentication and authorization flows
- Uses alice's credentials
- Validates entire architecture
- **Run this first to verify everything works!**

**`test-login.sh`** - Authentication tests

```bash
./scripts/test-login.sh
```

- Tests login for all demo users (alice, bob, admin)
- Tests invalid credentials
- Returns exit code 0 on success

**`test-authorization.sh`** - Authorization tests

```bash
./scripts/test-authorization.sh
```

- Tests valid JWT tokens
- Tests invalid tokens
- Tests missing tokens
- Tests malformed headers
- Tests direct API access (security check)

## Making Scripts Executable

```bash
chmod +x scripts/*.sh
```

## Usage Examples

### Run all tests in sequence

```bash
./scripts/test-login.sh && ./scripts/test-authorization.sh
```

### Get a token and use it

```bash
# Get token
TOKEN=$(curl -s -X POST http://localhost/login \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "password123"}' | jq -r '.token')

# Use token
curl http://localhost/api/v1/user/profile \
  -H "Authorization: Bearer $TOKEN"
```

### Use environment variable for token

```bash
# Export token from test
export TOKEN="your-jwt-token-here"

# Run authorization tests
./scripts/test-authorization.sh
```

## Troubleshooting

**"Connection refused" errors:**

- Make sure services are running: `docker-compose up`
- Wait for all services to be ready (check logs)

**"jq: command not found" warnings:**

- Scripts will still work but output won't be pretty
- Install jq: `brew install jq` (macOS) or `apt-get install jq` (Linux)

**Login fails with valid credentials:**

- Check if database initialized: `docker-compose logs db`
- Look for "Seed data inserted" message
- Reset database if needed: `docker-compose down -v && docker-compose up`

## Script Output

All scripts use color-coded output:

- 🔵 **Blue**: Section headers
- 🟡 **Yellow**: Information/warnings
- 🟢 **Green**: Success messages
- 🔴 **Red**: Error messages

## Exit Codes

- `0`: All tests passed
- `> 0`: Number of failed tests
