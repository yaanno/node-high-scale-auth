# 🚀 Scaling to Thousands of Concurrent Users

> **Note**: This project is designed for learning. This document explains how to evolve the architecture for production scale with thousands of concurrent users.

---

## Current Architecture Limitations

The demo setup runs everything on a **single Docker host** with:
- 1 Nginx instance
- 1-2 Auth Service instances (Go/Rust)
- 1 API Service instance
- 1 PostgreSQL database

**This works fine for local testing, but breaks down under real load.**

---

## Scaling Strategy: The Three-Tier Approach

For **thousands of concurrent users**, you need to scale each tier independently:

```
┌──────────────────────────────────────────────────────────────────┐
│                         Load Balancer (AWS ELB)                  │
│                    (TLS/SSL termination)                          │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                    ┌────────┼────────┐
                    │        │        │
         ┌──────────▼─┐ ┌──────────┐  ┌──────────┐
         │  Nginx #1  │ │ Nginx #2 │  │ Nginx #3 │  (3-5 instances)
         └──────────┬─┘ └────┬─────┘  └────┬─────┘   (Auto-scaling group)
                    │        │             │
        ┌───────────┼────────┼─────────────┤
        │           │        │             │
┌───────▼──┐ ┌────────▼──┐ ┌────────▼──┐ ┌───────▼──┐
│ Auth #1  │ │ Auth #2   │ │ Auth #3   │ │ Auth #4  │  (6-10 instances)
│ (Go)     │ │ (Go)      │ │ (Rust)    │ │ (Rust)   │  (Auto-scaling group)
└──────────┘ └───────────┘ └───────────┘ └──────────┘
        │           │             │            │
        └───────────┼─────────────┼────────────┘
                    │             │
                    └─────────────┤────────────────────────┐
                                  │                        │
                        ┌─────────┼─────────┐              │
                        │         │         │              │
                ┌───────▼──┐ ┌─────▼───┐ ┌──▼────────┐    │
                │   API #1 │ │  API #2 │ │  API #3   │    │
                │(Node.js) │ │(Node.js)│ │ (Node.js) │    │
                └───────────┘ └─────────┘ └───────────┘    │
                        │         │         │              │
                        └────────┬┴──────┬──┘              │
                                 │      │                 │
                    ┌────────────▼┐   ┌─▼──────────┐      │
                    │ Read Replica│   │Primary DB  │      │
                    │(PostgreSQL) │   │(PostgreSQL)│      │
                    └─────────────┘   └────────────┘      │
                                           │              │
                                           └──────────────┘
                                        (Connection pooling)
```

---

## Component Scaling Analysis

### 1. **Nginx Load Balancer Tier** (Edge)

**Bottleneck at**: Connection handling, SSL/TLS termination

**Scaling strategy**:
- **Horizontal**: Deploy 3-5 Nginx instances in an auto-scaling group
- **Cloud Load Balancer**: Use AWS ALB, Google Cloud Load Balancer, or Azure LB for TLS termination
- **Configuration**: Health checks every 5 seconds, connection draining on shutdown

**Estimated capacity**:
- Single Nginx: 10,000-50,000 concurrent connections
- **3 Nginx instances**: 30,000-150,000 concurrent connections ✓

**Docker Compose equivalent**:
```yaml
services:
  nginx1:
    image: nginx:alpine
  nginx2:
    image: nginx:alpine
  nginx3:
    image: nginx:alpine
```

**Kubernetes equivalent**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-gateway
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        resources:
          requests:
            cpu: 500m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 512Mi
