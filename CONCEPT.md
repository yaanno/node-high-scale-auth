# 🚀 Simplified Demonstration of High-Performance Node.js Service

## Purpose

This repository contains a demonstration of a **high-performance microservice architecture** built with Node.js, Express, PostgreSQL, Nginx, and a custom Auth/Hasher service. The primary goal is to illustrate how to **isolate CPU-intensive security tasks** to maximize the I/O concurrency and horizontal scalability of the single-threaded Node.js API server.

---

## Features

- **Protected API Endpoint:** Endpoint to retrieve user information.
- **Decoupled Authentication:** The security and CPU workload (hashing, JWT signing, validation) is offloaded to a dedicated high-performance service.
- **JWT Management:** Token generation and CPU-intensive validation are handled by the Auth/Hasher service.
- **External Authorization:** **Nginx** acts as the security gate, using the **auth_request** directive to enforce JWT validation before any request hits the Node.js service.
- **Stateless Node.js:** The API service only trusts a header injected by Nginx, achieving trivial scalability.
- **Dockerized Setup:** Containers are orchestrated via Docker Compose for easy local deployment.

---

## Components

| Component               | Technology            | Primary Role                                                     | Performance Priority                      |
| :---------------------- | :-------------------- | :--------------------------------------------------------------- | :---------------------------------------- |
| **API Service**         | Node.js/Express       | **Core Business Logic (I/O)**. Extracts and validates JWT claims from Authorization header. | **I/O** (Fast concurrency, low CPU)       |
| **Auth/Hasher Service** | Go/Rust (Placeholder) | **Security/Cryptography (CPU)**. Handles bcrypt and JWT logic.   | **CPU** (Fast execution, high throughput) |
| **Reverse Proxy**       | Nginx                 | **Security Gate/Routing**. Implements the auth_request pattern.  | **Edge** Routing and Policy Enforcement   |
| **Database**            | PostgreSQL            | Persistent storage for user credentials (password hashes).       | **I/O** (Used only by Auth/Hasher)        |

---

## Flows

The architecture involves two distinct user journeys.

### Flow 1: 🔑 Authentication (Initial Login/Token Generation)

This process is handled entirely between the Client, Nginx, and the Auth/Hasher service, bypassing the Node.js API service.

1.  Client sends a POST request with credentials to the **/login** endpoint.
2.  **Nginx** forwards the request **directly** to the Auth/Hasher service (no auth_request check).
3.  The Auth/Hasher service retrieves the password hash from PostgreSQL.
4.  The service performs the **CPU-intensive bcrypt comparison**.
5.  Upon success, a JWT token is **generated and signed** and returned to the client.

### Flow 2: 🔒 Authorization (Accessing Protected Resources)

This process validates the JWT before the request is allowed to reach the Node.js API.

1.  Client sends a request (with JWT in the Authorization header) to the protected **/api/v1/** endpoint.
2.  **Nginx** intercepts the request and sends a sub-request to the Auth/Hasher service's internal **/validate** endpoint (**auth_request**).
3.  The Auth/Hasher service performs the **CPU-intensive JWT validation** (signature and expiry check) without hitting the database.
    - **If valid:** It responds to Nginx with a **200 OK** status.
    - **If invalid:** It responds with a **401 Unauthorized** status, which Nginx immediately returns to the client.
4.  **Nginx** forwards the authenticated request to the **Node.js API Service** (the original Authorization header is passed through).
5.  The **Node.js API Service** extracts the JWT from the Authorization header and validates the JWT claims (issuer, audience, signature).
6.  The **Node.js API Service** reads the user ID from the JWT's subject (`sub`) claim and executes its business logic. **Its Event Loop remains safe and non-blocking.**
