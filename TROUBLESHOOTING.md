# Troubleshooting Guide

## Common Issues and Solutions

### Login Fails with Valid Credentials

**Symptom**: `401 Unauthorized` when trying to login with correct username/password

**Cause**: Bcrypt hashes in the database don't match the passwords

**Solution**:

1. Regenerate bcrypt hashes:

   ```bash
   cd api-service
   NODE_PATH=./node_modules node ../scripts/generate-hashes.js
   ```

2. Copy the generated INSERT statement into `database/02-seed.sql`

3. Reset the database:

   ```bash
   docker compose down -v  # Remove volumes
   docker compose up -d    # Restart with fresh data
   ```

4. Verify seed data was inserted:
   ```bash
   docker compose logs db | grep -i "seed"
   ```

---

### Services Won't Start

**Symptom**: `docker compose up` fails or services crash

**Check logs**:

```bash
docker compose logs          # All services
docker compose logs db       # Database only
docker compose logs auth-service  # Auth service only
docker compose logs api-service   # API service only
docker compose logs nginx    # Nginx only
```

**Common causes**:

- Port conflicts (80, 3000, 5432, 8080 already in use)
- Docker daemon not running
- Insufficient resources allocated to Docker

---

### Database Initialization Issues

**Symptom**: "relation does not exist" errors

**Solution**:

```bash
# Remove volumes and restart
docker compose down -v
docker compose up -d

# Watch initialization
docker compose logs -f db
```

Look for these log messages:

- `running /docker-entrypoint-initdb.d/01-schema.sql`
- `running /docker-entrypoint-initdb.d/02-seed.sql`
- `NOTICE: Schema created successfully`
- `NOTICE: Seed data inserted: 3 demo users`

---

### JWT Validation Fails

**Symptom**: Always get `401` even with valid token

**Check**:

1. JWT_SECRET matches between auth-service instances
2. Token hasn't expired (24 hour expiry)
3. Nginx auth_request is configured correctly

**Debug**:

```bash
# Check auth service logs
docker compose logs auth-service | grep -i "validation"

# Test JWT validation directly
curl -v http://localhost/api/v1/user/profile \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

### Cannot Access Protected Endpoints

**Symptom**: Direct API access works, but going through Nginx fails

**Check Nginx configuration**:

```bash
docker exec nginx_proxy cat /etc/nginx/conf.d/nginx.conf
```

Verify:

- `auth_request /_auth_validation;` is present
- `auth_request_set $user_id $upstream_http_x_user_id;` is present
- `proxy_set_header X-User-ID $user_id;` is present

**Reload Nginx**:

```bash
docker compose restart nginx
```

---

### Connection Refused Errors

**Symptom**: `curl: (7) Failed to connect to localhost port 80`

**Check**:

1. Services are running:

   ```bash
   docker compose ps
   ```

2. Services are healthy:

   ```bash
   docker compose logs nginx | tail -20
   ```

3. Wait for all services to be ready (especially database initialization)

---

### Go Module Dependency Issues

**Symptom**: Auth service fails to build with "module not found" errors

**Solution**:

```bash
cd auth-service
go mod download
go mod tidy
```

Then rebuild:

```bash
docker compose build auth-service
docker compose up -d
```

---

### Node.js Module Issues

**Symptom**: API service fails with "Cannot find module"

**Solution**:

```bash
cd api-service
rm -rf node_modules package-lock.json
npm install
```

Then rebuild:

```bash
docker compose build api-service
docker compose up -d
```

---

## Debugging Commands

### Check Service Health

```bash
# See all container statuses
docker compose ps

# Check specific service logs
docker compose logs -f auth-service
docker compose logs -f api-service
docker compose logs -f nginx

# Check database
docker compose exec db psql -U postgres -d database -c "SELECT * FROM users;"
```

### Network Debugging

```bash
# Test auth service directly (inside Docker network)
docker compose exec api-service curl http://auth-service:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"password123"}'

# Test API service directly
docker compose exec nginx curl http://api-service:3000/api/v1/user/profile
```

### Clean Slate

```bash
# Nuclear option - remove everything and start fresh
docker compose down -v
docker system prune -f
docker compose up --build -d
```

---

## Getting Help

If you're still stuck:

1. Check all service logs for errors
2. Verify environment variables in `docker-compose.yml`
3. Ensure Docker has enough resources (CPU, memory)
4. Try the clean slate approach above
5. Check if ports are already in use on your system

### Useful Commands

```bash
# See what's using port 80
lsof -i :80

# See what's using port 5432
lsof -i :5432

# Docker resource usage
docker stats
```