```

---

### 2. **Auth Service Tier** (CPU-Bound)

**Bottleneck at**: bcrypt hashing (CPU-intensive), JWT signing/verification

**Current allocation**: 2 CPU cores per instance

**Scaling strategy**:
- **Horizontal**: Scale to 6-10 instances across Go and Rust
- **Auto-scaling**: Based on CPU utilization (target 60-70%)
- **Load balancing**: Nginx upstream with least_conn or ip_hash

**Why this scales well**:
- ✅ Stateless (no shared state between instances)
- ✅ Go/Rust can use multiple threads/goroutines efficiently
- ✅ No database queries needed for validation
- ✅ bcrypt operations are CPU-bound, not I/O-bound

**Estimated capacity per instance**:
- bcrypt verification: ~50-100 logins/sec (at cost factor 12)
- JWT validation: ~1,000-5,000 validations/sec
- **6 Auth instances**: 6,000-30,000 validations/sec ✓

**Nginx upstream configuration**:
```nginx
upstream auth_service_upstream {
    least_conn;  # Load balance by least connections
    
    server auth-1:8080 weight=1;
    server auth-2:8080 weight=1;
    server auth-3:8080 weight=1;
    server auth-4:8081 weight=1;  # Rust
    server auth-5:8081 weight=1;  # Rust
    server auth-6:8081 weight=1;  # Rust
    
    # Health check (ngx_http_upstream_module)
    server auth-fallback:8080 backup;
    keepalive 32;
}
```

**Auto-scaling triggers**:
```yaml
# Kubernetes HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: auth-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: auth-service
  minReplicas: 6
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

### 3. **API Service Tier** (I/O-Bound)

**Bottleneck at**: Database connections, concurrent request handling

**Current allocation**: 0.5 CPU cores per instance

**Scaling strategy**:
- **Horizontal**: Scale to 8-15 instances
- **Auto-scaling**: Based on request latency (p95 < 100ms target)
- **Connection pooling**: Essential to avoid database connection exhaustion

**Why this scales well**:
- ✅ Node.js event loop handles thousands of concurrent connections
- ✅ Stateless (no session affinity needed)
- ✅ I/O-bound (waiting on database), not CPU-bound
- ✅ Single 0.5 CPU instance can handle 1,000+ concurrent requests

**Estimated capacity per instance**:
- **1 API instance**: 1,000-3,000 concurrent requests
- **10 API instances**: 10,000-30,000 concurrent requests ✓

**Connection pooling (critical!)**:
```javascript
// api-service/db.js
import { Pool } from 'pg';

export const pool = new Pool({
  host: process.env.DATABASE_HOST,
  port: 5432,
  database: 'database',
  user: 'postgres',
  password: 'postgres',
  
  // Connection pool settings
  max: 20,                    // Max connections per instance
  idleTimeoutMillis: 30000,   // Close idle connections
  connectionTimeoutMillis: 2000,
  
  // Application pool settings
  application_name: 'api-service'
});

// Usage
const result = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
```

**Auto-scaling triggers**:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-service
  minReplicas: 8
  maxReplicas: 30
  metrics:
  - type: Pods
    pods:
      metricName: http_requests_per_second
      targetAverageValue: "100"  # 100 req/s per instance
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
```

---

### 4. **Database Tier** (Persistent State)

**Bottleneck at**: Connection limits, read/write bottleneck, replication lag

**This is THE critical bottleneck for scaling beyond 5,000 concurrent users.**

**Current setup**: Single PostgreSQL instance

**Scaling strategy for 10,000+ concurrent users**:

#### Option A: Read Replicas + Connection Pooling (Recommended for learning → production)

```yaml
# Primary database
Primary PostgreSQL (3,000+ connections)
  ├── Streaming replication
  ├── Read Replica #1 (read-only queries)
  └── Read Replica #2 (read-only queries)

Connection Pooling:
  PgBouncer (manages 100s of app connections → fewer DB connections)
  - Pool mode: transaction (one connection per transaction)
  - Max client conn: 1000
  - Default pool size: 25 per database
```

**Connection pooling diagram**:
```
10 API instances × 20 connections = 200 app connections
           │
           ▼
    ┌──────────────┐
    │  PgBouncer   │
    │ (Connection  │
    │   Pooling)   │
    └──────────────┘
           │
           ▼
    ┌──────────────┐
    │  PostgreSQL  │
    │  (Primary)   │
    │   ~50 conns  │
    └──────────────┘
```

**PgBouncer configuration**:
```ini
[databases]
database = host=postgres-primary port=5432 dbname=database

