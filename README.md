# 🚀 High-Performance Node.js Microservice Architecture Demo

A demonstration project showcasing how to build **high-performance, scalable microservices** by isolating CPU-intensive security operations from I/O-bound Node.js services.

> **⚠️ Educational Project**: This is a learning/demonstration project. Not intended for production use without additional hardening.

---

## 🎯 Purpose

This project demonstrates a **polyglot microservice architecture** that maximizes Node.js performance by:

- **Isolating CPU-intensive tasks** (bcrypt, JWT operations) to a dedicated Go service
- Keeping the **Node.js event loop unblocked** for maximum I/O concurrency
- Implementing **external authorization** using Nginx's `auth_request` directive
- Building **stateless, horizontally scalable** services

### Key Learning Objectives

✅ Understand when and why to use different languages in microservices  
✅ Learn the Nginx `auth_request` pattern for security gateways  
✅ See how CPU isolation improves Node.js performance  
✅ Implement zero-trust security with trusted header injection

---

## 🏗️ Architecture Overview

```
┌─────────┐
│ Client  │
└────┬────┘
     │
     │ HTTP Request
     │
┌────▼──────────────────────────────────────────────┐
│  Nginx (Reverse Proxy & Security Gateway)         │
│  - Routes traffic                                  │
│  - Enforces auth via auth_request                  │
│  - Injects trusted X-User-ID header                │
└────┬──────────────────────────┬───────────────────┘
     │                           │
     │ /login                    │ /api/v1/*
     │ (no auth check)           │ (auth check required)
     │                           │
┌────▼─────────────┐      ┌─────▼──────────────────┐
│  Auth Service    │      │  Sub-request:          │
│  (Go)            │◄─────┤  /_auth_validation     │
│  - CPU-bound     │      │  (internal)            │
│  - bcrypt        │      └────────────────────────┘
│  - JWT ops       │                │
└────┬─────────────┘                │ 200 OK + X-User-ID
     │                               │
     │ Generate JWT                  │
     │                          ┌────▼─────────────┐
     ▼                          │  API Service     │
┌─────────────┐                │  (Node.js)       │
│  Database   │◄───────────────┤  - I/O-bound     │
│  (Postgres) │                │  - Business logic│
└─────────────┘                └──────────────────┘
```

### Component Breakdown

| Component        | Technology        | Role                                    | CPU Allocation |
| ---------------- | ----------------- | --------------------------------------- | -------------- |
| **Nginx**        | Nginx             | Security gateway, routing, auth_request | Edge           |
| **Auth Service** | Go                | CPU-intensive crypto (bcrypt, JWT)      | 2 cores        |
| **API Service**  | Node.js + Express | I/O-bound business logic                | 0.5 core       |
| **Database**     | PostgreSQL        | Persistent user storage                 | Standard       |

---

## 🔐 Security Flows

### Flow 1: Authentication (Login)

```
1. Client → POST /login {username, password}
2. Nginx → Auth Service (direct, no validation)
3. Auth Service → Database (lookup user)
4. Auth Service → bcrypt comparison (CPU-intensive)
5. Auth Service → Generate JWT (CPU-intensive)
6. Auth Service → Client {token: "..."}
```

### Flow 2: Authorization (Protected Endpoints)

```
1. Client → GET /api/v1/user/profile (with JWT in Authorization header)
2. Nginx → Internal sub-request to /_auth_validation
3. Auth Service → Validate JWT signature (CPU-intensive)
4. Auth Service → Return 200 OK + X-User-ID header
5. Nginx → Inject X-User-ID into original request
6. Nginx → Forward to API Service (with trusted header)
7. API Service → Read X-User-ID, execute business logic
8. API Service → Client {user data}
```

**Critical Security Principle**: The Node.js API service **never** validates JWTs. It trusts only the `X-User-ID` header injected by Nginx after successful validation.

---

## 🚀 Getting Started

### Prerequisites

- Docker & Docker Compose
- curl (for testing)
- (Optional) Go 1.21+ for local auth service development

### Quick Start

1. **Clone the repository**

   ```bash
   git clone <your-repo-url>
   cd node-high-scale-auth
   ```

2. **Start all services**

   ```bash
   docker-compose up --build
   ```

3. **Wait for initialization**
   You'll see logs indicating:

   - Database schema created
   - Seed data inserted (3 demo users)
   - Auth service ready on port 8080
   - API service ready on port 3000
   - Nginx listening on port 80

4. **Test the authentication flow** (see Testing section below)

### Stopping Services

```bash
docker-compose down
```

To remove volumes (reset database):

```bash
docker-compose down -v
```

---

## 🧪 Testing

### Demo User Credentials

| Username | Password      | User ID |
| -------- | ------------- | ------- |
| alice    | password123   | 1       |
| bob      | securepass456 | 2       |
| admin    | adminpass789  | 3       |

