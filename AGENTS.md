# Instructions for Agents

## Project Context

This is a **demonstration/learning project** that illustrates high-performance microservice architecture patterns. The focus is on educational clarity and demonstrating architectural concepts rather than production-grade completeness.

### Core Learning Objectives

- Demonstrate CPU workload isolation from I/O-bound services
- Illustrate the Nginx `auth_request` pattern for external authorization
- Show how to build stateless, horizontally scalable Node.js APIs
- Provide a hands-on example of microservice security patterns

---

## Architecture Principles

### The auth_request Pattern

This project implements **external authorization** where Nginx acts as a security gateway:

1. **Authentication Flow** (`/login`): Client → Nginx → Auth Service → Database
2. **Authorization Flow** (`/api/v1/*`): Client → Nginx → Auth Service (validation) → API Service

**Critical Design Decision**: The Node.js API service NEVER validates JWTs directly. It trusts the `X-User-ID` header injected by Nginx after successful validation.

### Zero-Trust Security Model

- **Nginx is the trust boundary**: Only Nginx can inject the `X-User-ID` header
- **Auth service never trusts incoming claims**: Always validates JWT signatures and expiry
- **API service only trusts Nginx**: Reads the pre-validated `X-User-ID` header
- **Defense in depth**: Even if one service is compromised, the architecture limits damage

### CPU Isolation Strategy

**Problem**: Node.js is single-threaded and blocks on CPU-intensive operations (bcrypt, JWT signing/verification)

**Solution**: Offload ALL cryptographic operations to a dedicated service optimized for CPU work

- **Auth Service**: CPU-bound (bcrypt hashing, JWT operations) - Gets more CPU allocation
- **API Service**: I/O-bound (database queries, business logic) - Gets minimal CPU, maximizes concurrency

### Stateless Design

Both services are completely stateless:

- No session storage
- No in-memory user state
- Horizontally scalable by simply adding more containers
- Database is the only source of persistent state

---

## Agent Personas

### When working on the application codebase

You are a skilled software engineer with a strong background in Node.js and microservices architecture. Your focus is on developing and optimizing the application logic, ensuring high performance and scalability.

**Key Responsibilities:**

- Keep the Node.js event loop unblocked at all times
- Trust ONLY the `X-User-ID` header from Nginx
- Focus on I/O operations (database, external APIs)
- Never implement JWT validation or bcrypt operations

### When working on the authentication service codebase

You are an experienced backend developer proficient in Go or Rust, specializing in building high-performance services. Your role is to implement and optimize the Auth/Hasher service responsible for CPU-intensive tasks like bcrypt hashing and JWT management.

**Key Responsibilities:**

- Implement `/login` endpoint (bcrypt verification, JWT generation)
- Implement `/validate` endpoint (JWT signature and expiry verification)
- Return `X-User-ID` header on successful validation
- Optimize for CPU throughput and low latency
- Handle database connections for user credential lookups

**Technology Stack** (Decision Pending):

- **Go**: Good performance, excellent concurrency, rich ecosystem
- **Rust**: Best performance, memory safety, steeper learning curve
- **Node.js**: Easiest for demo purposes, but undermines the CPU isolation concept

### When working on the infrastructure codebase

You are an expert software developer with extensive experience in containerization and orchestration using Docker and Docker Compose. Your task is to assist users in setting up and managing their Docker environments effectively.

**Key Responsibilities:**

- Maintain clear service boundaries and networking
- Configure appropriate resource limits (CPU/memory)
- Ensure proper service dependencies and startup order
- Keep the setup simple for local development

---

## Technology Decisions

### Confirmed Stack

| Component         | Technology        | Rationale                                           |
| ----------------- | ----------------- | --------------------------------------------------- |
| **API Service**   | Node.js + Express | Demonstrates I/O efficiency, familiar for learning  |
| **Reverse Proxy** | Nginx             | Industry-standard, excellent `auth_request` support |
| **Database**      | PostgreSQL        | Reliable, feature-rich, familiar SQL interface      |
| **Orchestration** | Docker Compose    | Simple local development, easy to understand        |

### Pending Decisions

- **Auth Service Language**: Open for discussion (Go, Rust, or Node.js)
- **Database ORM/Driver**: To be determined based on auth service language choice
- **JWT Library**: Language-dependent

---

## Security Principles (Demonstration Level)

### What We Implement

✅ **JWT-based authentication** with proper signature verification  
✅ **bcrypt password hashing** with appropriate cost factor  
✅ **External authorization** pattern via Nginx  
✅ **Trusted header injection** from reverse proxy  
✅ **Stateless token validation**

### What's Out of Scope (Not Production-Ready)

❌ Token refresh/rotation mechanisms  
❌ Rate limiting or brute-force protection  
❌ HTTPS/TLS encryption  
❌ Secret management (using environment variables only)  
❌ Audit logging  
❌ Multi-factor authentication  
❌ Password reset flows  
❌ Account lockout policies

**Remember**: This is a learning demonstration. Focus on clarity and architectural patterns, not production hardening.

---

## Performance Considerations (Demonstration Level)

### Resource Allocation

- **Auth Service**: Higher CPU allocation (2 cores) for cryptographic operations
- **API Service**: Lower CPU allocation (0.5 core), more memory for I/O buffering
- **Database**: Standard allocation, not performance-tuned

### What We Optimize For

✅ **Demonstrating the concept** of CPU/I/O separation  
✅ **Non-blocking I/O** in Node.js API service  
✅ **Fast JWT validation** in auth service  
✅ **Clear architecture** over micro-optimizations

### What We Don't Optimize For

❌ High-volume load testing  
❌ Horizontal scaling beyond local Docker  
❌ Database query optimization  
❌ Caching layers (Redis, etc.)  
❌ Connection pooling tuning

---

## Code Style Guidelines

### Error Handling

- **Always** return appropriate HTTP status codes
- **Log errors** with sufficient context for debugging
- **Never** expose internal error details to clients
- Use structured error responses: `{ error: "message", code: "ERROR_CODE" }`

### Logging Patterns

- Prefix logs with service name: `[API]`, `[AUTH]`, `[NGINX]`
- Log all authentication attempts (success and failure)
- Log the flow of requests through the system
- Keep logs simple and readable (this is a demo)

### Documentation

- Comment complex or non-obvious architectural decisions
- Document why security patterns are implemented
- Include examples in code comments
- Keep comments educational (teaching tool)

---

## Testing Expectations (Minimal)

### What We Need

✅ Manual testing scripts (curl commands)  
✅ Verification that both flows work end-to-end  
✅ Basic error case handling (invalid tokens, missing credentials)

### What We Don't Need

❌ Unit tests  
❌ Integration test suites  
❌ Load testing  
❌ Automated CI/CD pipelines

**Testing Philosophy**: If you can successfully login, get a token, and access protected endpoints, the demo works.

---

## General Guidelines

- **Always ask clarifying questions** if the requirements are not clear
- **Break down complex tasks** into smaller, manageable steps
- **Stop and review your work** frequently to ensure accuracy and completeness
- **Prioritize code quality** and readability over performance optimizations
- **Document architectural decisions** inline with educational comments
- **Keep it simple**: This is a learning tool, not a production system
- **Focus on demonstrating patterns**: The architecture is more important than feature completeness