[pgbouncer]
listen_port = 6432
max_client_conn = 1000
default_pool_size = 25
min_pool_size = 10
pool_mode = transaction
server_lifetime = 3600
server_idle_timeout = 600
```

#### Option B: PostgreSQL Sharding (for 50,000+ users)

When a single primary becomes the bottleneck:

```
┌─────────────────────────────────────┐
│  Sharding Layer (Middleware)        │
│  - Routes queries by user_id shard  │
└──────┬───────────────────┬──────────┘
       │                   │
   ┌───▼────┐         ┌────▼───┐
   │Shard 1 │         │Shard 2 │  ... Shard N
   │(users  │         │(users  │
   │1-5000) │         │5001+)  │
   └────────┘         └────────┘
```

#### Option C: Managed Database Services (Easiest for production)

- **AWS RDS with Read Replicas** (auto-scaling storage, automated backups)
- **Google Cloud SQL** (automatic failover, better than self-hosted)
- **Azure Database for PostgreSQL** (Flexible Server with Hyperscale Citus for massive scale)

---

## Resource Allocation for 10,000 Concurrent Users

### Infrastructure:

| Component | Instances | CPU per Instance | RAM per Instance | Total | Notes |
|-----------|-----------|------------------|------------------|-------|-------|
| Nginx (LB) | 3 | 1 core | 512 MB | 3 cores, 1.5 GB | Could be less |
| Auth Service (Go/Rust) | 8-10 | 2 cores | 512 MB | 16-20 cores, 4-5 GB | CPU-bound, scale on CPU |
| API Service (Node.js) | 10-15 | 0.5 cores | 256 MB | 5-7.5 cores, 2.5-3.75 GB | I/O-bound, scale on latency |
| **PostgreSQL** | 1 primary + 2 replicas | 4 cores | 16-32 GB | 12-20 cores, 48-96 GB | **Biggest cost** |
| **Total** | - | ~35-50 cores | ~55-100 GB | - | ~$1,000-5,000/month on AWS |

### Kubernetes (Recommended approach):

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: auth-system-quota
spec:
  hard:
    requests.cpu: "50"
    requests.memory: "100Gi"
    limits.cpu: "100"
    limits.memory: "200Gi"
```

---

## Performance Expectations at Scale

### Baseline (This Demo)

| Metric | Single Instance | Notes |
|--------|-----------------|-------|
| Logins/sec | 5-10 | bcrypt cost=12, bottlenecked by CPU |
| JWT validations/sec | 100-200 | Very fast, no DB queries |
| API requests/sec | 50-100 | Bottlenecked by single database connection |
| Concurrent users | 1,000 | Limited by database connections |

### Scaled (10,000 Concurrent Users)

| Metric | Scaled System | How Achieved |
|--------|---------------|-------------|
| Logins/sec | 500-1,000 | 8-10 Auth instances × 50-100 per instance |
| JWT validations/sec | 10,000-30,000 | Auth instances validate without DB |
| API requests/sec | 10,000-20,000 | 10-15 API instances × 1,000 each |
| Concurrent users | 10,000+ | Connection pooling + read replicas |
| Auth latency (p95) | <50ms | CPU-bound, but high allocation |
| API latency (p95) | 50-200ms | DB query dependent |
| Database connections | 50-100 | Connection pooling reduces from 1,000+ |

---

## Cost Analysis (AWS Estimation)

### Per-Month Costs for 10,000 Concurrent Users

| Component | Service | Instance | Count | Cost/mo |
|-----------|---------|----------|-------|---------|
| Load Balancing | ALB | Standard | 1 | $16 |
| Nginx | EC2 t3.small | 0.2 vCPU | 3 | $90 |
| Auth Service | EC2 c5.large | 2 vCPU | 10 | $500 |
| API Service | EC2 t3.medium | 0.5 vCPU | 15 | $300 |
| **Database** | **RDS Multi-AZ** | **db.r5.xlarge** | **1** | **$2,000** |
| Data Transfer | AWS | - | - | $100-200 |
| **Total** | - | - | - | **~$3,000-3,200/mo** |

**Key insight**: Database is 60-70% of infrastructure cost. At scale, consider:
- Caching layer (Redis) to reduce DB queries
- Read-heavy optimization
- Sharding to split load across multiple databases

---

## Recommended Scaling Steps