### Test Authentication (Login)

```bash
# Login as alice
curl -X POST http://localhost/login \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "password123"}'

# Expected response:
# {"token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}
```

Save the token from the response for the next step.

### Test Authorization (Protected Endpoint)

```bash
# Replace <YOUR_TOKEN> with the token from login response
curl http://localhost/api/v1/user/profile \
  -H "Authorization: Bearer <YOUR_TOKEN>"

# Expected response:
# {
#   "message": "Profile data fetched successfully (I/O operation simulated)",
#   "data": {
#     "id": "1",
#     "username": "User-1",
#     "role": "standard",
#     "lastLogin": "2025-10-31T..."
#   },
#   "status": "OK"
# }
```

### Test Invalid Token

```bash
curl http://localhost/api/v1/user/profile \
  -H "Authorization: Bearer invalid-token-here"

# Expected response: 401 Unauthorized
```

### Test Missing Token

```bash
curl http://localhost/api/v1/user/profile

# Expected response: 401 Unauthorized
```

---

## 📁 Project Structure

```
.
├── AGENTS.md                 # Instructions for AI agents
├── CONCEPT.md                # Architectural concept document
├── README.md                 # This file
├── docker-compose.yml        # Multi-service orchestration
│
├── api-service/              # Node.js I/O-bound service
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
│
├── auth-service/             # Go CPU-bound service
│   ├── Dockerfile
│   ├── go.mod
│   ├── main.go               # Entry point & HTTP server
│   ├── handlers.go           # /login and /validate endpoints
│   ├── database.go           # PostgreSQL operations
│   └── jwt.go                # JWT signing & validation
│
├── nginx/                    # Reverse proxy & security gateway
│   ├── Dockerfile
│   └── nginx.conf            # auth_request configuration
│
└── database/                 # PostgreSQL initialization
    ├── 01-schema.sql         # Table definitions
    └── 02-seed.sql           # Demo user data
```

---

## 🔧 Configuration

### Environment Variables

**Auth Service** (`docker-compose.yml`):

- `PORT`: HTTP port (default: 8080)
- `DATABASE_URL`: PostgreSQL connection string
- `JWT_SECRET`: Secret key for JWT signing ⚠️ **Change in production!**

**API Service** (`docker-compose.yml`):

- `PORT`: HTTP port (default: 3000)
- `DATABASE_URL`: PostgreSQL connection string (currently unused)

### Resource Limits

Configured in `docker-compose.yml`:

- **Auth Service**: 2 CPU cores, 256MB RAM (CPU-intensive)
- **API Service**: 0.5 CPU core, 512MB RAM (I/O-bound)

---

## 🎓 Educational Notes

### Why Go for Auth Service?

- **CPU Performance**: Go handles bcrypt/JWT operations ~10x faster than Node.js
- **Concurrency**: Goroutines efficiently handle multiple concurrent auth requests
- **Simplicity**: Easier to learn than Rust, clearer than async Node.js
- **Demonstrates the Pattern**: Shows why polyglot architectures make sense

### Why Not Implement JWT in Node.js?

❌ **Bad**: Node.js validates JWTs (blocks event loop)  
✅ **Good**: Dedicated service validates JWTs (Node.js stays fast)

Bcrypt comparison takes ~50-100ms. JWT validation takes ~5-10ms. In a Node.js single-threaded environment, these operations **block** the entire server from handling other requests.

### The auth_request Pattern

Nginx's `auth_request` directive enables **external authorization**:

1. Intercepts incoming requests
2. Sends a sub-request to a validation endpoint
3. Proceeds only if the sub-request returns 200 OK
4. Captures response headers for injection

This pattern is used by companies like Google (Identity-Aware Proxy), Cloudflare (Access), and many others.

---

## 🚨 Production Considerations (Out of Scope)

This is a **demonstration project**. For production, you would need:

❌ HTTPS/TLS encryption  
❌ Token refresh/rotation mechanisms  
❌ Rate limiting & brute-force protection  
❌ Proper secret management (vault, k8s secrets)  
❌ Audit logging  
❌ Health checks & monitoring  
❌ Horizontal scaling configuration  
❌ Database connection pooling tuning  
❌ Multi-factor authentication  
❌ Password reset flows

---

## 📚 Further Reading

- [Nginx auth_request Module](http://nginx.org/en/docs/http/ngx_http_auth_request_module.html)
- [Node.js Event Loop](https://nodejs.org/en/docs/guides/event-loop-timers-and-nexttick/)
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
- [bcrypt Work Factor](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)

---

## 📝 License

This project is for educational purposes. Feel free to use and modify for learning.

---

## 🤝 Contributing

This is a learning project! Improvements and educational enhancements are welcome.

---

**Happy Learning! 🎉**