### Phase 1: Local Demo → Small Production (100-500 users)
```bash
# What you have now
docker-compose up --build
```

### Phase 2: Medium Scale (1,000-5,000 users)
```yaml
# Kubernetes deployment with:
- 3 Nginx replicas
- 4-6 Auth replicas
- 5-8 API replicas
- RDS PostgreSQL db.t3.medium
- PgBouncer for connection pooling
```

### Phase 3: Large Scale (5,000-50,000 users)
```yaml
# Kubernetes deployment with:
- 5 Nginx replicas (behind AWS ALB)
- 8-12 Auth replicas (auto-scaling)
- 15-30 API replicas (auto-scaling)
- RDS PostgreSQL db.r5.2xlarge + read replicas
- ElastiCache Redis for caching
- CloudFront CDN for static assets
```

### Phase 4: Massive Scale (50,000+ users)
```yaml
# Consider:
- Multi-region deployment with replication
- Database sharding by user_id
- Read-heavy caching (Redis/Memcached)
- API Gateway for rate limiting
- Message queue (RabbitMQ/Kafka) for async operations
- Separate read/write databases
```

---

## Critical Bottlenecks & Solutions

### Bottleneck 1: Database Connection Exhaustion
**Symptom**: `FATAL: too many connections`

**Solution**:
- ✅ Connection pooling with PgBouncer
- ✅ Reduce `max_connections` per application
- ✅ Use read replicas to distribute load

### Bottleneck 2: Database CPU/Memory
**Symptom**: Slow queries even with pooling

**Solution**:
- ✅ Add indexes on frequently queried columns
- ✅ Use read replicas for read-heavy workloads
- ✅ Implement query caching (Redis)
- ✅ Shard by user_id for massive scale

### Bottleneck 3: Auth Service CPU Exhaustion
**Symptom**: Login requests timeout at peak

**Solution**:
- ✅ Horizontal scaling (already addresses this)
- ✅ Increase bcrypt cost factor (currently 12 is good)
- ✅ Use Rust auth service (faster than Go)
- ✅ Enable CPU affinity for better cache locality

### Bottleneck 4: Nginx Connection Limits
**Symptom**: Requests rejected at reverse proxy

**Solution**:
- ✅ Increase `worker_connections` (default: 512)
- ✅ Add more Nginx instances
- ✅ Use cloud load balancer for better distribution

---

## Monitoring & Observability

At scale, you MUST have:

```yaml
Metrics (Prometheus):
  - nginx_requests_total
  - nginx_upstream_requests_total
  - auth_service_duration_seconds
  - api_service_duration_seconds
  - postgresql_connections_used
  - postgresql_query_duration_seconds

Tracing (Jaeger):
  - /login endpoint latency breakdown
  - /api/v1/* endpoint latency breakdown
  - Database query times

Logging (ELK/Datadog):
  - Failed authentication attempts
  - Slow queries (>100ms)
  - Error rates
  - Unusual access patterns
```

---

## Summary: Can This Architecture Scale to 10,000+ Users?

| Aspect | Can Scale? | How |
|--------|------------|-----|
| **Nginx** | ✅ Yes | Add more instances, use cloud ALB |
| **Auth Service** | ✅ Yes | Horizontal scaling, CPU allocation |
| **API Service** | ✅ Yes | Horizontal scaling, event loop handles thousands |
| **Database** | ⚠️ Bottleneck | Connection pooling, read replicas, caching |
| **Overall** | ✅ **Yes** | With proper database optimization |

**Verdict**: This architecture is **fundamentally sound** for 10,000+ concurrent users. The key is investing in:
1. **Database optimization** (pooling, replicas, caching)
2. **Horizontal scaling** of stateless services (trivial)
3. **Monitoring & alerting** (essential at scale)
4. **Infrastructure automation** (Kubernetes highly recommended)

The separation of CPU-bound auth service from I/O-bound API service is actually a **major advantage** at scale, because you can tune each tier independently!

---

## Additional Resources

- PostgreSQL Connection Pooling: https://wiki.postgresql.org/wiki/PgBouncer
- Kubernetes HPA: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
- AWS RDS Best Practices: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html
- Load Testing Tools: k6, Apache JMeter, Locust
